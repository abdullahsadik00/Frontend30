import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/day_content.dart';
import 'struggle_record.dart';

export 'struggle_record.dart';

enum DayStatus { locked, unlocked, completed }

class ProgressState extends ChangeNotifier {
  static const _kPassed      = 'passed_days';
  static const _kStreak      = 'streak_count';
  static const _kBestStreak  = 'best_streak';
  static const _kLastAt      = 'last_completed_epoch';
  static const _kStruggles   = 'struggled_questions';
  static const _kOnboarding  = 'onboarding_done';
  static const _kScoreHistory= 'score_history';
  static const _kNotes       = 'day_notes';

  final Set<int>               _passed;
  int                          _streak;
  int                          _bestStreak;
  DateTime?                    _lastCompletedAt;
  final List<StruggleRecord>   _struggles;
  bool                         _onboardingDone;
  final Map<int, List<double>> _scoreHistory;
  final Map<int, String>       _notes;

  ProgressState._({
    required Set<int>               passed,
    required int                    streak,
    required int                    bestStreak,
    required DateTime?              lastCompletedAt,
    required List<StruggleRecord>   struggles,
    required bool                   onboardingDone,
    required Map<int, List<double>> scoreHistory,
    required Map<int, String>       notes,
  })  : _passed          = passed,
        _streak          = streak,
        _bestStreak      = bestStreak,
        _lastCompletedAt = lastCompletedAt,
        _struggles       = struggles,
        _onboardingDone  = onboardingDone,
        _scoreHistory    = scoreHistory,
        _notes           = notes;

  // ── Loader ────────────────────────────────────────────────────────────────

