import 'package:flutter/material.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import '../../../../cached_o3d_widget.dart';

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

  TextDirection get _textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  CrossAxisAlignment get _sectionCrossAxisAlignment =>
      isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start;

  TextAlign get _textAlign => isArabic ? TextAlign.right : TextAlign.left;

  String _toArabicDigits(Object value) {
    var text = value.toString();
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < englishDigits.length; i++) {
      text = text.replaceAll(englishDigits[i], arabicDigits[i]);
    }

    return text;
  }

  Widget _responsiveContainerTitle(
      String title, {
        Color color = const Color(0xFF6A5CFF),
        double fontSize = 14,
      }) {
    return SizedBox(
      width: double.infinity,
      child: Directionality(
        textDirection: _textDirection,
        child: Text(
          title,
          textDirection: _textDirection,
          textAlign: _textAlign,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _responsiveBodyText(
      String text, {
        Color color = const Color(0xFF3D2D5A),
        double fontSize = 13.5,
        FontWeight fontWeight = FontWeight.w400,
      }) {
    return SizedBox(
      width: double.infinity,
      child: Directionality(
        textDirection: _textDirection,
        child: Text(
          text,
          textDirection: _textDirection,
          textAlign: _textAlign,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.65,
            color: color,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

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
                  color: const Color(0xFF6A5CFF).withValues(alpha: 0.2),
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
                      textDirection: _textDirection,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _localizedCharacterName(character).toUpperCase(),
                            textDirection: _textDirection,
                            textAlign: _textAlign,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              letterSpacing: 1.2,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6A5CFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.insights_rounded,
                          color: const Color(0xFF6A5CFF).withValues(alpha: 0.5),
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
                                  .withValues(alpha: 0.05),
                            ),
                          ),

                          // 3D Model
                          glbPath.isNotEmpty
                              ? CachedO3D(
                            glbPath: glbPath,
                            cacheKey: glbPath,
                            height: 250,
                            width: 250,
                            autoPlay: true,
                            cameraControls: true,
                            backgroundColor: Colors.transparent,
                          )
                              : Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              color: _getCharacterColor(character)
                                  .withValues(alpha: 0.1),
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


  String _localizedCharacterName(UserCharacter value) {
    if (!isArabic) {
      return value.displayNameEn.isNotEmpty
          ? value.displayNameEn
          : value.characterName;
    }

    if (value.displayNameAr.isNotEmpty &&
        value.displayNameAr != value.displayNameEn) {
      return value.displayNameAr;
    }

    final arabicNames = <String, String>{
      'Inner Critic': 'الناقد الداخلي',
      'Perfectionist': 'الكمالي',
      'People Pleaser': 'المُرضي',
      'Controller': 'المتحكم',
      'Controller Part': 'المتحكم',
      'Stoic Part': 'الكتوم',
      'Workaholic': 'مدمن الشغل',
      'Confused Part': 'الحيران',
      'Procrastinator': 'المؤجل',
      'Overeater': 'الآكل العاطفي',
      'Binger': 'الآكل العاطفي',
      'Overeater/Binger': 'الآكل العاطفي',
      'Excessive Gamer': 'مدمن الألعاب',
      'Lonely Part': 'الوحيد',
      'Fearful Part': 'الخايف',
      'Neglected Part': 'المهمل',
      'Ashamed Part': 'الخجلان',
      'Overwhelmed Part': 'المضغوط',
      'Dependent Part': 'المعتمد',
      'Jealous Part': 'الغيور',
      'Wounded Child': 'الطفل المجروح',
    };

    return arabicNames[value.characterName] ??
        arabicNames[value.displayNameEn] ??
        value.displayNameAr ??
        value.displayNameEn;
  }

  String _localizedArchetypeText(String archetype) {
    if (!isArabic) return archetype.toLowerCase();

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

  String _localizedArchetypeRelation(
      String sourceArchetype,
      String targetArchetype,
      ) {
    final source = sourceArchetype.toLowerCase();
    final target = targetArchetype.toLowerCase();

    if (!isArabic) {
      if (source == 'manager' && target == 'firefighter') {
        return 'triggers when overwhelmed';
      }
      if (source == 'manager' && target == 'exile') {
        return 'protects from pain';
      }
      if (source == 'firefighter' && target == 'manager') {
        return 'reacts to control';
      }
      if (source == 'firefighter' && target == 'exile') {
        return 'distracts from pain';
      }
      if (source == 'exile' && target == 'manager') {
        return 'needs protection';
      }
      if (source == 'exile' && target == 'firefighter') {
        return 'needs comfort';
      }
      return 'connected part';
    }

    if (source == 'manager' && target == 'firefighter') {
      return 'بيظهر لما الضغط يزيد';
    }
    if (source == 'manager' && target == 'exile') {
      return 'بيحمي من الوجع';
    }
    if (source == 'firefighter' && target == 'manager') {
      return 'بيرد على السيطرة';
    }
    if (source == 'firefighter' && target == 'exile') {
      return 'بيشتت عن الوجع';
    }
    if (source == 'exile' && target == 'manager') {
      return 'محتاج حماية';
    }
    if (source == 'exile' && target == 'firefighter') {
      return 'محتاج تهدئة';
    }
    return 'مرتبط بالجزء ده';
  }

  List<String> _localizedArchetypeRelationshipTexts() {
    if (!isArabic) return archetypeRelationships;

    switch (character.archetype.toLowerCase()) {
      case 'manager':
        return const [
          'المدير بيحاول يحافظ على النظام والسيطرة.',
          'غالبًا بيحمي الأجزاء الضعيفة من إنها تحس بالوجع.',
          'لما الضغط يزيد ممكن يشغّل رجال الإطفاء.',
          'هدفه الأساسي يمنع الألم ويحافظ على الثبات.',
        ];
      case 'firefighter':
        return const [
          'رجل الإطفاء بيظهر وقت الطوارئ العاطفية.',
          'بيحاول يبعدك بسرعة عن الوجع أو الإحساس التقيل.',
          'ممكن يدخل في شد وجذب مع المدير اللي عايز يسيطر.',
          'هدفه يديك راحة فورية حتى لو الطريقة مش دايمًا صحية.',
        ];
      case 'exile':
        return const [
          'المنفي شايل مشاعر حساسة وذكريات موجعة.',
          'غالبًا المديرين بيحاولوا يحمُوه من الظهور.',
          'لما الوجع يطلع، رجال الإطفاء ممكن يشتغلوا بسرعة.',
          'الجزء ده محتاج يتشاف ويتسمع بهدوء وأمان.',
        ];
      default:
        return const [
          'الجزء ده ليه دور مهم جواك.',
          'كل جزء بيحاول يساعدك بطريقته.',
          'الفهم والهدوء بيساعدوا على التكامل.',
        ];
    }
  }

  List<UserCharacter> _connectedCharacters() {
    return allCharacters
        .where((value) => value.id != character.id)
        .toList();
  }

  Widget _buildContentSections() {
    return Directionality(
      textDirection: _textDirection,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: _sectionCrossAxisAlignment,
          children: [
            // Archetype badge
            _buildArchetypeBadge(),
            const SizedBox(height: 20),

            // Part State Status
            _buildPartStateSection(),
            const SizedBox(height: 20),

            // System Dynamics Section
            _buildSectionHeader(
                isArabic ? "الديناميكية جواك" : "System Dynamics",
                Icons.psychology_rounded
            ),
            _buildSystemDynamicsSection(),
            const SizedBox(height: 20),

            // IFS Archetype Relationships
            _buildSectionHeader(
                isArabic ? "ديناميكية أنواع IFS" : "IFS Archetype Dynamics",
                Icons.link_rounded
            ),
            _buildArchetypeRelationshipsSection(),
            const SizedBox(height: 20),

            // Relationship with Other Parts
            if (allCharacters.length > 1) ...[
              _buildSectionHeader(
                isArabic ? "الأجزاء المرتبطة جواك" : "Connected Parts in Your System",
                Icons.group_rounded,
              ),
              _buildIFSRelationshipsSection(),
              const SizedBox(height: 20),
            ],

            // Character Specific Insights
            _buildSectionHeader(
                isArabic ? "ملاحظات عن الجزء ده" : "Part-Specific Insights",
                Icons.insights_rounded
            ),
            _buildCharacterInsightsSection(),
            const SizedBox(height: 20),

            // Healing Context
            _buildSectionHeader(
                isArabic ? "إزاي تتعامل معاه" : "Healing Context",
                Icons.self_improvement_rounded
            ),
            _buildHealingContextSection(),
            const SizedBox(height: 20),

            // Predicted Date
            _buildPredictedDateSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildArchetypeBadge() {
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

    return Align(
      alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getCharacterColor(character).withValues(alpha: 0.15),
              _getCharacterColor(character).withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _getCharacterColor(character).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getCharacterColor(character).withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Directionality(
          textDirection: _textDirection,
          child: Row(
            textDirection: _textDirection,
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
                      color: _getCharacterColor(character).withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  archetypeDisplay.toUpperCase(),
                  textDirection: _textDirection,
                  textAlign: _textAlign,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: _getCharacterColor(character),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartStateSection() {
    Color stateColor;
    String stateText;
    String stateDescription;
    IconData stateIcon;

    switch (character.currentState) {
      case 'stable':
        stateColor = const Color(0xFF5CB85C);
        stateText = isArabic ? 'مستقر' : 'Stable';
        stateDescription = isArabic
            ? 'الجزء ده بقى أهدى ومتوازن أكتر. لسه ليه دور جواك، بس تأثيره بقى صحي أكتر.'
            : 'This part is stable and integrated. It continues to play a role in your system but in a balanced way.';
        stateIcon = Icons.verified;
        break;
      case 'inactive':
        stateColor = const Color(0xFF9E9E9E);
        stateText = isArabic ? 'غير نشط' : 'Inactive';
        stateDescription = isArabic
            ? 'الجزء ده مش نشط دلوقتي بسبب قلة استخدام التطبيق. لما تستخدم التطبيق بانتظام هيرجع يظهر تاني.'
            : 'This part is currently inactive due to app inactivity. Continue using the app regularly to activate it.';
        stateIcon = Icons.block;
        break;
      case 'active':
      default:
        stateColor = const Color(0xFFAB47BC);
        stateText = isArabic ? 'نشط' : 'Active';
        stateDescription = isArabic
            ? 'الجزء ده نشط دلوقتي وبيأثر عليك من جوا. حاول تفهمه وتتعامل معاه بهدوء.'
            : 'This part is currently active and influencing your internal system. You can work on understanding and integrating it.';
        stateIcon = Icons.circle;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: stateColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stateColor.withValues(alpha: 0.3),
        ),
      ),
      child: Directionality(
        textDirection: _textDirection,
        child: Row(
          textDirection: _textDirection,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                stateIcon,
                size: 16,
                color: stateColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: _sectionCrossAxisAlignment,
                children: [
                  Text(
                    stateText,
                    textDirection: _textDirection,
                    textAlign: _textAlign,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: stateColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stateDescription,
                    textDirection: _textDirection,
                    textAlign: _textAlign,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: stateColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Directionality(
        textDirection: _textDirection,
        child: Row(
          textDirection: _textDirection,
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.3),
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
                textDirection: _textDirection,
                textAlign: _textAlign,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2A1E3B),
                  letterSpacing: -0.3,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemDynamicsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E1FF),
          width: 1.5,
        ),
      ),
      child: Directionality(
        textDirection: _textDirection,
        child: Column(
          crossAxisAlignment: _sectionCrossAxisAlignment,
          children: [
            _responsiveContainerTitle(
              isArabic
                  ? 'جواك، الجزء ده:'
                  : 'In your internal system, this part:',
            ),
            const SizedBox(height: 10),
            _responsiveBodyText(
              isArabic && character.descriptionAr.isNotEmpty
                  ? character.descriptionAr
                  : character.descriptionEn,
              fontSize: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchetypeRelationshipsSection() {
    final relationships = _localizedArchetypeRelationshipTexts();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8E1FF),
          width: 1.5,
        ),
      ),
      child: Directionality(
        textDirection: _textDirection,
        child: Column(
          crossAxisAlignment: _sectionCrossAxisAlignment,
          children: [
            for (final relationship in relationships)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  textDirection: _textDirection,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6A5CFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        relationship,
                        textDirection: _textDirection,
                        textAlign: _textAlign,
                        softWrap: true,
                        overflow: TextOverflow.visible,
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
      ),
    );
  }

  Widget _buildIFSRelationshipsSection() {
    final connectedCharacters = _connectedCharacters();

    if (connectedCharacters.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5DEFF),
            width: 1.5,
          ),
        ),
        child: _responsiveBodyText(
          isArabic
              ? 'لسه مفيش أجزاء تانية متسجلة.'
              : 'No other parts identified yet.',
          color: const Color(0xFF6A5CFF),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5DEFF),
          width: 1.5,
        ),
      ),
      child: Directionality(
        textDirection: _textDirection,
        child: Column(
          crossAxisAlignment: _sectionCrossAxisAlignment,
          children: [
            _responsiveContainerTitle(
              isArabic
                  ? 'الجزء ده غالبًا بيتفاعل مع:'
                  : 'This ${character.archetype.toLowerCase()} typically interacts with:',
            ),
            const SizedBox(height: 12),
            ...connectedCharacters.map((otherCharacter) {
              final name = _localizedCharacterName(otherCharacter);
              final relation = _localizedArchetypeRelation(
                character.archetype,
                otherCharacter.archetype,
              );

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD8CEFF),
                  ),
                ),
                child: Text(
                  '$name ($relation)',
                  textDirection: _textDirection,
                  textAlign: _textAlign,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF6A5CFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterInsightsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFECB3),
          width: 1.5,
        ),
      ),
      child: Directionality(
        textDirection: _textDirection,
        child: Column(
          crossAxisAlignment: _sectionCrossAxisAlignment,
          children: [
            _responsiveContainerTitle(
              isArabic ? 'عن الجزء ده:' : 'About this specific part:',
              color: _getCharacterColor(character),
            ),
            const SizedBox(height: 10),
            _responsiveBodyText(
              _getCharacterInsights(character.displayNameEn.toLowerCase()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealingContextSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8FFE1),
          width: 1.5,
        ),
      ),
      child: Directionality(
        textDirection: _textDirection,
        child: Column(
          crossAxisAlignment: _sectionCrossAxisAlignment,
          children: [
            _responsiveContainerTitle(
              isArabic
                  ? 'لما تتعامل مع الجزء ده:'
                  : 'When working with this part:',
              color: const Color(0xFF00A86B),
            ),
            const SizedBox(height: 10),
            _responsiveBodyText(
              _getHealingGuidance(character.archetype),
              color: const Color(0xFF2A1E3B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictedDateSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5DEFF),
        ),
      ),
      child: Directionality(
        textDirection: _textDirection,
        child: Row(
          textDirection: _textDirection,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: const Color(0xFF6A5CFF).withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic
                    ? 'اتعرّفنا عليه: ${_formatDate(character.predictedAt)}'
                    : 'Identified: ${_formatDate(character.predictedAt)}',
                textDirection: _textDirection,
                textAlign: _textAlign,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: const Color(0xFF6A5CFF).withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
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
                color: const Color(0xFF6A5CFF).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              isArabic ? "اقفل" : "Close Insights",
              textDirection: _textDirection,
              textAlign: TextAlign.center,
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
        return _getSpecificCharacterIcon(character.displayNameEn.toLowerCase());
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
          ? "الجزء ده شايل إحساس بالخزي وعدم القيمة. غالبًا بيستخبى من الناس وبيجلد نفسه جامد. هو بيحاول يحميك من الضعف، بس ممكن يعزلك عن التواصل."
          : "This part carries feelings of shame and unworthiness. It often hides from others and criticizes itself harshly. Shame protects against vulnerability but can isolate you from connection.";
    } else if (characterName.contains('confused')) {
      return isArabic
          ? "الجزء ده بيحس بعدم وضوح وتوهان. ممكن يصعّب عليك القرار أو فهم الموقف. ساعات الحيرة بتكون طريقة حماية من وضوح تقيل أو مخيف."
          : "This part feels uncertain and unclear. It may struggle with decision-making or understanding situations. Confusion can be a protective mechanism against overwhelming clarity.";
    } else if (characterName.contains('controller')) {
      return isArabic
          ? "الجزء ده بيحاول يسيطر على المواقف أو الناس أو النتائج. فاكر إن الأمان بييجي من السيطرة. هو بيحميك، بس ممكن يعمل توتر وجمود."
          : "This part seeks to control situations, people, or outcomes. It believes safety comes from maintaining control. While protective, it can create rigidity and tension.";
    } else if (characterName.contains('dependent')) {
      return isArabic
          ? "الجزء ده بيحس إنه مش قادر يعتمد على نفسه. بيدور على دعم وتأكيد من بره. الاعتماد ده غالبًا جاي من احتياجات قديمة متسمعتش."
          : "This part feels unable to function independently. It seeks external validation and support. Dependency often develops from early experiences of unmet needs.";
    } else if (characterName.contains('gamer')) {
      return isArabic
          ? "الجزء ده بيستخدم الألعاب كهروب أو تشتيت. ممكن يلاقي إنجاز وسيطرة في العالم الافتراضي لما الواقع يبقى تقيل. الألعاب بتدي راحة مؤقتة من الضغط."
          : "This part uses gaming as escape or distraction. It might seek achievement in virtual worlds when real-world needs feel unmet. Gaming can provide temporary relief from stress.";
    } else if (characterName.contains('fearful')) {
      return isArabic
          ? "الجزء ده دايمًا صاحي للخطر. بيتوقع الأسوأ وبيستعدله. الخوف بيحميك، بس ممكن يمنعك من تجارب كتير."
          : "This part is constantly alert to danger. It anticipates threats and prepares for worst-case scenarios. Fear protects but can limit life experiences.";
    } else if (characterName.contains('critic')) {
      return isArabic
          ? "الجزء ده بيحكم وبيقيّم طول الوقت. بيحط معايير عالية وبيمسك في العيوب. الناقد بيحاول يحميك من الفشل أو الإحراج."
          : "This part constantly judges and evaluates. It sets high standards and points out flaws. The critic tries to protect by preventing failure or embarrassment.";
    } else if (characterName.contains('jealous')) {
      return isArabic
          ? "الجزء ده بيقارن وبيحس بالنقص. بيراقب اللي عند غيره وبيخاف يتساب بره. الغيرة غالبًا بتقول إن فيه احتياج للأمان أو التقدير."
          : "This part compares and feels lacking. It monitors what others have and fears being left out. Jealousy signals unmet needs for security or validation.";
    } else if (characterName.contains('lonely')) {
      return isArabic
          ? "الجزء ده بيحس بوحدة وانفصال. نفسه في تواصل حقيقي بس ممكن يخاف يقرب. الوحدة غالبًا شايلة وجع علاقات قديمة."
          : "This part feels isolated and disconnected. It longs for meaningful connection but may fear reaching out. Loneliness often holds past relational wounds.";
    } else if (characterName.contains('neglected')) {
      return isArabic
          ? "الجزء ده شايل ذكريات إهمال أو إحساس إنه مش مهم. ممكن يحس إنه مش متشاف ومحتاج اهتمام. وجع الإهمال بيأثر على تقديرك لنفسك."
          : "This part carries memories of being overlooked or unimportant. It may feel invisible and yearn for attention. Neglect wounds affect self-worth.";
    } else if (characterName.contains('overeater') || characterName.contains('binger')) {
      return isArabic
          ? "الجزء ده بيستخدم الأكل للراحة أو التشتيت أو تهدئة المشاعر. سلوك الأكل ساعات بيغطي احتياجات أعمق أو بيدي راحة مؤقتة من الضغط."
          : "This part uses food for comfort, distraction, or emotional regulation. Eating behaviors often mask deeper emotional needs or provide temporary relief from stress.";
    } else if (characterName.contains('overwhelmed')) {
      return isArabic
          ? "الجزء ده بيحس إنه مدفون تحت المسؤوليات أو المشاعر. ممكن يوقفك أو يخليك مش قادر تتحرك. الإرهاق ساعات بيحميك من مواجهة حاجات كتير مرة واحدة."
          : "This part feels buried under responsibilities or emotions. It may shut down or become paralyzed. Overwhelm protects against facing too much at once.";
    } else if (characterName.contains('people pleaser')) {
      return isArabic
          ? "الجزء ده بيحط احتياجات الناس قبل احتياجاتك. بيدور على الموافقة وبيبعد عن الخناق. إرضاء الناس غالبًا اتكوّن كطريقة للأمان والقبول."
          : "This part prioritizes others' needs above its own. It seeks approval and avoids conflict. People-pleasing develops as a strategy for safety and acceptance.";
    } else if (characterName.contains('perfectionist')) {
      return isArabic
          ? "الجزء ده فاكر إن الكمال يمنع النقد أو الفشل. بيحط معايير عالية جدًا وصعبة. الكمالية بتحاول تعمل أمان عن طريق التفوق."
          : "This part believes flawlessness prevents criticism or failure. It sets impossibly high standards. Perfectionism aims to ensure safety through excellence.";
    } else if (characterName.contains('procrastinator')) {
      return isArabic
          ? "الجزء ده بيأجل المهام أو القرارات. ممكن يكون خايف من الفشل أو النجاح أو حكم الناس. التأجيل بيدي راحة مؤقتة من الضغط."
          : "This part avoids tasks or decisions. It may fear failure, success, or judgment. Procrastination provides temporary relief from pressure.";
    } else if (characterName.contains('stoic')) {
      return isArabic
          ? "الجزء ده بيكتم المشاعر ويفضل متماسك. بيقدّم العقل على الإحساس. الكتمان بيحميك من الضعف، بس ممكن يعمل مسافة عاطفية."
          : "This part suppresses emotions and maintains composure. It values rationality over feeling. Stoicism protects against vulnerability but can create emotional distance.";
    } else if (characterName.contains('workaholic')) {
      return isArabic
          ? "الجزء ده بيلاقي قيمته في الإنتاج والشغل. ممكن يهرب من الراحة أو المتعة. إدمان الشغل ساعات بيبقى هروب من وجع أو بحث عن تقدير."
          : "This part finds identity and worth in productivity. It may avoid rest or leisure. Workaholism can be an escape from emotional pain or a quest for validation.";
    } else if (characterName.contains('wounded') || characterName.contains('child')) {
      return isArabic
          ? "الجزء ده شايل جروح قديمة واحتياجات طفولة متسمعتش. جواه أذى أو خوف أو حزن. الطفل ده محتاج يتشاف بلطف وأمان."
          : "This part holds early developmental wounds and unmet childhood needs. It carries vulnerable emotions like hurt, fear, or sadness. This child part needs gentle witnessing.";
    } else {
      return isArabic
          ? "الجزء ده ليه دور مهم جواك. زي باقي الأجزاء، هو اتكوّن عشان يحميك بطريقة ما، حتى لو طريقته دلوقتي بقت صعبة عليك."
          : "This part plays an important role in your internal system. Like all parts, it developed to protect you in some way, even if its methods now feel challenging.";
    }
  }

  String _getHealingGuidance(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return isArabic
            ? "اشكر الجزء ده على حمايته، واطلب منه بهدوء يسيبلك مساحة تفهم الوجع اللي بيحميه. المديرين بيهدوا لما يحسوا بالتقدير والاطمئنان."
            : "Thank this part for its protection. Ask it to step back gently so you can access the exile it protects. Managers respond well to appreciation and reassurance.";
      case 'firefighter':
        return isArabic
            ? "اعترف إن الجزء ده بيظهر وقت الطوارئ. اشكره إنه بيحاول يساعد، واسأله لو ينفع تجرّب طريقة أهدى. رجال الإطفاء بيهدوا أكتر لما نقابلهم بتعاطف."
            : "Recognize this part's emergency response. Thank it for trying to help. Ask if it would be willing to let you handle the situation differently. Firefighters calm down when met with compassion.";
      case 'exile':
        return isArabic
            ? "قرب منه بهدوء وفضول. اسمع الوجع من غير ما تستعجل تصلحه. الجزء ده محتاج حضورك وحنانك أكتر من أي حلول."
            : "Approach with gentleness and curiosity. Witness the pain without trying to fix it. This part needs your compassionate presence more than solutions.";
      default:
        return isArabic
            ? "قرب بفضول وتعاطف. كل الأجزاء ليها مكان. اسأل: إنت بتحاول تعمل إيه عشاني؟ وإزاي اتعلمت تساعدني بالطريقة دي؟"
            : "Approach with curiosity and compassion. All parts are welcome. Ask: \"What are you trying to do for me? How did you learn to help in this way?\"";
    }
  }

  String _formatDate(DateTime date) {
    final formatted = "${date.day}/${date.month}/${date.year}";
    return isArabic ? _toArabicDigits(formatted) : formatted;
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