// lib/features/progress/domain/entities/daily_activity.dart

class DailyActivity {
  final String id;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final String category; // morning, afternoon, evening
  final int estimatedMinutes;
  final List<Tag> tags; // Now List of Tag objects instead of strings

  DailyActivity({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.category,
    required this.estimatedMinutes,
    required this.tags,
  });

  factory DailyActivity.fromMap(Map<String, dynamic> map) {
    return DailyActivity(
      id: map['id'],
      titleEn: map['titleEn'],
      titleAr: map['titleAr'],
      descriptionEn: map['descriptionEn'],
      descriptionAr: map['descriptionAr'],
      category: map['category'],
      estimatedMinutes: map['estimatedMinutes'],
      tags: (map['tags'] as List).map((tag) => Tag.fromMap(tag)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titleEn': titleEn,
      'titleAr': titleAr,
      'descriptionEn': descriptionEn,
      'descriptionAr': descriptionAr,
      'category': category,
      'estimatedMinutes': estimatedMinutes,
      'tags': tags.map((tag) => tag.toMap()).toList(),
    };
  }
}

// New Tag class to support bilingual tags
class Tag {
  final String en;
  final String ar;

  Tag({
    required this.en,
    required this.ar,
  });

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      en: map['en'],
      ar: map['ar'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'en': en,
      'ar': ar,
    };
  }
}

// Activity Repository
class DailyActivityRepository {
  List<DailyActivity> getAllActivities() {
    return _allActivities;
  }

  List<DailyActivity> getActivitiesByCategory(String category) {
    return _allActivities.where((activity) => activity.category == category).toList();
  }

  List<DailyActivity> getActivitiesByTags(List<String> tagEnValues) {
    return _allActivities.where((activity) =>
        activity.tags.any((tag) => tagEnValues.contains(tag.en))
    ).toList();
  }

