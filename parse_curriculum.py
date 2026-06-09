#!/usr/bin/env python3
"""
parse_curriculum.py
Parses curriculum.md → assets/curriculum_data.json for the Frontend30 Flutter app.

Per-day output:
  dayNumber          int
  title              str
  phase              str
  sections           list[str]
  markdownContent    str   (cleaned markdown for flutter_markdown rendering)
  practiceQuestions  {
    easy   : [{prompt, code, expectedOutput, explanation}]
    medium : [...]
    hard   : [...]
  }
"""

import re, json
from pathlib import Path

SCRIPT_DIR  = Path(__file__).parent
CURRICULUM  = SCRIPT_DIR.parent / "untitled folder" / "curriculum.md"
OUTPUT_PATH = SCRIPT_DIR / "assets" / "curriculum_data.json"

# ── day / phase markers ───────────────────────────────────────────────────────
DAY_START_RE = re.compile(r"^#\s+📅\s+DAY\s+(\d+)\s+START", re.IGNORECASE)
DAY_END_RE   = re.compile(r"^#\s+📅\s+DAY\s+(\d+)\s+END",   re.IGNORECASE)
PHASE_RE     = re.compile(r"^#{1,2}\s+(?:🚀\s*)?Phase\s+(\d+)[:\s]+(.+)", re.IGNORECASE)
SECTION_RE   = re.compile(
    r"^#{1,3}\s+(?:[📘📚🚀🎯]\s*)?(?:MODULE|SECTION|Section|Phase)\s*[\d.:–\-A-Z]*[:\s]+(.+)",
    re.IGNORECASE,
)
CODE_FENCE_RE = re.compile(r"^```")

# ── difficulty ────────────────────────────────────────────────────────────────
_DIFF_H = re.compile(r"^#{1,4}\s+.*?\b(easy|medium|hard)\b", re.IGNORECASE)
_DIFF_B = re.compile(r"^(?:🟢\s*Easy|🟡\s*Medium|🔴\s*Hard)\s*$", re.IGNORECASE)


def detect_diff(line: str):
    for p in (_DIFF_H, _DIFF_B):
        if p.match(line):
            u = line.upper()
            if "EASY" in u:   return "easy"
            if "MEDIUM" in u: return "medium"
            if "HARD" in u:   return "hard"
    return None


# ── question patterns ─────────────────────────────────────────────────────────
FMT_A = re.compile(r"^Q\s*(\d+)\s*[:.)]\s+(.+)")                                       # Q1: What…
FMT_B = re.compile(r"^//\s*(EASY|MEDIUM|HARD)\s+Q(\d+)\s*[:.)]\s*(.*)", re.IGNORECASE) # // EASY Q1: …
FMT_C = re.compile(r"^//\s*(EASY|MEDIUM|HARD)\s+(\d+)\s*[:.)]\s*(.*)",  re.IGNORECASE) # // EASY 1: …

# Question-section separators (inside fence)
ANS_RE     = re.compile(r"^\s*(?:YOUR\s+ANSWER|Your\s+Answer)\s*:", re.IGNORECASE)
OUTPUT_RE  = re.compile(r"^\s*(?:EXPECTED\s+OUTPUT|Expected\s+Output)\s*:", re.IGNORECASE)
EXPLAIN_RE = re.compile(r"^\s*(?:EXPLANATION|Explanation)\s*[:\s]\s*(.*)", re.IGNORECASE)
SOLUTION_RE= re.compile(r"^\s*(?://\s*)?SOLUTION[:\s]", re.IGNORECASE)
BLOCK_OPEN = re.compile(r"^/\*+")
BLOCK_CLOSE= re.compile(r"\*+/\s*$")
SEP_RE     = re.compile(r"^//\s*[=─═╔╚]{3,}\s*")

# ── box-art cleanup (for markdownContent) ────────────────────────────────────
_BOX = frozenset("│┌┐└┘├┤┬┴┼─═║╔╗╚╝╠╣╦╩╬╟╞░▒▓┿╋╪╫╬")

def _is_box_only(line: str) -> bool:
    s = line.strip()
    return bool(s) and all(c in _BOX or c in " \t" for c in s)

def _strip_box(line: str) -> str:
    s = line.strip()
    while s and s[0] in _BOX: s = s[1:]
    while s and s[-1] in _BOX: s = s[:-1]
    return s.strip()


