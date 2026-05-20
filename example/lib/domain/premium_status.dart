import 'package:zerosettle/zerosettle.dart';

/// A user is "premium" while they hold any active [Entitlement].
///
/// Consumables (streak savers) never produce an `Entitlement` — the backend
/// creates no entitlement state for them — so every entitlement in the list
/// is a subscription or non-consumable purchase. Any active one means premium.
bool isPremium(List<Entitlement> entitlements) {
  return entitlements.any((e) => e.isActive);
}
