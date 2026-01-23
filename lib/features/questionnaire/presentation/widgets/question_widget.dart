import 'package:flutter/material.dart';
import 'package:ana_ifs_app/features/questionnaire/domain/entities/question.dart';
import 'package:ana_ifs_app/features/questionnaire/domain/entities/user_answer.dart';

class QuestionAnswer {
  final int questionNumber;
  final String? answerText;
  final List<int>? selectedIndices;
  final double? sliderValue;

  QuestionAnswer({
    required this.questionNumber,
    this.answerText,
    this.selectedIndices,
    this.sliderValue,
  });
}

class QuestionWidget extends StatefulWidget {
  final Question question;
  final Function(QuestionAnswer) onAnswer;
  final QuestionAnswer? initialAnswer;

  const QuestionWidget({
    super.key,
    required this.question,
    required this.onAnswer,
    this.initialAnswer,
  });

  @override
  State<QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  List<int> _selectedIndices = [];
  double? _sliderValue;
  final TextEditingController _textController = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromAnswer();
    });
  }

  void _initializeFromAnswer() {
    if (widget.initialAnswer != null) {
      if (widget.question.multipleSelect &&
          widget.initialAnswer!.selectedIndices != null) {
        _selectedIndices = List.from(widget.initialAnswer!.selectedIndices!);
      } else if (widget.question.isSlider &&
          widget.initialAnswer!.sliderValue != null) {
        _sliderValue = widget.initialAnswer!.sliderValue;
      } else if (widget.initialAnswer!.answerText != null) {
        _textController.text = widget.initialAnswer!.answerText!;
      }

      // Mark as initialized
      _initialized = true;

      // Notify parent after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _notifyParent();
        }
      });
    } else {
      _initialized = true;
    }
  }

  void _notifyParent() {
    if (!mounted) return;

    final answer = QuestionAnswer(
      questionNumber: widget.question.questionNumber,
      answerText: _textController.text.isNotEmpty ? _textController.text : null,
      selectedIndices: _selectedIndices.isNotEmpty ? _selectedIndices : null,
      sliderValue: _sliderValue,
    );
    widget.onAnswer(answer);
  }

  void _toggleOption(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        if (widget.question.multipleSelect) {
          _selectedIndices.add(index);
        } else {
          _selectedIndices = [index];
        }
      }
      _notifyParent();
    });
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderValue = value;
      _notifyParent();
    });
  }

  String _getSliderLabel() {
    if (widget.question.sliderLabels != null && _sliderValue != null) {
      final index =
          ((_sliderValue! - (widget.question.minValue ?? 0)) /
                  ((widget.question.maxValue ?? 100) -
                      (widget.question.minValue ?? 0)) *
                  (widget.question.sliderLabels!.length - 1))
              .round()
              .clamp(0, widget.question.sliderLabels!.length - 1);
      return widget.question.sliderLabels![index];
    }
    return _sliderValue?.toStringAsFixed(0) ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question text
        Text(
          widget.question.text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A1E3B),
            height: 1.4,
          ),
        ),

        const SizedBox(height: 24),

        // Question type
        if (widget.question.isSlider) ...[
          // Slider question
          Column(
            children: [
              // Slider labels
              if (widget.question.sliderLabels != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: widget.question.sliderLabels!.asMap().entries.map(
                      (entry) {
                        final isFirst = entry.key == 0;
                        final isLast =
                            entry.key ==
                            widget.question.sliderLabels!.length - 1;

                        return Expanded(
                          child: Align(
                            alignment: isFirst
                                ? Alignment.centerLeft
                                : isLast
                                ? Alignment.centerRight
                                : Alignment.center,
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF7A6A5A),
                                fontWeight: isFirst || isLast
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF8E7CFF),
                  inactiveTrackColor: const Color(0xFFE5DEFF),
                  thumbColor: const Color(0xFF8E7CFF),
                  overlayColor: const Color(0xFF8E7CFF).withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 14,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 24,
                  ),
                  trackHeight: 8,
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                  valueIndicatorTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Slider(
                  value: _sliderValue ?? (widget.question.minValue ?? 0),
                  min: widget.question.minValue ?? 0,
                  max: widget.question.maxValue ?? 100,
                  divisions: 100,
                  label: _getSliderLabel(),
                  onChanged: _onSliderChanged,
                  onChangeEnd: _onSliderChanged,
                ),
              ),
            ],
          ),
        ] else ...[
          // Multiple choice question
          Column(
            children: widget.question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;

              final isSelected = _selectedIndices.contains(index);

              return GestureDetector(
                onTap: () => _toggleOption(index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8E7CFF).withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8E7CFF)
                          : const Color(0xFFE5DEFF),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8E7CFF).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      // Selection indicator
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8E7CFF)
                                : const Color(0xFFD0C6E8),
                            width: 2,
                          ),
                          color: isSelected
                              ? const Color(0xFF8E7CFF)
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),

                      const SizedBox(width: 16),

                      // Option text
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color(0xFF2A1E3B),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Instruction for multiple select
          if (widget.question.multipleSelect)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'You can select multiple options',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF9C90B3),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],

        const SizedBox(height: 32),

        // Character association (optional display)
        if (false) // Set to true if you want to show character associations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECF7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0C6E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      size: 18,
                      color: Color(0xFF6A5CFF),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Associated Inner Parts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6A5CFF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your answers help identify different parts of your inner world.',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF7A6A5A),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
