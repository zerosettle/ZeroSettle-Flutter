import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Embeds the plugin's cross-platform [MigrationTipView] — a SwiftUI view on
/// iOS and a Compose view on Android — once a user has been identified.
///
/// [MigrationTipView] requires a non-null `userId`, so this card subscribes
/// to [ZeroSettle.currentUserIdUpdates] and renders nothing until the SDK
/// reports an identified user. The native view is self-sizing and
/// self-collapsing: it reports a height of 0 when no migration offer is
/// available, so an absent offer leaves no visible gap.
///
/// Use this instead of [ZeroSettleOfferTip] when you want the tip to appear
/// on both platforms — `ZeroSettleOfferTip` is Android-only.
class MigrationTipCard extends StatelessWidget {
  const MigrationTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: ZeroSettle.instance.currentUserIdUpdates,
      builder: (context, snapshot) {
        final userId = snapshot.data;
        if (userId == null || userId.isEmpty) {
          return const SizedBox.shrink();
        }
        return MigrationTipView(
          userId: userId,
          // The native view uses this as the card fill AND the CTA text
          // color — pass a saturated brand color, not a neutral surface.
          backgroundColor: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}
