class WeightRecord {
  final String recordId;
  final String cattleId;
  final double weight;
  final String imagePath;
  final DateTime date;
  final String? notes;

  WeightRecord({
    required this.recordId,
    required this.cattleId,
    required this.weight,
    required this.imagePath,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'cattleId': cattleId,
      'weight': weight,
      'imagePath': imagePath,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      recordId: map['recordId'],
      cattleId: map['cattleId'],
      weight: map['weight'],
      imagePath: map['imagePath'],
      date: DateTime.parse(map['date']),
      notes: map['notes'],
    );
  }
}