import 'package:app/core/api/json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

/// A message in the user's activity list. `payload` carries the identifiers needed to open the right screen.
@freezed
abstract class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    required String id,
    required String type,
    required String title,
    required String body,
    @JsonObjectConverter()
    @Default(<String, dynamic>{})
    Map<String, dynamic> payload,
    @Default(false) bool isRead,
    @UtcDateTimeConverter() DateTime? readAt,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  /// The booking this notification is about, when it is about one.
  String? get bookingId {
    final value = payload['booking_id'];
    return value is String ? value : null;
  }
}
