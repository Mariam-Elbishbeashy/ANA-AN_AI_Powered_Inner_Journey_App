import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/core/localization/app_language_provider.dart';
import 'package:ana_ifs_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:ana_ifs_app/features/questionnaire/domain/entities/question.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/screens/results_screen.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/state/questionnaire_provider.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/widgets/question_widget.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  late QuestionnaireProvider _provider;
  late PageController _pageController;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isInitialized = false;
  bool _shouldSyncPageController = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _provider = QuestionnaireProvider(_firestoreService);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }


  String _normalizeLanguage(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('ar') ? 'ar' : 'en';
  }

  String _toArabicDigits(Object value) {
    var text = value.toString();
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < englishDigits.length; i++) {
      text = text.replaceAll(englishDigits[i], arabicDigits[i]);
    }
    return text;
  }

  String _localizedNumber(Object value) {
    return _provider.language == 'ar'
        ? _toArabicDigits(value)
        : value.toString();
  }

  String _questionProgressText(QuestionnaireProvider provider) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.totalQuestions;

    if (provider.language == 'ar') {
      return 'سؤال ${_toArabicDigits(current)} من ${_toArabicDigits(total)}';
    }

    return 'Question $current/$total';
  }

  String _questionNumberText(int questionNumber) {
    return _provider.language == 'ar'
        ? _toArabicDigits(questionNumber)
        : questionNumber.toString();
  }

  String _multiSelectHintText(String language) {
    return language == 'ar'
        ? 'تقدر تختار أكتر من اختيار'
        : 'You can select multiple options';
  }

  String _singleSelectHintText(String language) {
    return language == 'ar'
        ? 'اختار الإجابة الأنسب ليك'
        : 'Choose the answer that fits you best';
  }

  String _sliderHintText(String language) {
    return language == 'ar'
        ? 'حرّك المؤشر للقيمة اللي تعبّر عنك'
        : 'Move the slider to the value that represents you';
  }

  String _currentAppLanguage() {
    try {
      return _normalizeLanguage(context.read<AppLanguageProvider>().language);
    } catch (_) {
      return _normalizeLanguage(_provider.language);
    }
  }

  Future<void> _syncAppLanguageWithQuestionnaire() async {
    final selectedLanguage = _normalizeLanguage(_provider.language);
    try {
      await context.read<AppLanguageProvider>().setLanguage(selectedLanguage);
    } catch (e) {
      print('App language provider sync skipped: $e');
    }
    await _firestoreService.setUserLanguage(selectedLanguage);
  }

  Future<void> _initializeProvider() async {
    try {
      final appLanguage = _currentAppLanguage();

      // The visible app language is the source of truth.
      // This prevents Firestore's old preferredLanguage from forcing
      // the questionnaire to open/save in the wrong language.
      await _provider.syncLanguageFromApp(
        appLanguage,
        forceReload: true,
      );

      if (_provider.hasLoaded && _provider.questions.isNotEmpty) {
        setState(() {
          _shouldSyncPageController = true;
        });
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing provider: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _syncPageController() {
    if (!_shouldSyncPageController || !_pageController.hasClients) return;

    final currentPage = _pageController.page?.round() ?? 0;
    final targetPage = _provider.currentQuestionIndex;

    if (currentPage != targetPage) {
      _pageController.jumpToPage(targetPage);
      print('🔄 Synced PageController to page $targetPage');
    }

    setState(() {
      _shouldSyncPageController = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _switchLanguage(String newLanguage) async {
    final normalizedLanguage = _normalizeLanguage(newLanguage);
    if (_provider.language == normalizedLanguage) return;

    try {
      // Change the questionnaire language.
      await _provider.switchLanguage(normalizedLanguage);

      // Also change the whole app language immediately.
      // So if the user switches to Arabic inside the questionnaire,
      // Results and Home will stay Arabic too.
      await context.read<AppLanguageProvider>().setLanguage(normalizedLanguage);
      await _firestoreService.setUserLanguage(normalizedLanguage);

      setState(() {
        _shouldSyncPageController = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            normalizedLanguage == 'ar'
                ? 'تم التبديل إلى العربية'
                : 'Switched to English',
          ),
          backgroundColor: const Color(0xFF8E7CFF),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _provider.language == 'ar'
                ? 'خطأ في تبديل اللغة'
                : 'Error switching language',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _nextQuestion() {
    if (!_validateCurrentQuestion()) {
      return;
    }

    if (_pageController.hasClients &&
        _provider.currentQuestionIndex < _provider.totalQuestions - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentQuestion() {
    final currentIndex = _provider.currentQuestionIndex;
    if (currentIndex >= _provider.questions.length) return false;

    final question = _provider.questions[currentIndex];
    final answer = _provider.getAnswerForQuestion(currentIndex);

    if (answer == null) {
      _showValidationError(
        _provider.language == 'ar'
            ? 'جاوب على السؤال ده الأول'
            : 'Please answer this question first',
      );
      return false;
    }

    if (question.isSlider && answer.sliderValue == null) {
      _showValidationError(
        _provider.language == 'ar'
            ? 'اختار قيمة للسؤال ده'
            : 'Please select a value for this question',
      );
      return false;
    }

    if (!question.isSlider &&
        (answer.selectedIndices == null || answer.selectedIndices!.isEmpty) &&
        (answer.answerText == null || answer.answerText!.isEmpty)) {
      _showValidationError(
        _provider.language == 'ar'
            ? 'اختار إجابة واحدة على الأقل'
            : 'Please select at least one option',
      );
      return false;
    }

    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _questionLanguageFromContext(BuildContext context) {
    try {
      final appLanguage = context.select<AppLanguageProvider, String>(
            (provider) => provider.language,
      );
      return _normalizeLanguage(appLanguage);
    } catch (_) {
      return _normalizeLanguage(_provider.language);
    }
  }

  String _multiSelectHintTextFromContext(BuildContext context) {
    final language = _questionLanguageFromContext(context);
    return language == 'ar'
        ? 'تقدر تختار أكتر من اختيار'
        : 'You can select multiple options';
  }

  String _sliderHintTextFromContext(BuildContext context) {
    final language = _questionLanguageFromContext(context);
    return language == 'ar'
        ? 'حرّك المؤشر للقيمة اللي تعبّر عنك'
        : 'Move the slider to the value that represents you';
  }

  Widget _buildQuestionPage(int index, Question question) {
    final language = _questionLanguageFromContext(context);
    final isArabicQuestion = language == 'ar';
    final hintText = question.isSlider
        ? _sliderHintTextFromContext(context)
        : _multiSelectHintTextFromContext(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Directionality(
        textDirection: isArabicQuestion ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment:
          isArabicQuestion ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            QuestionWidget(
              question: question,
              onAnswer: (answer) {
                _provider.saveAnswer(index, answer);
              },
              initialAnswer: _provider.getAnswerForQuestion(index),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    final provider = Provider.of<QuestionnaireProvider>(context, listen: false);
    final currentLang = provider.language;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    currentLang == 'ar' ? 'اختر اللغة' : 'Select Language',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ),
              ),
              const Divider(),

              // English Option
              ListTile(
                leading: const Icon(Icons.language, color: Color(0xFF8E7CFF)),
                title: const Text('English'),
                trailing: currentLang == 'en'
                    ? const Icon(
                  Icons.check_circle,
                  color: Color(0xFF8E7CFF),
                )
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _switchLanguage('en');
                },
              ),

              // Arabic Option
              ListTile(
                leading: const Icon(Icons.language, color: Color(0xFF8E7CFF)),
                title: const Text('العربية'),
                trailing: currentLang == 'ar'
                    ? const Icon(
                  Icons.check_circle,
                  color: Color(0xFF8E7CFF),
                )
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _switchLanguage('ar');
                },
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(currentLang == 'ar' ? 'إغلاق' : 'Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F6FF),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF6A5CFF),
            ),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const AnaWelcomeScreen(),
                ),
                    (route) => false,
              );
            },
          ),
          title: Consumer<QuestionnaireProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  Image.asset(
                    'assets/images/ANA\'s-logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E7CFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'ANA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _questionProgressText(provider),
                      style: const TextStyle(
                        color: Color(0xFF2A1E3B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            Consumer<QuestionnaireProvider>(
              builder: (context, provider, child) {
                return IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0ECF7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      provider.language == 'ar' ? 'AR' : 'EN',
                      style: const TextStyle(
                        color: Color(0xFF8E7CFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  onPressed: () => _showLanguageSwitcher(context),
                );
              },
            ),
          ],
        ),
        body: Consumer<QuestionnaireProvider>(
          builder: (context, provider, child) {
            // Sync page controller when needed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_shouldSyncPageController) {
                _syncPageController();
              }
            });

            // Only show loading for initial load
            if (!_isInitialized || (provider.isLoading && !provider.hasLoaded)) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF8E7CFF)),
                    const SizedBox(height: 20),
                    Text(
                      provider.language == 'ar'
                          ? 'بنحمّل الأسئلة...'
                          : 'Loading questions...',
                      style: const TextStyle(
                        color: Color(0xFF4B3A66),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!provider.hasLoaded || provider.questions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 60,
                      color: Color(0xFF6A5CFF),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      provider.language == 'ar'
                          ? 'معرفناش نحمّل الأسئلة'
                          : 'Unable to load questions',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _initializeProvider();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E7CFF),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        provider.language == 'ar' ? 'حاول تاني' : 'Retry',
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                LinearProgressIndicator(
                  value: (provider.currentQuestionIndex + 1) / provider.totalQuestions,
                  backgroundColor: const Color(0xFFE5DEFF),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF8E7CFF),
                  ),
                  minHeight: 4,
                ),

                Expanded(
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (notification) {
                      if (_pageController.hasClients && _pageController.page != null) {
                        final currentPage = _pageController.page!.round();
                        if (currentPage != provider.currentQuestionIndex) {
                          provider.setCurrentQuestionIndex(currentPage);
                        }
                      }
                      return true;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      itemCount: provider.totalQuestions,
                      onPageChanged: (index) {
                        provider.setCurrentQuestionIndex(index);
                      },
                      itemBuilder: (context, index) {
                        return _buildQuestionPage(
                          index,
                          provider.questions[index],
                        );
                      },
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      if (_pageController.hasClients && provider.currentQuestionIndex > 0)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _previousQuestion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF6A5CFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: const Color(0xFF6A5CFF).withValues(alpha: 0.3),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                  color: const Color(0xFF6A5CFF),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  provider.language == 'ar' ? 'السابق' : 'Previous',
                                  style: const TextStyle(
                                    color: Color(0xFF6A5CFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_pageController.hasClients && provider.currentQuestionIndex > 0)
                        const SizedBox(width: 10),

                      Expanded(
                        flex: _pageController.hasClients && provider.currentQuestionIndex > 0 ? 1 : 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_pageController.hasClients &&
                                provider.currentQuestionIndex < provider.totalQuestions - 1) {
                              _nextQuestion();
                            } else {
                              _submitQuestionnaire();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E7CFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _pageController.hasClients &&
                                    provider.currentQuestionIndex < provider.totalQuestions - 1
                                    ? (provider.language == 'ar' ? 'التالي' : 'Next')
                                    : (provider.language == 'ar' ? 'إرسال' : 'Submit'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_pageController.hasClients &&
                                  provider.currentQuestionIndex < provider.totalQuestions - 1)
                                const SizedBox(width: 8),
                              if (_pageController.hasClients &&
                                  provider.currentQuestionIndex < provider.totalQuestions - 1)
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _validateAllQuestions() {
    final totalQuestions = _provider.totalQuestions;

    for (int i = 0; i < totalQuestions; i++) {
      final answer = _provider.getAnswerForQuestion(i);
      final question = _provider.questions[i];

      if (answer == null) {
        _pageController.jumpToPage(i);
        _provider.setCurrentQuestionIndex(i);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _provider.language == 'ar'
                  ? 'السؤال ${_questionNumberText(i + 1)} لسه متجاوبش'
                  : 'Question ${i + 1} is not answered',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return false;
      }

      if (question.isSlider && answer.sliderValue == null) {
        _pageController.jumpToPage(i);
        _provider.setCurrentQuestionIndex(i);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _provider.language == 'ar'
                  ? 'السؤال ${_questionNumberText(i + 1)} محتاج تختار قيمة'
                  : 'Question ${i + 1} needs a slider value',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return false;
      }

      if (!question.isSlider &&
          (answer.selectedIndices == null || answer.selectedIndices!.isEmpty) &&
          (answer.answerText == null || answer.answerText!.isEmpty)) {
        _pageController.jumpToPage(i);
        _provider.setCurrentQuestionIndex(i);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _provider.language == 'ar'
                  ? 'السؤال ${_questionNumberText(i + 1)} محتاج تختار إجابة واحدة على الأقل'
                  : 'Question ${i + 1} needs an option selection',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return false;
      }
    }

    return true;
  }

  void _previousQuestion() {
    if (_pageController.hasClients && _provider.currentQuestionIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitQuestionnaire() async {
    if (!_validateAllQuestions()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
      ),
    );

    try {
      await _syncAppLanguageWithQuestionnaire();
      final success = await _provider.submitAnswers();

      if (mounted) {
        Navigator.of(context).pop();

        if (success) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const QuestionnaireResultsScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _provider.language == 'ar'
                    ? 'جاوب على كل الأسئلة قبل الإرسال'
                    : 'Please answer all questions before submitting.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _provider.language == 'ar'
                  ? 'حصل خطأ وإحنا بنبعت الاستبيان'
                  : 'Error submitting questionnaire',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}