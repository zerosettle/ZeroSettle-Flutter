/// Cancel flow configuration returned by the backend.
class CancelFlowConfig {
  final bool enabled;
  final List<CancelFlowQuestion> questions;
  final CancelFlowOffer? offer;

  CancelFlowConfig({
    required this.enabled,
    required this.questions,
    this.offer,
  });

  factory CancelFlowConfig.fromMap(Map<String, dynamic> map) {
    return CancelFlowConfig(
      enabled: map['enabled'] as bool,
      questions: (map['questions'] as List?)
              ?.map((e) => CancelFlowQuestion.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      offer: map['offer'] != null
          ? CancelFlowOffer.fromMap(Map<String, dynamic>.from(map['offer'] as Map))
          : null,
    );
  }
}

/// A single question in the cancel flow questionnaire.
class CancelFlowQuestion {
  final int id;
  final int order;
  final String questionText;
  final String questionType;
  final bool isRequired;
  final List<CancelFlowOption> options;

  CancelFlowQuestion({
    required this.id,
    required this.order,
    required this.questionText,
    required this.questionType,
    required this.isRequired,
    required this.options,
  });

  factory CancelFlowQuestion.fromMap(Map<String, dynamic> map) {
    return CancelFlowQuestion(
      id: map['id'] as int,
      order: map['order'] as int,
      questionText: map['questionText'] as String,
      questionType: map['questionType'] as String,
      isRequired: map['isRequired'] as bool,
      options: (map['options'] as List?)
              ?.map((e) => CancelFlowOption.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }
}

/// An answer option for a single-select question.
class CancelFlowOption {
  final int id;
  final int order;
  final String label;
  final bool triggersOffer;

  CancelFlowOption({
    required this.id,
    required this.order,
    required this.label,
    required this.triggersOffer,
  });

  factory CancelFlowOption.fromMap(Map<String, dynamic> map) {
    return CancelFlowOption(
      id: map['id'] as int,
      order: map['order'] as int,
      label: map['label'] as String,
      triggersOffer: map['triggersOffer'] as bool,
    );
  }
}

/// Save offer configuration shown to retain the user.
class CancelFlowOffer {
  final bool enabled;
  final String title;
  final String body;
  final String ctaText;
  final String type;
  final String value;

  CancelFlowOffer({
    required this.enabled,
    required this.title,
    required this.body,
    required this.ctaText,
    required this.type,
    required this.value,
  });

  factory CancelFlowOffer.fromMap(Map<String, dynamic> map) {
    return CancelFlowOffer(
      enabled: map['enabled'] as bool,
      title: map['title'] as String,
      body: map['body'] as String,
      ctaText: map['ctaText'] as String,
      type: map['type'] as String,
      value: map['value'] as String,
    );
  }
}

/// The outcome of a cancel flow presentation.
enum CancelFlowResult {
  cancelled('cancelled'),
  retained('retained'),
  dismissed('dismissed');

  const CancelFlowResult(this.rawValue);
  final String rawValue;

  static CancelFlowResult fromRawValue(String value) {
    return CancelFlowResult.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => CancelFlowResult.cancelled,
    );
  }
}
