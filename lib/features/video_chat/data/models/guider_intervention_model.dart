/// Model for Guider intervention data during character chats.
/// When the Guider detects the user may need support, an intervention is triggered.
class GuiderInterventionModel {
  final bool shouldIntervene;
  final String? reason;
  final String? severity;
  final String? guiderMessage;

  const GuiderInterventionModel({
    required this.shouldIntervene,
    this.reason,
    this.severity,
    this.guiderMessage,
  });

  /// Create from JSON map (API response).
  factory GuiderInterventionModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const GuiderInterventionModel(shouldIntervene: false);
    }
    return GuiderInterventionModel(
      shouldIntervene: data['shouldIntervene'] == true,
      reason: data['reason']?.toString(),
      severity: data['severity']?.toString(),
      guiderMessage: data['guiderMessage']?.toString(),
    );
  }

  /// No intervention instance.
  static const none = GuiderInterventionModel(shouldIntervene: false);

  /// Check if this is a high severity intervention (crisis).
  bool get isCrisis => severity == 'high';

  /// Check if this is a medium severity intervention.
  bool get isMedium => severity == 'medium';

  /// Check if this is a low severity intervention.
  bool get isLow => severity == 'low';
}
