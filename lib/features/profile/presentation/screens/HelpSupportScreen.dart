// help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int _rating = 0;
  bool _hasRated = false;

  void _rateApp() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isArabicValue = isArabic(context);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isArabicValue ? 'تقييم التطبيق' : 'Rate Our App',
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
                        ? 'كيف تقيم تجربتك مع ANA؟'
                        : 'How would you rate your experience with ANA?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7A6A5A),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
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

                  // Rating Message
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

                  // Feedback Text Field (for low ratings)
                  if (_rating > 0 && _rating < 4)
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isArabicValue
                            ? 'كيف يمكننا التحسين؟ (اختياري)'
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    isArabicValue ? 'لاحقاً' : 'Maybe Later',
                    style: const TextStyle(
                      color: Color(0xFF7A6A5A),
                    ),
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

                    // Show thank you message
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
            ? 'آسفون لسماع ذلك 😔'
            : 'Sorry to hear that 😔';
      case 2:
        return isArabic
            ? 'سنعمل على التحسين 💪'
            : 'We\'ll work on improving 💪';
      case 3:
        return isArabic
            ? 'شكراً لك! نحن نحاول دائماً التحسين 👍'
            : 'Thank you! We\'re always trying to improve 👍';
      case 4:
        return isArabic
            ? 'رائع! سعيد لأنك استمتعت بالتجربة 😊'
            : 'Great! Glad you enjoyed it 😊';
      case 5:
        return isArabic
            ? 'مذهل! شكراً لك على التقييم الرائع! 🌟'
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
    // 1. Save the rating locally
    // 2. Send it to your backend
    // 3. Open app store for high ratings

    // For demonstration, we'll just print it
    print('User rated the app: $rating stars');

    // If rating is 4 or 5, you could open the app store
    if (rating >= 4) {
      // _openAppStore();
    }
  }

  void _openAppStore() {
    // This would open the app store rating page
    // For iOS: 'https://apps.apple.com/app/idYOUR_APP_ID?action=write-review'
    // For Android: 'market://details?id=YOUR_PACKAGE_NAME'
  }

  void _sendEmail() {
    // Implement email sending
  }

  void _openWebsite() {
    // Implement website opening
  }

  void _openCommunity() {
    // Implement community opening
  }

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Column(
        children: [
          // App Bar
          Container(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF2A1E3B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabicValue ? 'المساعدة والدعم' : 'Help & Support',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // FAQ Section
                  Container(
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.help_rounded,
                                  color: Color(0xFF8E7CFF), size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                isArabicValue ? 'الأسئلة الشائعة' : 'Frequently Asked Questions',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2A1E3B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ..._buildFAQItems(context),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Contact Support Section
                  Container(
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
                    child: Column(
                      children: [
                        Text(
                          isArabicValue ? 'اتصل بنا' : 'Contact Support',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ContactOption(
                          icon: Icons.email_rounded,
                          title: isArabicValue ? 'البريد الإلكتروني' : 'Email',
                          subtitle: isArabicValue
                              ? 'دعم@ana.app'
                              : 'support@ana.app',
                          onTap: _sendEmail,
                        ),
                        const Divider(height: 24),
                        _ContactOption(
                          icon: Icons.language_rounded,
                          title: isArabicValue ? 'موقع الويب' : 'Website',
                          subtitle: isArabicValue
                              ? 'www.ana.app'
                              : 'www.ana.app',
                          onTap: _openWebsite,
                        ),
                        const Divider(height: 24),
                        _ContactOption(
                          icon: Icons.forum_rounded,
                          title: isArabicValue ? 'المجتمع' : 'Community',
                          subtitle: isArabicValue
                              ? 'انضم إلى مجتمعنا'
                              : 'Join our community',
                          onTap: _openCommunity,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Rate App Section
                  Container(
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
                          color: _hasRated ? const Color(0xFFFFD700) : const Color(0xFF8E7CFF),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isArabicValue
                              ? 'كيف تحب تطبيق ANA؟'
                              : 'How do you like ANA?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArabicValue
                              ? 'ساعدنا بتحسين التطبيق عن طريق تقييمنا'
                              : 'Help us improve by rating the app',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF7A6A5A)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _rateApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasRated
                                ? const Color(0xFF5CB85C)
                                : const Color(0xFF8E7CFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
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
                                    : (isArabicValue ? 'تقييم التطبيق' : 'Rate App'),
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
                              isArabicValue
                                  ? 'شكراً لك على تقييمك!'
                                  : 'Thank you for your rating!',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF5CB85C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40), // Extra padding at bottom
                ],
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
        'question': isArabicValue
            ? 'كيف يعمل نظام الشخصيات؟'
            : 'How does the character system work?',
        'answer': isArabicValue
            ? 'ANA يحدد شخصياتك الداخلية بناءً على استجاباتك للاستبيان'
            : 'ANA identifies your inner characters based on your questionnaire responses',
      },
      {
        'question': isArabicValue
            ? 'كيف يمكنني إعادة الاستبيان؟'
            : 'How can I retake the questionnaire?',
        'answer': isArabicValue
            ? 'اذهب إلى إعدادات الحساب وانقر على "إعادة الاستبيان"'
            : 'Go to Account Settings and click "Retake Questionnaire"',
      },
      {
        'question': isArabicValue
            ? 'هل بياناتي آمنة؟'
            : 'Is my data secure?',
        'answer': isArabicValue
            ? 'نعم، جميع بياناتك مشفرة ومحمية'
            : 'Yes, all your data is encrypted and protected',
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

class _ContactOption extends StatelessWidget {
  final IconData icon;
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
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF8E7CFF), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF2A1E3B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Color(0xFF7A6A5A)),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Color(0xFFD0C6E8),
      ),
    );
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
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                widget.question,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A1E3B),
                ),
              ),
              trailing: Icon(
                _isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: const Color(0xFF8E7CFF),
              ),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                child: Text(
                  widget.answer,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
              ),
            const Divider(height: 1),
          ],
        ));
    }
}
