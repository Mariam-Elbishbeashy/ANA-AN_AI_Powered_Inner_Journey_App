import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/core/services/firestore_service.dart';
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

  Future<void> _initializeProvider() async {
    try {
      await _provider.loadQuestions();

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
    if (_provider.language == newLanguage) return;

    try {
      await _provider.switchLanguage(newLanguage);

      setState(() {
        _shouldSyncPageController = true;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newLanguage == 'ar'
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
            ? 'يرجى الإجابة على هذا السؤال أولاً'
            : 'Please answer this question first',
      );
      return false;
    }

    if (question.isSlider && answer.sliderValue == null) {
      _showValidationError(
        _provider.language == 'ar'
            ? 'يرجى تحديد قيمة للسؤال'
            : 'Please select a value for this question',
      );
      return false;
    }

    if (!question.isSlider &&
        (answer.selectedIndices == null || answer.selectedIndices!.isEmpty) &&
        (answer.answerText == null || answer.answerText!.isEmpty)) {
      _showValidationError(
        _provider.language == 'ar'
            ? 'يرجى اختيار خيار على الأقل'
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

  Widget _buildQuestionPage(int index, Question question) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: QuestionWidget(
        question: question,
        onAnswer: (answer) {
          _provider.saveAnswer(index, answer);
        },
        initialAnswer: _provider.getAnswerForQuestion(index),
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
                      '${provider.language == 'ar' ? 'السؤال' : 'Question'} ${provider.currentQuestionIndex + 1}/${provider.totalQuestions}',
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
                          ? 'جاري تحميل الأسئلة...'
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
                          ? 'تعذر تحميل الأسئلة'
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
                        provider.language == 'ar' ? 'إعادة المحاولة' : 'Retry',
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
                  ? 'السؤال ${i + 1} لم يتم الإجابة عليه'
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
                  ? 'السؤال ${i + 1} يحتاج إلى تحديد قيمة'
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
                  ? 'السؤال ${i + 1} يحتاج إلى اختيار خيار'
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
                    ? 'يرجى الإجابة على جميع الأسئلة قبل الإرسال'
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
                  ? 'خطأ في إرسال الاستبيان'
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