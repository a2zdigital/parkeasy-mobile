import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A one-time code, shown as one box per digit.
///
/// It is a single text field underneath, so typing, deleting, pasting and
/// SMS autofill all behave as the platform does them; the boxes only draw
/// what the field holds.
class OtpField extends StatefulWidget {
  const OtpField({
    required this.label,
    required this.length,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.onCompleted,
    super.key,
  });

  final String label;
  final int length;
  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final bool autofocus;

  /// Called once each time the last digit is entered.
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(OtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final value = widget.controller.text;
    final error = widget.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: text.label.copyWith(color: colors.textSecondary),
          ),
        ),
        const Gap.xs(),
        Stack(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const Gap.sm(),
                    Expanded(
                      child: _DigitBox(
                        digit: i < value.length ? value[i] : null,
                        isActive:
                            _focus.hasFocus &&
                            i == value.length.clamp(0, widget.length - 1),
                        hasError: error != null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned.fill(
              child: Semantics(
                label: widget.label,
                textField: true,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  // The boxes show the digits; the field itself is invisible.
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: text.body.copyWith(color: Colors.transparent),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (code) {
                    if (code.length == widget.length) {
                      widget.onCompleted?.call(code);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const Gap.xs(),
        Semantics(
          liveRegion: error != null,
          child: Text(
            error ?? '',
            style: text.bodySmall.copyWith(color: colors.danger.solid),
          ),
        ),
      ],
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
  });

  final String? digit;
  final bool isActive;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color outline;
    if (hasError) {
      outline = colors.danger.solid;
    } else {
      outline = isActive ? colors.primary : colors.borderControl;
    }

    return AnimatedContainer(
      duration: AppMotion.fast,
      height: AppSize.inputHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.controlAll,
        border: Border.all(
          color: outline,
          width: isActive || hasError
              ? AppSize.focusBorderWidth
              : AppSize.borderWidth,
        ),
      ),
      child: Text(digit ?? '', style: context.text.price),
    );
  }
}
