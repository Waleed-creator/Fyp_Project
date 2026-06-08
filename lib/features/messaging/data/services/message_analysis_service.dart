import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import 'package:flutter/foundation.dart';

class MessageAnalysisService {
 static const String _toxicCheckerUrl = 'http://192.168.18.41:5000/analyze'; // Flask server on LAN
// Python service URL
  
  /// Analyze a single message for toxic content
  static Future<Map<String, dynamic>> analyzeMessage(String message) async {
    try {
      debugPrint("🧩 Analyzing message: $message");
      final response = await http.post(
        Uri.parse(_toxicCheckerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': message}), // 🔹 use "text" — matches Flask
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint("📊 Result: $result");
        return result;
      } else {
        debugPrint('⚠️ Toxic service returned ${response.statusCode}');
        return {'flag': 0, 'tox_label': 'neutral', 'tox_score': 0.0};
      }
    } catch (e) {
      debugPrint('❌ Error calling toxic checker: $e');
      return {'flag': 0, 'tox_label': 'error', 'tox_score': 0.0};
    }
  }
  
  /// Analyze multiple messages
  static Future<List<Map<String, dynamic>>> analyzeMessages(List<String> messages) async {
    List<Map<String, dynamic>> results = [];
    for (final message in messages) {
      final result = await analyzeMessage(message);
      results.add(result);
    }
    return results;
  }
  
  
  /// Process child's messages and flag suspicious ones
  static Future<List<MessageModel>> processChildMessages({
    required String childId,
    required String parentId,
    required List<MessageModel> messages,
  }) async {
    List<MessageModel> flaggedMessages = [];
    
    for (final message in messages) {
      // Analyze message for toxic content
      final analysis = await analyzeMessage(message.content);
      
 if (analysis['flag'] == 1) {
  final flaggedMessage = message.copyWith(
    isSuspicious: true,
    toxicType: analysis['tox_label'] as String?,
    riskScore: (analysis['tox_score'] as num?)?.toDouble(),
    analysisData: analysis,
  );
  flaggedMessages.add(flaggedMessage);

  await _saveFlaggedMessage(          // ← add this
    childId: childId,
    parentId: parentId,
    message: message,
    analysis: analysis,
  );
}
    }
    
    return flaggedMessages;
  }
  
  static Future<void> _saveFlaggedMessage({
    required String childId,
    required String parentId,
    required MessageModel message,
    required Map<String, dynamic> analysis,
  }) async {
    final firestore = FirebaseFirestore.instance;
    await firestore
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .doc(childId)
        .collection('flagged_messages')
        .add({
      'content': message.content,
      'timestamp': message.timestamp,
      'sender': message.senderId,
      'tox_label': analysis['tox_label'] ?? 'unknown',
      'tox_score': analysis['tox_score'] ?? 0.0,
      'similarity_score': analysis['similarity_score'] ?? 0.0,
      'analyzed_at': FieldValue.serverTimestamp(),
      'analysis_source': 'flask_server',
    });
    debugPrint('✅ Saved flagged message to Firestore');
  }
}
