import 'package:app/core/api/api_error_code.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/files/picked_file.dart';
import 'package:app/features/owner/data/models/owner_document.dart';
import 'package:app/features/owner/data/models/owner_parking_lot.dart';
import 'package:app/features/owner/data/owner_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ownerFacilityChoicesProvider =
    FutureProvider.autoDispose<List<OwnerParkingLot>>((ref) async {
      final repository = ref.watch(ownerRepositoryProvider);
      final facilities = <OwnerParkingLot>[];
      String? cursor;

      while (true) {
        final page = await repository.facilities(cursor: cursor);
        facilities.addAll(page.items);
        if (!page.hasMore) return facilities;
        cursor = page.nextCursor;
        if (cursor == null) {
          throw StateError('A facility page with more results needs a cursor.');
        }
      }
    });

final ownerDocumentsProvider =
    AsyncNotifierProvider.autoDispose<
      OwnerDocumentsNotifier,
      OwnerDocumentsState
    >(OwnerDocumentsNotifier.new);

class OwnerDocumentsState {
  const OwnerDocumentsState({
    required this.documents,
    this.isBusy = false,
    this.failure,
    this.problem,
  });

  final List<OwnerDocument> documents;
  final bool isBusy;
  final ApiException? failure;

  /// Why the chosen file was not sent; the API never saw it.
  final PickProblem? problem;
}

/// The documents sent with the owner application. Each change re-reads the
/// list, so the links are always fresh.
class OwnerDocumentsNotifier
    extends AutoDisposeAsyncNotifier<OwnerDocumentsState> {
  @override
  Future<OwnerDocumentsState> build() async => OwnerDocumentsState(
    documents: await ref.watch(ownerRepositoryProvider).documents(),
  );

  Future<void> upload(
    OwnerDocumentType type,
    PickedFile file, {
    String? expiresOn,
    String? parkingLotId,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;

    if (file.sizeBytes > maxUploadBytes) {
      state = AsyncData(
        OwnerDocumentsState(
          documents: current.documents,
          problem: PickProblem.tooLarge,
        ),
      );
      return;
    }

    await _run(current, () async {
      await ref
          .read(ownerRepositoryProvider)
          .uploadDocument(
            type,
            file,
            expiresOn: expiresOn,
            parkingLotId: parkingLotId,
          );
    });
  }

  /// The picker could not give a usable file; nothing was sent.
  void pickFailed(PickProblem problem) {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncData(
      OwnerDocumentsState(documents: current.documents, problem: problem),
    );
  }

  Future<void> remove(OwnerDocument document) async {
    final current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    await _run(current, () async {
      await ref.read(ownerRepositoryProvider).deleteDocument(document.id);
    });
  }

  Future<void> _run(
    OwnerDocumentsState current,
    Future<void> Function() change,
  ) async {
    state = AsyncData(
      OwnerDocumentsState(documents: current.documents, isBusy: true),
    );
    try {
      await change();
      final documents = await ref.read(ownerRepositoryProvider).documents();
      state = AsyncData(OwnerDocumentsState(documents: documents));
    } on ApiException catch (failure) {
      state = AsyncData(
        OwnerDocumentsState(documents: current.documents, failure: failure),
      );
    } on Object {
      state = AsyncData(
        OwnerDocumentsState(
          documents: current.documents,
          failure: const ApiException(code: ApiErrorCode.unknown),
        ),
      );
    }
  }
}
