// help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const String _supportEmail = 'anajourney26@hotmail.com';
  static const String _instagramUrl =
      'https://www.instagram.com/anajourney26/';

  int _rating = 0;
  bool _hasRated = false;

  void _rateApp() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isArabicValue = isArabic(context);

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Directionality(
              textDirection:
              isArabicValue ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  isArabicValue ? 'قيّم التطبيق' : 'Rate Our App',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArabicValue
                          ? 'إيه رأيك في تجربتك مع تطبيق أنا؟'
                          : 'How would you rate your experience with ANA?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A6A5A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            dialogSetState(() {
                              _rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              index < _rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 40,
                              color: index < _rating
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFFD0C6E8),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    if (_rating > 0)
                      Text(
                        _getRatingMessage(_rating, isArabicValue),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _getRatingColor(_rating),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_rating > 0 && _rating < 4)
                      TextField(
                        maxLines: 3,
                        textAlign:
                        isArabicValue ? TextAlign.right : TextAlign.left,
                        decoration: InputDecoration(
                          hintText: isArabicValue
                              ? 'إيه اللي نقدر نحسّنه؟ (اختياري)'
                              : 'How can we improve? (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5DEFF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF8E7CFF),
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      isArabicValue ? 'بعدين' : 'Maybe Later',
                      style: const TextStyle(color: Color(0xFF7A6A5A)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _rating > 0
                        ? () {
                      _submitRating(_rating);
                      Navigator.of(context).pop();
                      setState(() {
                        _hasRated = true;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabicValue
                                ? 'شكراً لتقييمك!'
                                : 'Thank you for your rating!',
                          ),
                          backgroundColor: const Color(0xFF8E7CFF),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E7CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isArabicValue ? 'إرسال التقييم' : 'Submit Rating',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getRatingMessage(int rating, bool isArabic) {
    switch (rating) {
      case 1:
        return isArabic
            ? 'زعلانين إن تجربتك ماكانتش مريحة 😔'
            : 'Sorry to hear that 😔';
      case 2:
        return isArabic
            ? 'هنشتغل نخلّي التجربة أحسن 💪'
            : 'We\'ll work on improving 💪';
      case 3:
        return isArabic
            ? 'شكراً! رأيك هيساعدنا نطوّر 👍'
            : 'Thank you! We\'re always trying to improve 👍';
      case 4:
        return isArabic
            ? 'جميل! مبسوطين إن التجربة عجبتك 😊'
            : 'Great! Glad you enjoyed it 😊';
      case 5:
        return isArabic
            ? 'مبسوطين جداً بتقييمك الرائع! 🌟'
            : 'Amazing! Thank you for the excellent rating! 🌟';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 4:
      case 5:
        return Colors.green;
      default:
        return const Color(0xFF7A6A5A);
    }
  }

  void _submitRating(int rating) {
    // Here you would typically:
    // 1. Save the rating locally.
    // 2. Send it to Firestore/backend.
    // 3. Open the app store for high ratings.
    debugPrint('User rated the app: $rating stars');

    if (rating >= 4) {
      // _openAppStore();
    }
  }

  void _openAppStore() {
    // For iOS: https://apps.apple.com/app/idYOUR_APP_ID?action=write-review
    // For Android: market://details?id=YOUR_PACKAGE_NAME
  }

  Future<void> _sendEmail(bool isArabicValue) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': isArabicValue ? 'طلب دعم من تطبيق أنا' : 'ANA Support Request',
      },
    );

    await _launchUri(
      uri,
      isArabicValue: isArabicValue,
      fallbackMessage: isArabicValue
          ? 'مش قادرين نفتح البريد دلوقتي.'
          : 'Could not open your email app right now.',
    );
  }

  Future<void> _openCommunity(bool isArabicValue) async {
    await _launchUri(
      Uri.parse(_instagramUrl),
      isArabicValue: isArabicValue,
      fallbackMessage: isArabicValue
          ? 'مش قادرين نفتح إنستجرام دلوقتي'
          : 'Could not open Instagram',
    );
  }

  Future<void> _launchUri(
      Uri uri, {
        required bool isArabicValue,
        required String fallbackMessage,
      }) async {

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                fallbackMessage,
                textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
              ),
            ),
            backgroundColor: const Color(0xFF8E7CFF),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fallbackMessage),
          backgroundColor: const Color(0xFF8E7CFF),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Directionality(
      textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F6FF),
        body: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildGuideSection(context),
                    const SizedBox(height: 24),
                    _buildFAQSection(context),
                    const SizedBox(height: 24),
                    _buildContactSupportSection(context),
                    const SizedBox(height: 24),
                    _buildRateAppSection(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isArabicValue = isArabic(context);

    // Keep the back button and the page title in the same position in Arabic
    // and English, so the top bar does not flip when the app language changes.
    return Container(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Color(0xFF2A1E3B),
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabicValue ? 'المساعدة والدعم' : 'Help & Support',
                    textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                    textDirection:
                    isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection(BuildContext context) {
    final isArabicValue = isArabic(context);

    final guideSections = [
      _GuideSectionData(
        icon: Icons.flag_rounded,
        title: isArabicValue ? 'أول مرة أستخدم أنا' : 'First time using ANA',
        subtitle: isArabicValue
            ? 'ابدأ من هنا لو لسه بتتعرف على التطبيق ومش عارف تبدأ منين.'
            : 'Start here if you are new and want to know where to begin.',
        points: isArabicValue
            ? const [
          'سجّل دخولك أو اعمل حساب جديد عشان رحلتك تتسجل باسمك.',
          'ابدأ بالاستبيان الأول لأنه بيبني أول صورة عن شخصياتك الداخلية.',
          'اختار الإجابات اللي قريبة من إحساسك، مش الإجابات اللي شايف إنها مثالية.',
          'بعد الاستبيان هتظهرلك الشخصيات الأساسية اللي ANA شايف إنها أوضح عندك.',
          'ادخل على خريطة الشخصيات عشان تفهم مين نشط، مين مستقر، ومين غير نشط.',
          'ابدأ بجلسة بسيطة مع أكتر شخصية ظاهرة بدل ما تفتح كل حاجة مرة واحدة.',
          'لو مش عارف تبدأ منين، شوف المهام اليومية لأنها بتديك خطوة صغيرة وواضحة.',
          'ارجع للصفحة دي في أي وقت لو حسيت إن في ميزة مش واضحة.',
        ]
            : const [
          'Sign in or create an account so your journey can be saved to your profile.',
          'Start with the first questionnaire because it builds your first inner character view.',
          'Choose the answers that feel closest to you, not the answers that sound perfect.',
          'After the questionnaire, ANA shows the main characters that seem most visible for you.',
          'Open the character map to understand which parts are Active, Stable, or Inactive.',
          'Start with one simple session instead of opening every feature at once.',
          'If you are not sure what to do next, check your daily tasks for one small step.',
          'Come back to this page any time a feature feels unclear.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.quiz_rounded,
        title: isArabicValue ? 'الاستبيان والنتائج' : 'Questionnaire and results',
        subtitle: isArabicValue
            ? 'افتح الجزء ده لو عايز تفهم الأسئلة، النتيجة، أو إعادة الاستبيان.'
            : 'Open this if you want to understand the questions, results, or retaking the questionnaire.',
        points: isArabicValue
            ? const [
          'الاستبيان مش اختبار، هو طريقة عشان ANA يفهم أنماطك بشكل مبدئي.',
          'كل سؤال بيقيس إحساس أو تصرف ممكن يظهر في مواقف مختلفة.',
          'لو سؤال حسيته قريب من كذا إجابة، اختار الإجابة الأقرب لحالتك أغلب الوقت.',
          'النتيجة بتطلع أول مجموعة شخصيات ممكن تكون مؤثرة على رحلتك.',
          'وجود شخصية في النتيجة مش معناه حكم ثابت، ده مجرد بداية لفهم أعمق.',
          'نتيجتك ممكن تتغير بعد الجلسات، وإعادة التأطير، والمتابعة المستمرة.',
          'تقدر تعيد الاستبيان من الإعدادات لو حسيت إن حالتك أو ردودك اتغيرت.',
          'بعد إعادة الاستبيان، ANA يحدّث الصورة العامة حسب إجاباتك الجديدة.',
          'لو النتيجة مش مفهومة، افتح خريطة الشخصيات واقرأ وصف كل شخصية بهدوء.',
        ]
            : const [
          'The questionnaire is not a test; it helps ANA understand your patterns at the beginning.',
          'Each question looks at a feeling or behavior that may appear in different situations.',
          'If more than one answer feels right, choose what matches you most of the time.',
          'The result shows the first group of characters that may affect your journey.',
          'Seeing a character in your result is not a fixed label; it is only a starting point.',
          'Your result can change through sessions, Reframe, and ongoing progress.',
          'You can retake the questionnaire from settings if your state or answers change.',
          'After retaking it, ANA updates your overall view based on the new answers.',
          'If the result feels unclear, open the character map and read each character description slowly.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.view_in_ar_rounded,
        title: isArabicValue ? 'خريطة الشخصيات' : 'Character map',
        subtitle: isArabicValue
            ? 'افتح الجزء ده لو عايز تفهم حالة كل شخصية ومكانها في رحلتك.'
            : 'Open this if you want to understand each character state and its role in your journey.',
        points: isArabicValue
            ? const [
          'الخريطة بتعرض الشخصيات بشكل بصري عشان تشوف الصورة العامة بسرعة.',
          'نشطة يعني الشخصية ظاهرة بقوة ومحتاجة اهتمام أو جلسة دلوقتي.',
          'مستقرة يعني الشخصية لسه موجودة، بس حالتها أهدى ومتوازنة أكتر.',
          'غير نشطة يعني الشخصية ما ظهرتش كتير في الفترة الأخيرة أو تأثيرها قل.',
          'افتح أي شخصية عشان تشوف الوصف، الحالة، والجلسات المرتبطة بيها.',
          'لو في أكتر من شخصية نشطة، ابدأ بالأقوى أو اللي حاسس إنها مأثرة عليك أكتر.',
          'الخريطة بتتحدث مع الوقت حسب الاستبيان، الجلسات، وإعادة التأطير.',
          'مش لازم كل الشخصيات تظهر عندك في نفس الوقت، وده طبيعي.',
          'استخدم الخريطة كملخص سريع، وبعدها ادخل على التفاصيل لو محتاج تفهم أكتر.',
        ]
            : const [
          'The map shows your characters visually so you can see the bigger picture quickly.',
          'Active means the character is strongly present and may need attention or a session now.',
          'Stable means the character is still present but feels calmer and more balanced.',
          'Inactive means the character has not appeared much recently or its effect is lower.',
          'Open any character to see its description, current state, and related sessions.',
          'If several characters are Active, start with the strongest one or the one affecting you most.',
          'The map updates over time based on the questionnaire, sessions, and Reframe.',
          'Not all characters need to appear at the same time, and that is normal.',
          'Use the map as a quick summary, then open details when you need a deeper view.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.auto_fix_high_rounded,
        title: isArabicValue ? 'إعادة التأطير' : 'Reframe',
        subtitle: isArabicValue
            ? 'افتح الجزء ده لو عايز تفهم موقف أو إحساس من زاوية أوضح.'
            : 'Open this if you want to understand a feeling or situation from a clearer angle.',
        points: isArabicValue
            ? const [
          'إعادة التأطير معمولة عشان تكتب أو تسجل موقف مضايقك وتفهمه بشكل أهدى.',
          'ممكن تستخدم كتابة، صوت، أو فيديو حسب اللي ظاهر ومتاح عندك في التطبيق.',
          'حاول تكتب موقف واحد في كل مرة عشان التحليل يبقى أوضح.',
          'ANA بيحلل الإحساس، النبرة، أو الإشارات المتاحة ويربطها بأقرب شخصية داخلية.',
          'بعد التحليل ممكن يظهرلك اقتراح بجلسة مع شخصية معينة.',
          'لو عندك شخصيات نشطة كتير، إعادة التأطير ممكن تتقفل مؤقتاً عشان ما يحصلش تشتيت.',
          'لو إعادة التأطير مقفولة، كمّل الأول مع الشخصيات الحالية أو المهام اليومية.',
          'استخدم إعادة التأطير لما تكون عايز تفهم معنى الإحساس، مش بس تسجله.',
          'النتيجة هدفها تساعدك تلاحظ نمطك، مش تحكم عليك أو تشخصك.',
        ]
            : const [
          'Reframe helps you write or record a difficult situation and understand it more calmly.',
          'You can use text, voice, or video depending on what is available inside the app.',
          'Try to describe one situation at a time so the analysis is clearer.',
          'ANA analyzes the feeling, tone, or available signals and connects them to the closest inner character.',
          'After the analysis, ANA may suggest a session with a specific character.',
          'If several characters are Active, Reframe may pause temporarily to avoid overload.',
          'If Reframe is locked, continue with your current characters or daily tasks first.',
          'Use Reframe when you want to understand the meaning behind a feeling, not just save it.',
          'The result is meant to help you notice a pattern, not to judge or diagnose you.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.chat_bubble_rounded,
        title: isArabicValue ? 'الجلسات والمرشد' : 'Sessions and Guider',
        subtitle: isArabicValue
            ? 'افتح الجزء ده لو عايز تعرف الدردشة ماشية إزاي وإمتى المرشد بيتدخل.'
            : 'Open this if you want to know how chats work and when the Guider steps in.',
        points: isArabicValue
            ? const [
          'كل جلسة بتكون مع شخصية محددة عشان الحوار يبقى مركز ومش متلخبط.',
          'ابدأ الجلسة بجملة بسيطة عن اللي حاسس بيه دلوقتي.',
          'حاول ترد بهدوء ومن غير ضغط، حتى لو الرد قصير.',
          'لو الشخصية بتكرر نفس الفكرة، ANA ممكن يلاحظ إن الحوار محتاج تنظيم.',
          'المرشد بيتدخل لما الجلسة تحتاج تهدئة، تلخيص، أو خطوات أبسط.',
          'المرشد مش بيغيّر إحساسك غصب، هو بيساعدك تشوفه بأمان أكتر.',
          'ممكن تكمل مع الشخصية بعد تدخل المرشد لو حسيت إنك جاهز.',
          'لو حسيت بتوتر عالي، اقفل الجلسة وخد نفس أو وقفة صغيرة.',
          'لو في خطر حقيقي أو أزمة شديدة، تواصل مع مختص أو جهة طوارئ فوراً.',
        ]
            : const [
          'Each session is with one character so the conversation stays focused and clear.',
          'Start the session with one simple sentence about what you feel right now.',
          'Reply slowly without pressure, even if your answer is short.',
          'If the character keeps repeating the same idea, ANA may notice that the session needs structure.',
          'The Guider steps in when the session needs grounding, a summary, or simpler steps.',
          'The Guider does not force your feelings to change; it helps you look at them more safely.',
          'You can continue with the character after the Guider if you feel ready.',
          'If you feel too tense, stop the session and take a breath or a short pause.',
          'If you are in real danger or severe crisis, contact a professional or emergency service immediately.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.insights_rounded,
        title: isArabicValue ? 'التقدم والرسوم' : 'Progress and charts',
        subtitle: isArabicValue
            ? 'افتح الجزء ده لو عايز تفهم الشدة، النبرة، والمشاعر مع الوقت.'
            : 'Open this if you want to understand intensity, tone, and emotions over time.',
        points: isArabicValue
            ? const [
          'صفحة التقدم بتجمع إشارات من الجلسات وإعادة التأطير عشان توريك التغيير مع الوقت.',
          'الشدة بتوضح قد إيه الإحساس كان قوي في جلساتك الأخيرة.',
          'النبرة بتساعدك تلاحظ هل كلامك كان أهدى، أضغط، أو متغير.',
          'المشاعر بتوضح الأنماط اللي بتتكرر أكتر في رحلتك.',
          'ممكن تشوف اليوم أو الأسبوع حسب طريقة العرض المتاحة.',
          'لو يوم فيه جلسات كتير، راجع آخر الجلسات عشان تفهم السبب مش الرقم بس.',
          'ما تحكمش على تقدمك من يوم واحد، بص على الاتجاه العام خلال أسبوع.',
          'لو في ارتفاع مفاجئ، ده ممكن يبقى إشارة إن في شخصية محتاجة اهتمام أكتر.',
          'استخدم الرسوم كأداة ملاحظة، مش كدرجات أو تقييم لشخصيتك.',
        ]
            : const [
          'The progress page collects signals from sessions and Reframe to show change over time.',
          'Intensity shows how strong the feeling was in your recent sessions.',
          'Tone helps you notice whether your language felt calmer, heavier, or different.',
          'Emotions show the patterns that repeat most in your journey.',
          'You can review the day or week depending on the available view.',
          'If one day has many sessions, check the recent sessions to understand the reason, not only the number.',
          'Do not judge your progress from one day; look at the overall direction across the week.',
          'A sudden increase may mean one character needs more attention.',
          'Use charts as a reflection tool, not as grades or a judgment of who you are.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.task_alt_rounded,
        title: isArabicValue ? 'المهام اليومية والإنجازات' : 'Daily tasks and achievements',
        subtitle: isArabicValue
            ? 'افتح الجزء ده لو عايز تعرف تستخدم المهام والإنجازات إزاي.'
            : 'Open this if you want to know how to use tasks and achievements.',
        points: isArabicValue
            ? const [
          'المهام اليومية معمولة عشان تديك خطوة صغيرة بدل ما الرحلة تبقى تقيلة.',
          'اختار مهمة واحدة في اليوم لو حاسس إن طاقتك قليلة.',
          'المهمة ممكن تكون ملاحظة، تمرين بسيط، أو خطوة مرتبطة بشخصية معينة.',
          'الالتزام مش معناه تعمل كل حاجة، معناه ترجع لنفسك حتى بخطوة صغيرة.',
          'الإنجازات بتظهر لما تكتشف شخصيات، تكمل جلسات، أو تحافظ على الاستمرارية.',
          'لو فاتك يوم، كمّل عادي من غير ما تحس إنك بدأت من الصفر.',
          'استخدم الإنجازات كتشجيع، مش كضغط أو مقارنة.',
          'راجع المهام مع التقدم عشان تفهم إيه اللي بيساعدك فعلاً.',
        ]
            : const [
          'Daily tasks are designed to give you one small step instead of making the journey feel heavy.',
          'Choose one task a day if your energy feels low.',
          'A task may be a reflection, a small exercise, or a step linked to a specific character.',
          'Consistency does not mean doing everything; it means returning to yourself with one small step.',
          'Achievements appear when you discover characters, complete sessions, or stay consistent.',
          'If you miss a day, continue normally without feeling like you started from zero.',
          'Use achievements as encouragement, not as pressure or comparison.',
          'Review tasks with progress to understand what is actually helping you.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.lock_rounded,
        title: isArabicValue ? 'الخصوصية والأمان' : 'Privacy and safety',
        subtitle: isArabicValue
            ? 'افتح الجزء ده لو عايز تعرف بياناتك بتتستخدم إزاي وحدود التطبيق.'
            : 'Open this if you want to understand how your data is used and the app limits.',
        points: isArabicValue
            ? const [
          'بياناتك بتستخدم جوّه التطبيق عشان تحسين تجربتك ومتابعة تقدمك.',
          'الجلسات والنتائج بتساعد ANA يفهم الأنماط اللي بتظهر عندك مع الوقت.',
          'ما تكتبش معلومات حساسة جداً لو مش مرتاح تحفظها في التطبيق.',
          'ANA أداة مساعدة للفهم والتأمل، مش بديل عن دكتور أو معالج نفسي.',
          'لو عندك أزمة شديدة أو إحساس بخطر، لازم تتواصل مع شخص موثوق أو مختص فوراً.',
          'لو حسيت إن جلسة فتحت موضوع تقيل، اقفلها وخد وقتك قبل ما ترجع.',
          'استخدم التطبيق في مكان هادي لما تكون بتتكلم عن مشاعر حساسة.',
          'لو في مشكلة تقنية أو سؤال عن البيانات، ابعت لنا من قسم تواصل معانا.',
        ]
            : const [
          'Your data is used inside the app to improve your experience and track your progress.',
          'Sessions and results help ANA understand the patterns that appear over time.',
          'Do not write very sensitive details if you do not feel comfortable saving them in the app.',
          'ANA is a reflection support tool, not a replacement for a doctor or therapist.',
          'If you are in severe crisis or danger, contact a trusted person or professional immediately.',
          'If a session opens a heavy topic, close it and take your time before returning.',
          'Use the app in a calm place when you are talking about sensitive feelings.',
          'If you have a technical problem or data question, contact us from the support section.',
        ],
      ),
    ];

    return _SectionCard(
      child: Column(
        crossAxisAlignment:
        isArabicValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.menu_book_rounded,
            title: isArabicValue ? 'دليل استخدام أنا' : 'ANA User Guide',
            subtitle: isArabicValue
                ? 'افتح الجزء اللي محتاجه بس، وهتلاقي شرح واضح من غير ما تقرأ كل حاجة مرة واحدة.'
                : 'Open only the part you need and get clear guidance without reading everything at once.',
          ),
          const SizedBox(height: 16),
          ...guideSections.map((section) {
            return _GuideItem(data: section);
          }),
        ],
      ),
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    final isArabicValue = isArabic(context);

    return _SectionCard(
      child: Column(
        crossAxisAlignment:
        isArabicValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.help_rounded,
            title: isArabicValue ? 'الأسئلة الشائعة' : 'Frequently Asked Questions',
            subtitle: isArabicValue
                ? 'إجابات سريعة على أكتر حاجات ممكن تحتاجها جوّه التطبيق.'
                : 'Quick answers to the most common things you may need inside the app.',
          ),
          const SizedBox(height: 20),
          ..._buildFAQItems(context),
        ],
      ),
    );
  }

  Widget _buildContactSupportSection(BuildContext context) {
    final isArabicValue = isArabic(context);

    return _SectionCard(
      child: Column(
        crossAxisAlignment:
        isArabicValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment:
            isArabicValue ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              isArabicValue ? 'تواصل معانا' : 'Contact Support',
              textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
              textDirection:
              isArabicValue ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A1E3B),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabicValue
                ? 'لو عندك سؤال أو مشكلة، اختار الطريقة الأنسب ليك.'
                : 'Choose the easiest way to reach ANA support.',
            textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
            textDirection:
            isArabicValue ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7A6A5A),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _ContactOption(
            icon: const Icon(
              Icons.email_rounded,
              color: Color(0xFF8E7CFF),
              size: 20,
            ),
            title: isArabicValue ? 'البريد الإلكتروني' : 'Email',
            subtitle: _supportEmail,
            onTap: () {
              _sendEmail(isArabicValue);
            },
          ),
          const Divider(height: 24),
          _ContactOption(
            icon: const _InstagramIcon(
              size: 20,
              color: Color(0xFF8E7CFF),
            ),
            title: isArabicValue ? 'انضم لمجتمع أنا' : 'Join ANA Community',
            subtitle: '@anajourney26',
            onTap: () {
              _openCommunity(isArabicValue);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRateAppSection(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECF7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            _hasRated ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 40,
            color: _hasRated
                ? const Color(0xFFFFD700)
                : const Color(0xFF8E7CFF),
          ),
          const SizedBox(height: 16),
          Text(
            isArabicValue ? 'إيه رأيك في تطبيق أنا؟' : 'How do you like ANA?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A1E3B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabicValue
                ? 'تقييمك بيساعدنا نطوّر التجربة ونخليها أوضح وأسهل.'
                : 'Your rating helps us improve the experience and make it clearer.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7A6A5A), height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _rateApp,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              _hasRated ? const Color(0xFF5CB85C) : const Color(0xFF8E7CFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasRated ? Icons.check_rounded : Icons.star_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasRated
                      ? (isArabicValue ? 'تم التقييم!' : 'Rated!')
                      : (isArabicValue ? 'قيّم التطبيق' : 'Rate App'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_hasRated)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                isArabicValue ? 'شكراً لتقييمك!' : 'Thank you for your rating!',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5CB85C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFAQItems(BuildContext context) {
    final isArabicValue = isArabic(context);

    final faqs = [
      {
        'question': isArabicValue ? 'إيه هو تطبيق أنا؟' : 'What is ANA?',
        'answer': isArabicValue
            ? 'تطبيق أنا بيساعدك تفهم مشاعرك من خلال شخصيات داخلية، جلسات تأمل، إعادة التأطير، وخريطة بتوضح حالتك مع الوقت.'
            : 'ANA helps you understand your emotions through inner characters, reflection sessions, Reframe, and a character map that changes over time.',
      },
      {
        'question': isArabicValue
            ? 'إزاي نظام الشخصيات بيشتغل؟'
            : 'How does the character system work?',
        'answer': isArabicValue
            ? 'تطبيق أنا بيستخدم إجابات الاستبيان وتحليلات الجلسات عشان يحدد الشخصيات الأقرب لحالتك، زي الشخصيات النشطة أو المستقرة أو الأقل ظهوراً.'
            : 'ANA uses questionnaire answers and session analysis to identify the characters closest to your current state, such as active, stable, or less visible characters.',
      },
      {
        'question': isArabicValue
            ? 'إيه فائدة الاستبيان في البداية؟'
            : 'Why do I start with a questionnaire?',
        'answer': isArabicValue
            ? 'الاستبيان بيدي تطبيق أنا نقطة بداية يقدر منها يتعرف على الأنماط اللي بتظهر عندك ويكوّن أول صورة عن الشخصيات.'
            : 'The questionnaire gives ANA a starting point to understand your patterns and build your first character view.',
      },
      {
        'question': isArabicValue
            ? 'إزاي أعيد الاستبيان؟'
            : 'How can I retake the questionnaire?',
        'answer': isArabicValue
            ? 'ادخل على إعدادات الحساب، وبعدها اختار إعادة الاستبيان. ده هيحدّث النتائج بناءً على إجاباتك الجديدة.'
            : 'Go to Account Settings and choose Retake Questionnaire. Your results will update based on your new answers.',
      },
      {
        'question': isArabicValue ? 'إيه هي إعادة التأطير؟' : 'What is Reframe?',
        'answer': isArabicValue
            ? 'إعادة التأطير مساحة تكتب أو تسجل فيها موقف أو إحساس، وتطبيق أنا يحلله عشان يساعدك تشوفه بطريقة أوضح ويربطه بالشخصية المناسبة.'
            : 'Reframe lets you write or record a feeling or situation. ANA analyzes it to help you see it more clearly and connect it to the right character.',
      },
      {
        'question': isArabicValue
            ? 'ليه أحياناً إعادة التأطير بتكون مقفولة؟'
            : 'Why is Reframe sometimes locked?',
        'answer': isArabicValue
            ? 'لو عندك شخصيات نشطة كتير في نفس الوقت، التطبيق ممكن يوقف إعادة التأطير مؤقتاً عشان يشجعك تهدى وتكمل مع الشخصيات الحالية الأول.'
            : 'If several characters are active at the same time, ANA may pause Reframe temporarily so you can slow down and work with the current characters first.',
      },
      {
        'question': isArabicValue
            ? 'إزاي أستخدم خريطة الشخصيات؟'
            : 'How do I use the character map?',
        'answer': isArabicValue
            ? 'الخريطة بتعرض الشخصيات بطريقة بصرية. افتح الشخصية من الخريطة عشان تشوف تفاصيلها، حالتها، وتأثيرها على رحلتك.'
            : 'The map displays your characters visually. Open a character from the map to see its details, state, and role in your journey.',
      },
      {
        'question': isArabicValue
            ? 'إيه الفرق بين نشطة ومستقرة وغير نشطة؟'
            : 'What is the difference between Active, Stable, and Inactive?',
        'answer': isArabicValue
            ? 'نشطة يعني الشخصية ظاهرة بقوة حالياً، مستقرة يعني موجودة بس أهدى، وغير نشطة يعني مش ظاهرة كتير في الفترة الأخيرة.'
            : 'Active means the character is showing strongly now, Stable means it is present but calmer, and Inactive means it has not appeared much recently.',
      },
      {
        'question': isArabicValue ? 'مين هو المرشد؟' : 'Who is the Guider?',
        'answer': isArabicValue
            ? 'المرشد هو مساعد داخل تطبيق أنا بيتدخل لما الحوار يحتاج تهدئة أو تنظيم، وبيقدملك خطوات بسيطة تكمل بيها بأمان.'
            : 'The Guider is an ANA helper that steps in when a session needs grounding or structure, giving you simple steps to continue safely.',
      },
      {
        'question': isArabicValue
            ? 'هل أقدر أستخدم صوت أو فيديو؟'
            : 'Can I use voice or video?',
        'answer': isArabicValue
            ? 'أيوه، تطبيق أنا بيدعم الكتابة والصوت والفيديو في أجزاء من الرحلة عشان يقرأ الإشارات العاطفية بطريقة أوسع.'
            : 'Yes. ANA supports text, voice, and video in parts of the journey so it can understand emotional signals more broadly.',
      },
      {
        'question': isArabicValue ? 'هل بياناتي آمنة؟' : 'Is my data secure?',
        'answer': isArabicValue
            ? 'أيوه، بياناتك بتتخزن بشكل محمي، وهدف استخدامها جوّه التطبيق هو تحسين تجربتك ومتابعة تقدمك.'
            : 'Yes. Your data is stored securely and is used inside the app to improve your experience and track your progress.',
      },
      {
        'question': isArabicValue
            ? 'هل تطبيق أنا بديل للعلاج النفسي؟'
            : 'Is ANA a replacement for therapy?',
        'answer': isArabicValue
            ? 'لا، تطبيق أنا أداة مساعدة للتأمل وفهم الذات، لكنه مش بديل عن دكتور أو مختص. لو في خطر أو أزمة شديدة، لازم تتواصل مع مختص أو جهة طوارئ فوراً.'
            : 'No. ANA is a self-reflection support tool, not a replacement for a therapist or clinician. If you are in danger or crisis, contact a professional or emergency service immediately.',
      },
      {
        'question': isArabicValue
            ? 'أعمل إيه لو في مشكلة في التطبيق؟'
            : 'What should I do if something is not working?',
        'answer': isArabicValue
            ? 'جرّب تقفل التطبيق وتفتحه تاني، اتأكد من الإنترنت، ولو المشكلة مستمرة ابعت لنا من قسم تواصل معانا.'
            : 'Try closing and reopening the app, check your internet connection, and contact us from the support section if the issue continues.',
      },
    ];

    return faqs.map((faq) {
      return _FAQItem(
        question: faq['question']!,
        answer: faq['answer']!,
      );
    }).toList();
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);
    final textDirection = isArabicValue ? TextDirection.rtl : TextDirection.ltr;
    final titleAlignment =
    isArabicValue ? Alignment.centerRight : Alignment.centerLeft;

    final iconBox = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF8E7CFF), size: 22),
    );

    final textBlock = Expanded(
      child: Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: titleAlignment,
              child: Text(
                title,
                textAlign: TextAlign.start,
                textDirection: textDirection,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.start,
              textDirection: textDirection,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ],
        ),
      ),
    );

    return Directionality(
      textDirection: textDirection,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconBox,
          const SizedBox(width: 14),
          textBlock,
        ],
      ),
    );
  }
}

class _GuideSectionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> points;

  const _GuideSectionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
  });
}

