// ─────────────────────────────────────────────────────────────────────────────
// Short Stay enumerations.
//
// Every value is stored in Firestore as the exact string in `wire`. Never store
// an index: reordering an enum would silently rewrite history.
// ─────────────────────────────────────────────────────────────────────────────

enum BookingStatus {
  pending('pending'),
  confirmed('confirmed'),
  declined('declined'),
  cancelledGuest('cancelled_guest'),
  cancelledHost('cancelled_host'),
  inProgress('in_progress'),
  completed('completed'),
  disputed('disputed');

  final String wire;
  const BookingStatus(this.wire);

  static BookingStatus from(String? v) => BookingStatus.values.firstWhere(
        (e) => e.wire == v,
        orElse: () => BookingStatus.pending,
      );

  bool get isCancelled =>
      this == BookingStatus.cancelledGuest || this == BookingStatus.cancelledHost;

  /// A guest may cancel while the stay has not started.
  bool get guestCanCancel =>
      this == BookingStatus.pending || this == BookingStatus.confirmed;
}

enum ListingStatus {
  draft('draft'),
  live('live'),
  paused('paused'),
  suspended('suspended');

  final String wire;
  const ListingStatus(this.wire);

  static ListingStatus from(String? v) => ListingStatus.values
      .firstWhere((e) => e.wire == v, orElse: () => ListingStatus.draft);
}

enum CaptureKind {
  hostPreArrival('host_pre_arrival'),
  guestCheckIn('guest_check_in'),
  guestCheckOut('guest_check_out');

  final String wire;
  const CaptureKind(this.wire);

  static CaptureKind from(String? v) => CaptureKind.values
      .firstWhere((e) => e.wire == v, orElse: () => CaptureKind.guestCheckIn);

  String get label => switch (this) {
        CaptureKind.hostPreArrival => 'Host, before you arrived',
        CaptureKind.guestCheckIn => 'You, on arrival',
        CaptureKind.guestCheckOut => 'You, on departure',
      };
}

enum ClaimStatus {
  submitted('submitted'),
  awaitingGuest('awaiting_guest'),
  contested('contested'),
  underReview('under_review'),
  decided('decided'),
  appealed('appealed'),
  closed('closed');

  final String wire;
  const ClaimStatus(this.wire);

  static ClaimStatus from(String? v) => ClaimStatus.values
      .firstWhere((e) => e.wire == v, orElse: () => ClaimStatus.submitted);
}

enum CancellationPolicy {
  flexible('flexible'),
  moderate('moderate'),
  strict('strict');

  final String wire;
  const CancellationPolicy(this.wire);

  static CancellationPolicy from(String? v) => CancellationPolicy.values
      .firstWhere((e) => e.wire == v, orElse: () => CancellationPolicy.moderate);

  // Deliberately no percentages here. The tiers are an undecided figure and
  // live in platform_config/short_stay, read server side. A refund amount is
  // NEVER computed on the client. See quoteStayCancellation.
  String get label => switch (this) {
        CancellationPolicy.flexible => 'Flexible',
        CancellationPolicy.moderate => 'Moderate',
        CancellationPolicy.strict => 'Strict',
      };
}

enum BookingMode {
  instant('instant'),
  request('request');

  final String wire;
  const BookingMode(this.wire);

  static BookingMode from(String? v) => BookingMode.values
      .firstWhere((e) => e.wire == v, orElse: () => BookingMode.request);
}
