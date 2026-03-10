import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/questionnaire/domain/entities/question.dart';
import 'package:ana_ifs_app/features/questionnaire/domain/entities/user_answer.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Questions Collection
  CollectionReference get questionsCollection =>
      _firestore.collection('questions');

  // User Answers Collection
  CollectionReference get userAnswersCollection =>
      _firestore.collection('user_answers');

  // User Characters Collection
  CollectionReference get userCharactersCollection =>
      _firestore.collection('user_characters');

  // Users Collection
  CollectionReference get usersCollection => _firestore.collection('users');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ============= QUESTION METHODS =============

  // Fetch all questions for a specific language
  Future<List<Question>> getQuestions(String language) async {
    try {
      print('📥 Fetching questions for language: $language');

      final querySnapshot = await questionsCollection
          .where('language', isEqualTo: language)
          .orderBy('questionNumber')
          .get();

      print(
        '📊 Found ${querySnapshot.docs.length} documents for language: $language',
      );

      // DEBUG: Print all document data
      for (var doc in querySnapshot.docs) {
        print('📄 Document ID: ${doc.id}');
        print('   Data: ${doc.data()}');
        print('   ---');
      }

      if (querySnapshot.docs.isEmpty) {
        print('⚠️ No questions found for language: $language');
        print('   Checking if questions collection exists...');

        // Check if collection exists at all
        final allQuestions = await questionsCollection.limit(1).get();
        print('   Total questions in collection: ${allQuestions.docs.length}');

        // Check what languages exist
        final allDocs = await questionsCollection.get();
        final languages = <String>{};
        for (var doc in allDocs.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final lang = data['language']?.toString() ?? 'unknown';
          languages.add(lang);
        }
        print('   Available languages in database: ${languages.toList()}');

        return [];
      }

      final questions = querySnapshot.docs
          .map((doc) {
        try {
          return Question.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        } catch (e) {
          print('❌ Error parsing document ${doc.id}: $e');
          print('📄 Document data: ${doc.data()}');
          return null;
        }
      })
          .where((question) => question != null)
          .cast<Question>()
          .toList();

      print(
        '✅ Successfully parsed ${questions.length} questions for language: $language',
      );

      // Debug: Print first question details
      if (questions.isNotEmpty) {
        print('🔍 First question details:');
        print('  - Number: ${questions[0].questionNumber}');
        print('  - Text: ${questions[0].text}');
        print('  - Language: ${questions[0].language}');
        print('  - Text length: ${questions[0].text.length}');
      }

      return questions;
    } catch (e, stackTrace) {
      print('❌ ERROR fetching questions for language $language: $e');
      print('📝 Stack trace: $stackTrace');
      return [];
    }
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

  // Check if user has completed questionnaire
  Future<bool> hasCompletedQuestionnaire() async {
    try {
      // Check if user has characters data
      final hasCharacters = await hasUserCharacters();
      if (hasCharacters) return true;

      // Check if user has answered all 13 questions
      final answers = await getAllUserAnswers();
      return answers.length >= 13;
    } catch (e) {
      print('Error checking questionnaire completion: $e');
      return false;
    }
  }

  // ============= USER CHARACTERS METHODS =============

  // Save user's predicted characters - UPDATED with healing status
  Future<void> saveUserCharacters(List<UserCharacter> characters) async {
    try {
      // Delete existing characters for this user
      await deleteUserCharacters();

      // Save new characters with consistent IDs
      final userId = currentUserId;
      if (userId != null) {
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

        // Update user document to mark questionnaire as completed
        await usersCollection.doc(userId).set({
          'hasCompletedQuestionnaire': true,
          'questionnaireCompletedAt': DateTime.now().toIso8601String(),
          'questionnaireLanguage': characters.first.language,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error saving user characters: $e');
      throw e;
    }
  }

  // Get ALL user's characters (both healed and unhealed)
  Future<List<UserCharacter>> getUserCharacters() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final querySnapshot = await userCharactersCollection
          .where('userId', isEqualTo: userId)
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
      print('Error getting user characters: $e');
      return [];
    }
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
        return data?['preferredLanguage'] ?? 'en';
      }
      return 'en';
    } catch (e) {
      print('Error getting user language: $e');
      return 'en';
    }
  }

  // Set user's preferred language
  Future<void> setUserLanguage(String language) async {
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

  // Clear user's questionnaire data (for retaking)
  Future<void> clearQuestionnaireData() async {
    try {
      await deleteUserCharacters();

      // Delete all user answers
      final userId = currentUserId;
      if (userId != null) {
        // Get all answers for this user
        final answersQuery = await userAnswersCollection
            .where('userId', isEqualTo: userId)
            .get();

        final batch = _firestore.batch();
        for (final doc in answersQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Update user document
        await usersCollection.doc(userId).set({
          'hasCompletedQuestionnaire': false,
          'questionnaireCompletedAt': null,
          'questionnaireLanguage': null,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error clearing questionnaire data: $e');
      throw e;
    }
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