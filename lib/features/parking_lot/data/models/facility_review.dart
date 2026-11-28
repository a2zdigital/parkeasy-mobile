/// One visible review of a facility, as `GET /parking-lots/{id}/ratings`
/// returns it. Anonymous: no customer is named.
class FacilityReview {
  const FacilityReview({
    required this.id,
    required this.score,
    required this.createdAt,
    this.comment,
  });

  factory FacilityReview.fromJson(Map<String, dynamic> json) => FacilityReview(
    id: json['id'] as String,
    score: (json['score'] as num).toInt(),
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
  );

  final String id;

  /// 1 to 5.
  final int score;
  final String? comment;
  final DateTime createdAt;
}