def _clean_markdown(lines: list) -> str:
    """Return cleaned markdown string from raw day lines."""
    out, blanks, in_fence = [], 0, False
    i = 0
    while i < len(lines):
        raw = lines[i].rstrip()

        # drop DAY markers and separator lines
        if DAY_START_RE.match(raw) or DAY_END_RE.match(raw) \
                or ("📅" in raw and "====" in raw):
            i += 1; continue

        # code fence toggle
        if CODE_FENCE_RE.match(raw):
            if not in_fence:
                # fix malformed ``` / language / code → ```language / code
                lang = ""
                if raw.strip() == "```" and i + 1 < len(lines):
                    nxt = lines[i + 1].strip()
                    if re.match(r"^[A-Za-z][A-Za-z0-9+#._-]*$", nxt) and nxt not in ("text",):
                        lang = nxt.lower()
                        i += 1
                out.append(f"```{lang}")
                in_fence = True
            else:
                out.append("```")
                in_fence = False
            blanks = 0; i += 1; continue

        if in_fence:
            out.append(raw); blanks = 0; i += 1; continue

        # outside fence: strip box art
        if _is_box_only(raw):
            i += 1; continue
        if any(c in _BOX for c in raw):
            raw = _strip_box(raw)
            if not raw:
                i += 1; continue

        # blank line collapse
        if not raw.strip():
            blanks += 1
            if blanks <= 2: out.append("")
        else:
            blanks = 0
            out.append(raw)
        i += 1

    return "\n".join(out).strip()


def clean_str(s: str) -> str:
    return re.sub(r"[*#`_]+", "", s).strip()


# ── rich question extraction ──────────────────────────────────────────────────

class QuestionAccumulator:
    """Collects lines for one question and builds a dict when flushed."""

    def __init__(self):
        self.reset()

    def reset(self):
        self.prompt    = None
        self.diff      = None
        self.code      = []
        self.output    = []
        self.explain   = []
        self.state     = "code"   # code | answer | output | explain | solution
        self.in_block  = False    # inside /* */ comment

    def _transition(self, new_state):
        self.state = new_state

    def feed(self, line: str):
        stripped = line.strip()

        # block comment tracking
        if BLOCK_OPEN.match(stripped):
            self.in_block = True
            return
        if self.in_block:
            if BLOCK_CLOSE.search(stripped):
                self.in_block = False
            else:
                # route block-comment lines to right bucket
                if ANS_RE.match(stripped):
                    self._transition("answer"); return
                if OUTPUT_RE.match(stripped):
                    self._transition("output"); return
                m = EXPLAIN_RE.match(stripped)
                if m:
                    self._transition("explain")
                    if m.group(1).strip():
                        self.explain.append(m.group(1).strip())
                    return
                if self.state == "output"  and stripped and stripped != "_______________":
                    self.output.append(stripped)
                elif self.state == "explain" and stripped:
                    self.explain.append(stripped)
            return

        # separator comment lines
        if SEP_RE.match(stripped):
            return

        # state transitions
        if ANS_RE.match(stripped):
            self._transition("answer"); return
        if OUTPUT_RE.match(stripped):
            self._transition("output"); return
        m = EXPLAIN_RE.match(stripped)
        if m:
            self._transition("explain")
            if m.group(1).strip():
                self.explain.append(m.group(1).strip())
            return
        if SOLUTION_RE.match(stripped):
            self._transition("solution"); return

        # accumulate
        if self.state == "code":
            if stripped and stripped != "_______________":
                # skip standalone "text" / "jsx" language-tag lines
                if not re.match(r"^(?:text|jsx|tsx|javascript|typescript)$", stripped, re.IGNORECASE):
                    self.code.append(line.rstrip())
        elif self.state == "output":
            if stripped and stripped not in ("text", "_______________"):
                self.output.append(stripped)
        elif self.state in ("explain", "solution"):
            if stripped:
                self.explain.append(stripped)

    def flush(self, buckets: dict):
        if not self.prompt or not self.diff:
            self.reset(); return
        buckets[self.diff].append({
            "prompt":         self.prompt,
            "code":           "\n".join(self.code).strip() or None,
            "expectedOutput": "\n".join(self.output).strip() or None,
            "explanation":    "\n".join(self.explain).strip() or None,
        })
        self.reset()


# ── main day parser ───────────────────────────────────────────────────────────

