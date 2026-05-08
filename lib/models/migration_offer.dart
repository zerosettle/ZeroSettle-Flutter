import 'remote_config.dart' show MigrationPrompt;

/// Lifecycle state of the migration offer flow. Mirrors
/// `MigrationOffer.State` from ZeroSettleKit.
enum MigrationOfferState {
  loading('loading'),
  ineligible('ineligible'),
  eligible('eligible'),
  presented('presented'),
  accepted('accepted'),
  completed('completed'),
  dismissed('dismissed');

  const MigrationOfferState(this.rawValue);
  final String rawValue;

  static MigrationOfferState fromRawValue(String value) {
    return MigrationOfferState.values.firstWhere(
      (e) => e.rawValue == value,
      orElse: () => MigrationOfferState.loading,
    );
  }
}

/// Server-driven data for an eligible migration offer. Mirrors
/// `MigrationOffer.OfferData` from ZeroSettleKit.
class MigrationOfferData {
  final MigrationPrompt prompt;
  final int freeTrialDays;
  final String activeStoreKitProductId;
  final DateTime? storekitSubscriptionEnd;
  final String? activeStoreKitOriginalTransactionId;

  const MigrationOfferData({
    required this.prompt,
    required this.freeTrialDays,
    required this.activeStoreKitProductId,
    this.storekitSubscriptionEnd,
    this.activeStoreKitOriginalTransactionId,
  });

  factory MigrationOfferData.fromMap(Map<String, dynamic> map) {
    return MigrationOfferData(
      prompt: MigrationPrompt.fromMap(
        Map<String, dynamic>.from(map['prompt'] as Map),
      ),
      freeTrialDays: map['freeTrialDays'] as int,
      activeStoreKitProductId: map['activeStoreKitProductId'] as String,
      storekitSubscriptionEnd: map['storekitSubscriptionEnd'] != null
          ? DateTime.parse(map['storekitSubscriptionEnd'] as String)
          : null,
      activeStoreKitOriginalTransactionId:
          map['activeStoreKitOriginalTransactionId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'prompt': prompt.toMap(),
        'freeTrialDays': freeTrialDays,
        'activeStoreKitProductId': activeStoreKitProductId,
        if (storekitSubscriptionEnd != null)
          'storekitSubscriptionEnd': storekitSubscriptionEnd!.toIso8601String(),
        if (activeStoreKitOriginalTransactionId != null)
          'activeStoreKitOriginalTransactionId':
              activeStoreKitOriginalTransactionId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MigrationOfferData &&
          prompt == other.prompt &&
          freeTrialDays == other.freeTrialDays &&
          activeStoreKitProductId == other.activeStoreKitProductId &&
          storekitSubscriptionEnd == other.storekitSubscriptionEnd &&
          activeStoreKitOriginalTransactionId ==
              other.activeStoreKitOriginalTransactionId;

  @override
  int get hashCode => Object.hash(
        prompt,
        freeTrialDays,
        activeStoreKitProductId,
        storekitSubscriptionEnd,
        activeStoreKitOriginalTransactionId,
      );
}

/// Coherent snapshot of `ZSMigrationManager`'s 5 published properties.
/// Emitted on every state-property change via the manager's stream.
class MigrationManagerState {
  final MigrationOfferState state;
  final MigrationOfferData? offerData;
  final String? checkoutErrorMessage;
  final bool isLoading;
  final bool storekitCancelRequired;

  const MigrationManagerState({
    required this.state,
    this.offerData,
    this.checkoutErrorMessage,
    required this.isLoading,
    required this.storekitCancelRequired,
  });

  factory MigrationManagerState.fromMap(Map<String, dynamic> map) {
    return MigrationManagerState(
      state: MigrationOfferState.fromRawValue(map['state'] as String),
      offerData: map['offerData'] != null
          ? MigrationOfferData.fromMap(
              Map<String, dynamic>.from(map['offerData'] as Map),
            )
          : null,
      checkoutErrorMessage: map['checkoutErrorMessage'] as String?,
      isLoading: map['isLoading'] as bool,
      storekitCancelRequired: map['storekitCancelRequired'] as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'state': state.rawValue,
        if (offerData != null) 'offerData': offerData!.toMap(),
        if (checkoutErrorMessage != null)
          'checkoutErrorMessage': checkoutErrorMessage,
        'isLoading': isLoading,
        'storekitCancelRequired': storekitCancelRequired,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MigrationManagerState &&
          state == other.state &&
          offerData == other.offerData &&
          checkoutErrorMessage == other.checkoutErrorMessage &&
          isLoading == other.isLoading &&
          storekitCancelRequired == other.storekitCancelRequired;

  @override
  int get hashCode => Object.hash(
        state,
        offerData,
        checkoutErrorMessage,
        isLoading,
        storekitCancelRequired,
      );
}
