import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerosettle/zerosettle.dart';

/// Embeds the plugin's cross-platform [OfferTipView] — the unified
/// `ZSOfferManager`-backed offer tip (SwiftUI `OfferTipView` on iOS, Compose
/// `ZeroSettleOfferTip` on Android) — once a user has been identified.
///
/// The offer tip is identify-first: it resolves the active user from
/// `identify(_:)`. This card renders nothing until an identified user is
/// known, so the native view only mounts when it can actually resolve an
/// offer. The native view is self-sizing and self-collapsing: it reports a
/// height of 0 when no offer is available, so an absent offer leaves no gap.
///
/// The current identity is **seeded** from [ZeroSettle.getCurrentUserId] and
/// then kept current via [ZeroSettle.currentUserIdUpdates]. The seed is
/// essential: `identify()` runs in `main()` before this widget ever mounts,
/// and `currentUserIdUpdates` is a change-only broadcast stream (its native
/// replay-on-listen only reaches the *first* subscriber). A bare
/// `StreamBuilder` would therefore miss the launch-time identification and
/// the tip would never appear.
class OfferTipCard extends StatefulWidget {
  const OfferTipCard({super.key});

  @override
  State<OfferTipCard> createState() => _OfferTipCardState();
}

class _OfferTipCardState extends State<OfferTipCard> {
  String? _userId;
  StreamSubscription<String?>? _sub;

  @override
  void initState() {
    super.initState();
    // Seed with the identity the SDK already knows — see the class doc.
    ZeroSettle.instance.getCurrentUserId().then((id) {
      // Don't clobber a value the change stream already delivered.
      if (mounted && _userId == null) setState(() => _userId = id);
    }).catchError((_) {
      // Leave _userId null — the card stays collapsed, which is correct
      // when the current identity can't be resolved.
    });
    // Track subsequent identity changes (identify / logout / user switch).
    _sub = ZeroSettle.instance.currentUserIdUpdates.listen((id) {
      if (mounted) setState(() => _userId = id);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }
    return OfferTipView(
      // The native view uses this as the card fill AND the CTA text
      // color — pass a saturated brand color, not a neutral surface.
      backgroundColor: Theme.of(context).colorScheme.primary,
    );
  }
}
