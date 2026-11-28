import 'package:app/core/api/json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_ticket.freezed.dart';
part 'support_ticket.g.dart';

/// Where a ticket stands. [unknown] stands for a value added to the API
/// after this app was built.
@JsonEnum(valueField: 'wire')
enum SupportTicketStatus {
  open('open'),
  inProgress('in_progress'),
  resolved('resolved'),
  closed('closed'),
  unknown('unknown');

  const SupportTicketStatus(this.wire);

  final String wire;
}

/// One message in a ticket. Staff are never named to the customer.
@freezed
abstract class SupportMessage with _$SupportMessage {
  const factory SupportMessage({
    required String id,
    @Default(false) bool fromStaff,
    required String body,
    @UtcDateTimeConverter() required DateTime createdAt,
  }) = _SupportMessage;

  factory SupportMessage.fromJson(Map<String, dynamic> json) =>
      _$SupportMessageFromJson(json);
}

/// A request for help, with its conversation on the detail screen.
@freezed
abstract class SupportTicket with _$SupportTicket {
  const factory SupportTicket({
    required String id,
    required String reference,
    required String subject,
    required String category,
    required String categoryLabel,
    @JsonKey(unknownEnumValue: SupportTicketStatus.unknown)
    required SupportTicketStatus status,
    String? bookingId,
    @UtcDateTimeConverter() required DateTime lastMessageAt,
    @UtcDateTimeConverter() required DateTime createdAt,
    @Default(<SupportMessage>[]) List<SupportMessage> messages,
  }) = _SupportTicket;

  factory SupportTicket.fromJson(Map<String, dynamic> json) =>
      _$SupportTicketFromJson(json);
}
