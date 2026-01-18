import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/question_model.dart';
import '../../models/user_answer_model.dart';
import '../../models/user_character_model.dart';
import 'question_widget.dart';
import '../../services/ai_service.dart';

class QuestionnaireProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  List<Question> _questions = [];
  List<QuestionAnswer> _answers = [];
  int _currentQuestionIndex = 0;
  final AIService _aiService = AIService();
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isLanguageSwitching = false;
  String _language = 'en';
  int? _lastQuestionNumberBeforeSwitch;

  Timer? _debounceTimer;

  QuestionnaireProvider(this._firestoreService) {
    _initialize();
  }

  List<Question> get questions => _questions;
  List<QuestionAnswer> get answers => _answers;
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isLanguageSwitching => _isLanguageSwitching;
  int get totalQuestions => _questions.length;
  String get language => _language;

  Future<void> _initialize() async {
    try {
      _language = await _firestoreService.getUserLanguage();
      _safeNotifyListeners();
    } catch (e) {
      print('Error initializing language: $e');
    }
  }

  void _safeNotifyListeners() {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (_debounceTimer?.isActive == false) {
        notifyListeners();
      }
    });
  }

  Future<void> _loadQuestionsForLanguage(String language) async {
    try {
      print('🌐 Loading questions for language: $language');

      final loadedQuestions = await _firestoreService.getQuestions(language);

      if (loadedQuestions.isEmpty) {
        print('⚠️ No questions loaded for language $language');
        return;
      }

      // Sort questions by questionNumber
      loadedQuestions.sort(
        (a, b) => a.questionNumber.compareTo(b.questionNumber),
      );

      _questions = loadedQuestions;
      print('📥 Loaded ${_questions.length} questions for $language');

      // Load existing answers for this language
      await _loadExistingAnswers();

      // Mark as successfully loaded
      _hasLoaded = true;
      print('✅ Questions loaded successfully for $language');

      // Log all question numbers for debugging
      print(
        '🔍 Available question numbers: ${_questions.map((q) => q.questionNumber).toList()}',
      );
    } catch (e, stackTrace) {
      print('❌ ERROR loading questions for $language: $e');
      print('📝 Stack trace: $stackTrace');
      _hasLoaded = false;
      rethrow;
    }
  }

  Future<void> loadQuestions() async {
    if (_isLoading || _hasLoaded) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      await _loadQuestionsForLanguage(_language);
    } catch (e) {
      print('Load questions failed: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> switchLanguage(String newLanguage) async {
    if (_language == newLanguage) return;

    print('🔄 Switching language from $_language to $newLanguage');

    // Store current question number BEFORE clearing
    int? questionNumberToRestore;
    if (_questions.isNotEmpty && _currentQuestionIndex < _questions.length) {
      questionNumberToRestore =
          _questions[_currentQuestionIndex].questionNumber;
      _lastQuestionNumberBeforeSwitch = questionNumberToRestore;
      print('💾 Storing current question: Q$questionNumberToRestore');
    }

    // Set loading states
    _isLanguageSwitching = true;
    _isLoading = true;
    _safeNotifyListeners();

    try {
      // Save old values for fallback
      final oldLanguage = _language;
      final oldQuestions = List<Question>.from(_questions);
      final oldAnswers = List<QuestionAnswer>.from(_answers);
      final oldQuestionIndex = _currentQuestionIndex;

      // Clear state but keep question number to restore
      _questions.clear();
      _answers.clear();
      _currentQuestionIndex = 0; // Temporary, will be restored
      _hasLoaded = false;
      _language = newLanguage;

      // Update language in Firestore
      await _firestoreService.setUserLanguage(newLanguage);

      // Load new questions
      await _loadQuestionsForLanguage(newLanguage);

      // RESTORE POSITION: Find the same question number in new language
      if (questionNumberToRestore != null && _questions.isNotEmpty) {
        _restoreQuestionPositionByNumber(questionNumberToRestore);
      } else {
        // If no specific question to restore, stay at index 0
        _currentQuestionIndex = 0;
      }

      print('✅ Language switched to $newLanguage');
      print(
        '📊 Restored to question ${_currentQuestionIndex + 1} (Q${_questions.isNotEmpty ? _questions[_currentQuestionIndex].questionNumber : 'N/A'})',
      );
    } catch (e, stackTrace) {
      print('❌ ERROR switching language: $e');
      print('📝 Stack trace: $stackTrace');

      rethrow;
    } finally {
      _isLanguageSwitching = false;
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  void _restoreQuestionPositionByNumber(int questionNumber) {
    if (_questions.isEmpty) {
      _currentQuestionIndex = 0;
      return;
    }

    print('🔍 Looking for question number $questionNumber in new language...');

    // Try exact match first
    for (int i = 0; i < _questions.length; i++) {
      if (_questions[i].questionNumber == questionNumber) {
        _currentQuestionIndex = i;
        print('🎯 Found exact match at index $i');
        return;
      }
    }

    // If no exact match, find the closest question
    print('⚠️ No exact match found, looking for closest question...');

    int closestIndex = 0;
    int minDifference = (_questions[0].questionNumber - questionNumber).abs();

    for (int i = 1; i < _questions.length; i++) {
      final difference = (_questions[i].questionNumber - questionNumber).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestIndex = i;
      }
    }

    _currentQuestionIndex = closestIndex;
    print(
      '📍 Using closest question at index $closestIndex (Q${_questions[closestIndex].questionNumber})',
    );
  }

  Future<void> _loadExistingAnswers() async {
    try {
      final userAnswers = await _firestoreService.getAllUserAnswers();
      _answers = userAnswers.map((answer) {
        return QuestionAnswer(
          questionNumber: answer.questionNumber,
          answerText: answer.answerText,
          selectedIndices: answer.selectedIndices,
          sliderValue: answer.sliderValue,
        );
      }).toList();

      print('📝 Loaded ${_answers.length} existing answers');
    } catch (e) {
      print('Error loading existing answers: $e');
    }
  }

  void setCurrentQuestionIndex(int index) {
    if (index >= 0 &&
        index < _questions.length &&
        index != _currentQuestionIndex) {
      _currentQuestionIndex = index;
      _safeNotifyListeners();
    }
  }

  void saveAnswer(int questionIndex, QuestionAnswer answer) {
    if (questionIndex >= _questions.length) return;

    _answers.removeWhere((a) => a.questionNumber == answer.questionNumber);
    _answers.add(answer);

    _saveAnswerToFirestore(answer);
    _safeNotifyListeners();
  }

  Future<void> _saveAnswerToFirestore(QuestionAnswer answer) async {
    try {
      final userAnswer = UserAnswer(
        id: '',
        userId: _firestoreService.currentUserId ?? '',
        questionNumber: answer.questionNumber,
        answerText: answer.answerText,
        selectedIndices: answer.selectedIndices,
        sliderValue: answer.sliderValue,
        language: _language,
        answeredAt: DateTime.now(),
      );

      await _firestoreService.saveAnswer(userAnswer);
    } catch (e) {
      print('❌ Error saving answer to Firestore: $e');
    }
  }

  QuestionAnswer? getAnswerForQuestion(int questionIndex) {
    if (questionIndex >= _questions.length) return null;

    final questionNumber = _questions[questionIndex].questionNumber;

    try {
      return _answers.firstWhere(
        (answer) => answer.questionNumber == questionNumber,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> submitAnswers() async {
    if (!_validateAllQuestionsForSubmission()) {
      return false;
    }

    try {
      final formattedAnswers = _formatAnswersForAI();
      final predictions = await _callAIModel(formattedAnswers);
      await _savePredictions(predictions);
      return true;
    } catch (e) {
      print('Error submitting answers: $e');
      return false;
    }
  }

  bool _validateAllQuestionsForSubmission() {
    if (_answers.length < _questions.length) {
      print('⚠️ Not all questions answered');
      return false;
    }

    for (var answer in _answers) {
      try {
        final question = _questions.firstWhere(
          (q) => q.questionNumber == answer.questionNumber,
        );

        if (question.isSlider && answer.sliderValue == null) {
          return false;
        }

        if (!question.isSlider &&
            (answer.selectedIndices == null ||
                answer.selectedIndices!.isEmpty) &&
            (answer.answerText == null || answer.answerText!.isEmpty)) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }

    return true;
  }

  List<Map<String, dynamic>> _getMockPredictions() {
    return [
      {
        'characterName': 'Inner Critic',
        'displayName': 'Inner Critic',
        'archetype': 'manager',
        'confidence': 0.85,
        'rank': 1,
        'glbFileName': 'inner_critic.glb',
        'description':
            'This part helps you stay safe by pointing out potential mistakes.',
      },
    ];
  }

  Future<List<Map<String, dynamic>>> _callAIModel(
    Map<String, dynamic> answers,
  ) async {
    try {
      print('🤖 Calling AI model API...');
      final formattedAnswers = _formatAnswersForAI();
      final aiService = AIService();
      final response = await aiService.predictCharacters(formattedAnswers);

      if (response['success'] == true) {
        final predictions = List<Map<String, dynamic>>.from(
          response['predictions'],
        );
        print('✅ Received ${predictions.length} predictions from AI model');
        return predictions;
      } else {
        print('❌ AI model error: ${response['error']}');
        return _getMockPredictions();
      }
    } catch (e, stackTrace) {
      print('❌ Error calling AI model: $e');
      return _getMockPredictions();
    }
  }

  Map<String, dynamic> _formatAnswersForAI() {
    final formatted = <String, dynamic>{};

    for (final answer in _answers) {
      try {
        final question = _questions.firstWhere(
          (q) => q.questionNumber == answer.questionNumber,
        );

        if (question.isSlider && answer.sliderValue != null) {
          final percentage =
              ((answer.sliderValue! - (question.minValue ?? 0)) /
                      ((question.maxValue ?? 100) - (question.minValue ?? 0)) *
                      100)
                  .round();

          if (percentage <= 20) {
            formatted['Q${answer.questionNumber}'] = '0-20%';
          } else if (percentage <= 50) {
            formatted['Q${answer.questionNumber}'] = '21-50%';
          } else if (percentage <= 80) {
            formatted['Q${answer.questionNumber}'] = '51-80%';
          } else {
            formatted['Q${answer.questionNumber}'] = '81-100%';
          }
        } else if (answer.selectedIndices != null &&
            answer.selectedIndices!.isNotEmpty) {
          formatted['Q${answer.questionNumber}'] = answer.selectedIndices!.join(
            ',',
          );
        }
      } catch (e) {
        print('Error formatting answer: $e');
      }
    }

    return formatted;
  }

  Future<void> _savePredictions(List<Map<String, dynamic>> predictions) async {
    final userCharacters = predictions.map((prediction) {
      return UserCharacter(
        id: '',
        userId: _firestoreService.currentUserId ?? '',
        characterName: prediction['characterName'],
        displayName: prediction['displayName'],
        archetype: prediction['archetype'],
        confidence: prediction['confidence'],
        rank: prediction['rank'],
        language: _language,
        glbFileName: prediction['glbFileName'],
        description: prediction['description'],
        predictedAt: DateTime.now(),
      );
    }).toList();

    await _firestoreService.saveUserCharacters(userCharacters);
  }

  void clearAnswers() {
    _answers.clear();
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
