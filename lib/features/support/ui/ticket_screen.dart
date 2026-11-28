import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/core/widgets/status_chip.dart';
import 'package:app/features/support/state/support_providers.dart';
import 'package:app/features/support/ui/help_screen.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// One support ticket: the conversation and a reply box.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    final sent = await ref
        .read(supportTicketProvider(widget.id).notifier)
        .reply(body);
    if (sent) _reply.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final provider = supportTicketProvider(widget.id);
    final details = ref.watch(provider);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return details.when(
      loading: () => AppScaffold(
        title: l10n.supportTitle,
        body: const Column(children: [Gap.lg(), SkeletonCard()]),
      ),
      error: (error, _) => AppScaffold(
        title: l10n.supportTitle,
        body: Center(
          child: ErrorState(
            failure: error is ApiException
                ? error
                : const ApiException(code: ApiErrorCode.unknown),
            onRetry: () => ref.invalidate(provider),
          ),
        ),
      ),
      data: (state) {
        final ticket = state.ticket;
        final (tone, label) = supportStatus(l10n, ticket.status);
        final failure = state.failure;

        return AppScaffold(
          title: ticket.reference,
          scrollable: false,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap.md(),
              Row(
                children: [
                  Expanded(child: Text(ticket.subject, style: text.h3)),
                  StatusChip(tone: tone, label: label),
                ],
              ),
              const Gap.xs(),
              Text(
                ticket.categoryLabel,
                style: text.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const Gap.md(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(provider),
                  child: ListView.separated(
                    itemCount: ticket.messages.length,
                    separatorBuilder: (_, _) => const Gap.sm(),
                    itemBuilder: (context, index) {
                      final message = ticket.messages[index];
                      return Align(
                        alignment: message.fromStaff
                            ? AlignmentDirectional.centerStart
                            : AlignmentDirectional.centerEnd,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: message.fromStaff
                                  ? colors.surfaceSubtle
                                  : colors.primaryContainer,
                              borderRadius: AppRadius.cardAll,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpace.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.fromStaff
                                        ? l10n.supportFromSupport
                                        : l10n.supportFromYou,
                                    style: text.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const Gap.xs(),
                                  Text(message.body, style: text.body),
                                  const Gap.xs(),
                                  Text(
                                    DateFormat.yMMMd(locale).add_jm().format(
                                      message.createdAt.toLocal(),
                                    ),
                                    style: text.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (failure != null)
                AppBanner(
                  tone: StatusTone.danger,
                  message: l10n.describe(failure),
                ),
              if (state.canReply)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          enabled: !state.isSending,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 5000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: l10n.supportReply,
                            counterText: '',
                          ),
                        ),
                      ),
                      const Gap.sm(),
                      IconButton.filled(
                        tooltip: l10n.supportSend,
                        icon: state.isSending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        onPressed: state.isSending ? null : _send,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Text(
                    l10n.supportClosedNote,
                    style: text.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
