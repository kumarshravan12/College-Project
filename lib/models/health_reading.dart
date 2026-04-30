import 'package:cloud_firestore/cloud_firestore.dart';

enum ReadingType { heartRate, stress }

class HealthReading {
  final String id;
  final String userId;
  final double value;
  final ReadingType type;
  final String status;
  final DateTime timestamp;
  final String? advice;

  HealthReading({
    required this.id,
    required this.userId,
    required this.value,
    required this.type,
    required this.status,
    required this.timestamp,
    this.advice,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'value': value,
      'type': type.name,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'advice': advice,
    };
  }

  factory HealthReading.fromMap(String id, Map<String, dynamic> map) {
    return HealthReading(
      id: id,
      userId: map['userId'] ?? '',
      value: (map['value'] as num).toDouble(),
      type: ReadingType.values.firstWhere((e) => e.name == map['type']),
      status: map['status'] ?? 'Unknown',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      advice: map['advice'],
    );
  }
}
