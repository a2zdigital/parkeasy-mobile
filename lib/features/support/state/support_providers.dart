import 'package:app/core/api/api_exception.dart';
import 'package:app/features/parking_lot/data/models/code_name.dart';
import 'package:app/features/support/data/models/support_ticket.dart';
import 'package:app/features/support/data/support_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(supportRepositoryProvider).tickets(),
);

final supportCategoriesProvider = FutureProvider.autoDispose<List<CodeName>>(
  (ref) => ref.watch(supportRepositoryProvider).categories(),
);

final supportTicketProvider = AsyncNotifierProvider.autoDispose
    .family<SupportTicketNotifier, SupportTicketState, String>(
      SupportTicketNotifier.new,
    );

class SupportTicketState {
  const SupportTicketState({
    required this.ticket,
    this.isSending = false,
    this.failure,
  });

  final SupportTicket ticket;
  final bool isSending;
  final ApiException? failure;

  bool get canReply => ticket.status != SupportTicketStatus.closed;
}

/// One ticket and its conversation.
class SupportTicketNotifier
    extends AutoDisposeFamilyAsyncNotifier<SupportTicketState, String> {
  @override
  Future<SupportTicketState> build(String arg) async => SupportTicketState(
    ticket: await ref.watch(supportRepositoryProvider).ticket(arg),
  );

  /// True when the message was sent.
  Future<bool> reply(String body) async {
    final current = state.valueOrNull;
    if (current == null || current.isSending) return false;

    state = AsyncData(
      SupportTicketState(ticket: current.ticket, isSending: true),
    );
    try {
      final ticket = await ref.read(supportRepositoryProvider).reply(arg, body);
      ref.invalidate(supportTicketsProvider);
      state = AsyncData(SupportTicketState(ticket: ticket));
      return true;
    } on ApiException catch (failure) {
      state = AsyncData(
        SupportTicketState(ticket: current.ticket, failure: failure),
      );
      return false;
    }
  }
}