  DailyActivity? getActivityById(String id) {
    try {
      return _allActivities.firstWhere((activity) => activity.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get 3 random activities for today (one from each category)
  List<DailyActivity> getTodaysActivities() {
    final morningActivities = getActivitiesByCategory('morning');
    final afternoonActivities = getActivitiesByCategory('afternoon');
    final eveningActivities = getActivitiesByCategory('evening');

    final random = DateTime.now().microsecondsSinceEpoch;

    return [
      morningActivities[(random % morningActivities.length).toInt()],
      afternoonActivities[(random % afternoonActivities.length).toInt()],
      eveningActivities[(random % eveningActivities.length).toInt()],
    ];
  }

  // List of all activities with Egyptian Arabic tags
  static final List<DailyActivity> _allActivities = [
    // Morning Activities (16)
    DailyActivity(
      id: 'morning_gratitude',
      titleEn: 'Awakening to Abundance',
      titleAr: 'صحوة الامتنان',
      descriptionEn: 'As the new day dawns, gently bring to mind three blessings that exist in your life right now. They can be as simple as the warmth of your blanket, the gift of another day, or the presence of a loved one. Let each acknowledgment fill your heart with a quiet sense of appreciation.',
      descriptionAr: 'مع بداية اليوم الجديد، فكّر بهدوء في تلاتة حاجات انت شاكر إنهم في حياتك دلوقتي. ممكن يكونوا حاجات بسيطة زي دفء البطانية بتاعتك، أو إنك صحيت النهاردة، أو وجود حد بتحبه. مع كل حاجة، خلي قلبك يمتلئ بشعور جميل بالامتنان.',
      category: 'morning',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'gratitude', ar: 'امتنان'),
        Tag(en: 'positive_thinking', ar: 'تفكير إيجابي'),
      ],
    ),
    DailyActivity(
      id: 'deep_breathing',
      titleEn: 'The Breath of Life',
      titleAr: 'نَفَس الحياة',
      descriptionEn: 'Find a comfortable seat and close your eyes. Begin to breathe deeply, imagining each inhale drawing in fresh, revitalizing energy, and each exhale releasing any tension or heaviness you may be carrying. With each breath, feel yourself becoming more present and grounded in the here and now.',
      descriptionAr: 'اقعد في مكان مريح وغمض عينيك. ابدأ تاخد نفس عميق، وتخيل مع كل شهيق إنك بتستقبل طاقة جديدة ومنعشة، ومع كل زفير إنك بتخرج أي توتر أو تقل من جواك. مع كل نفس، حسّ إنك بتبقى أكتر حضورًا وثباتًا في اللحظة دي.',
      category: 'morning',
      estimatedMinutes: 3,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'stress_relief', ar: 'تخفيف التوتر'),
        Tag(en: 'breathing', ar: 'تنفس'),
      ],
    ),
    DailyActivity(
      id: 'intention_setting',
      titleEn: 'Planting a Seed of Intention',
      titleAr: 'زرع بذرة النية',
      descriptionEn: 'Before the busyness of the day takes hold, pause to set a single, heartfelt intention. Ask yourself: "What quality do I wish to cultivate today?" It might be patience, kindness, presence, or courage. Visualize this intention as a small seed you are planting in the garden of your day, ready to be nurtured by your awareness.',
      descriptionAr: 'قبل ما اليوم يبدأ وياخد منك، وقف شوية عشان تحدد نية واحدة صادقة. اسأل نفسك: "أنا عايز أزرع صفة إيه النهاردة في يومي؟" ممكن تكون الصبر، أو اللطف، أو الحضور، أو الشجاعة. تخيل النية دي زي بذرة صغيرة بتزرعها في حديقة يومك، ومستنية رعايتك عشان تكبر.',
      category: 'morning',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'focus', ar: 'تركيز'),
        Tag(en: 'positive_thinking', ar: 'تفكير إيجابي'),
      ],
    ),
    DailyActivity(
      id: 'sunlight_exposure',
      titleEn: 'The Morning Embrace',
      titleAr: 'عناق الصباح',
      descriptionEn: 'Step outside or find a sunlit window and let the gentle morning light touch your skin. Close your eyes for a moment and feel its warmth as a loving embrace from the universe. This light carries the energy of renewal and life – let it remind you that you, too, are a part of nature\'s beautiful rhythm.',
      descriptionAr: 'اطلع بره أو قف قدام شباك فيه شمس وخلي نور الصباح اللطيف يلمس وشك. أغمض عينيك شوية وحسّ بدفا الشمس زي عناق حنون من الدنيا. النور ده فيه طاقة التجدد والحياة - خلّيه يذكرّك إنك جزء من إيقاع الطبيعة الجميل.',
      category: 'morning',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
        Tag(en: 'energy', ar: 'طاقة'),
        Tag(en: 'vitamin_d', ar: 'فيتامين د'),
      ],
    ),
    DailyActivity(
      id: 'gentle_stretching',
      titleEn: 'Waking the Body',
      titleAr: 'إيقاظ الجسد',
      descriptionEn: 'Greet your body with gentle, loving movement. Like a cat stretching after a long nap, slowly extend your arms overhead, roll your shoulders, and twist your spine. Move with awareness, thanking each part of your body for its silent work. There is no need to force – just gentle awakening.',
      descriptionAr: 'صحّي جسدك بحركات لطيفة وحنينة. زي القطة لما تتمدد بعد النومة، مد دراعك ببطء لفوق، ودحرج كتفيك، ولفّ ضهرك. اتحرك بوعي، واشكر كل جزء في جسدك على شغله الصامت. مش محتاج تجهد نفسك – مجرد صحوة لطيفة.',
      category: 'morning',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
        Tag(en: 'flexibility', ar: 'مرونة'),
        Tag(en: 'energy', ar: 'طاقة'),
      ],
    ),
    DailyActivity(
      id: 'mindful_tea',
      titleEn: 'A Cup of Presence',
      titleAr: 'كوباية حضور',
      descriptionEn: 'Prepare your morning tea or coffee as if it were a sacred ritual. Notice the sound of the water, the aroma of the leaves or grounds, the warmth of the cup in your hands. With each sip, let the flavors dance on your tongue. This is not just a beverage; it is a moment of pure presence.',
      descriptionAr: 'حضّر شايك أو قهوتك الصبحية وكأنها طقس مقدس. اسمع صوت المية، وشمة ريحة السادة أو البن، وحسّ بدفا الكوباية في إيدك. مع كل رشفة، ذوق الطعم وخلّيه يعجبك. دي مش مجرد مشروب؛ دي لحظة حضور خالصة.',
      category: 'morning',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'sensory_awareness', ar: 'إدراك حسي'),
      ],
    ),
    DailyActivity(
      id: 'positive_affirmation',
      titleEn: 'Whispers to the Soul',
      titleAr: 'همس للروح',
      descriptionEn: 'Stand before a mirror, look into your own eyes, and offer yourself a kind affirmation. Speak slowly and with feeling: "I am enough, exactly as I am." or "Today, I choose peace." Let these words sink into your being, a gentle reminder of your inherent worth and the beauty you carry within.',
      descriptionAr: 'قف قدام المراية، بص في عينيك، و قول لنفسك كلمة حلوة. اتكلم ببطء و بإحساس: "أنا كفاية، زيّ ما أنا كده." أو "النهاردة، أنا بختار السلام." خلي الكلمات دي تتغرس في جواك، تذكّرك بقيمتك و جمالك اللي جواك.',
      category: 'morning',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'positive_thinking', ar: 'تفكير إيجابي'),
        Tag(en: 'self_esteem', ar: 'تقدير الذات'),
      ],
    ),
    DailyActivity(
      id: 'journal_prompt',
      titleEn: 'Pages of Possibility',
      titleAr: 'صفحات من إمكانيات',
      descriptionEn: 'Sit with your journal and let the question guide you: "If today were a gift, how would I unwrap it with joy?" Write whatever comes, without judgment. This is not about planning tasks, but about opening your heart to the day\'s possibilities – the small moments of beauty, connection, and wonder that await you.',
      descriptionAr: 'اقعد مع مذكرتك وخلّي السؤال يوجّهك: "لو النهاردة هدية، هافتحها إزاي بفرح؟" اكتب أي حاجة تيجي على بالك، من غير أحكام. ده مش عن تخطيط مهام، ده عن إنك تفتح قلبك لإمكانيات اليوم – لحظات الجمال الصغيرة، و التواصل، و الدهشة اللي مستنيّاك.',
      category: 'morning',
      estimatedMinutes: 7,
      tags: [
        Tag(en: 'journaling', ar: 'تدوين'),
        Tag(en: 'reflection', ar: 'تأمل'),
      ],
    ),
    DailyActivity(
      id: 'mindful_shower',
      titleEn: 'Cleansing Ritual',
      titleAr: 'طقس التطهر',
      descriptionEn: 'Let your shower become a meditation. Feel the water cascading over you, washing away not just the physical, but also any lingering sleep or worries. Notice the temperature, the sensation on your skin, the steam rising. Imagine the water cleansing you, leaving you refreshed and renewed for the day ahead.',
      descriptionAr: 'خلّي الدش بتاعك يكون تأمّل. حسّ بالميّة وهي بتنزل عليك، بتغسل مش بس الجسد، لكن كمان أي نوم أو هموم لسه معلّقة. لاحظ درجة الحرارة، الإحساس على جلدك، و البخار اللي طالع. تخيل المية بتطهّرك، و بتخلّيك منتعش و متجدّد لليوم الجاي.',
      category: 'morning',
      estimatedMinutes: 10,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'sensory_awareness', ar: 'إدراك حسي'),
      ],
    ),
    DailyActivity(
      id: 'digital_detox_start',
      titleEn: 'The Sacred Pause',
      titleAr: 'الوقف المقدس',
      descriptionEn: 'Before reaching for your phone, give yourself the gift of a sacred pause. Let the first moments of your day belong to you, not to notifications. Breathe, stretch, look out the window. Protect this quiet time as a sanctuary for your soul before the digital world calls you back.',
      descriptionAr: 'قبل ما تمسك التليفون، اهدي نفسك هدية الوقفة المقدسة. خلّي أول لحظات يومك تكونلك انت، مش للتنبيهات. تنفس، تمدد، بص من الشباك. احمي الوقت الهادئ ده و خلّيه ملجأ لروحك قبل ما العالم الرقمي يستدعيك.',
      category: 'morning',
      estimatedMinutes: 1,
      tags: [
        Tag(en: 'digital_detox', ar: 'صيام رقمي'),
        Tag(en: 'focus', ar: 'تركيز'),
      ],
    ),
    DailyActivity(
      id: 'nature_sounds',
      titleEn: 'Symphony of the Earth',
      titleAr: 'سيمفونية الأرض',
      descriptionEn: 'Close your eyes and listen to the subtle music of nature. The birds singing their morning songs, the rustle of leaves in the breeze, perhaps the distant hum of life. Let these sounds carry you away from thoughts and into a state of simple, peaceful listening. You are part of this symphony.',
      descriptionAr: 'أغمض عينيك و اسمع الموسيقى الخفية للطبيعة. العصافير بتغني أغاني الصباح، ورق الشجر بيحف في الهوا، و يمكن صوت الحياة البعيدة. خلّي الأصوات دي تودّيك بعيد عن الأفكار و توصلك لحالة من الاستماع البسيط والمسالم. انت جزء من السيمفونية دي.',
      category: 'morning',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'relaxation', ar: 'استرخاء'),
        Tag(en: 'nature', ar: 'طبيعة'),
      ],
    ),
    DailyActivity(
      id: 'energy_visualization',
      titleEn: 'The Inner Light',
      titleAr: 'النور الجواني',
      descriptionEn: 'Sit quietly and visualize a warm, golden light at the center of your being. With each inhale, see this light growing brighter and expanding, gently filling your entire body – your chest, your arms, your legs, all the way to your fingertips and toes. This light is your life force, your innate peace and energy, radiating from within.',
      descriptionAr: 'اقعد بهدوء و تخيل نور دافئ ذهبي في وسط كيانك. مع كل شهيق، شوف النور ده بيزيد و بيتمدّد، بيملى جسدك كله بلطف – صدرك، دراعك، رجلك، لحد أطراف أصابعك. النور ده هو طاقة حياتك، سلامك و طاقتك اللي جواك، و هي بتشعّ من جواك.',
      category: 'morning',
      estimatedMinutes: 3,
      tags: [
        Tag(en: 'visualization', ar: 'تصور'),
        Tag(en: 'energy', ar: 'طاقة'),
      ],
    ),
    DailyActivity(
      id: 'mindful_breakfast',
      titleEn: 'Nourishment in Silence',
      titleAr: 'أكل في صمت',
      descriptionEn: 'Sit down to eat your breakfast without the company of screens or reading. Simply be with your food. Notice the colors on your plate, the different textures, the aromas. Chew slowly, savoring each bite. This meal is fuel for your body, but it can also be a moment of gratitude and quiet connection with the present.',
      descriptionAr: 'اقعد عشان تاكل فطورك من غير شاشات أو قراية. ببساطة، كن مع أكلتك. لاحظ الألوان في طبقك، القوام المختلف، الروايح. امضغ بهدوء، و استمتع بكل لقمة. الأكلة دي وقود لجسدك، بس ممكن كمان تكون لحظة امتنان و اتصال مع اللحظة اللي انت فيها.',
      category: 'morning',
      estimatedMinutes: 15,
      tags: [
        Tag(en: 'mindful_eating', ar: 'أكل واعي'),
        Tag(en: 'nutrition', ar: 'تغذية'),
      ],
    ),
    DailyActivity(
      id: 'body_scan',
      titleEn: 'A Journey Through the Body',
      titleAr: 'رحلة في الجسد',
      descriptionEn: 'Lie down or sit comfortably and bring your awareness to your body. Start at the top of your head and slowly move your attention down – to your face, your neck, your shoulders. Notice any sensations without trying to change them: warmth, coolness, tingling, or simply the feeling of being. This is a journey of gentle curiosity and acceptance.',
      descriptionAr: 'اتمدد أو اقعد براحة و وجّه انتباهك لجسدك. ابدأ من فوق دماغك و حرّك تركيزك ببطء لتحت – لوشك، رقبتك، كتفيك. لاحظ أي أحاسيس من غير ما تحاول تغيّرها: دفا، برودة، تنميل، أو مجرد الإحساس بالوجود. دي رحلة فضول لطيف و قبول.',
      category: 'morning',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'body_awareness', ar: 'إدراك الجسد'),
        Tag(en: 'mindfulness', ar: 'وعي'),
      ],
    ),
    DailyActivity(
      id: 'scent_therapy',
      titleEn: 'The Invisible Embrace',
      titleAr: 'العناق الخفي',
      descriptionEn: 'Choose a scent that speaks to your soul – the freshness of a cut lemon, the floral notes of rose, the earthiness of sandalwood. Bring it close and inhale deeply, letting the aroma wash over you like an invisible embrace. Scents have the power to shift our mood and anchor us in the present moment.',
      descriptionAr: 'اختار ريحة بتخاطب روحك – نضارة الليمون المقطع، ريحة الورد، أو ريحة الأرض في خشب الصندل. قربها و استنشق بعمق، و خلّي الريحة تغمرك زي عناق خفي. الروايح عندها قدرة تغير مزاجنا و تخلينا نركز في اللحظة اللي إحنا فيها.',
      category: 'morning',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'sensory_awareness', ar: 'إدراك حسي'),
        Tag(en: 'aromatherapy', ar: 'علاج بالروائح'),
      ],
    ),
    DailyActivity(
      id: 'hydration_check',
      titleEn: 'A Toast to Life',
      titleAr: 'نخب الحياة',
      descriptionEn: 'Pour yourself a glass of cool, clear water. Before drinking, hold it up to the light and appreciate its simplicity and necessity. As you drink, feel the water quenching your body\'s thirst at the deepest level. With each sip, offer a silent toast to life itself and the new day you\'ve been given.',
      descriptionAr: 'احضر لنفسك كباية مية باردة صافية. قبل ما تشرب، ارفعها للنور و قدّر بساطتها و أهميتها. و انت بتشرب، حسّ بالميّة و هي تروي عطش جسدك من جوا. مع كل رشفة، ارفع نخب صامت للحياة نفسها و لليوم الجديد اللي اتهدالك.',
      category: 'morning',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
        Tag(en: 'hydration', ar: 'ترطيب'),
      ],
    ),

    // Afternoon Activities (17)
    DailyActivity(
      id: 'mindful_walk',
      titleEn: 'Walking Meditation',
      titleAr: 'مشي تأملي',
      descriptionEn: 'Step outside for a slow, mindful walk. Feel the ground beneath your feet with each step. Notice the air on your skin, the play of light and shadow. Instead of walking to get somewhere, walk as if you have already arrived – at this moment, right here. Let the world unfold around you.',
      descriptionAr: 'اطلع بره تمشّى بهدوء و وعي. حسّ بالأرض تحت رجليك مع كل خطوة. لاحظ الهوا على وشك، و لعب النور و الظل. بدل ما تمشي عشان توصل لحتة، امشي و كأنك وصلت بالفعل – للحظة دي، هنا. خلّي الدنيا تتكشف حواليك.',
      category: 'afternoon',
      estimatedMinutes: 10,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'exercise', ar: 'رياضة'),
        Tag(en: 'nature', ar: 'طبيعة'),
      ],
    ),
    DailyActivity(
      id: 'desk_stretches',
      titleEn: 'Unwinding the Day',
      titleAr: 'فك اليوم',
      descriptionEn: 'If you\'ve been sitting for a while, your body may be asking for a gentle release. Stand up and reach your arms overhead, feeling the length of your spine. Gently twist from side to side. Roll your shoulders forward and back. This is not exercise; it\'s a loving conversation with your body, thanking it for its work.',
      descriptionAr: 'لو قاعد فترة طويلة، جسدك يمكن بيطلب تحرير لطيف. قف و مد دراعك لفوق، و انت حاسس بطول ضهرك. لَف بلطف من جنب للتاني. دحرج كتفك قدام و ورا. ده مش تمرين، دي محادثة حب مع جسدك، بتشكره على شغله.',
      category: 'afternoon',
      estimatedMinutes: 3,
      tags: [
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
        Tag(en: 'ergonomics', ar: 'صحة العمل'),
      ],
    ),
    DailyActivity(
      id: 'breathing_break',
      titleEn: 'Returning to Center',
      titleAr: 'الرجوع للنفس',
      descriptionEn: 'Pause whatever you are doing and simply take three conscious breaths. Feel the air entering your nostrils, filling your lungs, and then leaving your body. This tiny pause is a return home to yourself, a reminder that amidst all the doing, you are first and foremost a human being.',
      descriptionAr: 'وقف أي حاجة بتعملها و خد بس تلات أنفاس واعية. حسّ بالهوا داخل من مناخيرك، و ملى رئتك، و بعدين طالع من جسدك. الوقفة الصغيرة دي هي رجوع لذاتك، تذكير إن وسط كل اللي بتعمله، انت الأول و الأخير إنسان.',
      category: 'afternoon',
      estimatedMinutes: 1,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'stress_relief', ar: 'تخفيف التوتر'),
      ],
    ),
    DailyActivity(
      id: 'gratitude_moment',
      titleEn: 'A Pause for the Heart',
      titleAr: 'توقفة للقلب',
      descriptionEn: 'In the midst of your day, stop and bring to mind one thing that has brought you even a small moment of joy or ease. Perhaps a kind word from someone, a sip of good coffee, or simply the fact that you are breathing. Let this small acknowledgment be a gift you give your heart.',
      descriptionAr: 'في نص يومك، وقف و افتكر حاجة واحدة جابتلك حتى لحظة صغيرة من فرح أو راحة. يمكن كلمة حلوة من حد، رشفة قهوة لذيذة، أو حتى إنك بتتنفس. خلّي الاعتراف الصغير ده يكون هدية تديها لقلبك.',
      category: 'afternoon',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'gratitude', ar: 'امتنان'),
        Tag(en: 'positive_thinking', ar: 'تفكير إيجابي'),
      ],
    ),
    DailyActivity(
      id: 'digital_detox_break',
      titleEn: 'An Invitation to Disconnect',
      titleAr: 'دعوة للانفصال',
      descriptionEn: 'For the next fifteen minutes, gently place your screens aside. This is an invitation to disconnect from the digital and reconnect with the real – the view from your window, the feel of a book in your hands, the simple act of doing nothing. Give your eyes and your mind a soft, restful pause.',
      descriptionAr: 'للخمسطعشر دقيقة الجايين، حط شاشاتك على جنب بلطف. دي دعوة إنك تنفصل عن الرقمي و تتواصل مع الحقيقي – المنظر من شباكك، ملمس كتاب في إيدك، فعل اللاشيء البسيط. ادي عينيك و عقلك توقفة ناعمة و مريحة.',
      category: 'afternoon',
      estimatedMinutes: 15,
      tags: [
        Tag(en: 'digital_detox', ar: 'صيام رقمي'),
        Tag(en: 'eye_rest', ar: 'راحة العين'),
      ],
    ),
    DailyActivity(
      id: 'hydrate_check',
      titleEn: 'Quenching the Inner Well',
      titleAr: 'ري العطش الداخلي',
      descriptionEn: 'Your body, like a garden, needs constant, gentle watering. Pour yourself a glass of water and drink it slowly, imagining it as life-giving nectar. Feel it hydrating not just your cells, but also your spirit. This simple act is a profound form of self-care.',
      descriptionAr: 'جسدك، زي الجنينة، محتاج سقاية مستمرة و لطيفة. احضر لنفسك كباية مية و اشربها بهدوء، و تخيلها رحيق بيدّي حياة. حسّ بيها و هي تروي مش بس خلاياك، لكن كمان روحك. الفعل البسيط ده هو شكل عميق من الرعاية الذاتية.',
      category: 'afternoon',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
        Tag(en: 'hydration', ar: 'ترطيب'),
      ],
    ),
    DailyActivity(
      id: 'mindful_snack',
      titleEn: 'A Moment of Nourishment',
      titleAr: 'لحظة تغذية',
      descriptionEn: 'Choose a small snack and eat it with full attention. Notice its color, texture, and aroma. As you bite into it, let the flavors unfold on your tongue. Chew slowly, savoring the experience. This is not just eating; it is a mindful communion with the nourishment the earth provides.',
      descriptionAr: 'اختار سناكس صغير و كله باهتمام كامل. لاحظ لونه و قوامه و ريحته. و انت بتقضم، خلّي الطعم يتكشف على لسانك. امضغ بهدوء، و استمتع بالتجربة. دي مش بس أكل، دي تواصل واعي مع الغذاء اللي الأرض بتقدمه.',
      category: 'afternoon',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'mindful_eating', ar: 'أكل واعي'),
        Tag(en: 'nutrition', ar: 'تغذية'),
      ],
    ),
    DailyActivity(
      id: 'nature_connection',
      titleEn: 'The Earth Beckons',
      titleAr: 'نداء الأرض',
      descriptionEn: 'Find a glimpse of nature – a plant on your desk, the sky outside your window, a patch of grass. Gaze at it softly, without labeling or thinking. Let its simple existence remind you of the larger, slower world beyond your tasks. You are a part of this natural world, always.',
      descriptionAr: 'دور على لمحة من الطبيعة – نبتة على مكتبك، السما بره شباكك، بقعة نجيل. بص لها بهدوء، من غير ما تفكر كتير. خلّي وجودها البسيط يذكّرك بالعالم الأكبر و الأبطأ بره مهامك. انت جزء من العالم الطبيعي ده، دايمًا.',
      category: 'afternoon',
      estimatedMinutes: 3,
      tags: [
        Tag(en: 'nature', ar: 'طبيعة'),
        Tag(en: 'mindfulness', ar: 'وعي'),
      ],
    ),
    DailyActivity(
      id: 'posture_check',
      titleEn: 'The Body\'s Alignment',
      titleAr: 'محاذاة الجسد',
      descriptionEn: 'Gently bring your awareness to how you are sitting or standing. Without judgment, see if you can soften and lengthen your spine, allowing your shoulders to relax away from your ears. Imagine a string gently pulling the crown of your head towards the sky. This is a small act of kindness for your body\'s structure.',
      descriptionAr: 'بلطف، وجّه انتباهك لطريقة جلوسك أو وقوفك. من غير أحكام، شوف تقدّر تلين و تطوّل ضهرك، و خلّي كتفك يرخوا و يبعدوا عن ودانك. تخيل خيط رفيع بيشدّ قمة راسك بلطف للسما. دي لفتة صغيرة من اللطف لهيكل جسدك.',
      category: 'afternoon',
      estimatedMinutes: 1,
      tags: [
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
        Tag(en: 'posture', ar: 'وضعية الجسم'),
      ],
    ),
    DailyActivity(
      id: 'kindness_act',
      titleEn: 'A Ripple of Kindness',
      titleAr: 'موجة لطف',
      descriptionEn: 'Look for a small, perhaps even invisible, opportunity to be kind. It could be a genuine smile to a stranger, a heartfelt thank you, or sending good thoughts to someone you know. Kindness, like a pebble dropped in water, creates ripples that extend far beyond the initial act, touching your own heart first.',
      descriptionAr: 'دور على فرصة صغيرة، يمكن حتى مش ظاهرة، إنك تبقى لطيف. ممكن تكون ابتسامة حقيقية لحد غريب، أو شكر من القلب، أو إنك تبعث أفكار حلوه لحد تعرفه. اللطف، زي ما تكون رميت حصاة في المية، بيعمل موجات بتتمدد بعيد عن الفعل الأول، و بتلمس قلبك الأول.',
      category: 'afternoon',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'kindness', ar: 'لطف'),
        Tag(en: 'compassion', ar: 'رحمة'),
      ],
    ),
    DailyActivity(
      id: 'music_break',
      titleEn: 'Melodies for the Soul',
      titleAr: 'ألحان للروح',
      descriptionEn: 'Choose a piece of calming music, perhaps without words, and let it be your companion for a few minutes. Close your eyes and let the melodies wash over you, carrying away the busyness of the mind. Let the notes resonate within you, a gentle soundtrack for your inner peace.',
      descriptionAr: 'اختار مقطوعة مزيكا هادية، يمكن من غير كلام، و خليها تكون رفيقتك لشوية. أغمض عينيك و خلّي الألحان تغمرك، و تودّي معاها صخب عقلك. خلّي النوتات ترن جواك، زيّ مزيكا تصويرية لسلامك الداخلي.',
      category: 'afternoon',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'music', ar: 'موسيقى'),
        Tag(en: 'relaxation', ar: 'استرخاء'),
      ],
    ),
    DailyActivity(
      id: 'tension_release',
      titleEn: 'Letting Go of Holding',
      titleAr: 'سيبة و ارتاح',
      descriptionEn: 'Notice if you are holding tension anywhere – perhaps in your jaw, your shoulders, or your hands. Take a deep breath, and as you exhale, consciously invite those areas to soften. Gently shake out your hands or roll your head. This is a practice in releasing, not just physically, but emotionally too.',
      descriptionAr: 'لاحظ لو شايل توتر في أي حتة – يمكن في فكّك، أو كتفيك، أو إيديك. خد نفس عميق، و و انت بتزفّر، ادع الأماكن دي بهدوء إنها تلين. حرّك إيديك بلطف أو لف راسك. دي ممارسة للتحرر، مش بس جسديًا، لكن عاطفيًا كمان.',
      category: 'afternoon',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'stress_relief', ar: 'تخفيف التوتر'),
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
      ],
    ),
    DailyActivity(
      id: 'mindful_hand_washing',
      titleEn: 'Water\'s Gentle Touch',
      titleAr: 'لمسة المية اللطيفة',
      descriptionEn: 'As you wash your hands, turn it into a moment of mindfulness. Feel the temperature of the water, the slippery sensation of the soap, the movement of your hands. Notice the sound of the water and the sight of the suds. This ordinary act, done with awareness, becomes a small oasis of calm.',
      descriptionAr: 'و انت بتغسل إيديك، حوّلها لحظة وعي. حسّ بدرجة حرارة المية، الإحساس الزلق بالصابون، حركة إيديك. اسمع صوت المية و شوف المنظر بتاع الرغوة. الفعل العادي ده، لو عملته بوعي، بيبقى واحة صغيرة من الهدوء.',
      category: 'afternoon',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'sensory_awareness', ar: 'إدراك حسي'),
      ],
    ),
    DailyActivity(
      id: 'positive_interaction',
      titleEn: 'A Meeting of Hearts',
      titleAr: 'لقاء قلوب',
      descriptionEn: 'In your next conversation, try to be fully present. Listen not just to the words, but to the feelings behind them. Offer a kind response or a simple acknowledgment. This is not about having a deep talk; it\'s about the quality of connection you bring to even the briefest exchange.',
      descriptionAr: 'في محادثتك الجاية، حاول تكون حاضر كلية. اسمع مش بس الكلمات، لكن كمان المشاعر وراها. قدّم رد لطيف أو اعتراف بسيط. ده مش عن محادثة عميقة، ده عن جودة الاتصال اللي بتقدمه حتى لأسرع كلام.',
      category: 'afternoon',
      estimatedMinutes: 10,
      tags: [
        Tag(en: 'social', ar: 'اجتماعي'),
        Tag(en: 'communication', ar: 'تواصل'),
      ],
    ),
    DailyActivity(
      id: 'task_prioritization',
      titleEn: 'Gentle Reordering',
      titleAr: 'إعادة ترتيب لطيفة',
      descriptionEn: 'Take a moment to gently look at what remains of your day. Without pressure, simply note your tasks and consider what truly matters. This is not about creating a rigid schedule, but about softly aligning your energy with what feels most important or nurturing to address next.',
      descriptionAr: 'خذ لحظة تنظر بهدوء للي متبقى من يومك. من غير ضغط، لاحظ مهامك و فكر في اللي مهم فعلاً. ده مش عن إنك تعمل جدول صارم، ده عن إنك تحاذي طاقتك بهدوء مع اللي تحس أنه أهم أو مغذّي عشان تبدأ بيه.',
      category: 'afternoon',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'productivity', ar: 'إنتاجية'),
        Tag(en: 'organization', ar: 'تنظيم'),
      ],
    ),
    DailyActivity(
      id: 'eye_relaxation',
      titleEn: 'A Balm for the Eyes',
      titleAr: 'بلسم للعين',
      descriptionEn: 'If you\'ve been looking at screens, give your eyes a gentle rest. Look away into the distance, towards something green or soft. Let your gaze be soft and unfocused. You can even gently cup your palms over your closed eyes for a moment, letting the darkness soothe them. Your eyes, like you, need moments of rest.',
      descriptionAr: 'لو بتحدق في شاشات فترة، ادّي عينيك راحة لطيفة. بصّ بعيد، لحتة فيها خضرة أو حاجة ناعمة. خلي نظرك ناعم و مش مركّز. حتى تقدّر تحط كفوف إيديك براحة على عينيك المغمضين لحظة، و خلّي الظلام يهديهم. عينيك، زيّك انت، محتاجين لحظات راحة.',
      category: 'afternoon',
      estimatedMinutes: 1,
      tags: [
        Tag(en: 'eye_health', ar: 'صحة العين'),
        Tag(en: 'digital_detox', ar: 'صيام رقمي'),
      ],
    ),
    DailyActivity(
      id: 'temperature_change',
      titleEn: 'A Splash of Refreshment',
      titleAr: 'رشة منعشة',
      descriptionEn: 'Splash some cool water on your face or step outside for a moment of fresh air. Feel the sudden change as a wake-up call to your senses, a gentle nudge back into your body. This simple act can clear the mental fog and refresh your spirit, if only for a moment.',
      descriptionAr: 'رش شوية مية باردة على وشك أو اطلع بره شوية عشان تاخد هوا نقي. حسّ بالتغيير الفجائي كنداء صحوة لحواسك، و دفعة لطيفة ترجّعك لجسدك. الفعل البسيط ده ممكن يزيل الضباب الذهني و ينعش روحك، حتى لو للحظة.',
      category: 'afternoon',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'energy_boost', ar: 'تنشيط'),
        Tag(en: 'sensory_awareness', ar: 'إدراك حسي'),
      ],
    ),

    // Evening Activities (17)
    DailyActivity(
      id: 'evening_gratitude',
      titleEn: 'Harvesting the Day',
      titleAr: 'حصاد اليوم',
      descriptionEn: 'As the day draws to a close, gently review it like a garden you have tended. What moments bloomed with beauty? What small joys can you harvest and hold in your heart? Write down or simply recall three things from today that you are grateful for, letting a sense of gentle contentment wash over you.',
      descriptionAr: 'مع إنتهاء اليوم، راجعه بلطف زي ما تراجع جنينة كنت بتعنى بيها. إيه اللحظات اللي أزهرت بجمال؟ إيه الأفراح الصغيرة اللي تقدّر تحصدها و تحتفظ بيه في قلبك؟ اكتب أو افتكر تلاتة حاجات من النهاردة انت شاكر إنها حصلت، و خلي شعور بالرضا يغمرك.',
      category: 'evening',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'gratitude', ar: 'امتنان'),
        Tag(en: 'journaling', ar: 'تدوين'),
        Tag(en: 'reflection', ar: 'تأمل'),
      ],
    ),
    DailyActivity(
      id: 'digital_sunset',
      titleEn: 'Time Away from Screens',
      titleAr: 'وقت بعيد عن الشاشات',
      descriptionEn: 'Before bed, give yourself some time away from phones, TV, and screens. Even 30 minutes helps. Read a book, talk to someone, or just sit quietly. Let your eyes and mind rest before sleep.',
      descriptionAr: 'قبل النوم، اهدي نفسك شوية وقت بعيد عن الموبايل و التلفزيون و الشاشات. حتى نص ساعة بتفرق. اقرا كتاب، كلم حد، أو بس اقعد في هدوء. خلّي عينيك و عقك يريحوا قبل النوم.',
      category: 'evening',
      estimatedMinutes: 1,
      tags: [
        Tag(en: 'digital_detox', ar: 'صيام رقمي'),
        Tag(en: 'sleep_hygiene', ar: 'نظافة النوم'),
      ],
    ),
    DailyActivity(
      id: 'gentle_yoga',
      titleEn: 'Easy Stretches',
      titleAr: 'تمدد خفيف',
      descriptionEn: 'Do a few gentle stretches to help your body relax. Reach your arms up, roll your shoulders, or gently twist side to side. Nothing hard, just easy movement to let go of the day.',
      descriptionAr: 'اعمل شوية تمددات خفيفة عشان جسمك يرتاح. مد دراعك لفوق، دحرج كتفك، أو لَف بلطف من جنب للتاني. مفيش حاجة صعبة، مجرد حركات سهلة عان تسيب اليوم.',
      category: 'evening',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'physical_health', ar: 'صحة جسدية'),
        Tag(en: 'relaxation', ar: 'استرخاء'),
      ],
    ),
    DailyActivity(
      id: 'breathing_for_sleep',
      titleEn: 'Breathe and Relax',
      titleAr: 'نفس و ارتاح',
      descriptionEn: 'Get comfortable in bed. Take a deep breath in, hold it for a moment, then breathe out slowly. Do this a few times. Let your breath be slow and easy, and feel yourself starting to relax.',
      descriptionAr: 'ارتاح في سريرك. خد نفس عميق، كتمه شوية، و بعدين زفّره بهدوء. كرر كده شوية. خلّي نفسك بطيء و هادي، و حسّ نفسك بدأت ترتاح.',
      category: 'evening',
      estimatedMinutes: 3,
      tags: [
        Tag(en: 'breathing', ar: 'تنفس'),
        Tag(en: 'sleep_hygiene', ar: 'نظافة النوم'),
      ],
    ),
    DailyActivity(
      id: 'mindful_tea_evening',
      titleEn: 'A Cup of Stillness',
      titleAr: 'كوباية سكون',
      descriptionEn: 'Prepare a cup of caffeine-free herbal tea – chamomile, lavender, or mint. Hold the warm cup in your hands and let its warmth seep into your palms. Sip slowly, feeling the liquid travel down your throat. Let this be a ritual of winding down, a cup of stillness before the silence of sleep.',
      descriptionAr: 'حضّر كوباية شاي أعشاب من غير كافيين – بابونج، لاڤندر، أو نعناع. أمسك الكوباية الدافية في إيدك و خلّي الدفا يتسرّب لراحة إيدك. اشرب بهدوء، و انت حاسس بالمشروب و هو بينزل في حلقك. خلّي ده طقس للتهدئة، كوباية سكون قبل صمت النوم.',
      category: 'evening',
      estimatedMinutes: 10,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'relaxation', ar: 'استرخاء'),
      ],
    ),
    DailyActivity(
      id: 'evening_journal',
      titleEn: 'Conversations with the Self',
      titleAr: 'كلام مع الذات',
      descriptionEn: 'Sit with your journal and reflect on the day just passed. Ask yourself, "What did I learn today?" or "How did I grow?" There\'s no need for profound answers. Simply let your thoughts flow onto the page. This is a quiet conversation with yourself, a way to honor your journey.',
      descriptionAr: 'اقعد مع مذكرتك و افتكر اليوم اللي فات. اسأل نفسك، "أنا اتعلمت إيه النهاردة؟" أو "أنا كبرت إزاي؟" مش محتاج إجابات عميقة. بس خلّي أفكارك تتدفق على الورقة. دي محادثة هادئة مع نفسك، طريقة تكرم بيها رحلتك.',
      category: 'evening',
      estimatedMinutes: 7,
      tags: [
        Tag(en: 'journaling', ar: 'تدوين'),
        Tag(en: 'reflection', ar: 'تأمل'),
      ],
    ),
    DailyActivity(
      id: 'body_scan_evening',
      titleEn: 'Rest Your Body',
      titleAr: 'ريح جسمك',
      descriptionEn: 'Lie down, get comfortable, and just let your body rest. Take a few deep breaths and allow yourself to fully relax into the bed.',
      descriptionAr: 'اتمدد، ارتاح، و بس سيِّب جسمك ينام. خد شوية نفس عميق و خلّي نفسك يرتاح تمامًا في السرير.',
      category: 'evening',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'body_awareness', ar: 'إدراك الجسد'),
        Tag(en: 'relaxation', ar: 'استرخاء'),
      ],
    ),
    DailyActivity(
      id: 'gratitude_meditation',
      titleEn: 'Heart-Centered Gratitude',
      titleAr: 'امتنان من القلب',
      descriptionEn: 'Sit or lie down and place a hand over your heart. Bring to mind the things you are grateful for, but this time, feel them in your heart space. Let the feeling of gratitude radiate from your chest, filling your entire being with warmth. This is not a mental exercise; it is a felt sense of appreciation that prepares you for peaceful rest.',
      descriptionAr: 'اقعد أو اتّمدد و حط إيدك على قلبك. افتكر الحاجات اللي انت شاكرها، لكن المرة دي، حسّ بيهم في مكان قلبك. خلّي شعور الامتنان يطلع من صدرك، و يملّي كيانك كله بدفا. ده مش تمرين عقلي، ده إحساس ملموس بالتقدير بيهيّئك لراحة سلمية.',
      category: 'evening',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'meditation', ar: 'تأمل'),
        Tag(en: 'gratitude', ar: 'امتنان'),
      ],
    ),
    DailyActivity(
      id: 'prep_tomorrow',
      titleEn: 'A Gentle Hello to Tomorrow',
      titleAr: 'تحية لطيفة لبكره',
      descriptionEn: 'As you prepare for sleep, gently set the stage for the morning. Lay out clothes, pack a bag, or simply decide on a small intention. This is not about rushing into the future, but about a soft gesture of care for your future self, so you may wake to a slightly easier morning.',
      descriptionAr: 'و انت بتجهّز للنوم، هيّأ المسرح بهدوء للصبح. جهّز هدومك، أو شنطتك، أو ببساطة حدد نية صغيرة. ده مش عن استعجال المستقبل، ده عن لفتة ناعمة من العناية لذاتك المستقبلية، عشان تصحى على صباح أسهل شوية.',
      category: 'evening',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'organization', ar: 'تنظيم'),
        Tag(en: 'productivity', ar: 'إنتاجية'),
      ],
    ),
    DailyActivity(
      id: 'positive_review',
      titleEn: 'Glimmers in the Day',
      titleAr: 'لمعات في اليوم',
      descriptionEn: 'Before sleep, recall one moment, however small, when you felt a sense of success or accomplishment. It might be finishing a task, offering a kind word, or simply getting through a difficult moment. Acknowledge this glimmer. You did something right today, and that is worth celebrating softly.',
      descriptionAr: 'قبل النوم، افتكر لحظة واحدة، حتى لو صغيرة، حسيت فيها بإنجاز أو نجاح. ممكن تكون خلّصت شغل، أو قلت كلمة حلوة لحد، أو حتى عديت لحظة صعبة. اعترف باللمعة دي. انت عملت حاجة صح النهاردة، و ده يستاهل تحتفل بيه بهدوء.',
      category: 'evening',
      estimatedMinutes: 3,
      tags: [
        Tag(en: 'positive_thinking', ar: 'تفكير إيجابي'),
        Tag(en: 'self_esteem', ar: 'تقدير الذات'),
      ],
    ),
    DailyActivity(
      id: 'reading_time',
      titleEn: 'A Sanctuary in Words',
      titleAr: 'ملاذ في الكلمات',
      descriptionEn: 'Pick up a book (a physical one, if possible) and read something gentle and calming. Let the words transport you to another world or simply soothe your mind. This quiet act of reading is a bridge between the activity of the day and the stillness of sleep.',
      descriptionAr: 'خد كتاب (ورقي لو تقدّر) و اقرا حاجة لطيفة و هادية. خلّي الكلمات تنقلك لعالم تاني أو بس تهدّي عقلك. فعل القراية الهادئ ده هو جسر بين نشاط النهار و سكون النوم.',
      category: 'evening',
      estimatedMinutes: 15,
      tags: [
        Tag(en: 'relaxation', ar: 'استرخاء'),
        Tag(en: 'learning', ar: 'تعلم'),
      ],
    ),
    DailyActivity(
      id: 'calming_music',
      titleEn: 'Night\'s Soft Melody',
      titleAr: 'لحن الليل الناعم',
      descriptionEn: 'As you prepare for bed, play some soft, instrumental music. Let it be a gentle background to your winding-down rituals. The melodies can help quiet the mind\'s chatter and create a peaceful atmosphere, inviting sleep to find you.',
      descriptionAr: 'و انت بتجهّز للنوم، شغّل موسيقى هادية. خليها تكون خلفية لطيفة لطقوس التهدئة بتاعتك. الألحان ممكن تساعد في إسكات كلام العقل و تخلق جو مسالم، يدعو النوم إنه يلاقيك.',
      category: 'evening',
      estimatedMinutes: 10,
      tags: [
        Tag(en: 'music', ar: 'موسيقى'),
        Tag(en: 'relaxation', ar: 'استرخاء'),
      ],
    ),
    DailyActivity(
      id: 'aromatherapy_evening',
      titleEn: 'Scents of Slumber',
      titleAr: 'روايح النوم',
      descriptionEn: 'Use calming essential oils like lavender or chamomile. You might add a few drops to a diffuser, or simply inhale gently from the bottle. Let the soothing aroma signal to your brain and body that it is time to rest, time to let go.',
      descriptionAr: 'استخدم زيوت عطرية مهدئة زي اللافندر أو البابونج. ممكن تحط شوية نقط في موزع الروايح، أو ببساطة استنشق بلطف من الزجاجة. خلّي الريحة المهدئة تشير لمخك و جسدك إنه وقت الراحة، وقت التخلي.',
      category: 'evening',
      estimatedMinutes: 3,
      tags: [
        Tag(en: 'aromatherapy', ar: 'علاج بالروائح'),
        Tag(en: 'relaxation', ar: 'استرخاء'),
      ],
    ),
    DailyActivity(
      id: 'temperature_adjustment',
      titleEn: 'Relaxing Environment',
      titleAr: 'بناء العش',
      descriptionEn: 'Take a moment to adjust your sleeping environment for optimal comfort. A slightly cooler room often promotes better sleep. Arrange your pillows just so, and make sure your blanket is just right. This is about creating a nest, a safe and comfortable space for your body to rest and restore.',
      descriptionAr: 'خذ لحظة تضبط فيها مكان نومك عشان ترتاح أكتر. الأوضة اللي فيها برد خفيف بتساعد على النوم الكويس. رتّب مخداتك كويس، و تأكد إن البطانية مضبوطة. ده عن إنك تبني عش، مكان آمن و مريح عشان جسدك يريح و يستعيد طاقته.',
      category: 'evening',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'sleep_hygiene', ar: 'نظافة النوم'),
        Tag(en: 'environment', ar: 'بيئة'),
      ],
    ),
    DailyActivity(
      id: 'mindful_brushing',
      titleEn: 'A Ritual of Nourishment',
      titleAr: 'طقس العناية المسائي',
      descriptionEn: 'As part of your evening routine, take a moment to care for your skin with gentle, mindful attention. Feel the texture of the products on your fingertips, the soothing sensation as you apply them to your face, the simple act of nourishing the body that has carried you through the day. This is not just skincare—it is a quiet conversation with yourself, a way of saying "I matter."',
      descriptionAr: 'كجزء من روتينك المسائي، خد لحظة تهتم فيها ببشرتك بانتباه لطيف و واعي. حسّ بملمس المنتجات على صوابيعك، الإحساس المهدئ و انت بتحطها على وشك، الفعل البسيط إنك تغذي الجسد اللي حملك النهاردة. دي مش بس عناية بالبشرة، دي محادثة هادئة مع نفسك، طريقة تقول فيها "أنا مهم".',
      category: 'evening',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'mindfulness', ar: 'وعي'),
        Tag(en: 'self_care', ar: 'عناية ذاتية'),
        Tag(en: 'evening_ritual', ar: 'طقوس مسائية'),
      ],
    ),
    DailyActivity(
      id: 'let_go_ritual',
      titleEn: 'Releasing to the Night',
      titleAr: 'الإطلاق لليل',
      descriptionEn: 'If you are carrying any worries or thoughts from the day, try this simple ritual. Write them down on a piece of paper. Then, as an act of release, you might tear it up, or simply say aloud, "I let this go for now. I can return to it tomorrow if needed." Trust that the night can hold these burdens for you.',
      descriptionAr: 'لو شايل أي هموم أو أفكار من اليوم، جرّب الطقس البسيط ده. اكتبهم على ورقة. بعدين، كفعل تحرر، تقدر تفرم الورقة، أو ببساطة تقول بصوت عالي، "أنا بسيب ده دلوقتي. أقدر أرجع له بكره لو محتاج." ثق إن الليل يقدر يحمل الأعباء دي عنك.',
      category: 'evening',
      estimatedMinutes: 5,
      tags: [
        Tag(en: 'stress_relief', ar: 'تخفيف التوتر'),
        Tag(en: 'emotional_release', ar: 'تحرير عاطفي'),
      ],
    ),
    DailyActivity(
      id: 'bedtime_affirmation',
      titleEn: 'A Lullaby for the Self',
      titleAr: 'تهويدة للذات',
      descriptionEn: 'As you drift towards sleep, whisper a kind affirmation to yourself. "I did my best today, and that is enough." "I am safe, I am at peace, I am loved." Let these words be a gentle lullaby for your soul, carrying you softly into the world of dreams, wrapped in self-compassion.',
      descriptionAr: 'و انت بتغفى للنوم، أهمس بكلمة حلوة لنفسك. "أنا عملت اللي عليا النهاردة، و ده كفاية." "أنا بأمان، أنا في سلام، أنا محبوب." خلّي الكلمات دي تكون تهويدة لطيفة لروحك، تحملك برفق لعالم الأحلام، ملفوف بالرحمة الذاتية.',
      category: 'evening',
      estimatedMinutes: 2,
      tags: [
        Tag(en: 'positive_thinking', ar: 'تفكير إيجابي'),
        Tag(en: 'self_compassion', ar: 'رحمة بالذات'),
      ],
    ),
  ];
}