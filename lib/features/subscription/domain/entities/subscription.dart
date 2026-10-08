enum SubscriptionStatus { active, cancelled }

/// How the subscription was obtained.
enum SubscriptionSource { payment, admin, coupon }

/// One of the student's subscriptions — `GET /subscriptions/me`.
class Subscription {
  const Subscription({
    required this.id,
    required this.planId,
    required this.planName,
    required this.programId,
    required this.status,
    required this.source,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final String planId;
  final String planName;
  final String programId;
  final SubscriptionStatus status;
  final SubscriptionSource source;
  final DateTime startsAt;
  final DateTime endsAt;
}
