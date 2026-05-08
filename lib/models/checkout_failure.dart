/// Reason a web checkout failed. Mirrors `CheckoutFailure` from
/// ZeroSettleKit, which is a Swift enum with associated values:
///
/// - `networkUnreachable(Error)` — DNS / certificate / "no connection".
/// - `loadFailed(Error)` — load started but errored mid-flight.
/// - `serverError(statusCode: Int, url: URL)` — HTTP 4xx/5xx.
/// - `unknown(Error)` — anything else.
///
/// The enum case is flattened to [kind] (one of `"networkUnreachable"`,
/// `"loadFailed"`, `"serverError"`, `"unknown"`); the human-readable
/// message is always populated. [statusCode] and [url] are only set when
/// [kind] is `"serverError"`.
class CheckoutFailure {
  /// Raw enum case name from the iOS Kit.
  final String kind;

  /// Human-readable description of the failure.
  final String message;

  /// HTTP status code — only populated when [kind] is `"serverError"`.
  final int? statusCode;

  /// Server URL that returned the error — only populated when [kind] is
  /// `"serverError"`.
  final String? url;

  const CheckoutFailure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.url,
  });

  factory CheckoutFailure.fromMap(Map<String, dynamic> map) {
    return CheckoutFailure(
      kind: map['kind'] as String,
      message: map['message'] as String,
      statusCode: map['statusCode'] as int?,
      url: map['url'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'message': message,
        if (statusCode != null) 'statusCode': statusCode,
        if (url != null) 'url': url,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutFailure &&
          kind == other.kind &&
          message == other.message &&
          statusCode == other.statusCode &&
          url == other.url;

  @override
  int get hashCode => Object.hash(kind, message, statusCode, url);

  @override
  String toString() => 'CheckoutFailure(kind: $kind, message: $message)';
}
