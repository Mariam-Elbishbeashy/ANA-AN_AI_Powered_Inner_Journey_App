class UserAnswer {
  final String id;
  final String userId;
  final int questionNumber;
  final String? answerText;
  final List<int>? selectedIndices; // For multiple select questions
  final double? sliderValue; // For slider questions
  final String language; // Language used when answering
  final DateTime answeredAt;

  UserAnswer({
    required this.id,
    required this.userId,
    required this.questionNumber,
    this.answerText,
    this.selectedIndices,
    this.sliderValue,
    required this.language,
    required this.answeredAt,
  });

  factory UserAnswer.fromMap(Map<String, dynamic> data, String id) {
    return UserAnswer(
      id: id,
      userId: data['userId'],
      questionNumber: data['questionNumber'],
      answerText: data['answerText'],
      selectedIndices: data['selectedIndices'] != null
          ? List<int>.from(data['selectedIndices'])
          : null,
      sliderValue: data['sliderValue']?.toDouble(),
      language: data['language'] ?? 'en',
      answeredAt: DateTime.parse(data['answeredAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'questionNumber': questionNumber,
      'answerText': answerText,
      'selectedIndices': selectedIndices,
      'sliderValue': sliderValue,
      'language': language,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }
}
