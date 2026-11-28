import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/widgets/api_error_text.dart';
import 'package:app/core/widgets/app_banner.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/core/widgets/app_card.dart';
import 'package:app/core/widgets/app_scaffold.dart';
import 'package:app/core/widgets/app_text_field.dart';
import 'package:app/core/widgets/state_views.dart';
import 'package:app/features/support/data/support_repository.dart';
import 'package:app/features/support/state/support_providers.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Opening a support ticket: what it is about, a short subject and the
/// details. The categories come from the server.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  String? _subjectError;
  String? _descriptionError;
  String? _categoryError;
  ApiException? _failure;
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = context.l10n;
    final subject = _subject.text.trim();
    final description = _description.text.trim();

    setState(() {
      _categoryError = _category == null ? l10n.supportCategoryRequired : null;
      _subjectError = subject.length < 5 ? l10n.supportSubjectTooShort : null;
      _descriptionError = description.length < 10
          ? l10n.supportDescriptionTooShort
          : null;
      _failure = null;
    });
    if (_categoryError != null ||
        _subjectError != null ||
        _descriptionError != null) {
      return;
    }

    setState(() => _sending = true);
    try {
      final ticket = await ref
          .read(supportRepositoryProvider)
          .open(
            category: _category!,
            subject: subject,
            description: description,
          );
      ref.invalidate(supportTicketsProvider);
      if (!mounted) return;
      final base = GoRouterState.of(context).matchedLocation;
      context.pushReplacement(
        '${base.substring(0, base.lastIndexOf('/'))}/${ticket.id}',
      );
    } on ApiException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = ref.watch(supportCategoriesProvider);
    final failure = _failure;

    return AppScaffold(
      title: l10n.supportNewTicket,
      bottom: PrimaryButton(
        label: l10n.supportSend,
        isLoading: _sending,
        onPressed: categories.hasValue ? _send : null,
      ),
      body: categories.when(
        loading: () => const Column(children: [Gap.lg(), SkeletonCard()]),
        error: (error, _) => ErrorState(
          failure: error is ApiException
              ? error
              : const ApiException(code: ApiErrorCode.unknown),
          onRetry: () => ref.invalidate(supportCategoriesProvider),
        ),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap.md(),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.supportCategory,
                errorText: _categoryError,
              ),
              items: [
                for (final category in list)
                  DropdownMenuItem(
                    value: category.code,
                    child: Text(category.name),
                  ),
              ],
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _category = value),
            ),
            const Gap.md(),
            AppTextField(
              label: l10n.supportSubject,
              controller: _subject,
              enabled: !_sending,
              errorText: _subjectError,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
            ),
            const Gap.md(),
            TextField(
              controller: _description,
              enabled: !_sending,
              minLines: 4,
              maxLines: 8,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.supportDescription,
                hintText: l10n.supportDescriptionHint,
                errorText: _descriptionError,
                alignLabelWithHint: true,
              ),
            ),
            if (failure != null) ...[
              const Gap.sm(),
              AppBanner(
                tone: StatusTone.danger,
                message: l10n.describe(failure),
              ),
            ],
            const Gap.xl(),
          ],
        ),
      ),
    );
  }
}
