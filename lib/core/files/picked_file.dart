import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the user chose, read into memory. Uploads are small (the API
/// accepts up to 5 MB), so the bytes are held whole.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  int get sizeBytes => bytes.length;
}

/// The largest file the API accepts for a document or photo.
const maxUploadBytes = 5 * 1024 * 1024;

/// Why a chosen file could not be used. The picker never lets a platform
/// error escape: each becomes one of these, for the screen to explain.
enum PickProblem {
  /// Over [maxUploadBytes]. Found before the file is read into memory.
  tooLarge,

  /// Not one of the accepted types, such as an iPhone HEIC photo.
  wrongType,

  /// The picker could not open, or the file could not be read.
  unreadable,
}

class PickException implements Exception {
  const PickException(this.problem);

  final PickProblem problem;
}

/// Opens the system file or photo picker. Behind an interface so tests can
/// supply a file without a platform picker.
abstract interface class FilePickerService {
  /// Null when the user cancels. [images] opens the photo gallery instead
  /// of the document picker. Throws [PickException].
  Future<PickedFile?> pick({
    required List<String> extensions,
    bool images = false,
  });
}

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => const PlatformFilePickerService(),
);

class PlatformFilePickerService implements FilePickerService {
  const PlatformFilePickerService();

  @override
  Future<PickedFile?> pick({
    required List<String> extensions,
    bool images = false,
  }) async {
    final PlatformFile? file;
    try {
      // Photos come from the gallery (no storage permission needed on
      // Android, the system photo picker on iOS); documents from the
      // document picker.
      file = images
          ? await FilePicker.pickFile(type: FileType.image)
          : await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: extensions,
            );
    } on PlatformException catch (error) {
      debugPrint('File picker failed: ${error.code}');
      throw const PickException(PickProblem.unreadable);
    }
    if (file == null) return null;

    // The gallery may name a file without an extension; the API checks the
    // content's real type either way.
    final extension = file.extension?.toLowerCase();
    if (extension != null &&
        extension.isNotEmpty &&
        !extensions.contains(extension)) {
      throw const PickException(PickProblem.wrongType);
    }

    try {
      // Before reading: a large camera photo is never loaded into memory.
      final length = await file.length();
      if (length != null && length > maxUploadBytes) {
        throw const PickException(PickProblem.tooLarge);
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > maxUploadBytes) {
        throw const PickException(PickProblem.tooLarge);
      }
      return PickedFile(
        name: nameWithExtension(file.name, bytes),
        bytes: bytes,
      );
    } on PickException {
      rethrow;
    } on Exception catch (error) {
      debugPrint('Could not read the chosen file: ${error.runtimeType}');
      throw const PickException(PickProblem.unreadable);
    }
  }
}

/// Gallery files can arrive as "1000012345" with no extension. The API
/// decides the type from the content, but a name with one reads better.
@visibleForTesting
String nameWithExtension(String name, Uint8List bytes) {
  if (name.contains('.')) return name;
  final String? extension;
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
    extension = 'jpg';
  } else if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) {
    extension = 'png';
  } else if (bytes.length > 12 &&
      _startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    extension = 'webp';
  } else if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46])) {
    extension = 'pdf';
  } else {
    extension = null;
  }
  return extension == null ? name : '$name.$extension';
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}
