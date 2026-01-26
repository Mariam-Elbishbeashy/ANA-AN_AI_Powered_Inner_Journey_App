import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

class CharacterDetailDialog extends StatelessWidget {
  final UserCharacter character;
  final List<String> ifsRelationships;
  final List<String> archetypeRelationships;
  final List<UserCharacter> allCharacters;
  final bool isArabic; // This parameter should be here

  const CharacterDetailDialog({
    super.key,
    required this.character,
    required this.ifsRelationships,
    required this.archetypeRelationships,
    required this.allCharacters,
    required this.isArabic, // Make sure this is in the constructor
  });

  @override
  Widget build(BuildContext context) {
    final glbPath = character.glbFileName.isNotEmpty
        ? "assets/models/${character.glbFileName}"
        : "";

    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A5CFF).withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9F6FF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          character.displayName.toUpperCase(),
                          style: const TextStyle(
                            letterSpacing: 1.5,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6A5CFF),
                          ),
                        ),
                        Icon(
                          Icons.insights_rounded,
                          color: const Color(0xFF6A5CFF).withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),

                  // Character image/3D model
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circle background
                          Container(
                            height: 180,
                            width: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getCharacterColor(character)
                                  .withOpacity(0.05),
                            ),
                          ),

                          // 3D Model
                          glbPath.isNotEmpty
                              ? SizedBox(
                            height: 250,
                            width: 250,
                            child: O3D(
                              controller: O3DController(),
                              src: glbPath,
                              autoPlay: true,
                              cameraControls: true,
                              backgroundColor: Colors.transparent,
                              autoRotate: false,
                              loading: Loading.eager,
                            ),
                          )
                              : Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              color: _getCharacterColor(character)
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getCharacterIcon(character),
                              size: 60,
                              color: _getCharacterColor(character),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content sections
                  _buildContentSections(),

                  // Close button
                  _buildCloseButton(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentSections() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Archetype badge
          _buildArchetypeBadge(),
          const SizedBox(height: 20),

          // Healing Status - NEW SECTION
          _buildHealingStatusSection(),
          const SizedBox(height: 20),

          // System Dynamics Section
          _buildSectionHeader(
              isArabic ? "ديناميكيات النظام" : "System Dynamics",
              Icons.psychology_rounded
          ),
          _buildSystemDynamicsSection(),
          const SizedBox(height: 20),

          // IFS Archetype Relationships
          _buildSectionHeader(
              isArabic ? "ديناميكيات النموذج البدئي لـ IFS" : "IFS Archetype Dynamics",
              Icons.link_rounded
          ),
          _buildArchetypeRelationshipsSection(),
          const SizedBox(height: 20),

          // Relationship with Other Parts
          if (allCharacters.length > 1) ...[
            _buildSectionHeader(
              isArabic ? "الأجزاء المتصلة في نظامك" : "Connected Parts in Your System",
              Icons.group_rounded,
            ),
            _buildIFSRelationshipsSection(),
            const SizedBox(height: 20),
          ],

          // Character Specific Insights
          _buildSectionHeader(
              isArabic ? "رؤى خاصة بالجزء" : "Part-Specific Insights",
              Icons.insights_rounded
          ),
          _buildCharacterInsightsSection(),
          const SizedBox(height: 20),

          // Healing Context
          _buildSectionHeader(
              isArabic ? "سياق الشفاء" : "Healing Context",
              Icons.self_improvement_rounded
          ),
          _buildHealingContextSection(),
          const SizedBox(height: 20),

          // Predicted Date
          _buildPredictedDateSection(),
        ],
      ),
    );
  }

  Widget _buildArchetypeBadge() {
    // Translate archetype name for Arabic
    String archetypeDisplay = character.archetype;
    if (isArabic) {
      switch (character.archetype.toLowerCase()) {
        case 'manager':
          archetypeDisplay = 'مدير';
          break;
        case 'firefighter':
          archetypeDisplay = 'رجل إطفاء';
          break;
        case 'exile':
          archetypeDisplay = 'منفي';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getCharacterColor(character).withOpacity(0.15),
            _getCharacterColor(character).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _getCharacterColor(character).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _getCharacterColor(character).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _getCharacterColor(character),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getCharacterColor(character).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            archetypeDisplay.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: _getCharacterColor(character),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealingStatusSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: character.isHealed
            ? const Color(0xFFE8F5E9) // Light green for healed
            : const Color(0xFFF3E5F5), // Light purple for unhealed
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: character.isHealed
              ? const Color(0xFFA5D6A7) // Green border for healed
              : const Color(0xFFCE93D8), // Purple border for unhealed
        ),
      ),
      child: Row(
        children: [
          Icon(
            character.isHealed ? Icons.check_circle : Icons.autorenew,
            size: 16,
            color: character.isHealed
                ? const Color(0xFF5CB85C) // Green for healed
                : const Color(0xFFAB47BC), // Purple for unhealed
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              character.isHealed
                  ? (isArabic ? "تم الشفاء - تم دمج هذا الجزء" : "Healed - This part has been integrated")
                  : (isArabic ? "لم يشفى بعد - هذا الجزء في انتظار الدمج" : "Unhealed - This part is waiting for integration"),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: character.isHealed
                    ? const Color(0xFF2E7D32) // Dark green for healed
                    : const Color(0xFF4A148C), // Dark purple for unhealed
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB4A3FF),
                  Color(0xFFA78BFA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA78BFA).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2A1E3B),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemDynamicsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E1FF),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? "في نظامك الداخلي، هذا الجزء:" : "In your internal system, this part:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A5CFF),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            character.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF3D2D5A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchetypeRelationshipsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8E1FF),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final relationship in archetypeRelationships)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6A5CFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      relationship,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIFSRelationshipsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5DEFF),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic
                ? "هذا ${_translateArchetypeToArabic(character.archetype)} يتفاعل عادة مع:"
                : "This ${character.archetype.toLowerCase()} typically interacts with:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A5CFF),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ifsRelationships.map((relationship) {
              return Chip(
                label: Text(relationship),
                backgroundColor: const Color(0xFFEDE7FF),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6A5CFF),
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterInsightsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFECB3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? "حول هذا الجزء المحدد:" : "About this specific part:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getCharacterColor(character),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getCharacterInsights(character.displayName.toLowerCase()),
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: Color(0xFF3D2D5A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealingContextSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8FFE1),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? "عند العمل مع هذا الجزء:" : "When working with this part:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00A86B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getHealingGuidance(character.archetype),
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: Color(0xFF2A1E3B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictedDateSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5DEFF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: const Color(0xFF6A5CFF).withOpacity(0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic
                  ? "تم التعرف عليه: ${_formatDate(character.predictedAt)}"
                  : "Identified: ${_formatDate(character.predictedAt)}",
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF6A5CFF).withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8E7CFF),
                Color(0xFF6A5CFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A5CFF).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              isArabic ? "إغلاق الرؤى" : "Close Insights",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCharacterColor(UserCharacter character) {
    // First check archetype for color
    switch (character.archetype.toLowerCase()) {
      case 'manager':
        return const Color(0xFF6A5CFF);
      case 'firefighter':
        return const Color(0xFFFF6B6B);
      case 'exile':
        return const Color(0xFFFFB84D);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  IconData _getCharacterIcon(UserCharacter character) {
    // First check archetype for icon
    switch (character.archetype.toLowerCase()) {
      case 'manager':
        return Icons.business_center;
      case 'firefighter':
        return Icons.local_fire_department;
      case 'exile':
        return Icons.people_alt;
      default:
      // Fallback to character-specific icons
        return _getSpecificCharacterIcon(character.displayName.toLowerCase());
    }
  }

  IconData _getSpecificCharacterIcon(String characterName) {
    if (characterName.contains('ashamed')) return Icons.visibility_off;
    if (characterName.contains('confused')) return Icons.help;
    if (characterName.contains('controller')) return Icons.control_camera;
    if (characterName.contains('dependent')) return Icons.attach_file;
    if (characterName.contains('gamer')) return Icons.videogame_asset;
    if (characterName.contains('fearful')) return Icons.warning;
    if (characterName.contains('critic')) return Icons.gavel;
    if (characterName.contains('jealous')) return Icons.heart_broken;
    if (characterName.contains('lonely')) return Icons.person_outline;
    if (characterName.contains('neglected')) return Icons.notifications_off;
    if (characterName.contains('overeater') || characterName.contains('binger'))
      return Icons.restaurant;
    if (characterName.contains('overwhelmed')) return Icons.waves;
    if (characterName.contains('people pleaser')) return Icons.group_add;
    if (characterName.contains('perfectionist')) return Icons.star;
    if (characterName.contains('procrastinator')) return Icons.schedule;
    if (characterName.contains('stoic')) return Icons.emoji_objects;
    if (characterName.contains('workaholic')) return Icons.work;
    if (characterName.contains('wounded') || characterName.contains('child'))
      return Icons.child_care;

    return Icons.person;
  }

  String _getCharacterInsights(String characterName) {
    // Provide specific insights for each character type
    if (characterName.contains('ashamed')) {
      return isArabic
          ? "يحمل هذا الجزء مشاعر الخزي وعدم القيمة. غالبًا ما يختبئ من الآخرين وينتقد نفسه بقسوة. يحمي الخزي من الضعف ولكنه قد يعزلك عن التواصل."
          : "This part carries feelings of shame and unworthiness. It often hides from others and criticizes itself harshly. Shame protects against vulnerability but can isolate you from connection.";
    } else if (characterName.contains('confused')) {
      return isArabic
          ? "يشعر هذا الجزء بعدم اليقين وعدم الوضوح. قد يعاني من صعوبة في اتخاذ القرارات أو فهم المواقف. يمكن أن يكون الارتباك آلية وقائية ضد الوضوح الساحق."
          : "This part feels uncertain and unclear. It may struggle with decision-making or understanding situations. Confusion can be a protective mechanism against overwhelming clarity.";
    } else if (characterName.contains('controller')) {
      return isArabic
          ? "يسعى هذا الجزء للسيطرة على المواقف أو الأشخاص أو النتائج. يعتقد أن الأمان يأتي من الحفاظ على السيطرة. بينما يكون وقائيًا، يمكن أن يخلق صلابة وتوترًا."
          : "This part seeks to control situations, people, or outcomes. It believes safety comes from maintaining control. While protective, it can create rigidity and tension.";
    } else if (characterName.contains('dependent')) {
      return isArabic
          ? "يشعر هذا الجزء بعدم القدرة على العمل بشكل مستقل. يبحث عن التحقق الخارجي والدعم. غالبًا ما يتطور الاعتماد من تجارب مبكرة للاحتياجات غير الملباة."
          : "This part feels unable to function independently. It seeks external validation and support. Dependency often develops from early experiences of unmet needs.";
    } else if (characterName.contains('gamer')) {
      return isArabic
          ? "يستخدم هذا الجزء الألعاب كوسيلة للهروب أو التشتيت. قد يسعى لتحقيق الإنجاز في العوالم الافتراضية عندما تشعر الاحتياجات في العالم الحقيقي بأنها غير ملباة. يمكن أن توفر الألعاب راحة مؤقتة من التوتر."
          : "This part uses gaming as escape or distraction. It might seek achievement in virtual worlds when real-world needs feel unmet. Gaming can provide temporary relief from stress.";
    } else if (characterName.contains('fearful')) {
      return isArabic
          ? "هذا الجزء دائم التنبيه للخطر. يتوقع التهديدات ويستعد لأسهم السيناريوهات. يحمي الخوف ولكن يمكن أن يحد من تجارب الحياة."
          : "This part is constantly alert to danger. It anticipates threats and prepares for worst-case scenarios. Fear protects but can limit life experiences.";
    } else if (characterName.contains('critic')) {
      return isArabic
          ? "يقوم هذا الجزء بالحكم والتقييم باستمرار. يضع معايير عالية ويشير إلى العيوب. يحاول الناقد الحماية من خلال منع الفشل أو الإحراج."
          : "This part constantly judges and evaluates. It sets high standards and points out flaws. The critic tries to protect by preventing failure or embarrassment.";
    } else if (characterName.contains('jealous')) {
      return isArabic
          ? "يقارن هذا الجزء ويشعر بالنقص. يراقب ما يمتلكه الآخرون ويخاف من أن يتم استبعاده. تشير الغيرة إلى احتياجات غير ملباة للأمن أو التحقق."
          : "This part compares and feels lacking. It monitors what others have and fears being left out. Jealousy signals unmet needs for security or validation.";
    } else if (characterName.contains('lonely')) {
      return isArabic
          ? "يشعر هذا الجزء بالعزلة والانفصال. يتوق للتواصل الهادف ولكن قد يخاف من الوصول للآخرين. غالبًا ما يحمل الوحدة جروحًا علائقية سابقة."
          : "This part feels isolated and disconnected. It longs for meaningful connection but may fear reaching out. Loneliness often holds past relational wounds.";
    } else if (characterName.contains('neglected')) {
      return isArabic
          ? "يحمل هذا الجزء ذكريات الإهمال أو عدم الأهمية. قد يشعر بأنه غير مرئي ويتوق للانتباه. تؤثر جروح الإهمال على تقدير الذات."
          : "This part carries memories of being overlooked or unimportant. It may feel invisible and yearn for attention. Neglect wounds affect self-worth.";
    } else if (characterName.contains('overeater') || characterName.contains('binger')) {
      return isArabic
          ? "يستخدم هذا الجزء الطعام للراحة أو التشتيت أو التنظيم العاطفي. غالبًا ما تخفي سلوكيات الأكل احتياجات عاطفية أعمق أو توفر راحة مؤقتة من التوتر."
          : "This part uses food for comfort, distraction, or emotional regulation. Eating behaviors often mask deeper emotional needs or provide temporary relief from stress.";
    } else if (characterName.contains('overwhelmed')) {
      return isArabic
          ? "يشعر هذا الجزء بأنه مدفون تحت المسؤوليات أو المشاعر. قد يتوقف عن العمل أو يصاب بالشلل. يحمي الشعور بالإرهاق من مواجهة الكثير في وقت واحد."
          : "This part feels buried under responsibilities or emotions. It may shut down or become paralyzed. Overwhelm protects against facing too much at once.";
    } else if (characterName.contains('people pleaser')) {
      return isArabic
          ? "يعطي هذا الجزء أولوية لاحتياجات الآخرين فوق احتياجاته الخاصة. يسعى للحصول على الموافقة ويتجنب الصراع. يتطور إرضاء الناس كاستراتيجية للأمان والقبول."
          : "This part prioritizes others' needs above its own. It seeks approval and avoids conflict. People-pleasing develops as a strategy for safety and acceptance.";
    } else if (characterName.contains('perfectionist')) {
      return isArabic
          ? "يعتقد هذا الجزء أن الكمال يمنع النقد أو الفشل. يضع معايير عالية مستحيلة. يهدف الكمالية إلى ضمان الأمان من خلال التميز."
          : "This part believes flawlessness prevents criticism or failure. It sets impossibly high standards. Perfectionism aims to ensure safety through excellence.";
    } else if (characterName.contains('procrastinator')) {
      return isArabic
          ? "يتجنب هذا الجزء المهام أو القرارات. قد يخاف من الفشل أو النجاح أو الحكم. يوفر المماطلة راحة مؤقتة من الضغط."
          : "This part avoids tasks or decisions. It may fear failure, success, or judgment. Procrastination provides temporary relief from pressure.";
    } else if (characterName.contains('stoic')) {
      return isArabic
          ? "يكبت هذا الجزء المشاعر ويحافظ على رباطة الجأش. يقدر العقلانية على الشعور. يحمي الرواقية من الضعف ولكن يمكن أن يخلق مسافة عاطفية."
          : "This part suppresses emotions and maintains composure. It values rationality over feeling. Stoicism protects against vulnerability but can create emotional distance.";
    } else if (characterName.contains('workaholic')) {
      return isArabic
          ? "يجد هذا الجزء الهوية والقيمة في الإنتاجية. قد يتجنب الراحة أو الترفيه. يمكن أن يكون إدمان العمل هروبًا من الألم العاطفي أو سعيًا للتحقق."
          : "This part finds identity and worth in productivity. It may avoid rest or leisure. Workaholism can be an escape from emotional pain or a quest for validation.";
    } else if (characterName.contains('wounded') || characterName.contains('child')) {
      return isArabic
          ? "يحمل هذا الجزء جروحًا تنموية مبكرة واحتياجات طفولة غير ملباة. يحمل مشاعر ضعيفة مثل الأذى أو الخوف أو الحزن. يحتاج هذا الجزء الطفل إلى المشاهدة بلطف."
          : "This part holds early developmental wounds and unmet childhood needs. It carries vulnerable emotions like hurt, fear, or sadness. This child part needs gentle witnessing.";
    } else {
      return isArabic
          ? "يلعب هذا الجزء دورًا مهمًا في نظامك الداخلي. مثل جميع الأجزاء، تطور لحمايتك بطريقة ما، حتى لو كانت أساليبه الآن تشعرك بالتحدي."
          : "This part plays an important role in your internal system. Like all parts, it developed to protect you in some way, even if its methods now feel challenging.";
    }
  }

  String _getHealingGuidance(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return isArabic
            ? "اشكر هذا الجزء على حمايته. اطلب منه التراجع بلطف حتى تتمكن من الوصول إلى المنفي الذي يحميه. يستجيب المديرون للتقدير والطمأنينة."
            : "Thank this part for its protection. Ask it to step back gently so you can access the exile it protects. Managers respond well to appreciation and reassurance.";
      case 'firefighter':
        return isArabic
            ? "اعترف باستجابة هذا الجزء لحالات الطوارئ. اشكره على محاولة المساعدة. اسأل عما إذا كان على استعداد للسماح لك بالتعامل مع الموقف بشكل مختلف. يهدأ رجال الإطفاء عند مواجهتهم بالتعاطف."
            : "Recognize this part's emergency response. Thank it for trying to help. Ask if it would be willing to let you handle the situation differently. Firefighters calm down when met with compassion.";
      case 'exile':
        return isArabic
            ? "تقدم بلطف وحب الاستطلاع. شاهد الألم دون محاولة إصلاحه. يحتاج هذا الجزء إلى حضورك الرحيم أكثر من الحلول."
            : "Approach with gentleness and curiosity. Witness the pain without trying to fix it. This part needs your compassionate presence more than solutions.";
      default:
        return isArabic
            ? "تقدم بحب الاستطلاع والتعاطف. جميع الأجزاء مرحب بها. اسأل: \"ماذا تحاول أن تفعل لي؟ كيف تعلمت المساعدة بهذه الطريقة؟\""
            : "Approach with curiosity and compassion. All parts are welcome. Ask: \"What are you trying to do for me? How did you learn to help in this way?\"";
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _translateArchetypeToArabic(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return 'المدير';
      case 'firefighter':
        return 'رجل الإطفاء';
      case 'exile':
        return 'المنفي';
      default:
        return archetype;
    }
  }
}