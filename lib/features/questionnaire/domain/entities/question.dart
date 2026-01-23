class Question {
  final String id;
  final int questionNumber;
  final String text;
  final List<String> options;
  final bool isSlider;
  final double? minValue;
  final double? maxValue;
  final List<String>? sliderLabels;
  final bool multipleSelect;
  final String language; // 'en' or 'ar'

  Question({
    required this.id,
    required this.questionNumber,
    required this.text,
    required this.options,
    this.isSlider = false,
    this.minValue,
    this.maxValue,
    this.sliderLabels,
    this.multipleSelect = false,
    required this.language,
  });

  factory Question.fromMap(Map<String, dynamic> data, String id) {
    // Handle options which might be null for slider questions
    List<String> optionsList = [];
    if (data['options'] != null) {
      final optionsData = data['options'];
      if (optionsData is List) {
        optionsList = optionsData.map((item) => item.toString()).toList();
      }
    }

    // Handle sliderLabels
    List<String>? sliderLabelsList;
    if (data['sliderLabels'] != null && data['sliderLabels'] is List) {
      sliderLabelsList = List<String>.from(data['sliderLabels']);
    }

    return Question(
      id: id,
      questionNumber: (data['questionNumber'] ?? 0).toInt(),
      text: data['text'] ?? '',
      options: optionsList,
      isSlider: data['isSlider'] ?? false,
      minValue: data['minValue']?.toDouble(),
      maxValue: data['maxValue']?.toDouble(),
      sliderLabels: sliderLabelsList,
      multipleSelect: data['multipleSelect'] ?? false,
      language: data['language'] ?? 'en',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionNumber': questionNumber,
      'text': text,
      'options': options,
      'isSlider': isSlider,
      'minValue': minValue,
      'maxValue': maxValue,
      'sliderLabels': sliderLabels,
      'multipleSelect': multipleSelect,
      'language': language,
    };
  }
}