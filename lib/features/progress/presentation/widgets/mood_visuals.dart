import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MoodVisual {
  final String key;
  final String assetPath;
  final String labelEn;
  final String labelAr;

  const MoodVisual({
    required this.key,
    required this.assetPath,
    required this.labelEn,
    required this.labelAr,
  });
}

const Map<String, MoodVisual> moodVisuals = {
  'angry': MoodVisual(
    key: 'angry',
    assetPath: 'assets/moods/mood_angry.svg',
    labelEn: 'Angry',
    labelAr: 'غاضب',
  ),
  'disgust': MoodVisual(
    key: 'disgust',
    assetPath: 'assets/moods/mood_disgust.svg',
    labelEn: 'Disgusted',
    labelAr: 'مشمئز',
  ),
  'fear': MoodVisual(
    key: 'fear',
    assetPath: 'assets/moods/mood_fear.svg',
    labelEn: 'Afraid',
    labelAr: 'خائف',
  ),
  'happy': MoodVisual(
    key: 'happy',
    assetPath: 'assets/moods/mood_happy.svg',
    labelEn: 'Happy',
    labelAr: 'سعيد',
  ),
  'sad': MoodVisual(
    key: 'sad',
    assetPath: 'assets/moods/mood_sad.svg',
    labelEn: 'Sad',
    labelAr: 'حزين',
  ),
  'surprise': MoodVisual(
    key: 'surprise',
    assetPath: 'assets/moods/mood_surprise.svg',
    labelEn: 'Surprised',
    labelAr: 'متفاجئ',
  ),
  'neutral': MoodVisual(
    key: 'neutral',
    assetPath: 'assets/moods/mood_neutral.svg',
    labelEn: 'Neutral',
    labelAr: 'محايد',
  ),
};

Widget buildMoodSvg(
  String moodKey, {
  double size = 24,
}) {
  final mood = moodVisuals[moodKey];
  if (mood == null) return const SizedBox.shrink();

  return SvgPicture.asset(
    mood.assetPath,
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}
