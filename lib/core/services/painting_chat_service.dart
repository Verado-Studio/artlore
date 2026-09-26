import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/painting.dart';

/// Thrown when the AI backend can't answer — callers should show a friendly
/// error rather than a crash.
class PaintingChatException implements Exception {
  PaintingChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One turn of a Q&A exchange about a painting.
class PaintingChatReply {
  const PaintingChatReply({required this.answer, required this.interactionId});
  final String answer;
  final String interactionId;
}

/// Answers free-form questions about a specific painting by writing a
/// "pending" request document to Firestore and waiting for a Cloud Function
/// (triggered by that write) to fill in the answer — see
/// [PaintingIdentifierService] for why this goes through Firestore rather
/// than a direct HTTP call. Follow-up turns chain via
/// [previousInteractionId] so Gemini keeps the conversation's context
/// server-side.
class PaintingChatService {
  PaintingChatService._();

  static Future<PaintingChatReply> ask({
    required Painting painting,
    required String question,
    String? previousInteractionId,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('chatRequests').doc();
    await docRef.set({
      'status': 'pending',
      'painting': {
        'title': painting.title,
        'artist': painting.artist,
        'year': painting.year,
        'movement': painting.movement,
        'museum': painting.museum,
        'stories': painting.stories,
        'details': painting.details.map((d) => {'title': d.title, 'description': d.description}).toList(),
      },
      'question': question,
      'previousInteractionId': ?previousInteractionId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    late final Map<String, dynamic> data;
    try {
      data = await docRef
          .snapshots()
          .map((snap) => snap.data())
          .where((data) => data != null && data['status'] != 'pending')
          .cast<Map<String, dynamic>>()
          .first
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw PaintingChatException('Could not reach the AI backend — check your connection and try again.');
    }

    if (data['status'] == 'error') {
      throw PaintingChatException(data['error'] as String? ?? "Couldn't get an answer — please try again.");
    }

    final answer = data['answer'] as String?;
    final interactionId = data['interactionId'] as String?;
    if (answer == null || answer.isEmpty || interactionId == null) {
      throw PaintingChatException('The AI backend returned an unexpected response.');
    }

    return PaintingChatReply(answer: answer, interactionId: interactionId);
  }
}
