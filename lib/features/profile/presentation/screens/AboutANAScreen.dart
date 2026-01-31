import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutANAScreen extends StatelessWidget {
  const AboutANAScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    // Team members list sorted alphabetically by name
    final List<Map<String, String>> teamMembers = [
      {
        'name': 'Aya Hisham',
        'role': isArabicValue ? 'مؤسسة ومهندسة الذكاء الاصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'متخصصة في تطوير خوارزميات الذكاء الاصطناعي للصحة النفسية'
            : 'Specialist in developing AI algorithms for mental health',
      },
      {
        'name': 'Laura Lucas',
        'role': isArabicValue ? 'مؤسسة ومهندسة الذكاء الاصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'متخصصة في تطوير خوارزميات الذكاء الاصطناعي للصحة النفسية'
            : 'Specialist in developing AI algorithms for mental health',
      },
      {
        'name': 'Mariam Elbishbeashy ',
        'role': isArabicValue ? 'مؤسسة ومهندسة الذكاء الاصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'متخصصة في تطوير خوارزميات الذكاء الاصطناعي للصحة النفسية'
            : 'Specialist in developing AI algorithms for mental health',
      },
      {
        'name': 'Mohamed Ihab',
        'role': isArabicValue ? 'مؤسسة ومهندسة الذكاء الاصطناعي' : 'Founder & AI Engineer',
        'description': isArabicValue
            ? 'متخصصة في تطوير خوارزميات الذكاء الاصطناعي للصحة النفسية'
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
                  color: Colors.black.withOpacity(0.05),
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
                    isArabicValue ? 'عن ANA' : 'About ANA',
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
                  // App Logo and Title - UPDATED WITH IMAGE
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF8E7CFF).withOpacity(0.1),
                          const Color(0xFF8E7CFF).withOpacity(0.05),
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
                                color: const Color(0xFF8E7CFF).withOpacity(0.3),
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
                          'ANA',
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
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabicValue ? 'ما هو ANA؟' : 'What is ANA?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isArabicValue
                              ? 'ANA هو تطبيق ذكي يمثل رحلتك الداخلية نحو الفهم الذاتي والشفاء النفسي. باستخدام تقنيات الذكاء الاصطناعي المتقدمة ونظام العائلة الداخلية (IFS)، يساعدك ANA على اكتشاف وفهم أجزائك الداخلية المختلفة، والتعامل معها، وتحويلها إلى مصادر قوة.'
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
                    padding: const EdgeInsets.all(20),
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
                              ? 'IFS هو نموذج علاجي مبتكر يرى العقل البشري كعائلة داخلية تتكون من أجزاء متعددة مع أدوار مختلفة. لكل منا:'
                              : 'IFS is an innovative therapeutic model that views the human mind as an internal family composed of multiple parts with different roles. We all have:',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7A6A5A),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _IFSPart(
                          title: isArabicValue ? 'المنفيون (Exiles)' : 'Exiles',
                          description: isArabicValue
                              ? 'أجزاء تحمل الألم والصدمات من الماضي'
                              : 'Parts carrying pain and trauma from the past',
                          color: const Color(0xFF5CB85C),
                        ),
                        _IFSPart(
                          title: isArabicValue ? 'المديرون (Managers)' : 'Managers',
                          description: isArabicValue
                              ? 'أجزاء تحاول التحكم في حياتك لمنع الألم'
                              : 'Parts trying to control your life to prevent pain',
                          color: const Color(0xFF4A6FA5),
                        ),
                        _IFSPart(
                          title: isArabicValue ? 'رجال الإطفاء (Firefighters)' : 'Firefighters',
                          description: isArabicValue
                              ? 'أجزاء تتصرف بسرعة لتخفيف الألم العاطفي'
                              : 'Parts that act quickly to relieve emotional pain',
                          color: const Color(0xFFD9534F),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isArabicValue
                              ? 'ANA يساعدك على التعرف على هذه الأجزاء وفهمها، وإعادة تواصلها مع الذات الأساسية - مركزك الداخلي من الهدوء والفضول والرحمة.'
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
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabicValue ? 'كيف يساعدك ANA؟' : 'How ANA Helps You',
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
                              ? 'تحليل ذكي لأجوبتك لتحديد شخصياتك الداخلية بدقة'
                              : 'Intelligent analysis of your responses to accurately identify your inner characters',
                        ),
                        _BenefitItem(
                          icon: Icons.insights_rounded,
                          title: isArabicValue ? 'رؤى مخصصة' : 'Personalized Insights',
                          description: isArabicValue
                              ? 'توصيات ورؤى مخصصة بناءً على شخصياتك الفريدة'
                              : 'Personalized recommendations and insights based on your unique characters',
                        ),
                        _BenefitItem(
                          icon: Icons.track_changes_rounded,
                          title: isArabicValue ? 'تتبع التقدم' : 'Progress Tracking',
                          description: isArabicValue
                              ? 'تتبع تقدمك في رحلة الشفاء مع مرور الوقت'
                              : 'Track your healing journey progress over time',
                        ),
                        _BenefitItem(
                          icon: Icons.security_rounded,
                          title: isArabicValue ? 'خصوصية تامة' : 'Complete Privacy',
                          description: isArabicValue
                              ? 'بياناتك مشفرة بشكل كامل وتبقى خاصة بك فقط'
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
                          color: Colors.black.withOpacity(0.05),
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
                              ? 'مطور بشغف لتقديم أفضل تجربة للصحة النفسية'
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

                  // Important Links
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _AboutLink(
                          icon: Icons.description_rounded,
                          title: isArabicValue ? 'شروط الخدمة' : 'Terms of Service',
                          onTap: () => _openUrl(
                            'https://ana.app/terms',
                            isArabicValue ? 'فتح شروط الخدمة' : 'Opening Terms of Service',
                            context,
                          ),
                        ),
                        const Divider(height: 24),
                        _AboutLink(
                          icon: Icons.privacy_tip_rounded,
                          title: isArabicValue ? 'سياسة الخصوصية' : 'Privacy Policy',
                          onTap: () => _openUrl(
                            'https://ana.app/privacy',
                            isArabicValue ? 'فتح سياسة الخصوصية' : 'Opening Privacy Policy',
                            context,
                          ),
                        ),
                        const Divider(height: 24),
                        _AboutLink(
                          icon: Icons.health_and_safety_rounded,
                          title: isArabicValue ? 'إخلاء المسؤولية الطبية' : 'Medical Disclaimer',
                          onTap: () => _openUrl(
                            'https://ana.app/disclaimer',
                            isArabicValue ? 'فتح إخلاء المسؤولية' : 'Opening Medical Disclaimer',
                            context,
                          ),
                        ),
                        const Divider(height: 24),
                        _AboutLink(
                          icon: Icons.book_rounded,
                          title: isArabicValue ? 'مراجع IFS' : 'IFS Resources',
                          onTap: () => _openUrl(
                            'https://ifs-institute.com',
                            isArabicValue ? 'فتح مراجع IFS' : 'Opening IFS Resources',
                            context,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Contact & Social
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0ECF7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isArabicValue ? 'تواصل معنا' : 'Get In Touch',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArabicValue
                              ? 'لديك سؤال أو فكرة؟ نحن نحب أن نسمع منك!'
                              : 'Have a question or idea? We\'d love to hear from you!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7A6A5A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SocialButton(
                              icon: Icons.email_rounded,
                              onTap: () => _sendEmail(
                                'support@ana.app',
                                isArabicValue ? 'الدعم' : 'Support',
                                isArabicValue ? 'استفسار حول تطبيق ANA' : 'Inquiry about ANA App',
                                context,
                              ),
                            ),
                            const SizedBox(width: 20),
                            _SocialButton(
                              icon: Icons.facebook,
                              onTap: () => _openUrl(
                                'https://facebook.com/anaapp',
                                isArabicValue ? 'فتح فيسبوك' : 'Opening Facebook',
                                context,
                              ),
                            ),
                            const SizedBox(width: 20),
                            _SocialButton(
                              icon: Icons.photo_camera_rounded,
                              onTap: () => _openUrl(
                                'https://instagram.com/anaapp',
                                isArabicValue ? 'فتح إنستجرام' : 'Opening Instagram',
                                context,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url, String message, BuildContext context) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF8E7CFF),
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
        await launchUrl(emailUri);
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
            margin: const EdgeInsets.only(top: 6, right: 12),
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
                color: const Color(0xFF8E7CFF).withOpacity(0.1),
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withOpacity(0.1),
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

class _AboutLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AboutLink({
    required this.icon,
    required this.title,
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
          color: const Color(0xFF8E7CFF).withOpacity(0.1),
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
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Color(0xFFD0C6E8),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF8E7CFF).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: const Color(0xFF8E7CFF),
          size: 24,
        ),
      ),
    );
  }
}