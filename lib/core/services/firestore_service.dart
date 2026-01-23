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

  // Save user's predicted characters
  Future<void> saveUserCharacters(List<UserCharacter> characters) async {
    try {
      // Delete existing characters for this user
      await deleteUserCharacters();

      // Save new characters with consistent IDs
      final userId = currentUserId;
      if (userId != null) {
        for (final character in characters) {
          final docId = '${userId}_char_${character.rank}';
          await userCharactersCollection.doc(docId).set(character.toMap());
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

  // Get user's characters
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
}