  static Future<ProgressState> load() async {
    final prefs = await SharedPreferences.getInstance();

    final passed = <int>{};
    for (final s in prefs.getStringList(_kPassed) ?? []) {
      final v = int.tryParse(s);
      if (v != null) passed.add(v);
    }

    final streak     = prefs.getInt(_kStreak)     ?? 0;
    final bestStreak = prefs.getInt(_kBestStreak) ?? 0;

    final lastEpoch = prefs.getInt(_kLastAt);
    final lastAt = lastEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(lastEpoch)
        : null;

    final struggles = <StruggleRecord>[];
    try {
      final raw = prefs.getString(_kStruggles);
      if (raw != null) {
        for (final e in jsonDecode(raw) as List<dynamic>) {
          struggles.add(StruggleRecord.fromJson(e as Map<String, dynamic>));
        }
      }
    } catch (_) {}

    final scoreHistory = <int, List<double>>{};
    try {
      final raw = prefs.getString(_kScoreHistory);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final key = int.tryParse(entry.key);
          if (key != null) {
            scoreHistory[key] = (entry.value as List<dynamic>)
                .map((v) => (v as num).toDouble())
                .toList();
          }
        }
      }
    } catch (_) {}

    final notes = <int, String>{};
    try {
      final raw = prefs.getString(_kNotes);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final key = int.tryParse(entry.key);
          if (key != null && entry.value is String) {
            notes[key] = entry.value as String;
          }
        }
      }
    } catch (_) {}

    return ProgressState._(
      passed:         passed,
      streak:         streak,
      bestStreak:     bestStreak,
      lastCompletedAt:lastAt,
      struggles:      struggles,
      onboardingDone: prefs.getBool(_kOnboarding) ?? false,
      scoreHistory:   scoreHistory,
      notes:          notes,
    );
  }

  // ── Day status ────────────────────────────────────────────────────────────

  DayStatus statusFor(int dayNumber) {
    if (_passed.contains(dayNumber)) return DayStatus.completed;
    if (dayNumber == 1 || _passed.contains(dayNumber - 1)) return DayStatus.unlocked;
    return DayStatus.locked;
  }

  // ── Progress metrics ──────────────────────────────────────────────────────

  int    get completedCount   => _passed.length;
  double get completionRatio  => _passed.length / 30.0;
  bool   get hasProgress      => _passed.isNotEmpty;
  bool   get isFirstLaunch    => !_onboardingDone;

  // ── Streak ────────────────────────────────────────────────────────────────

  int get currentStreak {
    if (_streak == 0 || _lastCompletedAt == null) return 0;
    return DateTime.now().difference(_lastCompletedAt!).inHours >= 48 ? 0 : _streak;
  }

  bool get isStreakAtRisk {
    if (currentStreak == 0 || _lastCompletedAt == null) return false;
    return DateTime.now().difference(_lastCompletedAt!).inHours >= 20;
  }

  int get hoursSinceLastActivity {
    if (_lastCompletedAt == null) return -1;
    return DateTime.now().difference(_lastCompletedAt!).inHours;
  }

  int get bestStreak => _bestStreak;

  // ── Struggles ─────────────────────────────────────────────────────────────

  List<StruggleRecord> get struggles =>
      List.unmodifiable(
          _struggles..sort((a, b) => b.failedAttempts.compareTo(a.failedAttempts)));

  // ── Score history ─────────────────────────────────────────────────────────

  List<double> scoresFor(int dayNumber) =>
      List.unmodifiable(_scoreHistory[dayNumber] ?? []);

  double get overallAverageScore {
    final all = _scoreHistory.values.expand((l) => l).toList();
    if (all.isEmpty) return 0;
    return all.reduce((a, b) => a + b) / all.length;
  }

  int get totalAttempts =>
      _scoreHistory.values.fold(0, (sum, l) => sum + l.length);

  // ── Notes ─────────────────────────────────────────────────────────────────

  String? noteFor(int dayNumber) => _notes[dayNumber];

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
  }

  Future<void> markPassed(int dayNumber) async {
    final now    = DateTime.now();
    final wasNew = _passed.add(dayNumber);

    if (_lastCompletedAt == null) {
      _streak = 1;
    } else {
      final last    = _lastCompletedAt!;
      final hours   = now.difference(last).inHours;
      final sameDay = last.year == now.year &&
          last.month == now.month &&
          last.day   == now.day;
      if (!sameDay && hours < 48) {
        _streak++;
      } else if (hours >= 48) {
        _streak = 1;
      }
    }
    if (_streak > _bestStreak) _bestStreak = _streak;
    _lastCompletedAt = now;

    if (wasNew) notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setStringList(_kPassed, _passed.map((e) => '$e').toList()),
      prefs.setInt(_kStreak,     _streak),
      prefs.setInt(_kBestStreak, _bestStreak),
      prefs.setInt(_kLastAt,     now.millisecondsSinceEpoch),
    ]);
  }

  Future<void> recordScore(int dayNumber, double score) async {
    _scoreHistory.putIfAbsent(dayNumber, () => []).add(score);
    notifyListeners();
    await _persistScoreHistory();
  }

  Future<void> recordStruggle({
    required int             dayNumber,
    required String          dayTopic,
    required PracticeQuestion question,
  }) async {
    final idx = _struggles.indexWhere(
        (r) => r.dayNumber == dayNumber && r.prompt == question.prompt);
    if (idx >= 0) {
      _struggles[idx] = _struggles[idx]
          .copyWith(failedAttempts: _struggles[idx].failedAttempts + 1);
    } else {
      _struggles.add(StruggleRecord(
        dayNumber:      dayNumber,
        dayTopic:       dayTopic,
        prompt:         question.prompt,
        expectedOutput: question.expectedOutput,
        explanation:    question.explanation,
        failedAttempts: 1,
        recordedAt:     DateTime.now(),
      ));
    }
    notifyListeners();
    await _persistStruggles();
  }

  Future<void> saveNote(int dayNumber, String note) async {
    if (note.trim().isEmpty) {
      _notes.remove(dayNumber);
    } else {
      _notes[dayNumber] = note;
    }
    await _persistNotes();
  }

  Future<void> reset() async {
    _passed.clear();
    _streak          = 0;
    _bestStreak      = 0;
    _lastCompletedAt = null;
    _struggles.clear();
    _scoreHistory.clear();
    _notes.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kPassed),
      prefs.remove(_kStreak),
      prefs.remove(_kBestStreak),
      prefs.remove(_kLastAt),
      prefs.remove(_kStruggles),
      prefs.remove(_kScoreHistory),
      prefs.remove(_kNotes),
    ]);
  }

  // ── Private persistence ───────────────────────────────────────────────────

  Future<void> _persistStruggles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kStruggles, jsonEncode(_struggles.map((r) => r.toJson()).toList()));
  }

  Future<void> _persistScoreHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kScoreHistory,
        jsonEncode(_scoreHistory
            .map((k, v) => MapEntry('$k', v))));
  }

  Future<void> _persistNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kNotes, jsonEncode(_notes.map((k, v) => MapEntry('$k', v))));
  }
}
