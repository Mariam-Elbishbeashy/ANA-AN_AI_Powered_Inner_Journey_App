import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/questionnaire/domain/entities/question.dart';
import 'package:ana_ifs_app/features/questionnaire/domain/entities/user_answer.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import '../../features/progress/domain/entities/stable_character_history.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static StreamSubscription<QuerySnapshot>? _stableCharactersRealtimeSyncSubscription;
  static String? _stableCharactersRealtimeSyncUserId;
  static final Map<String, String> _lastKnownCharacterStates = <String, String>{};
  static final Map<String, String> _lastKnownCharacterStableAt = <String, String>{};
  static final Map<String, String> _pendingStableHistoryStableAt = <String, String>{};

  // Simple in-memory cache while the app is open.
  // It prevents repeated Firestore reads / visible reloads when opening pages.
  static final Map<String, List<Question>> _questionsCache = <String, List<Question>>{};
  static final Map<String, int> _questionCountCache = <String, int>{};
  static final Map<String, List<UserCharacter>> _userCharactersCache =
  <String, List<UserCharacter>>{};
  static final Map<String, int> _userQuestionnaireCountCache =
  <String, int>{};

  String _questionCacheKey(String language) => language.trim().toLowerCase();

  List<Question>? getCachedQuestions(String language) {
    final cached = _questionsCache[_questionCacheKey(language)];
    if (cached == null) return null;
    return List<Question>.from(cached);
  }

  int? getCachedQuestionCount(String language) {
    return _questionCountCache[_questionCacheKey(language)];
  }

  List<UserCharacter>? getCachedUserCharacters() {
    final userId = currentUserId;
    if (userId == null) return null;

    final cached = _userCharactersCache[userId];
    if (cached == null) return null;
    return List<UserCharacter>.from(cached);
  }

  int? getCachedUserQuestionnaireQuestionCount() {
    final userId = currentUserId;
    if (userId == null) return null;
    return _userQuestionnaireCountCache[userId];
  }

  void _cacheUserQuestionnaireQuestionCount(
      String userId,
      int count,
      ) {
    if (count > 0) {
      _userQuestionnaireCountCache[userId] = count;
    }
  }

  void invalidateUserQuestionnaireQuestionCountCache([String? userId]) {
    final id = userId ?? currentUserId;
    if (id == null) {
      _userQuestionnaireCountCache.clear();
      return;
    }

    _userQuestionnaireCountCache.remove(id);
  }

  void invalidateQuestionsCache([String? language]) {
    if (language == null) {
      _questionsCache.clear();
      _questionCountCache.clear();
      return;
    }

    final cacheKey = _questionCacheKey(language);
    _questionsCache.remove(cacheKey);
    _questionCountCache.remove(cacheKey);
  }

  void invalidateUserCharactersCache([String? userId]) {
    final id = userId ?? currentUserId;
    if (id == null) {
      _userCharactersCache.clear();
      return;
    }

    _userCharactersCache.remove(id);
  }

  // Questions Collection
  CollectionReference get questionsCollection =>
      _firestore.collection('questions');

  // User Answers Collection
  CollectionReference get userAnswersCollection =>
      _firestore.collection('user_answers');

  // User Characters Collection
  CollectionReference get userCharactersCollection =>
      _firestore.collection('user_characters');

  // Stable Character History Collection
  CollectionReference get stableCharacterHistoryCollection =>
      _firestore.collection('user_character_stable_history');

  // Users Collection
  CollectionReference get usersCollection => _firestore.collection('users');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ============= QUESTION METHODS =============

  // Fetch all questions for a specific language.
  // Uses an in-memory cache so pages do not refetch the same questions
  // every time they open. Use forceRefresh when you add questions or retake.
  Future<List<Question>> getQuestions(
      String language, {
        bool forceRefresh = false,
      }) async {
    final cacheKey = _questionCacheKey(language);

    if (!forceRefresh && _questionsCache.containsKey(cacheKey)) {
      return List<Question>.from(_questionsCache[cacheKey]!);
    }

    try {
      print('📥 Fetching questions for language: $language');

      final querySnapshot = await questionsCollection
          .where('language', isEqualTo: language)
          .orderBy('questionNumber')
          .get();

      final questions = querySnapshot.docs
          .map((doc) {
        try {
          return Question.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        } catch (e) {
          print('❌ Error parsing question ${doc.id}: $e');
          return null;
        }
      })
          .where((question) => question != null)
          .cast<Question>()
          .toList()
        ..sort((a, b) => a.questionNumber.compareTo(b.questionNumber));

      _questionsCache[cacheKey] = List<Question>.from(questions);
      _questionCountCache[cacheKey] = questions.length;

      print('✅ Loaded ${questions.length} questions for $language');
      return List<Question>.from(questions);
    } catch (e, stackTrace) {
      print('❌ ERROR fetching questions for language $language: $e');
      print('📝 Stack trace: $stackTrace');

      final cached = _questionsCache[cacheKey];
      if (cached != null) {
        return List<Question>.from(cached);
      }

      return [];
    }
  }

  // Watch question count. This updates the cache only when Firestore changes,
  // so Profile can show 26 automatically without doing a visible reload.
  Stream<int> watchQuestionCount(String language) {
    final cacheKey = _questionCacheKey(language);

    return questionsCollection
        .where('language', isEqualTo: language)
        .snapshots()
        .map((snapshot) {
      _questionCountCache[cacheKey] = snapshot.docs.length;

      // The number changed, so the stored question list may be stale.
      // The next questionnaire load will fetch the new 26 questions.
      _questionsCache.remove(cacheKey);

      return snapshot.docs.length;
    });
  }

  // Get a specific question
  Future<Question?> getQuestion(int questionNumber, String language) async {
    try {
      final querySnapshot = await questionsCollection
          .where('questionNumber', isEqualTo: questionNumber)
          .where('language', isEqualTo: language)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Question.fromMap(
          querySnapshot.docs.first.data() as Map<String, dynamic>,
          querySnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting question: $e');
      return null;
    }
  }

  // Add a question (for admin use)
  Future<void> addQuestion(Question question) async {
    try {
      await questionsCollection.add(question.toMap());
    } catch (e) {
      print('Error adding question: $e');
      throw e;
    }
  }

  // ============= USER ANSWERS METHODS =============

  // Save user answer - UPDATED: Returns the document ID
  Future<String?> saveAnswer(UserAnswer answer) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      // Generate a consistent document ID based on user and question
      final docId = '${userId}_q${answer.questionNumber}';

      // Save or update the answer
      await userAnswersCollection.doc(docId).set({
        'userId': userId,
        'questionNumber': answer.questionNumber,
        'answerText': answer.answerText,
        'selectedIndices': answer.selectedIndices,
        'sliderValue': answer.sliderValue,
        'language': answer.language,
        'answeredAt': answer.answeredAt.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print(
        '💾 Saved/Updated answer for Q${answer.questionNumber} with ID: $docId',
      );
      return docId;
    } catch (e) {
      print('❌ Error saving answer to Firestore: $e');
      throw e;
    }
  }

  // Get user's answer for a specific question - UPDATED
  Future<UserAnswer?> getUserAnswer(int questionNumber) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final docId = '${userId}_q${questionNumber}';
      final doc = await userAnswersCollection.doc(docId).get();

      if (doc.exists) {
        return UserAnswer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user answer: $e');
      return null;
    }
  }

  // Get all user answers - UPDATED: Query by user ID prefix
  Future<List<UserAnswer>> getAllUserAnswers() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final querySnapshot = await userAnswersCollection
          .where('userId', isEqualTo: userId)
          .orderBy('questionNumber')
          .get();

      return querySnapshot.docs
          .map(
            (doc) =>
            UserAnswer.fromMap(doc.data() as Map<String, dynamic>, doc.id),
      )
          .toList();
    } catch (e) {
      print('Error getting all user answers: $e');
      return [];
    }
  }

  Future<int> getCompletedAnswerCount() async {
    final userId = currentUserId;
    if (userId == null) return 0;

    try {
      final snapshot = await userAnswersCollection
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting completed answer count: $e');
      return 0;
    }
  }

  Future<void> saveUserQuestionnaireQuestionCount(
      int count, {
        String? language,
        bool completed = false,
      }) async {
    final userId = currentUserId;
    if (userId == null || count <= 0) return;

    int finalCount = count;
    try {
      final existingDoc = await usersCollection.doc(userId).get();
      final existingData = existingDoc.data() as Map<String, dynamic>?;
      final existingRaw = existingData?['questionnaireQuestionCount'];
      final existingCount = existingRaw is int
          ? existingRaw
          : existingRaw is num
          ? existingRaw.toInt()
          : 0;

      // Never let an older 13 overwrite a newer 26 while the app is open.
      if (existingCount > finalCount) {
        finalCount = existingCount;
      }
    } catch (e) {
      print('Could not check existing questionnaireQuestionCount: $e');
    }

    await usersCollection.doc(userId).set({
      'questionnaireQuestionCount': finalCount,
      'questionnaireLanguage': language ?? await getUserLanguage(),
      'questionnaireQuestionCountUpdatedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      if (completed) 'questionnaireAnsweredCount': finalCount,
    }, SetOptions(merge: true));

    _cacheUserQuestionnaireQuestionCount(userId, finalCount);
  }

  Future<int> recordCompletedQuestionnaireAttempt({
    required int currentAttemptQuestionCount,
    String? language,
  }) async {
    final userId = currentUserId;
    if (userId == null || currentAttemptQuestionCount <= 0) return 0;

    final selectedLanguage = language ?? await getUserLanguage();
    final nowIso = DateTime.now().toIso8601String();
    final userRef = usersCollection.doc(userId);

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final newTotal = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() as Map<String, dynamic>? ?? <String, dynamic>{};

      // This field is cumulative: first completion = 13,
      // first retake completion = 26, second retake completion = 39, etc.
      final previousTotal = toInt(
        data['questionnaireQuestionCount'] ??
            data['questionnaireTotalAnsweredCount'] ??
            data['questionnaireAnsweredCount'],
      );

      final savedAttemptCount = toInt(data['questionnaireAttemptCount']);
      final startedRetakeCount = toInt(data['questionnaireRetakeStartedCount']);
      final inferredAttemptCount = previousTotal > 0
          ? (previousTotal / currentAttemptQuestionCount).floor()
          : 0;
      final previousAttemptCount = savedAttemptCount > 0
          ? savedAttemptCount
          : inferredAttemptCount;

      var updatedAttemptCount = previousAttemptCount + 1;

      // If this completion came after pressing Retake, make sure the attempt
      // count reflects that retake even if an older buggy version had saved
      // questionnaireQuestionCount as only 13.
      final minimumAttemptCountFromRetakes = startedRetakeCount + 1;
      if (minimumAttemptCountFromRetakes > updatedAttemptCount) {
        updatedAttemptCount = minimumAttemptCountFromRetakes;
      }

      final updatedRetakeCount = updatedAttemptCount > 0
          ? updatedAttemptCount - 1
          : 0;

      var updatedTotal = previousTotal + currentAttemptQuestionCount;
      final minimumTotalFromAttempts =
          updatedAttemptCount * currentAttemptQuestionCount;
      if (minimumTotalFromAttempts > updatedTotal) {
        updatedTotal = minimumTotalFromAttempts;
      }

      transaction.set(userRef, {
        'hasCompletedQuestionnaire': true,
        'questionnaireCompletedAt': nowIso,
        'questionnaireLanguage': selectedLanguage,

        // Main number shown in Profile.
        'questionnaireQuestionCount': updatedTotal,

        // Extra explicit fields for clarity/debugging.
        'questionnaireTotalAnsweredCount': updatedTotal,
        'questionnaireAnsweredCount': updatedTotal,
        'questionnaireLastAttemptQuestionCount': currentAttemptQuestionCount,
        'questionnaireAttemptCount': updatedAttemptCount,
        'questionnaireRetakeCount': updatedRetakeCount,
        'questionnaireQuestionCountUpdatedAt': nowIso,
        'updatedAt': nowIso,
      }, SetOptions(merge: true));

      return updatedTotal;
    });

    _cacheUserQuestionnaireQuestionCount(userId, newTotal);

    print(
      '✅ Cumulative questionnaireQuestionCount saved for $userId: $newTotal',
    );
    return newTotal;
  }

  Future<int> getUserQuestionnaireQuestionCount({
    String? language,
    bool forceRefresh = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) return 0;

    if (!forceRefresh && _userQuestionnaireCountCache.containsKey(userId)) {
      return _userQuestionnaireCountCache[userId]!;
    }

    try {
      final doc = forceRefresh
          ? await usersCollection.doc(userId).get(
        const GetOptions(source: Source.server),
      )
          : await usersCollection.doc(userId).get();

      final data = doc.data() as Map<String, dynamic>?;
      final savedCount = data?['questionnaireQuestionCount'];

      if (savedCount is int && savedCount > 0) {
        _cacheUserQuestionnaireQuestionCount(userId, savedCount);
        return savedCount;
      }

      if (savedCount is num && savedCount > 0) {
        final count = savedCount.toInt();
        _cacheUserQuestionnaireQuestionCount(userId, count);
        return count;
      }
    } catch (e) {
      print('Error getting user questionnaireQuestionCount: $e');
    }

    final answeredCount = await getCompletedAnswerCount();
    if (answeredCount > 0) {
      _cacheUserQuestionnaireQuestionCount(userId, answeredCount);
      return answeredCount;
    }

    return 0;
  }

  Stream<int> watchUserQuestionnaireQuestionCount({
    String? language,
  }) {
    final userId = currentUserId;
    if (userId == null) return const Stream<int>.empty();

    return usersCollection.doc(userId).snapshots().asyncMap((doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      final savedCount = data?['questionnaireQuestionCount'];

      if (savedCount is int && savedCount > 0) {
        _cacheUserQuestionnaireQuestionCount(userId, savedCount);
        return savedCount;
      }

      if (savedCount is num && savedCount > 0) {
        final count = savedCount.toInt();
        _cacheUserQuestionnaireQuestionCount(userId, count);
        return count;
      }

      return getUserQuestionnaireQuestionCount(
        language: language,
        forceRefresh: false,
      );
    });
  }

  // Get the current number of questionnaire questions for a language.
  // Uses the cached question list/count when available.
  Future<int> getQuestionCount([
    String? language,
    bool forceRefresh = false,
  ]) async {
    try {
      final selectedLanguage = language ?? await getUserLanguage();
      final cacheKey = _questionCacheKey(selectedLanguage);

      if (!forceRefresh && _questionCountCache.containsKey(cacheKey)) {
        return _questionCountCache[cacheKey]!;
      }

      final questions = await getQuestions(
        selectedLanguage,
        forceRefresh: forceRefresh,
      );

      _questionCountCache[cacheKey] = questions.length;
      return questions.length;
    } catch (e) {
      print('Error getting question count: $e');
      return 0;
    }
  }

  // Check if user has completed questionnaire
  Future<bool> hasCompletedQuestionnaire() async {
    try {
      // If predicted characters already exist, the questionnaire is complete.
      final hasCharacters = await hasUserCharacters();
      if (hasCharacters) return true;

      final language = await getUserLanguage();
      final requiredQuestionCount = await getQuestionCount(language, true);
      if (requiredQuestionCount == 0) return false;

      final answers = await getAllUserAnswers();
      return answers.length >= requiredQuestionCount;
    } catch (e) {
      print('Error checking questionnaire completion: $e');
      return false;
    }
  }

  // ============= USER CHARACTERS METHODS =============

  // Save user's predicted characters - UPDATED with healing status
  Future<void> saveUserCharacters(
      List<UserCharacter> characters, {
        int? questionCount,
      }) async {
    try {
      // Delete existing characters for this user
      await deleteUserCharacters();

      // Save new characters with consistent IDs
      final userId = currentUserId;
      if (userId != null) {
        _userCharactersCache[userId] = List<UserCharacter>.from(characters);

        for (final character in characters) {
          final docId = '${userId}_char_${character.rank}';
          // Save with bilingual fields
          await userCharactersCollection.doc(docId).set({
            'userId': character.userId,
            'characterName': character.characterName,
            'displayNameEn': character.displayNameEn,
            'displayNameAr': character.displayNameAr,
            'archetype': character.archetype,
            'confidence': character.confidence,
            'rank': character.rank,
            'language': character.language,
            'glbFileName': character.glbFileName,
            'descriptionEn': character.descriptionEn,
            'descriptionAr': character.descriptionAr,
            'predictedAt': character.predictedAt.toIso8601String(),
            'isHealed': false, // Default to unhealed when created
            'healedAt': null,
            'currentState': character.currentState,
          });
        }

        var currentAttemptQuestionCount = questionCount ?? 0;
        if (currentAttemptQuestionCount <= 0) {
          currentAttemptQuestionCount = await getCompletedAnswerCount();
        }
        if (currentAttemptQuestionCount <= 0) {
          currentAttemptQuestionCount = await getQuestionCount(
            characters.first.language,
            true,
          );
        }

        await recordCompletedQuestionnaireAttempt(
          currentAttemptQuestionCount: currentAttemptQuestionCount,
          language: characters.first.language,
        );
      }
    } catch (e) {
      print('Error saving user characters: $e');
      throw e;
    }
  }

  // Get ALL user's characters (both healed and unhealed).
  // Returns cached characters first unless forceRefresh is true.
  Future<List<UserCharacter>> getUserCharacters({
    bool forceRefresh = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];

    if (!forceRefresh && _userCharactersCache.containsKey(userId)) {
      return List<UserCharacter>.from(_userCharactersCache[userId]!);
    }

    try {
      final querySnapshot = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .orderBy('rank')
          .get();

      final characters = querySnapshot.docs
          .map(
            (doc) => UserCharacter.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();

      _userCharactersCache[userId] = List<UserCharacter>.from(characters);
      return List<UserCharacter>.from(characters);
    } catch (e) {
      print('Error getting user characters: $e');

      final cached = _userCharactersCache[userId];
      if (cached != null) {
        return List<UserCharacter>.from(cached);
      }

      return [];
    }
  }

  // Listen for actual updates to user characters and update the cache.
  // Profile can subscribe to this without showing a loading state.
  Stream<List<UserCharacter>> watchUserCharacters() {
    final userId = currentUserId;
    if (userId == null) return const Stream<List<UserCharacter>>.empty();

    return userCharactersCollection
        .where('userId', isEqualTo: userId)
        .orderBy('rank')
        .snapshots()
        .map((snapshot) {
      final characters = snapshot.docs
          .map(
            (doc) => UserCharacter.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();

      _userCharactersCache[userId] = List<UserCharacter>.from(characters);
      return List<UserCharacter>.from(characters);
    });
  }

  // Get only UNHEALED user characters (for home and profile)
  Future<List<UserCharacter>> getUnhealedCharacters() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final querySnapshot = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .where('isHealed', isEqualTo: false) // Only unhealed
          .orderBy('rank')
          .get();

      return querySnapshot.docs
          .map(
            (doc) => UserCharacter.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();
    } catch (e) {
      print('Error getting unhealed characters: $e');
      return [];
    }
  }

  // Get only HEALED user characters
  Future<List<UserCharacter>> getHealedCharacters() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final querySnapshot = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .where('isHealed', isEqualTo: true) // Only healed
          .orderBy('healedAt', descending: true) // Most recent first
          .get();

      return querySnapshot.docs
          .map(
            (doc) => UserCharacter.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();
    } catch (e) {
      print('Error getting healed characters: $e');
      return [];
    }
  }

  // Mark a character as healed
  Future<void> markCharacterAsHealed(String characterId) async {
    try {
      await userCharactersCollection.doc(characterId).update({
        'isHealed': true,
        'healedAt': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Character $characterId marked as healed');
    } catch (e) {
      print('Error marking character as healed: $e');
      throw e;
    }
  }

  // Mark a character as unhealed
  Future<void> markCharacterAsUnhealed(String characterId) async {
    try {
      await userCharactersCollection.doc(characterId).update({
        'isHealed': false,
        'healedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Character $characterId marked as unhealed');
    } catch (e) {
      print('Error marking character as unhealed: $e');
      throw e;
    }
  }

  Future<List<UserCharacter>> getCharactersByState(String state) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final querySnapshot = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .where('currentState', isEqualTo: state)
          .orderBy('rank')
          .get();

      return querySnapshot.docs
          .map(
            (doc) => UserCharacter.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();
    } catch (e) {
      print('Error getting characters by state: $e');
      return [];
    }
  }

  static final Set<String> _stableHistoryWriteInProgress = <String>{};

  String _buildStableHistoryDocId(String userId, String characterId, DateTime stableAt) {
    return '${userId}_${characterId}_${stableAt.millisecondsSinceEpoch}';
  }

  String? _normalizeState(dynamic value) {
    final state = value?.toString().trim().toLowerCase();
    if (state == null || state.isEmpty) return null;
    return state;
  }

  DateTime? _parseFlexibleDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  DateTime _currentStableTimestamp() {
    return DateTime.now();
  }

  DateTime _resolveStableDate(
      Map<String, dynamic> data, {
        DateTime? preferredStableAt,
      }) {
    return preferredStableAt ??
        _parseFlexibleDate(data['stableAt']) ??
        _parseFlexibleDate(data['updatedAt']) ??
        _parseFlexibleDate(data['predictedAt']) ??
        DateTime.now();
  }

  Future<bool> _historyEntryExists(
      String userId,
      String characterId,
      DateTime stableAt,
      ) async {
    final docId = _buildStableHistoryDocId(userId, characterId, stableAt);
    final doc = await stableCharacterHistoryCollection.doc(docId).get();
    return doc.exists;
  }

  Future<bool> _historyEntryExistsForExactStableAt(
      String userId,
      String characterId,
      DateTime stableAt,
      ) async {
    if (await _historyEntryExists(userId, characterId, stableAt)) {
      return true;
    }

    final stableIso = stableAt.toIso8601String();
    final query = await stableCharacterHistoryCollection
        .where('userId', isEqualTo: userId)
        .where('sourceCharacterId', isEqualTo: characterId)
        .where('stableAt', isEqualTo: stableIso)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<DateTime> _ensureStableAtOnCharacterDoc(
      String characterId,
      Map<String, dynamic> data, {
        DateTime? preferredStableAt,
        bool forceNewDate = false,
      }) async {
    final existingStableAt = _parseFlexibleDate(data['stableAt']);
    if (!forceNewDate && existingStableAt != null) {
      return existingStableAt;
    }

    final stableDate = forceNewDate
        ? _currentStableTimestamp()
        : _resolveStableDate(
      data,
      preferredStableAt: preferredStableAt,
    );

    await userCharactersCollection.doc(characterId).set({
      'stableAt': stableDate.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return stableDate;
  }

  Map<String, dynamic> _mergeCharacterSnapshotData(
      Map<String, dynamic> data,
      UserCharacter character,
      ) {
    return <String, dynamic>{
      ...data,
      'characterName': data['characterName'] ?? character.characterName,
      'displayNameEn': data['displayNameEn'] ?? character.displayNameEn,
      'displayNameAr': data['displayNameAr'] ?? character.displayNameAr,
      'archetype': data['archetype'] ?? character.archetype,
      'glbFileName': data['glbFileName'] ?? character.glbFileName,
    };
  }

  Future<void> saveStableCharacterHistory(
      UserCharacter character, {
        DateTime? stableAt,
      }) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final characterDoc = await userCharactersCollection.doc(character.id).get();
      final latestData =
          characterDoc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

      await _saveStableCharacterHistoryFromData(
        character.id,
        _mergeCharacterSnapshotData(latestData, character),
        stableAt: stableAt,
        userIdOverride: userId,
      );
    } catch (e) {
      print('Error saving stable character history: $e');
      rethrow;
    }
  }

  Future<bool> _saveStableCharacterHistoryFromData(
      String characterId,
      Map<String, dynamic> data, {
        DateTime? stableAt,
        String? userIdOverride,
        bool forceNewStableAtOnCharacter = false,
      }) async {
    final userId = userIdOverride ?? currentUserId;
    if (userId == null) return false;

    try {
      final stableDate = await _ensureStableAtOnCharacterDoc(
        characterId,
        data,
        preferredStableAt: stableAt,
        forceNewDate: forceNewStableAtOnCharacter,
      );
      final stableIso = stableDate.toIso8601String();
      final docId = _buildStableHistoryDocId(userId, characterId, stableDate);
      final historyRef = stableCharacterHistoryCollection.doc(docId);

      if (_stableHistoryWriteInProgress.contains(docId)) {
        _lastKnownCharacterStates[characterId] = 'stable';
        _lastKnownCharacterStableAt[characterId] = stableIso;
        return false;
      }

      _stableHistoryWriteInProgress.add(docId);
      try {
        final alreadyExists = await _historyEntryExistsForExactStableAt(
          userId,
          characterId,
          stableDate,
        );

        _lastKnownCharacterStates[characterId] = 'stable';
        _lastKnownCharacterStableAt[characterId] = stableIso;

        if (alreadyExists) {
          return false;
        }

        await historyRef.set({
          'userId': userId,
          'sourceCharacterId': characterId,
          'characterName': data['characterName'] ?? '',
          'displayNameEn': data['displayNameEn'] ?? data['displayName'] ?? '',
          'displayNameAr': data['displayNameAr'] ?? data['displayName'] ?? '',
          'archetype': data['archetype'] ?? '',
          'glbFileName': data['glbFileName'] ?? '',
          'stableAt': stableIso,
          'stateAtSave': 'stable',
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('✅ Stable history saved once for character $characterId at $stableIso');
        return true;
      } finally {
        _stableHistoryWriteInProgress.remove(docId);
      }
    } catch (e) {
      print('Error syncing stable history from character data: $e');
      return false;
    }
  }

  Future<void> syncStableCharactersToHistory() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final charactersQuery = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in charactersQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final state = _normalizeState(data['currentState']) ?? 'active';
        _lastKnownCharacterStates[doc.id] = state;

        if (state == 'stable') {
          final stableDate = await _ensureStableAtOnCharacterDoc(doc.id, data);
          _lastKnownCharacterStableAt[doc.id] = stableDate.toIso8601String();

          await _saveStableCharacterHistoryFromData(
            doc.id,
            <String, dynamic>{
              ...data,
              'stableAt': stableDate.toIso8601String(),
            },
            stableAt: stableDate,
            userIdOverride: userId,
          );
        } else {
          _lastKnownCharacterStableAt.remove(doc.id);
        }
      }
    } catch (e) {
      print('Error syncing stable characters to history: $e');
    }
  }

  Future<void> _handleStableCharacterRealtimeChange(
      DocumentChange change,
      String userId,
      ) async {
    final characterId = change.doc.id;
    final data = change.doc.data() as Map<String, dynamic>?;

    if (data == null) {
      _lastKnownCharacterStates.remove(characterId);
      _lastKnownCharacterStableAt.remove(characterId);
      _pendingStableHistoryStableAt.remove(characterId);
      return;
    }

    final previousState = _lastKnownCharacterStates[characterId];
    final currentState = _normalizeState(data['currentState']) ?? 'active';

    if (currentState == 'stable') {
      final stableDate = await _ensureStableAtOnCharacterDoc(
        characterId,
        data,
        preferredStableAt: _parseFlexibleDate(data['stableAt']),
      );
      final stableIso = stableDate.toIso8601String();
      final wasAlreadyTrackedAsSameStable =
          previousState == 'stable' &&
              _lastKnownCharacterStableAt[characterId] == stableIso;
      final pendingStableIso = _pendingStableHistoryStableAt[characterId];

      _lastKnownCharacterStates[characterId] = 'stable';
      _lastKnownCharacterStableAt[characterId] = stableIso;

      if (pendingStableIso == stableIso) {
        _pendingStableHistoryStableAt.remove(characterId);
        return;
      }

      if (!wasAlreadyTrackedAsSameStable) {
        await _saveStableCharacterHistoryFromData(
          characterId,
          <String, dynamic>{
            ...data,
            'stableAt': stableIso,
          },
          stableAt: stableDate,
          userIdOverride: userId,
        );
      }
      return;
    }

    _lastKnownCharacterStates[characterId] = currentState;
    _lastKnownCharacterStableAt.remove(characterId);
    _pendingStableHistoryStableAt.remove(characterId);

    if (previousState == 'stable' && currentState == 'active') {
      await userCharactersCollection.doc(characterId).set({
        'stableAt': FieldValue.delete(),
        'reactivatedAt': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> startStableCharactersRealtimeSync() async {
    final userId = currentUserId;
    if (userId == null) return;

    if (_stableCharactersRealtimeSyncSubscription != null &&
        _stableCharactersRealtimeSyncUserId == userId) {
      return;
    }

    await _stableCharactersRealtimeSyncSubscription?.cancel();
    _stableCharactersRealtimeSyncSubscription = null;
    _stableCharactersRealtimeSyncUserId = userId;
    _lastKnownCharacterStates.clear();
    _lastKnownCharacterStableAt.clear();
    _pendingStableHistoryStableAt.clear();
    _stableHistoryWriteInProgress.clear();

    await syncStableCharactersToHistory();

    _stableCharactersRealtimeSyncSubscription = userCharactersCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        await _handleStableCharacterRealtimeChange(change, userId);
      }
    }, onError: (error) {
      print('Error in stable characters realtime sync: $error');
    });

    print('📡 Stable characters realtime sync started for user $userId');
  }

  Future<void> stopStableCharactersRealtimeSync() async {
    await _stableCharactersRealtimeSyncSubscription?.cancel();
    _stableCharactersRealtimeSyncSubscription = null;
    _stableCharactersRealtimeSyncUserId = null;
    _lastKnownCharacterStates.clear();
    _lastKnownCharacterStableAt.clear();
    _pendingStableHistoryStableAt.clear();
    _stableHistoryWriteInProgress.clear();
  }

  Future<void> markCharacterAsStable(
      UserCharacter character, {
        DateTime? stableAt,
      }) async {
    try {
      final characterDoc = await userCharactersCollection.doc(character.id).get();
      final data = characterDoc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      final currentState =
          _normalizeState(data['currentState']) ??
              _normalizeState(character.currentState) ??
              'active';

      if (currentState == 'stable') {
        final preservedStableAt = await _ensureStableAtOnCharacterDoc(
          character.id,
          data,
          preferredStableAt: stableAt,
        );

        _lastKnownCharacterStates[character.id] = 'stable';
        _lastKnownCharacterStableAt[character.id] =
            preservedStableAt.toIso8601String();

        await _saveStableCharacterHistoryFromData(
          character.id,
          <String, dynamic>{
            ..._mergeCharacterSnapshotData(data, character),
            'stableAt': preservedStableAt.toIso8601String(),
          },
          stableAt: preservedStableAt,
        );

        print(
          'ℹ️ Character ${character.id} is already stable. Kept existing stable date and ensured one history entry only.',
        );
        return;
      }

      final stableDate = _currentStableTimestamp();
      final stableIso = stableDate.toIso8601String();

      await userCharactersCollection.doc(character.id).set({
        'currentState': 'stable',
        'stableAt': stableIso,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lastKnownCharacterStates[character.id] = 'stable';
      _lastKnownCharacterStableAt[character.id] = stableIso;
      _pendingStableHistoryStableAt[character.id] = stableIso;

      await _saveStableCharacterHistoryFromData(
        character.id,
        <String, dynamic>{
          ..._mergeCharacterSnapshotData(data, character),
          'stableAt': stableIso,
        },
        stableAt: stableDate,
      );

      print('✅ Character ${character.id} marked as stable');
    } catch (e) {
      print('Error marking character as stable: $e');
      rethrow;
    }
  }

  Future<void> markCharacterAsActive(String characterId) async {
    try {
      _lastKnownCharacterStates[characterId] = 'active';
      _lastKnownCharacterStableAt.remove(characterId);
      _pendingStableHistoryStableAt.remove(characterId);

      await userCharactersCollection.doc(characterId).update({
        'currentState': 'active',
        'stableAt': FieldValue.delete(),
        'reactivatedAt': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Character $characterId marked as active');
    } catch (e) {
      print('Error marking character as active: $e');
      rethrow;
    }
  }

  Future<void> updateCharacterCurrentState(
      UserCharacter character,
      String newState, {
        DateTime? changedAt,
      }) async {
    try {
      if (newState == 'stable') {
        await markCharacterAsStable(character, stableAt: changedAt);
        return;
      }

      final Map<String, dynamic> payload = {
        'currentState': newState,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newState == 'active') {
        payload['reactivatedAt'] = (changedAt ?? DateTime.now()).toIso8601String();
        payload['stableAt'] = FieldValue.delete();
        _lastKnownCharacterStableAt.remove(character.id);
        _pendingStableHistoryStableAt.remove(character.id);
      }

      await userCharactersCollection.doc(character.id).update(payload);
      _lastKnownCharacterStates[character.id] = newState;
      print('✅ Character ${character.id} state updated to $newState');
    } catch (e) {
      print('Error updating character state: $e');
      rethrow;
    }
  }

  Stream<List<StableCharacterHistory>> watchStableCharacterHistory({int? limit}) {
    final userId = currentUserId;
    if (userId == null) {
      return const Stream<List<StableCharacterHistory>>.empty();
    }

    startStableCharactersRealtimeSync();

    Query query = stableCharacterHistoryCollection
        .where('userId', isEqualTo: userId)
        .orderBy('stableAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => StableCharacterHistory.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();
    });
  }

  Future<List<StableCharacterHistory>> getStableCharacterHistory({int? limit}) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      await syncStableCharactersToHistory();

      Query query = stableCharacterHistoryCollection
          .where('userId', isEqualTo: userId)
          .orderBy('stableAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map(
            (doc) => StableCharacterHistory.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList();
    } catch (e) {
      print('Error getting stable character history: $e');
      return [];
    }
  }

  Future<void> checkAndUpdateInactiveCharacters() async {
    try {
      print('🔍 Checking for inactive users...');
      final userId = currentUserId;
      if (userId == null) {
        print(' No user logged in');
        return;
      }

      // Get current user's data
      final userDoc = await usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        print('User document not found');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final now = DateTime.now();
      final oneMonthAgo = now.subtract(const Duration(days: 30));

      // Get user's last activity
      DateTime? lastActivity;

      if (userData['lastActivityAt'] != null) {
        lastActivity = DateTime.tryParse(userData['lastActivityAt']);
        print('Last activity: $lastActivity');
      }

      // If no activity recorded, check creation time or updatedAt
      if (lastActivity == null) {
        if (userData['updatedAt'] != null) {
          lastActivity = DateTime.tryParse(userData['updatedAt']);
        } else if (userData['createdAt'] != null) {
          lastActivity = DateTime.tryParse(userData['createdAt']);
        }
      }

      // If we still don't have last activity, use current time minus 31 days to force check
      if (lastActivity == null) {
        print('No activity timestamp found, using default');
        lastActivity = now.subtract(const Duration(days: 31));
      }

      print('Last activity: ${lastActivity.toIso8601String()}');
      print('One month ago: ${oneMonthAgo.toIso8601String()}');
      print('Is inactive: ${lastActivity.isBefore(oneMonthAgo)}');

      // Check if user has been inactive for more than 30 days
      if (lastActivity.isBefore(oneMonthAgo)) {
        print('User has been inactive since ${lastActivity.toIso8601String()}');

        // Get all ACTIVE characters for this user (only active ones, not stable)
        final charactersQuery = await userCharactersCollection
            .where('userId', isEqualTo: userId)
            .where('currentState', isEqualTo: 'active') // Only get active characters
            .get();

        print('Found ${charactersQuery.docs.length} active characters');

        if (charactersQuery.docs.isNotEmpty) {
          final batch = _firestore.batch();
          int updatedCount = 0;

          for (final doc in charactersQuery.docs) {
            final characterData = doc.data() as Map<String, dynamic>;
            final currentState = characterData['currentState'];

            print('   - Character ${doc.id}: currentState=$currentState');

            // Only mark as inactive if currently active
            if (currentState == 'active') {
              batch.update(doc.reference, {
                'currentState': 'inactive',
                'inactivatedAt': now.toIso8601String(),
                'inactivatedReason': 'app_inactivity',
                'previousState': 'active',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              updatedCount++;
              print('Marked character ${characterData['displayNameEn']} as inactive');
            }
          }

          if (updatedCount > 0) {
            await batch.commit();
            print('Updated $updatedCount characters to inactive for user $userId');
          } else {
            print('No active characters needed updating');
          }
        } else {
          print('No active characters found to mark as inactive');
        }
      } else {
        print('User is active (last activity within 30 days)');
      }

      print('Inactivity check complete');
    } catch (e, stackTrace) {
      print('Error checking inactive users: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> updateUserLastActivity() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await usersCollection.doc(userId).set({
        'lastActivityAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      print('Updated last activity for user $userId');
    } catch (e) {
      print('Error updating last activity: $e');
    }
  }


  // Check if user has characters data
  Future<bool> hasUserCharacters() async {
    final characters = await getUserCharacters();
    return characters.isNotEmpty;
  }

  // Delete user's characters (for re-taking questionnaire)
  Future<void> deleteUserCharacters() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final querySnapshot = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _userCharactersCache[userId] = <UserCharacter>[];
    } catch (e) {
      print('Error deleting user characters: $e');
      throw e;
    }
  }

  // ============= USER PROFILE METHODS =============

  // Update current user's profile fields
  Future<void> updateCurrentUserProfile({
    String? firstName,
    String? lastName,
    String? birthdate,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await usersCollection.doc(userId).set({
        'firstName': firstName,
        'lastName': lastName,
        'birthdate': birthdate,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Get current user's profile fields
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      final doc = await usersCollection.doc(userId).get();
      if (!doc.exists) return {};
      return doc.data() as Map<String, dynamic>? ?? {};
    } catch (e) {
      print('Error loading user profile: $e');
      return {};
    }
  }


  // Watch current user's profile fields in real time.
  // Used by Profile and the shared top bar so profile photo changes
  // appear immediately across all pages.
  Stream<Map<String, dynamic>> watchCurrentUserProfile() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream<Map<String, dynamic>>.value(<String, dynamic>{});
    }

    return usersCollection.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return <String, dynamic>{};
      return doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    });
  }

  // Save current user's profile photo in Firestore.
  // The value can be either a normal http(s) URL or a compact data:image URL.
  // Using Firestore here avoids Firebase Storage 404 bucket/session errors and
  // keeps Profile + TopHelloBar synced from one real-time user document.
  Future<void> updateCurrentUserProfilePhoto({
    required String profilePhotoUrl,
    String? profilePhotoPath,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final trimmedUrl = profilePhotoUrl.trim();
      if (trimmedUrl.isEmpty) return;

      final userRef = usersCollection.doc(userId);
      final data = <String, dynamic>{
        'profilePhotoUrl': trimmedUrl,
        'photoURL': trimmedUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final trimmedPath = profilePhotoPath?.trim();
      if (trimmedPath != null && trimmedPath.isNotEmpty) {
        data['profilePhotoPath'] = trimmedPath;
      }

      await userRef.set(data, SetOptions(merge: true));

      if (trimmedPath == null || trimmedPath.isEmpty) {
        await userRef.update({
          'profilePhotoPath': FieldValue.delete(),
        });
      }

      final canBeAuthPhotoUrl =
          trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://');
      await _auth.currentUser?.updatePhotoURL(
        canBeAuthPhotoUrl ? trimmedUrl : null,
      );
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Error updating profile photo: $e');
      rethrow;
    }
  }

  // Remove current user's profile photo so the UI falls back to initials.
  Future<void> removeCurrentUserProfilePhoto() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final userRef = usersCollection.doc(userId);

      await userRef.set({
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      await userRef.update({
        'profilePhotoUrl': FieldValue.delete(),
        'photoURL': FieldValue.delete(),
        'profilePhotoPath': FieldValue.delete(),
      });

      await _auth.currentUser?.updatePhotoURL(null);
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Error removing profile photo: $e');
      rethrow;
    }
  }

  // Check if current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final doc = await usersCollection.doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      return data?['isAdmin'] == true;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Set current user's admin status
  Future<void> setCurrentUserAdmin(bool isAdmin) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await usersCollection.doc(userId).set({
        'isAdmin': isAdmin,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating admin status: $e');
      throw e;
    }
  }

  // Set admin status for a user by email
  Future<void> setAdminByEmail(String email, bool isAdmin) async {
    try {
      final query = await usersCollection
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        throw Exception('User with that email was not found.');
      }

      await usersCollection.doc(query.docs.first.id).set({
        'isAdmin': isAdmin,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating admin by email: $e');
      rethrow;
    }
  }

  // Basic admin overview counts
  Future<Map<String, int>> getAdminOverviewCounts() async {
    try {
      final usersSnapshot = await usersCollection.get();
      final questionsSnapshot = await questionsCollection.get();
      final answersSnapshot = await userAnswersCollection.get();
      final charactersSnapshot = await userCharactersCollection.get();

      var adminUsers = 0;
      var completedQuestionnaire = 0;
      for (final doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        if (data['isAdmin'] == true) adminUsers += 1;
        if (data['hasCompletedQuestionnaire'] == true) {
          completedQuestionnaire += 1;
        }
      }

      return {
        'users': usersSnapshot.docs.length,
        'questions': questionsSnapshot.docs.length,
        'answers': answersSnapshot.docs.length,
        'characters': charactersSnapshot.docs.length,
        'admins': adminUsers,
        'completedQuestionnaire': completedQuestionnaire,
      };
    } catch (e) {
      print('Error loading admin overview counts: $e');
      return {
        'users': 0,
        'questions': 0,
        'answers': 0,
        'characters': 0,
        'admins': 0,
        'completedQuestionnaire': 0,
      };
    }
  }

  // Get user's preferred language
  Future<String> getUserLanguage() async {
    final userId = currentUserId;
    if (userId == null) return 'en';

    try {
      final doc = await usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final language = data?['preferredLanguage']?.toString() ?? 'en';
        return language.trim().toLowerCase().startsWith('ar') ? 'ar' : 'en';
      }
      return 'en';
    } catch (e) {
      print('Error getting user language: $e');
      return 'en';
    }
  }

  // Set user's preferred language
  Future<void> setUserLanguage(String language) async {
    language = language.trim().toLowerCase().startsWith('ar') ? 'ar' : 'en';
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await usersCollection.doc(userId).set({
        'preferredLanguage': language,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting user language: $e');
      throw e;
    }
  }

  // Get user's questionnaire status
  Future<Map<String, dynamic>> getUserQuestionnaireStatus() async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      final doc = await usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'hasCompleted': data?['hasCompletedQuestionnaire'] ?? false,
          'completedAt': data?['questionnaireCompletedAt'],
          'language': data?['questionnaireLanguage'] ?? 'en',
        };
      }
      return {'hasCompleted': false, 'language': 'en'};
    } catch (e) {
      print('Error getting questionnaire status: $e');
      return {'hasCompleted': false, 'language': 'en'};
    }
  }

  // Get healing progress statistics
  Future<Map<String, dynamic>> getHealingProgress() async {
    final userId = currentUserId;
    if (userId == null) return {'total': 0, 'healed': 0, 'unhealed': 0, 'percentage': 0};

    try {
      final allCharacters = await getUserCharacters();
      final healedCharacters = await getHealedCharacters();
      final unhealedCharacters = await getUnhealedCharacters();

      final total = allCharacters.length;
      final healed = healedCharacters.length;
      final unhealed = unhealedCharacters.length;
      final percentage = total > 0 ? (healed / total * 100).round() : 0;

      return {
        'total': total,
        'healed': healed,
        'unhealed': unhealed,
        'percentage': percentage,
      };
    } catch (e) {
      print('Error getting healing progress: $e');
      return {'total': 0, 'healed': 0, 'unhealed': 0, 'percentage': 0};
    }
  }

  Future<void> _deleteCurrentUserDocumentsFromCollection(
      CollectionReference collection,
      String userId,
      ) async {
    final querySnapshot = await collection.where('userId', isEqualTo: userId).get();
    if (querySnapshot.docs.isEmpty) return;

    var batch = _firestore.batch();
    var operationCount = 0;

    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
      operationCount++;

      // Firestore batch limit is 500 operations. Use 450 to stay safe.
      if (operationCount == 450) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }

  // Fast cleanup needed before opening the questionnaire again.
  // It removes only old current-attempt answers and current characters.
  // IMPORTANT: Do NOT delete questionnaireQuestionCount here.
  // That number is cumulative across completed attempts:
  // first completion = 13, first retake completion = 26, etc.
  Future<void> clearQuestionnaireStartData({String? language}) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await deleteUserCharacters();
      await _deleteCurrentUserDocumentsFromCollection(
        userAnswersCollection,
        userId,
      );

      _userCharactersCache[userId] = <UserCharacter>[];

      final normalizedLanguage = language == null
          ? null
          : (language.trim().toLowerCase().startsWith('ar') ? 'ar' : 'en');

      await usersCollection.doc(userId).set({
        'hasCompletedQuestionnaire': false,
        'questionnaireCompletedAt': null,
        if (normalizedLanguage != null)
          'preferredLanguage': normalizedLanguage,
        if (normalizedLanguage != null)
          'questionnaireLanguage': normalizedLanguage,
        // Keep questionnaireQuestionCount/questionnaireAnsweredCount.
        // They represent the cumulative completed count and will be incremented
        // only after the user finishes the retake.
        'retakeStartedAt': DateTime.now().toIso8601String(),
        'questionnaireRetakeStartedCount': FieldValue.increment(1),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error clearing questionnaire start data: $e');
      throw e;
    }
  }

  // Slower cleanup that can run after navigation so the Retake button opens
  // the initial page quickly instead of waiting for all progress docs.
  Future<void> clearQuestionnaireProgressData() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _deleteCurrentUserDocumentsFromCollection(
        stableCharacterHistoryCollection,
        userId,
      );

      await _deleteCurrentUserDocumentsFromCollection(
        _firestore.collection('reframe_sessions'),
        userId,
      );
    } catch (e) {
      print('Error clearing questionnaire progress data: $e');
    }
  }

  // Backward-compatible full cleanup.
  Future<void> clearQuestionnaireData() async {
    await clearQuestionnaireStartData();
    await clearQuestionnaireProgressData();
  }

  // Add a reframe session to database
  Future<void> addReframeSession({
    required String userId,
    required String inputType,
    required String transcript,
    required String language,
    required Map<String, dynamic> analysisResult,
    required String mode,
    String? audioFilePath,
    String? videoFilePath,
  }) async {
    try {
      final sessionData = {
        'userId': userId,
        'inputType': inputType,
        'transcript': transcript,
        'language': language,
        'mode': mode,
        'analysisResult': analysisResult,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'audioFilePath': audioFilePath,
        'videoFilePath': videoFilePath,
        'primaryCharacter': analysisResult['primary_character'] ?? 'Unknown',
        'confidence': analysisResult['confidence'] ?? 0.0,
        'characterName': analysisResult['character_name'] ?? '',
      };

      await _firestore.collection('reframe_sessions').add(sessionData);
      print('✅ Reframe session saved to database');
    } catch (e) {
      print('❌ Error saving reframe session: $e');
      rethrow;
    }
  }

  // Get user's reframe sessions
  Stream<QuerySnapshot> getUserReframeSessions(String userId) {
    return _firestore
        .collection('reframe_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Clear user's sessions
  Future<void> clearUserSessions(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('reframe_sessions')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ Cleared all sessions for user: $userId');
    } catch (e) {
      print('❌ Error clearing sessions: $e');
      rethrow;
    }
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // ============= REFRAME CHARACTER METHODS =============

  // Check if character already exists for a user
  Future<bool> doesCharacterExistForUser({
    required String userId,
    required String displayName,
    required String characterName,
  }) async {
    try {
      print('🔍 Checking if character exists for user: $userId');
      print('   Display Name: $displayName');
      print('   Character Name: $characterName');

      // Check by displayName (primary check)
      final displayNameQuery = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .where('displayName', isEqualTo: displayName)
          .limit(1)
          .get();

      if (displayNameQuery.docs.isNotEmpty) {
        print('⚠️ Character "$displayName" already exists for user $userId');
        final existingDoc = displayNameQuery.docs.first;
        final data = existingDoc.data() as Map<String, dynamic>;
        print('   Existing character ID: ${existingDoc.id}');
        print('   Existing character rank: ${data['rank']}');
        print('   Existing character confidence: ${data['confidence']}');
        return true;
      }

      // Also check by characterName (secondary check)
      final characterNameQuery = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .where('characterName', isEqualTo: characterName)
          .limit(1)
          .get();

      if (characterNameQuery.docs.isNotEmpty) {
        print('⚠️ Character name "$characterName" already exists for user $userId');
        return true;
      }

      print('✅ Character "$displayName" does not exist yet, can be added');
      return false;
    } catch (e) {
      print('❌ Error checking if character exists: $e');
      return false; // Default to false to allow saving if check fails
    }
  }

  // Save reframe character to user_characters collection
  Future<void> saveReframeCharacterToUserCharacters({
    required String userId,
    required String characterName,
    required String displayName,
    required String archetype,
    required double confidence,
    required String language,
  }) async {
    try {
      print('💾 Starting to save reframe character for user: $userId');
      print('   Character: $displayName ($characterName)');
      print('   Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      print('   Archetype: $archetype');
      print('   Language: $language');

      // Check if character already exists
      final alreadyExists = await doesCharacterExistForUser(
        userId: userId,
        displayName: displayName,
        characterName: characterName,
      );

      if (alreadyExists) {
        print('⏭️ Skipping save - character "$displayName" already exists in collection');
        throw Exception('Character "$displayName" already exists');
      }

      // Get ALL existing characters for this user to calculate proper rank
      final existingCharactersQuery = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .orderBy('rank')
          .get();

      int nextRank;
      int totalCharacters = existingCharactersQuery.docs.length;

      if (totalCharacters == 0) {
        nextRank = 1;
        print('   No existing characters found, setting rank to 1');
      } else {
        // Find the highest rank among existing characters
        int highestRank = 0;
        for (final doc in existingCharactersQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final rank = data['rank'] as int? ?? 0;
          if (rank > highestRank) {
            highestRank = rank;
          }
        }
        nextRank = highestRank + 1;
        print('   Found $totalCharacters existing characters, highest rank: $highestRank');
        print('   Setting new rank to: $nextRank');
      }

      // Create a unique ID for this character
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final docId = '${userId}_reframe_$timestamp';

      // Map archetype to ensure it's one of the three valid types
      String mappedArchetype = archetype.toLowerCase();

      // Define archetype mapping patterns
      if (mappedArchetype.contains('manager') ||
          mappedArchetype.contains('critic') ||
          mappedArchetype.contains('controller') ||
          mappedArchetype.contains('perfectionist') ||
          mappedArchetype.contains('workaholic') ||
          mappedArchetype.contains('pleaser')) {
        mappedArchetype = 'manager';
      } else if (mappedArchetype.contains('firefighter') ||
          mappedArchetype.contains('gamer') ||
          mappedArchetype.contains('procrastinator') ||
          mappedArchetype.contains('overeater') ||
          mappedArchetype.contains('binger')) {
        mappedArchetype = 'firefighter';
      } else {
        mappedArchetype = 'exile';
      }

      // Generate GLB filename based on character name
      final glbFileName = 'character_${characterName.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_')}.glb';

      // Create description based on character type
      final description = 'This inner character was identified through reflective analysis '
          'with ${(confidence * 100).toStringAsFixed(1)}% confidence. '
          'It represents a $archetype archetype that influences your thoughts and behaviors.';

      // Create the character data matching your UserCharacter structure EXACTLY
      final characterData = {
        'userId': userId,
        'characterName': characterName,
        'displayName': displayName,
        'archetype': mappedArchetype,
        'confidence': confidence,
        'rank': nextRank,
        'language': language,
        'glbFileName': glbFileName,
        'description': description,
        'predictedAt': DateTime.now().toIso8601String(),
        'isHealed': false,
        'healedAt': null,
        'currentState': 'active',
        'addedFromReframe': true,
        'reframeSessionAt': DateTime.now().toIso8601String(),
      };

      // Save to user_characters collection
      await userCharactersCollection.doc(docId).set(characterData);

      print('✅ SUCCESS: New reframe character saved to user_characters collection');
      print('   Document ID: $docId');
      print('   Final rank: $nextRank');
      print('   Archetype: $mappedArchetype');
      print('   GLB File: $glbFileName');

      return;
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to save reframe character to user_characters');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      rethrow; // Re-throw so calling code knows it failed
    }
  }

  // Check if user has at least one healed character
  Future<bool> hasAtLeastOneHealedCharacter(String userId) async {
    try {
      final healedCharacters = await getHealedCharacters();
      final hasHealed = healedCharacters.isNotEmpty;

      print('🔍 Checking healing status for user: $userId');
      print('   Has healed characters: $hasHealed');
      print('   Number of healed characters: ${healedCharacters.length}');

      if (healedCharacters.isNotEmpty) {
        for (final character in healedCharacters) {
          print('   - ${character.displayNameEn} (healed at: ${character.healedAt})');
        }
      }

      return hasHealed;
    } catch (e) {
      print('❌ Error checking healed characters: $e');
      return false; // Default to false to be safe
    }
  }

// Get all characters count
  Future<Map<String, int>> getCharacterStats(String userId) async {
    try {
      final allCharacters = await getUserCharacters();
      final healedCharacters = await getHealedCharacters();

      return {
        'total': allCharacters.length,
        'healed': healedCharacters.length,
        'unhealed': allCharacters.length - healedCharacters.length,
      };
    } catch (e) {
      print('❌ Error getting character stats: $e');
      return {'total': 0, 'healed': 0, 'unhealed': 0};
    }
  }
}