def parse_day(day_lines: list, current_phase_ref: list) -> dict:
    title    = ""
    sections : list = []
    buckets  = {"easy": [], "medium": [], "hard": []}

    acc      = QuestionAccumulator()
    cur_diff = None
    in_fence = False

    for line in day_lines:
        stripped = line.strip()

        # phase update
        pm = PHASE_RE.match(line)
        if pm:
            current_phase_ref[0] = f"Phase {pm.group(1)}: {clean_str(pm.group(2))}"

        # code fence toggle
        if CODE_FENCE_RE.match(line):
            if not in_fence:
                in_fence = True
            else:
                acc.flush(buckets)
                in_fence = False
            continue

        # ── inside code fence ────────────────────────────────────────────────
        if in_fence:
            # Difficulty changes inside fence
            diff = detect_diff(stripped)
            if diff:
                acc.flush(buckets)
                cur_diff = diff
                acc.diff = cur_diff
                continue

            # Format B: // EASY Q1: ...
            mb = FMT_B.match(stripped)
            if mb:
                acc.flush(buckets)
                cur_diff = mb.group(1).lower()
                acc.diff   = cur_diff
                acc.prompt = f"Q{mb.group(2)}: {mb.group(3).strip()}" if mb.group(3).strip() else f"Q{mb.group(2)}"
                continue

            # Format C: // EASY 1: ...
            mc = FMT_C.match(stripped)
            if mc and not SEP_RE.match(stripped):
                acc.flush(buckets)
                cur_diff = mc.group(1).lower()
                acc.diff   = cur_diff
                acc.prompt = f"Q{mc.group(2)}: {mc.group(3).strip()}" if mc.group(3).strip() else f"Q{mc.group(2)}"
                continue

            # Format A also appears inside fences (subsequent questions after the first)
            ma_inner = FMT_A.match(stripped)
            if ma_inner and cur_diff and acc.prompt:
                acc.flush(buckets)
                acc.diff   = cur_diff
                acc.prompt = f"Q{ma_inner.group(1)}: {ma_inner.group(2).strip()}"
                continue

            if acc.prompt:
                acc.feed(line)
            continue

        # ── outside code fence ───────────────────────────────────────────────
        # day title (first real heading)
        if not title:
            hm = re.match(r"^#{1,2}\s+(.+)", line)
            if hm:
                cand = clean_str(hm.group(1))
                if "DAY" not in cand.upper() and "📅" not in cand and cand:
                    title = cand

        # section headings
        sm = SECTION_RE.match(line)
        if sm:
            sec = clean_str(sm.group(1))
            if sec and sec not in sections:
                sections.append(sec)
            acc.flush(buckets); cur_diff = None; continue

        # difficulty markers outside fence
        diff = detect_diff(stripped)
        if diff:
            acc.flush(buckets)
            cur_diff = diff
            acc.diff  = cur_diff
            continue

        # Format A: Q1: What is the output?
        ma = FMT_A.match(stripped)
        if ma and cur_diff:
            acc.flush(buckets)
            acc.diff   = cur_diff
            acc.prompt = f"Q{ma.group(1)}: {ma.group(2).strip()}"
            continue

        # accumulate into open question (text outside fences)
        if acc.prompt and not in_fence:
            acc.feed(line)

    acc.flush(buckets)
    return {
        "title":    title or "",
        "sections": sections,
        "questions": buckets,
    }


# ── main ──────────────────────────────────────────────────────────────────────

def parse(filepath: Path) -> list:
    lines = filepath.read_text(encoding="utf-8").splitlines()

    # collect day ranges
    starts, ends = {}, {}
    for i, line in enumerate(lines):
        m = DAY_START_RE.match(line)
        if m: starts[int(m.group(1))] = i; continue
        m = DAY_END_RE.match(line)
        if m: ends[int(m.group(1))]   = i

    phase_ref = ["Phase 1: JavaScript Mastery"]
    results   = []

    for day in sorted(set(starts) & set(ends)):
        s, e    = starts[day], ends[day]
        day_lines = lines[s:e]

        day_data  = parse_day(day_lines, phase_ref)
        md_content= _clean_markdown(day_lines)

        results.append({
            "dayNumber":       day,
            "title":           day_data["title"] or f"Day {day}",
            "phase":           phase_ref[0],
            "sections":        day_data["sections"],
            "markdownContent": md_content,
            "practiceQuestions": {
                "easy":   day_data["questions"]["easy"],
                "medium": day_data["questions"]["medium"],
                "hard":   day_data["questions"]["hard"],
            },
        })

    return results


def main():
    if not CURRICULUM.exists():
        raise FileNotFoundError(f"Not found: {CURRICULUM}")

    print(f"Parsing {CURRICULUM} …")
    data = parse(CURRICULUM)
    print(f"Extracted {len(data)} days.\n")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    total_q = 0
    for d in data:
        pq = d["practiceQuestions"]
        e = len(pq["easy"]); m = len(pq["medium"]); h = len(pq["hard"])
        total_q += e + m + h
        md_kb = len(d["markdownContent"]) // 1024
        print(f"  Day {d['dayNumber']:>2}  | {d['phase'][:35]:<35} | "
              f"E/M/H={e}/{m}/{h}  md={md_kb}KB")

    size_kb = OUTPUT_PATH.stat().st_size // 1024
    print(f"\n  Total questions: {total_q}")
    print(f"  Output size: {size_kb} KB → {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
