//Interact with Firestore database to store and retrieve chat data.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:ana_ifs_app/app/config/app_config.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_message_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_session_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_thread_model.dart';

//Data source for chat operations in Firestore (Firebase).
class ChatRemoteDataSource {
  ChatRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? client,
    String? aiBaseUrl,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _aiBaseUrl = aiBaseUrl ?? AppConfig.aiBaseUrl;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _client;
  final String _aiBaseUrl;

  CollectionReference<Map<String, dynamic>> _threadsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('chat_threads');
  }

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('sessions');
  }

  /// Ensure a chat thread exists for the user and character.
  ///
  /// IMPORTANT (legacy behavior):
  /// - This method returns the *active* thread for the character if it exists.
  /// - Otherwise it creates a new `sessions/{sessionId}` doc AND a new
  ///   `chat_threads/{threadId}` doc.
  ///
  /// In the new "session history" flow we will *not* use this to start a new
  /// session, because "Start a new session" should always create a new session.
  /// We keep this method for backwards-compatibility (Guider chat, old screens).
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
      'characterType': characterType,
      'threadId': threadDoc.id,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'messageCount': 0,
      'userTurnCount': 0,
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

  /// Create a brand new chat session + thread (used by the new flow).
  ///
  /// Firestore writes:
  /// - users/{uid}/sessions/{sessionId}
  /// - users/{uid}/chat_threads/{threadId}
  ///
  /// Rationale:
  /// - We already store messages under `chat_threads/{threadId}/messages`.
  /// - Sessions act as a "timeline index" and a lock state (active vs ended).
  Future<ChatSessionModel> createNewChatSession({
    required String uid,
    required String characterId,
    required String characterType,
    String? title,
  }) async {
    final sessionDoc = _sessionsRef(uid).doc();
    final threadDoc = _threadsRef(uid).doc();

    final batch = _firestore.batch();

    batch.set(sessionDoc, {
      'type': 'chat',
      'characterId': characterId,
      'characterType': characterType,
      'threadId': threadDoc.id,
      'title': title,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': null,
      'messageCount': 0,
      'userTurnCount': 0,
    }, SetOptions(merge: true));

    batch.set(threadDoc, {
      'characterId': characterId,
      'characterType': characterType,
      'sessionId': sessionDoc.id,
      'title': title,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': null,
    }, SetOptions(merge: true));

    await batch.commit();

    // We return the session model (the UI uses it to open the thread).
    final snapshot = await sessionDoc.get();
    return ChatSessionModel.fromMap(snapshot.data() ?? {}, snapshot.id);
  }

  /// Get the currently active chat session for a character (if any).
  Future<ChatSessionModel?> getActiveChatSessionForCharacter({
    required String uid,
    required String characterId,
  }) async {
    // Intentionally avoiding Firestore composite indexes:
    // - If we add multiple `where(...)` plus `orderBy(...)`, Firestore often
    //   requires a manual composite index.
    // - For a single user's sessions, the data size is small, so filtering
    //   client-side is acceptable and makes setup easier.
    final query = await _sessionsRef(
      uid,
    ).where('characterId', isEqualTo: characterId).limit(25).get();

    final candidates = query.docs
        .map((doc) => ChatSessionModel.fromMap(doc.data(), doc.id))
        .where((s) => s.type == 'chat' && s.status == 'active')
        .toList();

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aTime =
          a.startedAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.startedAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return candidates.first;
  }

  /// Stream all chat sessions for a character (active + ended), newest first.
  Stream<List<ChatSessionModel>> streamChatSessionsForCharacter({
    required String uid,
    required String characterId,
    int limit = 50,
  }) {
    return _sessionsRef(uid)
        .where('characterId', isEqualTo: characterId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final sessions = snapshot.docs
              .map((doc) => ChatSessionModel.fromMap(doc.data(), doc.id))
              // Keep the collection flexible (future session types), but only
              // show chat sessions on this screen.
              .where((s) => s.type == 'chat')
              .toList();

          sessions.sort((a, b) {
            final aTime =
                a.startedAt ??
                a.updatedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                b.startedAt ??
                b.updatedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          return sessions;
        });
  }

  /// Stream one session document by id.
  ///
  /// Used by active chat screens to react when a session is ended externally
  /// (e.g., background auto-end flow).
  Stream<ChatSessionModel?> streamSessionById({
    required String uid,
    required String sessionId,
  }) {
    return _sessionsRef(uid).doc(sessionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatSessionModel.fromMap(doc.data() ?? {}, doc.id);
    });
  }

  /// Fetch a thread document by id.
  ///
  /// This is needed for the new session flow, where the UI navigates by
  /// `session.threadId` and wants to stream messages from that thread.
  Future<ChatThreadModel?> getThreadById({
    required String uid,
    required String threadId,
  }) async {
    final doc = await _threadsRef(uid).doc(threadId).get();
    if (!doc.exists) return null;
    return ChatThreadModel.fromMap(doc.data() ?? {}, doc.id);
  }

  /// Find a thread by `sessionId`.
  ///
  /// This is a migration helper:
  /// - Older session docs may exist without a `threadId` field.
  /// - Threads have always stored `sessionId`, so we can recover the link.
  Future<ChatThreadModel?> getThreadBySessionId({
    required String uid,
    required String sessionId,
  }) async {
    final query = await _threadsRef(
      uid,
    ).where('sessionId', isEqualTo: sessionId).limit(1).get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return ChatThreadModel.fromMap(doc.data(), doc.id);
  }

  /// Store the threadId link on the session document.
  ///
  /// This makes session history navigation stable (open by threadId).
  Future<void> setSessionThreadId({
    required String uid,
    required String sessionId,
    required String threadId,
  }) async {
    await _sessionsRef(uid).doc(sessionId).set({
      'threadId': threadId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// End a chat session (locks it into history).
  ///
  /// What "end" means:
  /// - `sessions/{sessionId}.status` becomes `"ended"` and `endedAt` is set.
  /// - `chat_threads/{threadId}.status` becomes `"ended"`.
  ///
  /// After this, we treat the session as read-only in the UI.
  Future<void> endChatSession({
    required String uid,
    required String sessionId,
    required String threadId,
  }) async {
    final batch = _firestore.batch();
    batch.set(_sessionsRef(uid).doc(sessionId), {
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_threadsRef(uid).doc(threadId), {
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  //Stream chat messages in real-time.
  Stream<List<ChatMessageModel>> streamMessages({
    required String uid,
    required String threadId,
    int limit = 50,
  }) {
    // Backend-only decrypt policy: poll secure backend endpoint instead of
    // reading ciphertext directly from Firestore.
    final safeLimit = limit < 1 ? 1 : limit;
    return (() async* {
      yield await getRecentMessages(
        uid: uid,
        threadId: threadId,
        limit: safeLimit,
      );
      yield* Stream<void>.periodic(const Duration(seconds: 2)).asyncMap(
        (_) =>
            getRecentMessages(uid: uid, threadId: threadId, limit: safeLimit),
      );
    })();
  }

  /// Arm backend auto-end fallback for a still-active session.
  Future<void> setSessionAutoEndAt({
    required String uid,
    required String sessionId,
    required DateTime autoEndAt,
  }) async {
    await _sessionsRef(uid).doc(sessionId).set({
      'autoEndAt': Timestamp.fromDate(autoEndAt.toUtc()),
      'autoEndArmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Clear backend auto-end fallback when user returns/ends manually.
  Future<void> clearSessionAutoEndAt({
    required String uid,
    required String sessionId,
  }) async {
    await _sessionsRef(uid).doc(sessionId).set({
      'autoEndAt': FieldValue.delete(),
      'autoEndArmedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  //Get recent chat messages from Firestore.
  Future<List<ChatMessageModel>> getRecentMessages({
    required String uid,
    required String threadId,
    int limit = 20,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final idToken = await user.getIdToken();
    final uri = Uri.parse('$_aiBaseUrl/messages/recent');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: json.encode({'uid': uid, 'threadId': threadId, 'limit': limit}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Messages API error: ${response.statusCode}');
    }
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'Failed to fetch messages');
    }
    final messages = (decoded['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              ChatMessageModel.fromMap(item, item['id']?.toString() ?? ''),
        )
        .toList();
    return messages;
  }

  //Send a new chat message to Firestore.
  Future<void> sendMessage({
    required String uid,
    required String threadId,
    required String role,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final idToken = await user.getIdToken();
    final uri = Uri.parse('$_aiBaseUrl/messages/append');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: json.encode({
        'uid': uid,
        'threadId': threadId,
        'role': role,
        'content': content,
        'metadata': metadata,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Messages API error: ${response.statusCode}');
    }
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'Failed to send message');
    }
  }
}
