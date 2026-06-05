import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/features/questionnaire/domain/entities/question.dart';
import 'package:ana_ifs_app/features/questionnaire/domain/entities/user_answer.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/widgets/question_widget.dart';
import 'package:ana_ifs_app/core/services/ai_service.dart';

class QuestionnaireProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  List<Question> _questions = [];
  List<QuestionAnswer> _answers = [];
  int _currentQuestionIndex = 0;
  final AIService _aiService = AIService();
  bool _isLoading = true; // Start with loading true
  bool _hasLoaded = false;
  bool _isLanguageSwitching = false;
  String _language = 'en';
  int? _lastQuestionNumberBeforeSwitch;
  bool _isRetakeMode = false;

  Timer? _debounceTimer;

  QuestionnaireProvider(this._firestoreService);

  List<Question> get questions => _questions;
  List<QuestionAnswer> get answers => _answers;
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isLanguageSwitching => _isLanguageSwitching;
  int get totalQuestions => _questions.length;
  String get language => _language;

  String _normalizeLanguage(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('ar') ? 'ar' : 'en';
  }

  Future<void> _initialize() async {
    try {
      // Load user's saved language FIRST
      final savedLanguage = _normalizeLanguage(
        await _firestoreService.getUserLanguage(),
      );
      print('📱 User language loaded from Firestore: $savedLanguage');

      // Update language BEFORE loading questions
      _language = savedLanguage;
      _safeNotifyListeners();

      // Then load questions in that language
      await loadQuestions();
    } catch (e) {
      print('Error initializing: $e');
      // If error, still try to load questions in default language
      _isLoading = false;
      _safeNotifyListeners();
      await loadQuestions();
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

  Future<void> _loadQuestionsForLanguage(
      String language, {
        bool forceRefresh = false,
      }) async {
    try {
      print('🌐 Loading questions for language: $language');

      final loadedQuestions = await _firestoreService.getQuestions(
        language,
        forceRefresh: forceRefresh,
      );

      if (loadedQuestions.isEmpty) {
        print('⚠️ No questions loaded for language $language');
        throw Exception('No questions available in $language. Please check the database.');
      }

      // Sort questions by questionNumber
      loadedQuestions.sort(
            (a, b) => a.questionNumber.compareTo(b.questionNumber),
      );

      _questions = loadedQuestions;
      print('📥 Loaded ${_questions.length} questions for $language');

      // Do not save the Profile counter here. Loading 13 questions is not
      // the same as completing another questionnaire attempt. The cumulative
      // counter is updated only after submit succeeds.

      // During retake, do not reload old Firestore answers while background
      // cleanup may still be deleting them.
      if (_isRetakeMode) {
        _answers = [];
      } else {
        await _loadExistingAnswers();
      }

      // Mark as successfully loaded
      _hasLoaded = true;
      print('✅ Questions loaded successfully for $language');

    } catch (e, stackTrace) {
      print('❌ ERROR loading questions for $language: $e');
      print('📝 Stack trace: $stackTrace');

      // Reset state on error
      _hasLoaded = false;
      _questions = [];
      _answers = [];

      rethrow;
    }
  }

  Future<void> loadQuestions({bool forceReload = false}) async {
    if (_hasLoaded && !forceReload) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      if (forceReload) {
        _hasLoaded = false;
        _questions = [];
        _answers = [];
        _currentQuestionIndex = 0;
      }

      await _loadQuestionsForLanguage(
        _language,
        forceRefresh: forceReload,
      );
    } catch (e) {
      print('Load questions failed: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> switchLanguage(String newLanguage) async {
    newLanguage = _normalizeLanguage(newLanguage);
    if (_language == newLanguage) return;

    print('🔄 Switching language from $_language to $newLanguage');

    // Store current question number BEFORE switching
    int? questionNumberToRestore;
    if (_questions.isNotEmpty && _currentQuestionIndex < _questions.length) {
      questionNumberToRestore = _questions[_currentQuestionIndex].questionNumber;
      _lastQuestionNumberBeforeSwitch = questionNumberToRestore;
      print('💾 Storing current question: Q$questionNumberToRestore');
    }

    // Set loading states
    _isLanguageSwitching = true;
    _isLoading = true;
    _safeNotifyListeners();

    try {
      // 1. Update the language in Firestore
      await _firestoreService.setUserLanguage(newLanguage);

      // 2. Update the language variable
      _language = newLanguage;

      // 3. Reset state
      _hasLoaded = false;

      // 4. Load new questions for the new language
      await _loadQuestionsForLanguage(
        newLanguage,
        forceRefresh: true,
      );

      // 5. RESTORE POSITION: Find the same question number in new language
      if (questionNumberToRestore != null && _questions.isNotEmpty) {
        _restoreQuestionPositionByNumber(questionNumberToRestore);
      } else {
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
      // Get Arabic translations based on the English character name
      final arabicName = _getArabicDisplayName(prediction['characterName']);
      final arabicDescription = _getArabicDescription(prediction['characterName']);

      return UserCharacter(
        id: '',
        userId: _firestoreService.currentUserId ?? '',
        characterName: prediction['characterName'], // English identifier
        displayNameEn: prediction['displayName'], // English display name
        displayNameAr: arabicName, // Arabic display name
        archetype: prediction['archetype'],
        confidence: prediction['confidence'],
        rank: prediction['rank'],
        language: _language, // Language used for prediction
        glbFileName: prediction['glbFileName'],
        descriptionEn: prediction['description'], // English description
        descriptionAr: arabicDescription, // Arabic description
        predictedAt: DateTime.now(),
        isHealed: false,
        healedAt: null,
        currentState: 'active', // Make sure this is included
      );
    }).toList();

    // Log the data being saved to verify currentState is included
    print('💾 Saving user characters with currentState:');
    for (var character in userCharacters) {
      print('  - ${character.characterName}: ${character.currentState}');
    }

    // The cumulative Profile counter is incremented inside saveUserCharacters()
    // after this attempt successfully produces new predictions.

    await _firestoreService.saveUserCharacters(
      userCharacters,
      questionCount: _questions.length,
    );
  }

// Add these helper methods for Arabic translations
  String _getArabicDisplayName(String englishName) {
    final arabicNames = {
      'Inner Critic': 'الناقد الداخلي',
      'Perfectionist': 'الكمالي',
      'People Pleaser': 'المُرضي',
      'Controller': 'المتحكم',
      'Stoic Part': 'حمّال أسيّة',
      'Workaholic': 'مدمن العمل',
      'Confused Part': 'الجزء الحيران',
      'Procrastinator': 'المماطل',
      'Overeater': 'الآكل المفرط',
      'Binger': 'المفرط',
      'Overeater/Binger': 'الآكل المفرط',
      'Excessive Gamer': 'اللاعب المفرط',
      'Lonely Part': 'الجزء الوحيد',
      'Fearful Part': 'الجزء الخائف',
      'Neglected Part': 'الجزء المهمل',
      'Ashamed Part': 'الجزء الخجول',
      'Overwhelmed Part': 'الجزء المرهق',
      'Dependent Part': 'الجزء المعتمد',
      'Jealous Part': 'الجزء الغيور',
      'Wounded Child': 'الطفل الجريح',
    };

    return arabicNames[englishName] ?? englishName;
  }

  String _getArabicDescription(String englishName) {
    final arabicDescriptions = {
      'Inner Critic':
      'هذا الصوت الداخلي يُقيّم أفعالك باستمرار، مشيراً إلى العيوب والأخطاء لمنع الفشل. بينما يهدف إلى حمايتك من خلال الحفاظ على معايير عالية، إلا أنه غالباً ما يظهر كحكم ذاتي قاسٍ يمكن أن يقوّض ثقتك بنفسك.',
      'People Pleaser':
      'هذا الجزء يُعطي أولوية لاحتياجات الآخرين فوق احتياجاتك الخاصة، يسعى للحصول على الموافقة وتجنب الصراع بأي ثمن. يعمل على الحفاظ على الانسجام في العلاقات ولكنه قد يؤدي إلى كبت مشاعرك الحقيقية وإهمال الحدود الشخصية.',
      'Lonely Part':
      'هذا الجزء يحمل مشاعر عميقة بالعزلة والشوق للتواصل العميق. يحتفظ بذكريات المسافة العاطفية ويتوق لرفقة مفهمة، وغالباً ما يظهر عندما تشعر بالانفصال عن الآخرين.',
      'Jealous Part':
      'هذا الجزء الواقي يظهر عندما ترى الآخرين كتهديد لعلاقاتك أو نجاحك. يشير إلى احتياجات غير مُلباة للأمان والتقدير، ويهدف لحماية ما تقدّره ولكنّه أحياناً يخلق مسافة.',
      'Ashamed Part':
      'هذا الجزء الجريح يحمل مشاعر عميقة بعدم الاستحقاق والوعي الذاتي من تجارب سابقة. يخفي جوانب من نفسك يراها غير مقبولة، ويعمل على حمايتك من الحكم مع تقييد التعبير الحقيقي.',
      'Workaholic':
      'هذا الجزء يُبقيك مشغولاً ومنتجاً باستمرار كوسيلة لتجنب مواجهة المشاعر الصعبة أو الفراغ الداخلي. يستخدم الإنجاز كدرع ضد الضعف، مما يؤدي غالباً إلى الإنهاك وإهمال الاحتياجات الشخصية.',
      'Perfectionist':
      'هذا الجزء يطالب بالكمال في كل ما تفعله، معتقداً أن الأداء المثالي سيمنع الانتقاد ويضمن القبول. بينما يهدف إلى التميز، إلا أنه غالباً ما يخلق معايير غير واقعية تسبب القلق والتسويف.',
      'Procrastinator':
      'هذا الجزء الواقي يُؤجل المهام المهمة لتجنب الفشل المحتمل أو الإرهاق أو مواجهة المشاعر الصعبة. يوفر راحة مؤقتة ولكنه يزيد الضغط في النهاية ويقوّض إحساسك بالقدرة.',
      'Excessive Gamer':
      'هذا الجزء يستخدم الألعاب كهروب من تحديات العالم الحقيقي، أو المشاعر غير المريحة، أو مشاعر النقص. يوفر إشباعاً فورياً وسيطرة في عالم افتراضي مع إهمال المسؤوليات الحياتية.',
      'Confused Part':
      'هذا الجزء يظهر عندما تشعر بالإرهاق من الخيارات، أو عدم اليقين بشأن القرارات، أو الانفصال عن حدسك. يمثل قلق عدم معرفة المسار "الصحيح" ويسعى للوضوح وسط عدم اليقين.',
      'Dependent Part':
      'هذا الجزء يخاف من الاستقلالية ويسعى باستمرار للتحقق الخارجي والدعم. يقلق بشأن اتخاذ القرارات بشكل مستقل ويعتمد بشدة على موافقة الآخرين، مما يحد من تطوير الثقة بالنفس.',
      'Fearful Part':
      'هذا الجزء اليقظ يمسح باستمرار للبحث عن التهديدات والمخاطر المحتملة. يهدف إلى إبقائك آمناً من خلال توقع المشاكل ولكن يمكن أن يصبح مفرط اليقظة، مما يخلق قلقاً بشأن مواقف قد لا تحدث أبداً.',
      'Neglected Part':
      'هذا الجزء الجريح يحتفظ بذكريات الإهمال، أو عدم الاستماع، أو الهجر العاطفي. يحمل ألم الاحتياجات غير الملباة في الطفولة ويسعى للاعتراف والرعاية التي لم يتلقاها.',
      'Overeater/Binger':
      'هذا الجزء يستخدم الطعام لتهدئة الألم العاطفي، أو ملء الفراغ الداخلي، أو تخدير المشاعر الصعبة. يوفر راحة مؤقتة ولكن غالباً ما يؤدي إلى دورات من الذنب والمزيد من الأكل العاطفي.',
      'Overwhelmed Part':
      'هذا الجزء يشعر بعدم القدرة على التعامل مع مطالب ومسؤوليات الحياة. يمثل إرهاق محاولة إدارة كل شيء ويحتاج إلى دعم في وضع الحدود وتحديد أولويات الرعاية الذاتية.',
      'Stoic Part':
      'هذا الجزء يكبت المشاعر ويحافظ على المسافة العاطفية كاستراتيجية بقاء. يعتقد أن إظهار الضعف خطير ويخلق مظهراً خارجياً متحكماً بينما تظل المشاعر الداخلية غير معالجة.',
      'Wounded Child':
      'هذا الجزء الضعيف يحمل ألم الطفولة، والصدمة، والاحتياجات العاطفية غير الملباة. يحتفظ بالبراءة التي أذيَت ويحتاج إلى اهتمام عطوف للشفاء والشعور بالأمان مرة أخرى.',
      'Controller Part':
      'هذا الجزء يحاول إدارة كل شيء وكل شخص لخلق إحساس بالأمان والقابلية للتنبؤ. يخاف من الفوضى وفقدان السيطرة، ويعمل بلا كلل للحفاظ على النظام ولكنه غالباً ما يخلق جموداً.',
    };

    return arabicDescriptions[englishName] ??
        'تلعب هذه الشخصية الداخلية دوراً مهماً في مشهدك العاطفي. ظهرت كآلية وقائية خلال تجارب صعبة وتستمر في التأثير على كيفية تنقلك في العلاقات، والتحديات، وتصور الذات.';
  }

  void clearAnswers() {
    _answers.clear();
    _currentQuestionIndex = 0;
    _safeNotifyListeners();
  }

  Future<void> syncLanguageFromApp(
      String appLanguage, {
        bool forceReload = false,
      }) async {
    final normalizedLanguage = _normalizeLanguage(appLanguage);

    if (_language == normalizedLanguage && _hasLoaded && !forceReload) {
      await _firestoreService.setUserLanguage(normalizedLanguage);
      return;
    }

    _language = normalizedLanguage;
    await _firestoreService.setUserLanguage(normalizedLanguage);

    if (forceReload) {
      _answers = [];
      _questions = [];
      _currentQuestionIndex = 0;
      _hasLoaded = false;
      _safeNotifyListeners();
      await loadQuestions(forceReload: true);
      return;
    }

    if (!_hasLoaded) {
      await loadQuestions();
    }
  }

  Future<void> resetForRetake({String? appLanguage}) async {
    _isRetakeMode = true;
    if (appLanguage != null) {
      _language = _normalizeLanguage(appLanguage);
      await _firestoreService.setUserLanguage(_language);
    }
    _answers = [];
    _questions = [];
    _currentQuestionIndex = 0;
    _hasLoaded = false;
    _isLoading = true;
    _safeNotifyListeners();

    await loadQuestions(forceReload: true);

    // Do not update the cumulative question counter during retake start.
    // It should increase only after the user submits this new attempt.

    _isRetakeMode = false;
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}