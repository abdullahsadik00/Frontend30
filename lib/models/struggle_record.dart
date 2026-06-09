class StruggleRecord {
  final int dayNumber;
  final String dayTopic;
  final String prompt;
  final String? expectedOutput;
  final String? explanation;
  final int failedAttempts;
  final DateTime recordedAt;

  const StruggleRecord({
    required this.dayNumber,
    required this.dayTopic,
    required this.prompt,
    this.expectedOutput,
    this.explanation,
    required this.failedAttempts,
    required this.recordedAt,
  });

  StruggleRecord copyWith({int? failedAttempts}) => StruggleRecord(
        dayNumber:      dayNumber,
        dayTopic:       dayTopic,
        prompt:         prompt,
        expectedOutput: expectedOutput,
        explanation:    explanation,
        failedAttempts: failedAttempts ?? this.failedAttempts,
        recordedAt:     recordedAt,
      );

  Map<String, dynamic> toJson() => {
        'dayNumber':      dayNumber,
        'dayTopic':       dayTopic,
        'prompt':         prompt,
        'expectedOutput': expectedOutput,
        'explanation':    explanation,
        'failedAttempts': failedAttempts,
        'recordedAt':     recordedAt.millisecondsSinceEpoch,
      };

  factory StruggleRecord.fromJson(Map<String, dynamic> j) => StruggleRecord(
        dayNumber:      j['dayNumber']      as int,
        dayTopic:       j['dayTopic']       as String? ?? '',
        prompt:         j['prompt']         as String? ?? '',
        expectedOutput: j['expectedOutput'] as String?,
        explanation:    j['explanation']    as String?,
        failedAttempts: j['failedAttempts'] as int? ?? 1,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
            j['recordedAt'] as int? ?? 0),
      );
}
