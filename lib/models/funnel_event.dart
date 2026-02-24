/// Funnel analytics event types for paywall and checkout tracking.
enum FunnelEventType {
  paywallViewed('paywall_viewed'),
  checkoutStarted('checkout_started'),
  checkoutAbandoned('checkout_abandoned');

  const FunnelEventType(this.value);
  final String value;
}
