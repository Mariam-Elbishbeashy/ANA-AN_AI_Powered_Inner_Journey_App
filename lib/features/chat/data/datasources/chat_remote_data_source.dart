//Interact with Firestore database to store and retrieve chat data.
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ana_ifs_app/features/chat/data/models/chat_message_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_thread_model.dart';

//Data source for chat operations in Firestore (Firebase).
class ChatRemoteDataSource {
  ChatRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _threadsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('chat_threads');
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(
    String uid,
    String threadId,
  ) {
    return _threadsRef(uid).doc(threadId).collection('messages');
  }

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('sessions');
  }

//Ensure a chat thread exists for the user and character.
  Future<ChatThreadModel> ensureChatThread({
    required String uid,
    required String characterId,
    required String characterType,
    String? sessionId,
    String? title,
  }) async {
    final query = await _threadsRef(uid)
        .where('characterId', isEqualTo: characterId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return ChatThreadModel.fromMap(doc.data(), doc.id);
    }

    final threadDoc = _threadsRef(uid).doc();
    final newSessionId = sessionId ?? _sessionsRef(uid).doc().id;

    await _sessionsRef(uid).doc(newSessionId).set({
      'type': 'chat',
      'characterId': characterId,
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await threadDoc.set({
      'characterId': characterId,
      'characterType': characterType,
      'sessionId': newSessionId,
      'title': title,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': null,
    }, SetOptions(merge: true));

    final snapshot = await threadDoc.get();
    return ChatThreadModel.fromMap(snapshot.data() ?? {}, snapshot.id);
  }

//Stream chat messages in real-time.
  Stream<List<ChatMessageModel>> streamMessages({
    required String uid,
    required String threadId,
    int limit = 50,
  }) {
    return _messagesRef(uid, threadId)
        .orderBy('createdAt')
        .limitToLast(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  //Get recent chat messages from Firestore.
  Future<List<ChatMessageModel>> getRecentMessages({
    required String uid,
    required String threadId,
    int limit = 20,
  }) async {
    final snapshot = await _messagesRef(uid, threadId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
        .toList()
        .reversed
        .toList();
  }

  //Send a new chat message to Firestore.
  Future<void> sendMessage({
    required String uid,
    required String threadId,
    required String role,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    await _messagesRef(uid, threadId).add({
      'role': role,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
    });

    await _threadsRef(uid).doc(threadId).set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
