import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  // IMPORTANT: Replace with your real API key or use an environment variable
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';
  
  final GenerativeModel _model;

  GeminiService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _apiKey,
        );

  Future<String> getHealthAdvice({
    required double value,
    required String type,
    required String status,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY' || _apiKey.isEmpty) {
      return "Keep monitoring your $type regularly for better health insights.";
    }

    try {
      final prompt = '''
      A user has a $type reading of $value, which is characterized as "$status".
      Provide a short, empathetic, and professional health advice (max 2 sentences).
      If the status is high, suggest relaxation or consulting a doctor.
      If it's normal, encourage them to maintain their healthy lifestyle.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "Stay healthy and keep tracking!";
    } catch (e) {
      debugPrint("Gemini Service Error: $e");
      return "Great job checking your health metrics today!";
    }
  }

  Future<String> getQuickStatus(double value, String type) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY' || _apiKey.isEmpty) {
      return value > 100 ? "High" : "Normal";
    }

    try {
      final prompt = 'A user has a $type reading of $value. Respond with ONLY ONE word characterizing this (e.g., "Excellent", "Normal", "High", "Athletic").';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim().replaceAll(RegExp(r'[\*\.]'), '') ?? "Normal";
    } catch (e) {
      return "Normal";
    }
  }
}
