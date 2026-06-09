import 'package:flutter/material.dart';
import '../models/day_content.dart';
import '../models/progress_state.dart';
import '../utils/phase_colors.dart';
import '../widgets/progress_scope.dart';
import '../screens/day_detail_screen.dart';

enum _HitType { day, question }

class _SearchHit {
  final DayContent day;
  final _HitType type;
  final String snippet;
  const _SearchHit({
    required this.day,
    required this.type,
    required this.snippet,
  });
}

// ── Delegate ──────────────────────────────────────────────────────────────────

class DaySearchDelegate extends SearchDelegate<DayContent?> {
  final List<DayContent> days;
  DaySearchDelegate(this.days);

  @override
  String get searchFieldLabel => 'Search days, topics, questions…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = super.appBarTheme(context);
    return theme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) return _buildEmpty(context);
    return _buildResultList(context, _filter());
  }

  @override
  Widget buildResults(BuildContext context) =>
      _buildResultList(context, _filter());

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<_SearchHit> _filter() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final hits = <_SearchHit>[];

    for (final day in days) {
      // Day-level match (title / topic / "day N")
      if (day.shortTopic.toLowerCase().contains(q) ||
          day.title.toLowerCase().contains(q) ||
          'day ${day.dayNumber}'.contains(q)) {
        hits.add(_SearchHit(
          day: day,
          type: _HitType.day,
          snippet: day.phaseShort,
        ));
      }

      // Question-level match
      for (final question in [
        ...day.practiceQuestions.easy,
        ...day.practiceQuestions.medium,
        ...day.practiceQuestions.hard,
      ]) {
        if (question.prompt.toLowerCase().contains(q)) {
          hits.add(_SearchHit(
            day: day,
            type: _HitType.question,
            snippet: question.prompt,
          ));
        }
      }
    }

    return hits;
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Browse by phase',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: phaseNameMap.entries.map((e) {
            final color = phaseColor(e.key);
            return ActionChip(
              avatar: CircleAvatar(
                backgroundColor: color,
                radius: 7,
              ),
              label: Text(e.value),
              onPressed: () => query = e.value,
              backgroundColor: color.withValues(alpha: 0.1),
              side: BorderSide(color: color.withValues(alpha: 0.3)),
              labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              Icon(Icons.search, size: 40, color: cs.outlineVariant),
              const SizedBox(height: 8),
              Text('Type to search days or questions',
                  style: tt.bodySmall?.copyWith(color: cs.outline)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultList(BuildContext context, List<_SearchHit> hits) {
    if (hits.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('No results for "$query"',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.outline)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: hits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) => _HitTile(
        hit: hits[i],
        query: query,
        onTap: () {
          close(ctx, hits[i].day);
          final status =
              ProgressScope.of(ctx).statusFor(hits[i].day.dayNumber);
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => DayDetailScreen(
                day: hits[i].day,
                status: status,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Hit tile ──────────────────────────────────────────────────────────────────

class _HitTile extends StatelessWidget {
  final _SearchHit hit;
  final String query;
  final VoidCallback onTap;
  const _HitTile({required this.hit, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final color = phaseColor(hit.day.phaseNumber);
    final isQ   = hit.type == _HitType.question;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          '${hit.day.dayNumber}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      title: _HighlightText(
        text: isQ ? hit.day.shortTopic : hit.day.shortTopic,
        highlight: query,
        baseStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: _HighlightText(
        text: isQ ? hit.snippet : hit.snippet,
        highlight: query,
        baseStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        maxLines: 2,
      ),
      trailing: isQ
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Q',
                style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

// ── Highlight text ────────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String highlight;
  final TextStyle baseStyle;
  final int maxLines;

  const _HighlightText({
    required this.text,
    required this.highlight,
    required this.baseStyle,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final q = highlight.toLowerCase();
    if (q.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines,
          overflow: TextOverflow.ellipsis);
    }

    final lower = text.toLowerCase();
    final idx   = lower.indexOf(q);
    if (idx < 0) {
      return Text(text, style: baseStyle, maxLines: maxLines,
          overflow: TextOverflow.ellipsis);
    }

    final cs = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(children: [
        if (idx > 0)
          TextSpan(text: text.substring(0, idx), style: baseStyle),
        TextSpan(
          text: text.substring(idx, idx + q.length),
          style: baseStyle.copyWith(
            backgroundColor: cs.primaryContainer,
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (idx + q.length < text.length)
          TextSpan(
            text: text.substring(idx + q.length),
            style: baseStyle,
          ),
      ]),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
