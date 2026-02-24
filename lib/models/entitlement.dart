import 'enums.dart';

/// Represents an active entitlement from either a StoreKit or web checkout purchase.
class Entitlement {
  final String id;
  final String productId;
  final EntitlementSource source;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime purchasedAt;
  final String? status;
  final DateTime? pausedAt;
  final DateTime? pauseResumesAt;
  final bool willRenew;
  final bool isTrial;
  final DateTime? trialEndsAt;
  final DateTime? cancelledAt;

  const Entitlement({
    required this.id,
    required this.productId,
    required this.source,
    required this.isActive,
    this.expiresAt,
    required this.purchasedAt,
    this.status,
    this.pausedAt,
    this.pauseResumesAt,
    this.willRenew = true,
    this.isTrial = false,
    this.trialEndsAt,
    this.cancelledAt,
  });

  /// Whether this entitlement is currently paused.
  bool get isPaused => status == 'paused';

  factory Entitlement.fromMap(Map<String, dynamic> map) {
    return Entitlement(
      id: map['id'] as String,
      productId: map['productId'] as String,
      source: EntitlementSource.fromRawValue(map['source'] as String),
      isActive: map['isActive'] as bool,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      purchasedAt: DateTime.parse(map['purchasedAt'] as String),
      status: map['status'] as String?,
      pausedAt: map['pausedAt'] != null
          ? DateTime.parse(map['pausedAt'] as String)
          : null,
      pauseResumesAt: map['pauseResumesAt'] != null
          ? DateTime.parse(map['pauseResumesAt'] as String)
          : null,
      willRenew: map['willRenew'] as bool? ?? true,
      isTrial: map['isTrial'] as bool? ?? false,
      trialEndsAt: map['trialEndsAt'] != null
          ? DateTime.parse(map['trialEndsAt'] as String)
          : null,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.parse(map['cancelledAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'source': source.rawValue,
      'isActive': isActive,
      'expiresAt': expiresAt?.toIso8601String(),
      'purchasedAt': purchasedAt.toIso8601String(),
      if (status != null) 'status': status,
      if (pausedAt != null) 'pausedAt': pausedAt!.toIso8601String(),
      if (pauseResumesAt != null) 'pauseResumesAt': pauseResumesAt!.toIso8601String(),
      'willRenew': willRenew,
      'isTrial': isTrial,
      if (trialEndsAt != null) 'trialEndsAt': trialEndsAt!.toIso8601String(),
      if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entitlement &&
          id == other.id &&
          productId == other.productId &&
          source == other.source &&
          isActive == other.isActive &&
          expiresAt == other.expiresAt &&
          purchasedAt == other.purchasedAt &&
          status == other.status &&
          pausedAt == other.pausedAt &&
          pauseResumesAt == other.pauseResumesAt &&
          willRenew == other.willRenew &&
          isTrial == other.isTrial &&
          trialEndsAt == other.trialEndsAt &&
          cancelledAt == other.cancelledAt;

  @override
  int get hashCode =>
      Object.hash(id, productId, source, isActive, expiresAt, purchasedAt, status, pausedAt, pauseResumesAt, willRenew, isTrial, trialEndsAt, cancelledAt);

  @override
  String toString() =>
      'Entitlement(id: $id, productId: $productId, source: ${source.rawValue}, isActive: $isActive, status: $status)';
}
