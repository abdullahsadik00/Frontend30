import 'package:flutter/material.dart';

const phaseColorMap = {
  1: Color(0xFFF59E0B),
  2: Color(0xFF3B82F6),
  3: Color(0xFF10B981),
  4: Color(0xFF8B5CF6),
  5: Color(0xFFEF4444),
  6: Color(0xFFEC4899),
};

const phaseNameMap = {
  1: 'JavaScript',
  2: 'TypeScript',
  3: 'React',
  4: 'Next.js',
  5: 'System Design',
  6: 'Interview Prep',
};

Color phaseColor(int n) => phaseColorMap[n] ?? const Color(0xFF6366F1);
String phaseName(int n) => phaseNameMap[n] ?? 'Phase $n';
