import 'package:flutter/services.dart' show rootBundle;
import '../models/day_content.dart';

class CurriculumService {
  static const _assetPath = 'assets/curriculum_data.json';

  static CurriculumService? _instance;
  List<DayContent>? _days;

  CurriculumService._();

  static CurriculumService get instance {
    _instance ??= CurriculumService._();
    return _instance!;
  }

  Future<List<DayContent>> loadDays() async {
    if (_days != null) return _days!;
    final raw = await rootBundle.loadString(_assetPath);
    _days = DayContent.listFromJson(raw)
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return _days!;
  }

  Future<DayContent?> getDayByNumber(int dayNumber) async {
    final days = await loadDays();
    try {
      return days.firstWhere((d) => d.dayNumber == dayNumber);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, List<DayContent>>> groupedByPhase() async {
    final days = await loadDays();
    final map = <String, List<DayContent>>{};
    for (final day in days) {
      map.putIfAbsent(day.phase, () => []).add(day);
    }
    return map;
  }
}
