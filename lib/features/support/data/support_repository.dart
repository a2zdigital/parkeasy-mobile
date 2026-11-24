import 'package:app/core/api/api_client.dart';
import 'package:app/core/providers.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:app/features/support/data/models/support_ticket.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(ref.watch(apiClientProvider)),
);

/// The signed-in user's own support tickets.
class SupportRepository {
  const SupportRepository(this._api);

  final ApiClient _api;

  /// The categories a ticket can have, as the server configures them.
  Future<List<CodeName>> categories() async =>
      _list(await _api.get('/support/categories'), CodeName.fromJson);

  /// Own tickets, most recently active first.
  Future<List<SupportTicket>> tickets() async => _list(
    await _api.get('/support/tickets', query: {'per_page': 50}),
    SupportTicket.fromJson,
  );

  Future<SupportTicket> ticket(String id) async => SupportTicket.fromJson(
    ApiClient.object(await _api.get('/support/tickets/$id')),
  );

  Future<SupportTicket> open({
    required String category,
    required String subject,
    required String description,
  }) async => SupportTicket.fromJson(
    ApiClient.object(
      await _api.post(
        '/support/tickets',
        body: {
          'category': category,
          'subject': subject,
          'description': description,
        },
      ),
    ),
  );

  /// Refused with SUPPORT_TICKET_CLOSED on a closed ticket.
  Future<SupportTicket> reply(String id, String body) async =>
      SupportTicket.fromJson(
        ApiClient.object(
          await _api.post(
            '/support/tickets/$id/messages',
            body: {'body': body},
          ),
        ),
      );

  static List<T> _list<T>(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = envelope['data'];
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map) fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