class _GuideItem extends StatefulWidget {
  final _GuideSectionData data;

  const _GuideItem({required this.data});

  @override
  State<_GuideItem> createState() => _GuideItemState();
}

class _GuideItemState extends State<_GuideItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);
    final textDirection = isArabicValue ? TextDirection.rtl : TextDirection.ltr;
    final titleAlignment =
    isArabicValue ? Alignment.centerRight : Alignment.centerLeft;

    final arrowIcon = Icon(
      _isExpanded
          ? Icons.keyboard_arrow_up_rounded
          : Icons.keyboard_arrow_down_rounded,
      color: const Color(0xFF8E7CFF),
      size: 26,
    );

    final iconBox = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        widget.data.icon,
        color: const Color(0xFF8E7CFF),
        size: 22,
      ),
    );

    final textBlock = Expanded(
      child: Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: titleAlignment,
              child: Text(
                widget.data.title,
                textAlign: TextAlign.start,
                textDirection: textDirection,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.data.subtitle,
              textAlign: TextAlign.start,
              textDirection: textDirection,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isExpanded ? const Color(0xFFF9F6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
          _isExpanded ? const Color(0xFFCEC4FF) : const Color(0xFFE5DEFF),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Directionality(
                textDirection: textDirection,
                child: Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    textBlock,
                    const SizedBox(width: 10),
                    arrowIcon,
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: widget.data.points.map((point) {
                  return _GuidePoint(text: point);
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _GuidePoint extends StatelessWidget {
  final String text;

  const _GuidePoint({required this.text});

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF8E7CFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
              textDirection:
              isArabicValue ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);
    final textDirection = isArabicValue ? TextDirection.rtl : TextDirection.ltr;
    final titleAlignment =
    isArabicValue ? Alignment.centerRight : Alignment.centerLeft;

    final arrowIcon = Icon(
      isArabicValue
          ? Icons.arrow_forward_ios_rounded
          : Icons.arrow_forward_ios_rounded,
      size: 16,
      color: const Color(0xFFD0C6E8),
    );

    final iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: icon,
    );

    final textBlock = Expanded(
      child: Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: titleAlignment,
              child: Text(
                title,
                textAlign: TextAlign.start,
                textDirection: textDirection,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.start,
              textDirection: textDirection,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ],
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Directionality(
          textDirection: textDirection,
          child: Row(
            children: [
              iconBox,
              const SizedBox(width: 12),
              textBlock,
              const SizedBox(width: 10),
              arrowIcon,
            ],
          ),
        ),
      ),
    );
  }
}


class _InstagramIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _InstagramIcon({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _InstagramIconPainter(color: color),
      ),
    );
  }
}

class _InstagramIconPainter extends CustomPainter {
  final Color color;

  const _InstagramIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.08;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final outerRect = Rect.fromLTWH(
      size.width * 0.13,
      size.height * 0.13,
      size.width * 0.74,
      size.height * 0.74,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        outerRect,
        Radius.circular(size.width * 0.22),
      ),
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      size.width * 0.18,
      paint,
    );

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.70, size.height * 0.30),
      size.width * 0.045,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _InstagramIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);
    final textDirection = isArabicValue ? TextDirection.rtl : TextDirection.ltr;

    final arrowIcon = Icon(
      _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
      color: const Color(0xFF8E7CFF),
    );

    final questionText = Expanded(
      child: Text(
        widget.question,
        textAlign: TextAlign.start,
        textDirection: textDirection,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2A1E3B),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Directionality(
                textDirection: textDirection,
                child: Row(
                  children: [
                    questionText,
                    const SizedBox(width: 10),
                    arrowIcon,
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
              child: Align(
                alignment:
                isArabicValue ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  widget.answer,
                  textAlign: TextAlign.start,
                  textDirection: textDirection,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
