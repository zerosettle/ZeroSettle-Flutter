/// Cancel flow configuration returned by the backend.
class CancelFlowConfig {
  final bool enabled;
  final List<CancelFlowQuestion> questions;
  final CancelFlowOffer? offer;
  final CancelFlowPauseConfig? pause;

  CancelFlowConfig({
    required this.enabled,
    required this.questions,
    this.offer,
    this.pause,
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
      pause: map['pause'] != null
          ? CancelFlowPauseConfig.fromMap(Map<String, dynamic>.from(map['pause'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'questions': questions.map((e) => e.toMap()).toList(),
      if (offer != null) 'offer': offer!.toMap(),
      if (pause != null) 'pause': pause!.toMap(),
    };
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'questionText': questionText,
      'questionType': questionType,
      'isRequired': isRequired,
      'options': options.map((e) => e.toMap()).toList(),
    };
  }
}

/// An answer option for a single-select question.
class CancelFlowOption {
  final int id;
  final int order;
  final String label;
  final bool triggersOffer;
  final bool triggersPause;

  CancelFlowOption({
    required this.id,
    required this.order,
    required this.label,
    required this.triggersOffer,
    required this.triggersPause,
  });

  factory CancelFlowOption.fromMap(Map<String, dynamic> map) {
    return CancelFlowOption(
      id: map['id'] as int,
      order: map['order'] as int,
      label: map['label'] as String,
      triggersOffer: map['triggersOffer'] as bool,
      triggersPause: map['triggersPause'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'label': label,
      'triggersOffer': triggersOffer,
      'triggersPause': triggersPause,
    };
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

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'title': title,
      'body': body,
      'ctaText': ctaText,
      'type': type,
      'value': value,
    };
  }
}

/// Pause configuration within the cancel flow.
class CancelFlowPauseConfig {
  final bool enabled;
  final String title;
  final String body;
  final String ctaText;
  final List<CancelFlowPauseOption> options;

  CancelFlowPauseConfig({
    required this.enabled,
    required this.title,
    required this.body,
    required this.ctaText,
    required this.options,
  });

  factory CancelFlowPauseConfig.fromMap(Map<String, dynamic> map) {
    return CancelFlowPauseConfig(
      enabled: map['enabled'] as bool,
      title: map['title'] as String,
      body: map['body'] as String,
      ctaText: map['ctaText'] as String,
      options: (map['options'] as List?)
              ?.map((e) => CancelFlowPauseOption.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'title': title,
      'body': body,
      'ctaText': ctaText,
      'options': options.map((e) => e.toMap()).toList(),
    };
  }
}

/// A single pause duration option in the cancel flow.
class CancelFlowPauseOption {
  final int id;
  final int order;
  final String label;
  final String durationType;
  final int? durationDays;
  final DateTime? resumeDate;

  CancelFlowPauseOption({
    required this.id,
    required this.order,
    required this.label,
    required this.durationType,
    this.durationDays,
    this.resumeDate,
  });

  factory CancelFlowPauseOption.fromMap(Map<String, dynamic> map) {
    return CancelFlowPauseOption(
      id: map['id'] as int,
      order: map['order'] as int,
      label: map['label'] as String,
      durationType: map['durationType'] as String,
      durationDays: map['durationDays'] as int?,
      resumeDate: map['resumeDate'] != null
          ? DateTime.parse(map['resumeDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'label': label,
      'durationType': durationType,
      if (durationDays != null) 'durationDays': durationDays,
      if (resumeDate != null) 'resumeDate': resumeDate!.toIso8601String(),
    };
  }
}

/// The outcome of a cancel flow presentation.
sealed class CancelFlowResult {
  const CancelFlowResult();

  /// Parse a raw result string from the native method channel.
  ///
  /// The native bridge sends "paused:<ISO8601>" for pause results.
  /// All other values are plain strings: "cancelled", "retained", "dismissed".
  static CancelFlowResult fromRawValue(String value) {
    if (value.startsWith('paused:')) {
      final iso = value.substring('paused:'.length);
      final resumesAt = DateTime.tryParse(iso);
      return CancelFlowPaused(resumesAt: resumesAt);
    }
    switch (value) {
      case 'retained':
        return const CancelFlowRetained();
      case 'dismissed':
        return const CancelFlowDismissed();
      case 'paused':
        return const CancelFlowPaused();
      case 'cancelled':
      default:
        return const CancelFlowCancelled();
    }
  }
}

/// The user completed the flow and chose to cancel.
class CancelFlowCancelled extends CancelFlowResult {
  const CancelFlowCancelled();
}

/// The user accepted the save offer and was retained.
class CancelFlowRetained extends CancelFlowResult {
  const CancelFlowRetained();
}

/// The user dismissed the sheet without completing the flow.
class CancelFlowDismissed extends CancelFlowResult {
  const CancelFlowDismissed();
}

/// The user chose to pause their subscription.
class CancelFlowPaused extends CancelFlowResult {
  /// When the subscription will automatically resume. `null` if not specified.
  final DateTime? resumesAt;

  const CancelFlowPaused({this.resumesAt});
}

/// Payload submitted to the backend after a cancel flow completes.
class CancelFlowResponsePayload {
  final String userId;
  final String productId;
  final String outcome;
  final bool offerShown;
  final bool offerAccepted;
  final bool pauseShown;
  final bool pauseAccepted;
  final int? pauseDurationDays;
  final int lastStepSeen;
  final List<CancelFlowAnswerPayload> answers;

  CancelFlowResponsePayload({
    required this.userId,
    required this.productId,
    required this.outcome,
    required this.offerShown,
    required this.offerAccepted,
    this.pauseShown = false,
    this.pauseAccepted = false,
    this.pauseDurationDays,
    required this.lastStepSeen,
    required this.answers,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'productId': productId,
      'outcome': outcome,
      'offerShown': offerShown,
      'offerAccepted': offerAccepted,
      'pauseShown': pauseShown,
      'pauseAccepted': pauseAccepted,
      if (pauseDurationDays != null) 'pauseDurationDays': pauseDurationDays,
      'lastStepSeen': lastStepSeen,
      'answers': answers.map((e) => e.toMap()).toList(),
    };
  }
}

/// A single answer within a cancel flow response.
class CancelFlowAnswerPayload {
  final int questionId;
  final int? selectedOptionId;
  final String? freeText;

  CancelFlowAnswerPayload({
    required this.questionId,
    this.selectedOptionId,
    this.freeText,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
      if (freeText != null) 'freeText': freeText,
    };
  }
}

/// Result of accepting a save offer.
class CancelFlowSaveOfferResult {
  final String message;
  final int discountPercent;
  final int durationMonths;

  CancelFlowSaveOfferResult({
    required this.message,
    required this.discountPercent,
    required this.durationMonths,
  });

  factory CancelFlowSaveOfferResult.fromMap(Map<String, dynamic> map) {
    return CancelFlowSaveOfferResult(
      message: map['message'] as String,
      discountPercent: map['discountPercent'] as int,
      durationMonths: map['durationMonths'] as int,
    );
  }
}

/// The outcome of a cancel flow for analytics/reporting.
enum CancelFlowOutcome {
  cancelled('cancelled'),
  retained('retained'),
  paused('paused'),
  dismissed('dismissed');

  const CancelFlowOutcome(this.rawValue);
  final String rawValue;

  static CancelFlowOutcome fromRawValue(String value) {
    return CancelFlowOutcome.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => CancelFlowOutcome.cancelled,
    );
  }
}

/// A single answer in the cancel flow questionnaire.
class CancelFlowAnswer {
  final int questionId;
  final int selectedOptionId;
  final String? freeText;

  CancelFlowAnswer({
    required this.questionId,
    required this.selectedOptionId,
    this.freeText,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'questionId': questionId,
      'selectedOptionId': selectedOptionId,
    };
    if (freeText != null) {
      map['freeText'] = freeText;
    }
    return map;
  }
}

/// The complete response submitted at the end of a cancel flow.
class CancelFlowResponse {
  final String productId;
  final String userId;
  final CancelFlowOutcome outcome;
  final List<CancelFlowAnswer> answers;
  final bool offerShown;
  final bool offerAccepted;
  final bool pauseShown;
  final bool pauseAccepted;
  final int? pauseDurationDays;

  CancelFlowResponse({
    required this.productId,
    required this.userId,
    required this.outcome,
    required this.answers,
    required this.offerShown,
    required this.offerAccepted,
    required this.pauseShown,
    required this.pauseAccepted,
    this.pauseDurationDays,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'productId': productId,
      'userId': userId,
      'outcome': outcome.rawValue,
      'answers': answers.map((a) => a.toMap()).toList(),
      'offerShown': offerShown,
      'offerAccepted': offerAccepted,
      'pauseShown': pauseShown,
      'pauseAccepted': pauseAccepted,
    };
    if (pauseDurationDays != null) {
      map['pauseDurationDays'] = pauseDurationDays;
    }
    return map;
  }
}
