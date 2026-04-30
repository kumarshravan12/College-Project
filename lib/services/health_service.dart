import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_reading.dart';
import 'gemini_service.dart';

class HealthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _gemini = GeminiService();

  String? get _userId => _auth.currentUser?.uid;

  Future<void> saveReading({
    required double value,
    required ReadingType type,
    required String status,
  }) async {
    if (_userId == null) return;

    try {
      // Get AI advice before saving
      final advice = await _gemini.getHealthAdvice(
        value: value,
        type: type == ReadingType.heartRate ? "Heart Rate (BPM)" : "Stress Level",
        status: status,
      );

      final reading = HealthReading(
        id: '', // Firestore will generate this
        userId: _userId!,
        value: value,
        type: type,
        status: status,
        timestamp: DateTime.now(),
        advice: advice,
      );

      await _firestore.collection('health_readings').add(reading.toMap());
    } catch (e) {
      print("Error saving health reading: $e");
    }
  }

  Stream<List<HealthReading>> getReadings(ReadingType type) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('health_readings')
        .where('userId', isEqualTo: _userId)
        .where('type', isEqualTo: type.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => HealthReading.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Method to get "Smart Notifications" content
  Future<Map<String, String>> getHealthStatusSummary() async {
    // This could be used to generate a notification body
    return {
      'title': 'Daily Health Check',
      'body': 'You haven\'t checked your stress levels today. Take a moment to scan and stay mindful!',
    };
  }
}
