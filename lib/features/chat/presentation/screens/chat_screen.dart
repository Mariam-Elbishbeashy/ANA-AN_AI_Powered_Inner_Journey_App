import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';

class ChatScreen extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const ChatScreen({
    super.key,
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB79CFF);
    return Column(
      children: [
        TopHelloBar(
          name: name,
          onLogout: onLogout,
          onSettings: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SettingsBottomSheet(
                onRetakeQuestionnaire: onRetakeQuestionnaire,
                onSwitchLanguage: onSwitchLanguage,
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + 92 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(-40, 0),
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Image.asset(
                        'assets/animations/guider_chat.gif',
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.smart_toy_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  tr(context, "Chat with The Guider", "تحدث مع المُرشد"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  tr(
                    context,
                    "The Guider is your calm, supportive companion. It helps you slow down, notice your inner parts, and gently reframe what you share.",
                    "المُرشد هو رفيقك الهادئ والداعم. يساعدك على التمهّل وملاحظة أجزائك الداخلية، وإعادة صياغة ما تشاركه بلطف.",
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4B3A66),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            color: accent,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr(context, "How it works:", "كيف يعمل:"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _InstructionStep(
                        number: 1,
                        text: tr(
                          context,
                          "Say what’s on your mind",
                          "قل ما يدور في ذهنك",
                        ),
                      ),
                      _InstructionStep(
                        number: 2,
                        text: tr(
                          context,
                          "Let The Guider reflect and reframe",
                          "دع المُرشد يعكس ويعيد الصياغة",
                        ),
                      ),
                      _InstructionStep(
                        number: 3,
                        text: tr(
                          context,
                          "Notice which inner part shows up",
                          "لاحظ أي جزء داخلي يظهر",
                        ),
                      ),
                      _InstructionStep(
                        number: 4,
                        text: tr(
                          context,
                          "Choose a next step with clarity",
                          "اختر الخطوة التالية بوضوح",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFB79CFF).withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB79CFF)),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB79CFF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4B3A66),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
