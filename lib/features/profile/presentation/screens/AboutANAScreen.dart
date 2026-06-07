import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutANAScreen extends StatelessWidget {
  const AboutANAScreen({super.key});

  static const String _instagramUrl =
      'https://www.instagram.com/anajourney26/';
  static const String _contactEmail = 'anajourney26@hotmail.com';

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);
    final textDirection =
    isArabicValue ? TextDirection.rtl : TextDirection.ltr;

    // Team members list sorted alphabetically by name
    final List<Map<String, String>> teamMembers = [
      {
        'name': 'Aya Hisham',
        'role': isArabicValue ? 'مؤسِّسة ومهندسة ذكاء اصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'بتشتغل على تطوير حلول ذكاء اصطناعي لدعم الصحة النفسية'
            : 'Specialist in developing AI algorithms for mental health',
      },
      {
        'name': 'Laura Lucas',
        'role': isArabicValue ? 'مؤسِّسة ومهندسة ذكاء اصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'بتشتغل على تطوير حلول ذكاء اصطناعي لدعم الصحة النفسية'
            : 'Specialist in developing AI algorithms for mental health',
      },
      {
        'name': 'Mariam Elbishbeashy ',
        'role': isArabicValue ? 'مؤسِّسة ومهندسة ذكاء اصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'بتشتغل على تطوير حلول ذكاء اصطناعي لدعم الصحة النفسية'
            : 'Specialist in developing AI algorithms for mental health',
      },
      {
        'name': 'Mohamed Ihab',
        'role': isArabicValue ? 'مؤسس ومهندس ذكاء اصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'بيشتغل على تطوير حلول ذكاء اصطناعي لدعم الصحة النفسية'
            : 'Specialist in developing AI algorithms for mental health',
      },
    ];

    // Colors for team members
    final List<Color> teamColors = [
      const Color(0xFF8E7CFF),
      const Color(0xFF4A6FA5),
      const Color(0xFF5CB85C),
      const Color(0xFFD9534F),
    ];

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
                    child: Align(
                      alignment: isArabicValue
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        isArabicValue ? 'عن أنا' : 'About ANA',
                        textAlign:
                        isArabicValue ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
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
              child: Directionality(
                textDirection: textDirection,
                child: Column(
                  children: [
                    // App Logo and Title - UPDATED WITH IMAGE
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF8E7CFF).withValues(alpha: 0.1),
                            const Color(0xFF8E7CFF).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          // Logo Container
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8E7CFF).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            // Logo Image
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Image.asset(
                                'assets/images/ANA\'s-logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to icon if image doesn't exist
                                  return const Icon(
                                    Icons.psychology_rounded,
                                    size: 50,
                                    color: Color(0xFF8E7CFF),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isArabicValue ? 'أنا' : 'ANA',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2A1E3B),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isArabicValue
                                ? 'رحلة داخلية مدعومة بالذكاء الاصطناعي'
                                : 'An AI Powered Inner Journey',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7A6A5A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E7CFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // What is ANA?
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabicValue ? 'إيه هو تطبيق أنا؟' : 'What is ANA?',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isArabicValue
                                ? 'تطبيق أنا هو تطبيق ذكي بيساعدك في رحلتك الداخلية عشان تفهم نفسك ومشاعرك بشكل أهدى. باستخدام الذكاء الاصطناعي ونظام العائلة الداخلية (IFS)، أنا بيساعدك تكتشف شخصياتك الداخلية، تفهمها، وتتعامل معاها بطريقة أرحم وأوضح.'
                                : 'ANA is an intelligent companion for your inner journey toward self-understanding and psychological healing. Using advanced AI techniques and the Internal Family Systems (IFS) model, ANA helps you discover, understand, and transform your various inner parts into sources of strength.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7A6A5A),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // About IFS
                    Container(
                      padding: const EdgeInsets.all(19),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0ECF7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8E7CFF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.psychology_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isArabicValue ? 'نظام العائلة الداخلية (IFS)' : 'Internal Family Systems (IFS)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2A1E3B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isArabicValue
                                ? 'IFS هو نموذج بيفهم العقل كأنه عيلة داخلية فيها أجزاء مختلفة، وكل جزء ليه دور وبيحاول يساعد بطريقته. عند كل واحد فينا:'
                                : 'IFS is an innovative therapeutic model that views the human mind as an internal family composed of multiple parts with different roles. We all have:',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7A6A5A),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _IFSPart(
                            title: isArabicValue ? 'المنفيين (Exiles)' : 'Exiles',
                            description: isArabicValue
                                ? 'أجزاء شايلة وجع أو تجارب صعبة من الماضي'
                                : 'Parts carrying pain and trauma from the past',
                            color: const Color(0xFF5CB85C),
                          ),
                          _IFSPart(
                            title: isArabicValue ? 'المديرين (Managers)' : 'Managers',
                            description: isArabicValue
                                ? 'أجزاء بتحاول تسيطر وتنظم حياتك عشان تحميك من الوجع'
                                : 'Parts trying to control your life to prevent pain',
                            color: const Color(0xFF4A6FA5),
                          ),
                          _IFSPart(
                            title: isArabicValue ? 'الإطفائيين (Firefighters)' : 'Firefighters',
                            description: isArabicValue
                                ? 'أجزاء بتتصرف بسرعة عشان تهدي الوجع أو الضغط العاطفي'
                                : 'Parts that act quickly to relieve emotional pain',
                            color: const Color(0xFFD9534F),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isArabicValue
                                ? 'أنا بيساعدك تتعرف على الأجزاء دي وتفهمها، وتوصلها تاني بالذات الأساسية: المكان الهادي جواك اللي فيه فضول ورحمة واتزان.'
                                : 'ANA helps you identify and understand these parts, reconnecting them with your core Self - your inner center of calm, curiosity, and compassion.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7A6A5A),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // How ANA Helps
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabicValue ? 'إزاي أنا بيساعدك؟' : 'How ANA Helps You',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _BenefitItem(
                            icon: Icons.auto_awesome_rounded,
                            title: isArabicValue ? 'تحليل ذكي' : 'Smart Analysis',
                            description: isArabicValue
                                ? 'بيحلل إجاباتك عشان يحدد الشخصيات الداخلية الأقرب لحالتك'
                                : 'Intelligent analysis of your responses to accurately identify your inner characters',
                          ),
                          _BenefitItem(
                            icon: Icons.insights_rounded,
                            title: isArabicValue ? 'رؤى مناسبة ليك' : 'Personalized Insights',
                            description: isArabicValue
                                ? 'بيقدملك ملاحظات واقتراحات مناسبة للشخصيات اللي ظاهرة عندك'
                                : 'Personalized recommendations and insights based on your unique characters',
                          ),
                          _BenefitItem(
                            icon: Icons.track_changes_rounded,
                            title: isArabicValue ? 'متابعة التقدم' : 'Progress Tracking',
                            description: isArabicValue
                                ? 'بيساعدك تتابع تغيّر مشاعرك ورحلتك مع الوقت'
                                : 'Track your healing journey progress over time',
                          ),
                          _BenefitItem(
                            icon: Icons.security_rounded,
                            title: isArabicValue ? 'خصوصية وأمان' : 'Complete Privacy',
                            description: isArabicValue
                                ? 'بياناتك بتفضل خاصة بحسابك ومستخدمة عشان تحسين تجربتك'
                                : 'Your data is fully encrypted and remains completely private',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Meet Our Team - UPDATED WITH SORTED NAMES
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabicValue ? 'فريقنا' : 'Meet Our Team',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isArabicValue
                                ? 'اشتغلنا عليه بحب عشان التجربة تبقى مريحة وواضحة في دعم الصحة النفسية'
                                : 'Passionately developed to deliver the best mental health experience',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7A6A5A),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Dynamically generate team member cards
                          ...List.generate(teamMembers.length, (index) {
                            return Column(
                              children: [
                                _TeamMemberCard(
                                  name: teamMembers[index]['name']!,
                                  role: teamMembers[index]['role']!,
                                  description: teamMembers[index]['description']!,
                                  color: teamColors[index],
                                ),
                                if (index < teamMembers.length - 1)
                                  const SizedBox(height: 16),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Important Information
                    Container(
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
                      child: Column(
                        crossAxisAlignment: isArabicValue
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: isArabicValue
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Text(
                              isArabicValue
                                  ? 'معلومات مهمة'
                                  : 'Important Information',
                              textAlign: isArabicValue
                                  ? TextAlign.right
                                  : TextAlign.left,
                              textDirection: textDirection,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: Directionality(
                              textDirection: textDirection,
                              child: Text(
                                isArabicValue
                                    ? 'افتح أي نقطة عشان تقرأ شرحها من غير ما تخرج من الصفحة.'
                                    : 'Open any point to read the details without leaving this page.',
                                textAlign: isArabicValue
                                    ? TextAlign.right
                                    : TextAlign.left,
                                textDirection: textDirection,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7A6A5A),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AboutInfoItem(
                            icon: Icons.description_rounded,
                            title: isArabicValue
                                ? 'شروط الاستخدام'
                                : 'Terms of Service',
                            description: isArabicValue
                                ? 'باستخدامك تطبيق أنا، إنت بتستخدمه كمساحة مساعدة للتأمل وفهم المشاعر والشخصيات الداخلية. استخدمه بهدوء وبطريقة آمنة، وخليك فاكر إن التطبيق مش بديل للتشخيص أو المساعدة الطارئة.'
                                : 'By using ANA, you are using it as a supportive space for self-reflection, emotional understanding, and inner-character awareness. Use it safely and respectfully, keep your account secure, and do not rely on it for diagnosis or emergencies.',
                          ),
                          _AboutInfoItem(
                            icon: Icons.privacy_tip_rounded,
                            title: isArabicValue
                                ? 'سياسة الخصوصية'
                                : 'Privacy Policy',
                            description: isArabicValue
                                ? 'خصوصيتك مهمة عندنا. البيانات اللي بتدخلها في أنا بتساعد التطبيق يظبط تجربتك ويتابع تقدمك، زي الجلسات والنتائج والمزاج. بلاش تكتب تفاصيل حساسة جداً لو مش مرتاح إنها تتحفظ.'
                                : 'Your privacy matters. The data you add in ANA helps personalize your experience and track your progress, such as sessions, results, and mood records. Avoid writing very sensitive details if you are not comfortable saving them.',
                          ),
                          _AboutInfoItem(
                            icon: Icons.health_and_safety_rounded,
                            title: isArabicValue
                                ? 'إخلاء المسؤولية الطبية'
                                : 'Medical Disclaimer',
                            description: isArabicValue
                                ? 'أنا أداة مساعدة للفهم والتأمل الذاتي، لكنه مش دكتور أو معالج نفسي ومش بديل عن الدعم المهني. لو في أزمة شديدة، خطر، أو احتياج عاجل، تواصل فوراً مع مختص أو جهة طوارئ.'
                                : 'ANA is a self-reflection and awareness support tool. It is not a doctor, therapist, or replacement for professional care. If you are in crisis, danger, or need urgent help, contact a professional or emergency service immediately.',
                          ),
                          _AboutInfoItem(
                            icon: Icons.book_rounded,
                            title: isArabicValue
                                ? 'مراجع IFS'
                                : 'IFS Resources',
                            description: isArabicValue
                                ? 'فكرة الشخصيات الداخلية في أنا مستوحاة من نظام العائلة الداخلية IFS. لو عايز تفهم الفكرة أكتر، كتاب No Bad Parts للدكتور ريتشارد شوارتز بيشرح إن الأجزاء الداخلية مش وحشة، لكنها غالباً بتحاول تحمينا بطرق مختلفة.'
                                : 'ANA is inspired by Internal Family Systems. To understand the idea more deeply, No Bad Parts by Dr. Richard Schwartz explains that inner parts are not bad; they are usually trying to protect us in different ways.',
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Contact & Social
                    Container(
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
                      child: Column(
                        crossAxisAlignment: isArabicValue
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: isArabicValue
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Text(
                              isArabicValue ? 'تواصل معانا' : 'Get In Touch',
                              textAlign: isArabicValue
                                  ? TextAlign.right
                                  : TextAlign.left,
                              textDirection: textDirection,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: Directionality(
                              textDirection: textDirection,
                              child: Text(
                                isArabicValue
                                    ? 'لو عندك سؤال أو فكرة، اختار الطريقة الأنسب ليك.'
                                    : 'Choose the easiest way to reach the ANA team.',
                                textAlign: isArabicValue
                                    ? TextAlign.right
                                    : TextAlign.left,
                                textDirection: textDirection,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7A6A5A),
                                  height: 1.4,
                                ),
                              ),
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
                            subtitle: _contactEmail,
                            onTap: () => _sendEmail(
                              _contactEmail,
                              isArabicValue
                                  ? 'استفسار عن تطبيق أنا'
                                  : 'Inquiry about ANA App',
                              isArabicValue
                                  ? 'أهلاً فريق أنا،\n\n'
                                  : 'Hello ANA Team,\n\n',
                              context,
                            ),
                          ),
                          const Divider(height: 24),
                          _ContactOption(
                            icon: const _InstagramIcon(
                              size: 20,
                              color: Color(0xFF8E7CFF),
                            ),
                            title: isArabicValue
                                ? 'انضم لمجتمع أنا'
                                : 'Join ANA Community',
                            subtitle: '@anajourney26',
                            onTap: () => _openUrl(
                              _instagramUrl,
                              isArabicValue
                                  ? 'مش قادرين نفتح إنستجرام دلوقتي'
                                  : 'Could not open Instagram',
                              context,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog({
    required BuildContext context,
    required String title,
    required String description,
  }) {
    final isArabicValue = isArabic(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) => Directionality(
        textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: Color(0xFF2A1E3B),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            description,
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: Color(0xFF7A6A5A),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                isArabicValue ? 'تمام' : 'Got it',
                style: const TextStyle(
                  color: Color(0xFF8E7CFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url, String message, BuildContext context) async {
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF8E7CFF),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF8E7CFF),
        ),
      );
    }
  }

  Future<void> _sendEmail(String email, String subject, String body, BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    ).replace(queryParameters: {
      'subject': subject,
      'body': body,
    });

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open email client'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _IFSPart extends StatelessWidget {
  final String title;
  final String description;
  final Color color;

  const _IFSPart({
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsetsDirectional.only(top: 6, end: 12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF8E7CFF), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A6A5A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final String name;
  final String role;
  final String description;
  final Color color;

  const _TeamMemberCard({
    required this.name,
    required this.role,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Text(
              name.substring(0, 1),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutInfoItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool showDivider;

  const _AboutInfoItem({
    required this.icon,
    required this.title,
    required this.description,
    this.showDivider = true,
  });

  @override
  State<_AboutInfoItem> createState() => _AboutInfoItemState();
}

class _AboutInfoItemState extends State<_AboutInfoItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);
    final textDirection = isArabicValue ? TextDirection.rtl : TextDirection.ltr;
    final titleAlignment =
    isArabicValue ? Alignment.centerRight : Alignment.centerLeft;

    final iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.icon,
        color: const Color(0xFF8E7CFF),
        size: 20,
      ),
    );

    final titleBlock = Expanded(
      child: Directionality(
        textDirection: textDirection,
        child: Align(
          alignment: titleAlignment,
          child: Text(
            widget.title,
            textAlign: TextAlign.start,
            textDirection: textDirection,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2A1E3B),
            ),
          ),
        ),
      ),
    );

    final arrowIcon = Icon(
      _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
      color: const Color(0xFF8E7CFF),
      size: 24,
    );

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Directionality(
              textDirection: textDirection,
              child: Row(
                children: [
                  iconBox,
                  const SizedBox(width: 12),
                  titleBlock,
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
            padding: const EdgeInsetsDirectional.only(
              start: 52,
              end: 8,
              bottom: 14,
              top: 4,
            ),
            child: Align(
              alignment:
              isArabicValue ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                widget.description,
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
        if (widget.showDivider) const Divider(height: 16),
      ],
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

    final arrowIcon = Icon(
      isArabicValue
          ? Icons.arrow_forward_ios_rounded
          : Icons.arrow_forward_ios_rounded,
      size: 16,
      color: const Color(0xFFD0C6E8),
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