import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import '../services/firestore_service.dart';
import '../models/user_character_model.dart';
import 'widgets/shared_widgets.dart';
import 'character_chat_screen.dart';
import 'voice_analysis_screen.dart';
import '../l10n/app_strings.dart';

class HomeScreen extends StatefulWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const HomeScreen({
    super.key,
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  List<UserCharacter> _characters = [];
  bool _isLoading = true;
  String? _selectedCharacterId;
  Offset? _tapPosition;
  GifController? _gifController;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
    _loadCharacters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hot reload can skip initState for existing State objects.
    _gifController ??= GifController(vsync: this);
  }

  @override
  void dispose() {
    _gifController?.dispose();
    super.dispose();
  }

  Future<void> _loadCharacters() async {
    try {
      final characters = await _firestoreService.getUserCharacters();
      setState(() {
        _characters = characters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showInteractionBubbles(
      String characterId,
      GlobalKey key,
      Offset tapPosition,
      ) {
    setState(() {
      _selectedCharacterId = characterId;
      _tapPosition = tapPosition;
    });
  }

  void _hideInteractionBubbles() {
    setState(() {
      _selectedCharacterId = null;
      _tapPosition = null;
    });
  }

  void _handleInteraction(String interactionType, UserCharacter character) {
    _hideInteractionBubbles();
    if (interactionType == 'chat') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CharacterChatScreen(character: character),
        ),
      );
      return;
    }
    if (interactionType == 'voice') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VoiceAnalysisScreen(character: character),
        ),
      );
      return;
    }
    // TODO: Navigate to video based on interactionType
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $interactionType with ${character.displayName}'),
      ),
    );
  }

  String _getImagePathForCharacter(String characterName) {
    final imageMap = {
      'Inner Critic': 'inner_critic.png',
      'People Pleaser': 'people_pleaser.png',
      'Lonely Part': 'lonely.png',
      'Jealous Part': 'jealous.png',
      'Ashamed Part': 'ashamed.png',
      'Workaholic': 'workaholic.png',
      'Perfectionist': 'perfictionist.png',
      'Procrastinator': 'procrastinator.png',
      'Excessive Gamer': 'excessive_gamer.png',
      'Confused Part': 'confused.png',
      'Dependent Part': 'dependant.png',
      'Fearful Part': 'fearful.png',
      'Neglected Part': 'neglected.png',
      'Overeater': 'overeater_binger.png',
      'Binger': 'overeater_binger.png',
      'Overeater/Binger': 'overeater_binger.png',
      'Overwhelmed Part': 'overwhelmed.png',
      'Stoic Part': 'stoic.png',
      'Wounded Child': 'wounded_child.png',
      'Controller': 'controller.png',
      'Controller Part': 'controller.png',
    };

    if (imageMap.containsKey(characterName)) {
      return 'assets/images/${imageMap[characterName]}';
    }

    final lowerName = characterName.toLowerCase();
    for (final entry in imageMap.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return 'assets/images/${entry.value}';
      }
    }

    return 'assets/images/inner_critic.png';
  }

  String _localizedArchetype(BuildContext context, String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(context, 'Manager', 'مدير');
      case 'firefighter':
        return tr(context, 'Firefighter', 'إطفائي');
      case 'exile':
        return tr(context, 'Exile', 'منفى');
      default:
        return archetype;
    }
  }

  String _characterDescription(BuildContext context, String characterName) {
    final key = characterName.toLowerCase().replaceAll('the ', '').trim();
    final Map<String, List<String>> descriptions = {
      'inner critic': [
        'This part uses harsh standards to protect you from failure or judgment.',
        'It believes criticism keeps you motivated and safe from mistakes.',
      ],
      'people pleaser': [
        'This part prioritizes harmony and approval to avoid conflict or rejection.',
        'It often says yes when your needs say no.',
      ],
      'lonely part': [
        'This part carries the ache of disconnection and longs to be seen.',
        'It seeks closeness but fears being a burden.',
      ],
      'jealous part': [
        'This part fears being replaced or overlooked.',
        'It wants reassurance that you matter and are chosen.',
      ],
      'ashamed part': [
        'This part holds painful beliefs of not being good enough.',
        'It may hide to avoid exposure or judgment.',
      ],
      'workaholic': [
        'This part equates productivity with worth and safety.',
        'It pushes you to stay busy to avoid discomfort.',
      ],
      'perfectionist': [
        'This part strives for flawless outcomes to prevent criticism.',
        'It can create pressure and delay action.',
      ],
      'procrastinator': [
        'This part delays tasks to protect you from overwhelm or failure.',
        'It prefers short-term relief over long-term goals.',
      ],
      'excessive gamer': [
        'This part uses gaming to escape stress or emotional pain.',
        'It seeks comfort and control in a safe world.',
      ],
      'confused part': [
        'This part feels stuck and unsure which direction is right.',
        'It may slow decisions to avoid regret.',
      ],
      'dependent part': [
        'This part leans on others for security and guidance.',
        'It fears being alone with difficult choices.',
      ],
      'fearful part': [
        'This part anticipates danger and scans for what could go wrong.',
        'It tries to keep you prepared and protected.',
      ],
      'neglected part': [
        'This part holds the pain of unmet needs and feeling unseen.',
        'It longs for consistent care and attention.',
      ],
      'overeater': [
        'This part uses food for soothing and emotional relief.',
        'It seeks comfort when feelings feel too big.',
      ],
      'binger': [
        'This part turns to intensity or excess to numb pain quickly.',
        'It often appears when stress is high or boundaries feel tight.',
      ],
      'overwhelmed part': [
        'This part feels flooded by demands and pressure.',
        'It wants everything to slow down so you can breathe.',
      ],
      'stoic part': [
        'This part keeps emotions contained to stay strong and composed.',
        'It fears that vulnerability could be unsafe.',
      ],
      'wounded child': [
        'This part carries early hurt and unmet needs.',
        'It needs tenderness, protection, and reassurance.',
      ],
      'controller': [
        'This part tries to manage outcomes so nothing feels out of control.',
        'It believes certainty keeps you safe.',
      ],
    };

    final match = descriptions.entries.firstWhere(
      (entry) => key.contains(entry.key) || entry.key.contains(key),
      orElse: () => const MapEntry('', []),
    );

    if (match.value.isNotEmpty) {
      final english = match.value.join(' ');
      final arabicMap = {
        'inner critic':
            'هذا الجزء يضع معايير قاسية ليحميك من الفشل أو الحكم. يعتقد أن النقد يبقيك متحفزًا وآمنًا من الأخطاء.',
        'people pleaser':
            'هذا الجزء يفضل الانسجام والقبول لتجنب الصراع أو الرفض. غالبًا يقول نعم عندما تقول احتياجاتك لا.',
        'lonely part':
            'هذا الجزء يحمل ألم الانفصال ويتوق لأن يُرى. يسعى للقرب لكنه يخشى أن يكون عبئًا.',
        'jealous part':
            'هذا الجزء يخشى أن يُستبدل أو يُتجاهل. يريد طمأنة بأنك مهم ومختار.',
        'ashamed part':
            'هذا الجزء يحمل معتقدات مؤلمة بعدم الكفاية. قد يختبئ لتجنب الانكشاف أو الحكم.',
        'workaholic':
            'هذا الجزء يربط الإنتاجية بالقيمة والأمان. يدفعك للبقاء مشغولًا لتجنب الانزعاج.',
        'perfectionist':
            'هذا الجزء يسعى للكمال لتجنب النقد. يمكن أن يخلق ضغطًا وتأخيرًا في البدء.',
        'procrastinator':
            'هذا الجزء يؤجل المهام ليحميك من الإرهاق أو الفشل. يفضّل الراحة السريعة على الأهداف البعيدة.',
        'excessive gamer':
            'هذا الجزء يستخدم اللعب للهروب من التوتر أو الألم العاطفي. يبحث عن الراحة والسيطرة في عالم آمن.',
        'confused part':
            'هذا الجزء يشعر بالتشتت وعدم اليقين في الاتجاه الصحيح. قد يبطئ القرارات لتجنب الندم.',
        'dependent part':
            'هذا الجزء يعتمد على الآخرين للأمان والإرشاد. يخشى مواجهة الخيارات الصعبة وحده.',
        'fearful part':
            'هذا الجزء يتوقع الخطر ويراقب ما قد يحدث. يحاول إبقاءك مستعدًا ومحميًا.',
        'neglected part':
            'هذا الجزء يحمل ألم الاحتياجات غير المُلبّاة والشعور بعدم الرؤية. يتوق لرعاية ثابتة واهتمام.',
        'overeater':
            'هذا الجزء يستخدم الطعام للتهدئة والراحة العاطفية. يبحث عن سكينة عندما تكبر المشاعر.',
        'binger':
            'هذا الجزء يلجأ للشدة أو الإفراط لتخدير الألم بسرعة. يظهر غالبًا عند ارتفاع الضغط أو ضيق الحدود.',
        'overwhelmed part':
            'هذا الجزء يشعر بالانغمار بالطلبات والضغط. يريد إبطاء كل شيء لتستطيع التنفس.',
        'stoic part':
            'هذا الجزء يكتم المشاعر ليبقى قويًا ومتزنًا. يخشى أن تكون الهشاشة غير آمنة.',
        'wounded child':
            'هذا الجزء يحمل جراحًا مبكرة واحتياجات غير مُلبّاة. يحتاج للحنان والحماية والطمأنة.',
        'controller':
            'هذا الجزء يحاول التحكم في النتائج حتى لا يشعر بعدم السيطرة. يعتقد أن اليقين يحميك.',
      };
      final arabic = arabicMap[match.key] ??
          tr(
            context,
            'An inner part with a unique role in protecting and expressing you.',
            'جزء داخلي له دور مميز في حمايتك والتعبير عنك.',
          );
      return tr(context, english, arabic);
    }

    return tr(
      context,
      'An inner part with a unique role in protecting and expressing you.',
      'جزء داخلي له دور مميز في حمايتك والتعبير عنك.',
    );
  }

  String _archetypeDescription(BuildContext context, String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(
          context,
          'Protective, proactive parts that try to keep life organized and safe.',
          'أجزاء وقائية ومبادِرة تحاول إبقاء الحياة منظمة وآمنة.',
        );
      case 'firefighter':
        return tr(
          context,
          'Reactive parts that try to quickly soothe pain or overwhelm.',
          'أجزاء تفاعلية تحاول تهدئة الألم أو التوتر بسرعة.',
        );
      case 'exile':
        return tr(
          context,
          'Vulnerable parts carrying emotions like fear, shame, or loneliness.',
          'أجزاء حساسة تحمل مشاعر مثل الخوف أو العار أو الوحدة.',
        );
      default:
        return tr(
          context,
          'An inner part with a unique role in protecting and expressing you.',
          'جزء داخلي له دور مميز في حمايتك والتعبير عنك.',
        );
    }
  }

  Future<void> _showIfsInfoDialog() async {
    await showGeneralDialog(
      context: context,
      barrierLabel: 'IFS Info',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return _AnimatedInfoDialog(
          title: tr(context, 'What is IFS?', 'ما هو IFS؟'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  context,
                  'Internal Family Systems is a gentle, evidence-informed approach that sees your mind as a system of inner parts. Each part has a purpose, and healing happens when they feel heard and supported by your core Self.',
                  'نظام العائلة الداخلي هو منهج لطيف مدعوم بالأدلة يرى العقل كنظام من الأجزاء الداخلية. لكل جزء هدف، ويحدث الشفاء عندما يشعر بأنه مسموع ومدعوم من ذاتك الجوهرية.',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF4B3A66),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: Color(0xFF8E7CFF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, 'The 8 C’s of Self', 'صفات الذات الثماني'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'Calm, Curious, Compassionate, Confident, Courageous, Creative, Connected, Clear.',
                  'الهدوء، الفضول، التعاطف، الثقة، الشجاعة، الإبداع، الاتصال، الوضوح.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF4B3A66),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.layers_rounded,
                    size: 18,
                    color: Color(0xFF6A5CFF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, 'Types of Parts', 'أنواع الأجزاء'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'Managers prevent pain, Firefighters react to pain, and Exiles carry the original wounds.',
                  'المديرون يمنعون الألم، والمطفئون يتعاملون معه بسرعة، والمنفيون يحملون الجروح الأصلية.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF4B3A66),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.bubble_chart_rounded,
                    size: 18,
                    color: Color(0xFF4A3F6F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, 'Healing', 'الشفاء'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'Healing comes from leading with Self energy: calm, compassion, and clarity.',
                  'يأتي الشفاء عندما تقودك طاقة الذات: الهدوء والتعاطف والوضوح.',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF4B3A66),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showCharactersInfoDialog() async {
    await showGeneralDialog(
      context: context,
      barrierLabel: 'Character Info',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return _AnimatedInfoDialog(
          title: tr(
            context,
            'Learn about your characters',
            'تعرّف على شخصياتك',
          ),
          body: _characters.isEmpty
              ? Text(
                  tr(
                    context,
                    'Complete the questionnaire to see your characters.',
                    'أكمل الاستبيان لعرض شخصياتك.',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF4B3A66),
                  ),
                )
              : SizedBox(
                  height: 260,
                  child: ListView.separated(
                    itemCount: _characters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final character = _characters[index];
                      final imagePath = _getImagePathForCharacter(
                        character.characterName,
                      );
                      final color = _getCharacterColor(character.archetype);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5DEFF)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  imagePath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    character.displayName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2A1E3B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _localizedArchetype(
                                      context,
                                      character.archetype,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _archetypeDescription(
                                      context,
                                      character.archetype,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4B3A66),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _characterDescription(
                                      context,
                                      character.displayName,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4B3A66),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showReflectionPromptDialog() async {
    await showGeneralDialog(
      context: context,
      barrierLabel: 'Daily Reflection',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return _AnimatedInfoDialog(
          title: tr(context, 'Daily Reflection', 'تأمل يومي'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  context,
                  'Take a minute to check in with yourself. What part of you needed the most support today?',
                  'خذ دقيقة لتطمئن على نفسك. أي جزء منك احتاج أكبر قدر من الدعم اليوم؟',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF4B3A66),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EDFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF8E7CFF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          'Write a few words or share it with ANA in Reframe.',
                          'اكتب بضع كلمات أو شاركها مع آنا في إعادة الإطار.',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3A66),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }


  Color _getCharacterColor(String archetype) {
    switch (archetype.toLowerCase()) {
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

  Offset _getBubblePosition(BuildContext context, Offset tapPosition) {
    const bubbleWidth = 280.0;
    const bubbleHeight = 200.0;
    const padding = 12.0;
    final screenSize = MediaQuery.of(context).size;

    double left = tapPosition.dx - bubbleWidth / 2;
    double top = tapPosition.dy - bubbleHeight - 16;

    if (left < padding) left = padding;
    if (left + bubbleWidth > screenSize.width - padding) {
      left = screenSize.width - bubbleWidth - padding;
    }
    if (top < padding) top = tapPosition.dy + 16;
    if (top + bubbleHeight > screenSize.height - padding) {
      top = screenSize.height - bubbleHeight - padding;
    }

    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    _gifController ??= GifController(vsync: this);
    return Stack(
      children: [
        Column(
          children: [
            TopHelloBar(
              name: widget.name,
              onLogout: widget.onLogout,
              onSettings: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SettingsBottomSheet(
                    onRetakeQuestionnaire: widget.onRetakeQuestionnaire,
                onSwitchLanguage: widget.onSwitchLanguage,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Welcome card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8E7CFF), Color(0xFFB79CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8E7CFF).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(
                              context,
                              'Welcome to Your Inner Sanctuary',
                              'مرحباً بك في ملاذك الداخلي',
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr(
                              context,
                              'Hello ${widget.name}, your inner characters are waiting to connect with you.',
                              'مرحباً ${widget.name}، شخصياتك الداخلية بانتظار التواصل معك.',
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tr(
                                    context,
                                    '${_characters.length} Characters Identified',
                                    'تم تحديد ${_characters.length} شخصية',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Robot Guide Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5DEFF)),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Robot GIF on the left
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: Gif(
                                  image: const AssetImage(
                                    'assets/animations/guider.gif',
                                  ),
                                  controller: _gifController!,
                                  autostart: Autostart.once,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Speech bubble with text
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _SpeechBubble(
                                    child: _GuiderSpeechText(),
                                    backgroundColor: const Color(0xFFF0ECF7),
                                    borderColor: const Color(0xFFE5DEFF),
                                    textColor: const Color(0xDF2A1E3B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF8E7CFF),
                              ),
                            )
                          else if (_characters.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                tr(
                                  context,
                                  'No characters found. Please complete the questionnaire.',
                                  'لم يتم العثور على شخصيات. يرجى إكمال الاستبيان.',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF7A6A5A),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final cardWidth = 150.0;
                                Widget buildCard(UserCharacter character) {
                                  final key = GlobalKey();
                                  final color = _getCharacterColor(character.archetype);
                                  final isSelected =
                                      _selectedCharacterId == character.id;
                                  final imagePath =
                                  _getImagePathForCharacter(character.characterName);
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _CharacterCard(
                                      key: key,
                                      character: character,
                                      color: color,
                                      imagePath: imagePath,
                                      isSelected: isSelected,
                                      onTapDown: (details) {
                                        final tapPosition = details.globalPosition;
                                        if (isSelected) {
                                          _hideInteractionBubbles();
                                        } else {
                                          _showInteractionBubbles(
                                            character.id,
                                            key,
                                            tapPosition,
                                          );
                                        }
                                      },
                                    ),
                                  );
                                }

                                if (_characters.length == 1) {
                                  return Center(child: buildCard(_characters[0]));
                                }

                                if (_characters.length == 2) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      buildCard(_characters[0]),
                                      buildCard(_characters[1]),
                                    ],
                                  );
                                }

                                if (_characters.length == 3) {
                                  return Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                        children: [
                                          buildCard(_characters[0]),
                                          buildCard(_characters[1]),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Center(child: buildCard(_characters[2])),
                                    ],
                                  );
                                }

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.center,
                                  children:
                                  _characters.map((c) => buildCard(c)).toList(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Recent insights
                    Text(
                      tr(context, 'Recent Insights', 'أحدث الرؤى'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5DEFF)),
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
                                  color: const Color(0xFF8E7CFF).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.insights_rounded,
                                  color: Color(0xFF8E7CFF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  tr(
                                    context,
                                    'Your Inner Critic has been active this week',
                                    'كان ناقدك الداخلي نشطًا هذا الأسبوع',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2A1E3B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            tr(
                              context,
                              'This might be a sign that you\'re facing new challenges or stepping out of your comfort zone. Remember, your inner critic is trying to protect you.',
                              'قد يكون هذا علامة على أنك تواجه تحديات جديدة أو تخرج من منطقة الراحة. تذكر أن ناقدك الداخلي يحاول حمايتك.',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7A6A5A),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0ECF7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                            child: Text(
                              tr(context, 'Weekly Pattern', 'نمط أسبوعي'),
                              style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6A5CFF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                          Text(
                            tr(context, '2 days ago', 'قبل يومين'),
                            style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF7A6A5A).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Quick actions
                    Text(
                      tr(context, 'Quick Actions', 'إجراءات سريعة'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.psychology_rounded,
                            label: tr(
                              context,
                              'What is\nIFS?',
                              'ما هو\nIFS؟',
                            ),
                            color: const Color(0xFF8E7CFF),
                            onTap: () {
                              _showIfsInfoDialog();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.groups_rounded,
                            label: tr(
                              context,
                              'Learn About\nYour Characters',
                              'تعرّف على\nشخصياتك',
                            ),
                            color: const Color(0xFF8E7CFF),
                            onTap: () {
                              _showCharactersInfoDialog();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionButton(
                            icon: Icons.self_improvement_rounded,
                            label: tr(
                              context,
                              'Daily\nReflection',
                              'تأمل\nيومي',
                            ),
                            color: const Color(0xFF8E7CFF),
                            onTap: () {
                              _showReflectionPromptDialog();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Interaction Bubbles Overlay
        if (_selectedCharacterId != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideInteractionBubbles,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    Positioned(
                      left: _tapPosition == null
                          ? 0
                          : _getBubblePosition(context, _tapPosition!).dx,
                      top: _tapPosition == null
                          ? 0
                          : _getBubblePosition(context, _tapPosition!).dy,
                      child: _InteractionBubbles(
                        character: _characters.firstWhere(
                              (c) => c.id == _selectedCharacterId,
                        ),
                        onInteraction: _handleInteraction,
                        onClose: _hideInteractionBubbles,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final UserCharacter character;
  final Color color;
  final String imagePath;
  final bool isSelected;
  final GestureTapDownCallback onTapDown;

  const _CharacterCard({
    super.key,
    required this.character,
    required this.color,
    required this.imagePath,
    required this.isSelected,
    required this.onTapDown,
  });

  String _localizedArchetype(BuildContext context, String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(context, 'MANAGER', 'مدير');
      case 'firefighter':
        return tr(context, 'FIREFIGHTER', 'إطفائي');
      case 'exile':
        return tr(context, 'EXILE', 'منفى');
      default:
        return archetype.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5DEFF),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Character Image
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Character Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      character.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _localizedArchetype(context, character.archetype),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedInfoDialog extends StatelessWidget {
  final String title;
  final Widget body;

  const _AnimatedInfoDialog({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5DEFF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF8E7CFF),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B3A66),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _SpeechBubble({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeechBubblePainter(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 14, 10),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
            height: 1.4,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GuiderSpeechText extends StatelessWidget {
  const _GuiderSpeechText();

  @override
  Widget build(BuildContext context) {
    final isAr = isArabic(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final label = isAr ? 'المرشد:' : 'Guider:';
    final rest = isAr
        ? '\n مع من تريد التحدث اليوم؟'
        : '\nWho do you want to talk to today?';
    final gradient = const LinearGradient(
      colors: [Color(0xFFB79CFF), Color(0xFF665EB5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final labelPaint = Paint()
      ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 60, 60));

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              foreground: labelPaint,
            ),
          ),
          TextSpan(
            text: rest,
            style: baseStyle.copyWith(color: baseStyle.color),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  _SpeechBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = 10.0;
    const tailHeight = 10.0;
    const radius = 12.0;

    final bubbleRect = Rect.fromLTWH(
      tailWidth,
      0,
      size.width - tailWidth,
      size.height,
    );

    final rrect = RRect.fromRectAndRadius(
      bubbleRect,
      const Radius.circular(radius),
    );

    final fillPaint = Paint()..color = backgroundColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw main bubble
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Draw tail
    final tailPath = Path()
      ..moveTo(tailWidth, size.height * 0.5 - tailHeight * 0.5)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(tailWidth, size.height * 0.5 + tailHeight * 0.5)
      ..close();

    canvas.drawPath(tailPath, fillPaint);
    canvas.drawPath(tailPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _InteractionBubbles extends StatefulWidget {
  final UserCharacter character;
  final void Function(String interactionType, UserCharacter character)
  onInteraction;
  final VoidCallback onClose;

  const _InteractionBubbles({
    required this.character,
    required this.onInteraction,
    required this.onClose,
  });

  @override
  State<_InteractionBubbles> createState() => _InteractionBubblesState();
}

class _InteractionBubblesState extends State<_InteractionBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _leftSlide;
  late final Animation<Offset> _topSlide;
  late final Animation<Offset> _rightSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _leftSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _topSlide = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _rightSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 210,
          height: 150,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Chat option (left)
              Positioned(
                bottom: 10,
                left: 6,
                child: SlideTransition(
                  position: _leftSlide,
                  child: _InteractionBubble(
                    label: tr(context, 'Chat', 'دردشة'),
                    icon: Icons.chat_bubble_rounded,
                    color: const Color(0xFF8E7CFF),
                    onTap: () => widget.onInteraction('chat', widget.character),
                  ),
                ),
              ),
              // Video option (top)
              Positioned(
                top: 6,
                child: SlideTransition(
                  position: _topSlide,
                  child: _InteractionBubble(
                    label: tr(context, 'Video', 'فيديو'),
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFF6A5CFF),
                    onTap: () => widget.onInteraction('video', widget.character),
                  ),
                ),
              ),
              // Voice option (right)
              Positioned(
                bottom: 10,
                right: 6,
                child: SlideTransition(
                  position: _rightSlide,
                  child: _InteractionBubble(
                    label: tr(context, 'Voice', 'صوت'),
                    icon: Icons.mic_rounded,
                    color: const Color(0xFF4A3F6F),
                    onTap: () => widget.onInteraction('voice', widget.character),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractionBubble extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InteractionBubble({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFF8E7CFF),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2A1E3B),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5DEFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A1E3B),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

