import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/day_content.dart';
import 'struggle_record.dart';

export 'struggle_record.dart';

enum DayStatus { locked, unlocked, completed }

class ProgressState extends ChangeNotifier {
  // SharedPreferences keys
  static const _kPassed    = 'passed_days';
  static const _kStreak    = 'streak_count';
  static const _kLastAt    = 'last_completed_epoch';
  static const _kStruggles = 'struggled_questions';

  final Set<int> _passed;
  int _streak;
  DateTime? _lastCompletedAt;
  final List<StruggleRecord> _struggles;

  ProgressState._({
    required Set<int> passed,
    required int streak,
    required DateTime? lastCompletedAt,
    required List<StruggleRecord> struggles,
  })  : _passed          = passed,
        _streak          = streak,
        _lastCompletedAt = lastCompletedAt,
        _struggles       = struggles;

  // ── Loader ────────────────────────────────────────────────────────────────

  static Future<ProgressState> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Passed days
    final passed = <int>{};
    for (final s in prefs.getStringList(_kPassed) ?? []) {
      final v = int.tryParse(s);
      if (v != null) passed.add(v);
    }

    // Streak
    final streak = prefs.getInt(_kStreak) ?? 0;

    // Last completed timestamp
    final lastEpoch = prefs.getInt(_kLastAt);
    final lastAt = lastEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(lastEpoch)
        : null;

    // Struggled questions
    final struggles = <StruggleRecord>[];
    try {
      final raw = prefs.getString(_kStruggles);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          struggles.add(StruggleRecord.fromJson(e as Map<String, dynamic>));
        }
      }
    } catch (_) {
      // corrupt data — start fresh
    }

    return ProgressState._(
      passed:          passed,
      streak:          streak,
      lastCompletedAt: lastAt,
      struggles:       struggles,
    );
  }

  // ── Day status ────────────────────────────────────────────────────────────

  DayStatus statusFor(int dayNumber) {
    if (_passed.contains(dayNumber)) return DayStatus.completed;
    if (dayNumber == 1 || _passed.contains(dayNumber - 1)) return DayStatus.unlocked;
    return DayStatus.locked;
  }

  // ── Progress metrics ──────────────────────────────────────────────────────

  int get completedCount => _passed.length;
  double get completionRatio => _passed.length / 30.0;
  bool get hasProgress => _passed.isNotEmpty;

  // ── Streak ────────────────────────────────────────────────────────────────

  /// Returns 0 if the streak has expired (>48 h of inactivity).
  int get currentStreak {
    if (_streak == 0 || _lastCompletedAt == null) return 0;
    final hours = DateTime.now().difference(_lastCompletedAt!).inHours;
    return hours >= 48 ? 0 : _streak;
  }

  /// True once the user hasn't completed a test for 20+ hours (but < 48 h).
  bool get isStreakAtRisk {
    if (currentStreak == 0 || _lastCompletedAt == null) return false;
    final hours = DateTime.now().difference(_lastCompletedAt!).inHours;
    return hours >= 20;
  }

  int get hoursSinceLastActivity {
    if (_lastCompletedAt == null) return -1;
    return DateTime.now().difference(_lastCompletedAt!).inHours;
  }

  // ── Struggled questions ───────────────────────────────────────────────────

  List<StruggleRecord> get struggles =>
      List.unmodifiable(_struggles..sort((a, b) => b.failedAttempts.compareTo(a.failedAttempts)));

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> markPassed(int dayNumber) async {
    final now = DateTime.now();
    final wasNew = _passed.add(dayNumber);

    // Streak logic
    if (_lastCompletedAt == null) {
      _streak = 1;
    } else {
      final last   = _lastCompletedAt!;
      final hours  = now.difference(last).inHours;
      final sameDay = last.year == now.year &&
          last.month == now.month &&
          last.day   == now.day;

      if (!sameDay && hours < 48) {
        _streak++;   // consecutive day
      } else if (hours >= 48) {
        _streak = 1; // gap > 1 day → reset
      }
      // same calendar day → streak stays the same
    }
    _lastCompletedAt = now;

    if (wasNew) notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setStringList(_kPassed, _passed.map((e) => '$e').toList()),
      prefs.setInt(_kStreak, _streak),
      prefs.setInt(_kLastAt, now.millisecondsSinceEpoch),
    ]);
  }

  Future<void> recordStruggle({
    required int dayNumber,
    required String dayTopic,
    required PracticeQuestion question,
  }) async {
    final idx = _struggles.indexWhere(
        (r) => r.dayNumber == dayNumber && r.prompt == question.prompt);

    if (idx >= 0) {
      _struggles[idx] =
          _struggles[idx].copyWith(failedAttempts: _struggles[idx].failedAttempts + 1);
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

  Future<void> reset() async {
    _passed.clear();
    _streak          = 0;
    _lastCompletedAt = null;
    _struggles.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kPassed),
      prefs.remove(_kStreak),
      prefs.remove(_kLastAt),
      prefs.remove(_kStruggles),
    ]);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _persistStruggles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kStruggles, jsonEncode(_struggles.map((r) => r.toJson()).toList()));
  }
}
