import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reads one QR code with the camera.
abstract class QrScanner {
  /// The text of the first QR code seen, or null when the user backed out
  /// or the camera could not be used.
  Future<String?> scan(BuildContext context);
}

final qrScannerProvider = Provider<QrScanner>((ref) => const CameraQrScanner());

class CameraQrScanner implements QrScanner {
  const CameraQrScanner();

  @override
  Future<String?> scan(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<String>(builder: (_) => const QrScanScreen()));
}

/// The camera, full screen, looking for a QR code. Asks for camera
/// permission the first time; says so when it is refused.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .firstOrNull;
    if (value == null) return;
    _done = true;
    Navigator.of(context).pop(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScanError(
              message:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? l10n.scanCameraDenied
                  : l10n.scanUnavailable,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Text(
                l10n.scanHint,
                textAlign: TextAlign.center,
                style: context.text.body.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.surface,
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center, style: context.text.body),
          const Gap.lg(),
          SecondaryButton(
            label: context.l10n.scanTypeInstead,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}
