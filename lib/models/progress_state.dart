import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DayStatus { locked, unlocked, completed }

class ProgressState extends ChangeNotifier {
  static const _key = 'passed_days';
  final Set<int> _passed;

  ProgressState._(this._passed);

  static Future<ProgressState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final passed = <int>{};
    for (final s in list) {
      final v = int.tryParse(s);
      if (v != null) passed.add(v);
    }
    return ProgressState._(passed);
  }

  DayStatus statusFor(int dayNumber) {
    if (_passed.contains(dayNumber)) return DayStatus.completed;
    if (dayNumber == 1 || _passed.contains(dayNumber - 1)) return DayStatus.unlocked;
    return DayStatus.locked;
  }

  int get completedCount => _passed.length;
  double get completionRatio => _passed.length / 30.0;
  bool get hasProgress => _passed.isNotEmpty;

  Future<void> markPassed(int dayNumber) async {
    if (_passed.add(dayNumber)) {
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _passed.map((e) => '$e').toList());
    }
  }

  Future<void> reset() async {
    _passed.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
