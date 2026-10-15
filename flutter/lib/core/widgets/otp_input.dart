import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/digit_utils.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/utils/input_formatters.dart';
import 'package:yalla_5roga/core/utils/validators.dart';

class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    required this.label,
    this.length = Validators.otpLength,
    this.validator,
    this.onCompleted,
    this.action,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final String label;
  final int length;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onCompleted;
  final Widget? action;
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_rebuild);
    widget.controller.addListener(_rebuild);
    if (widget.autofocus) {
      // Autofocus on TextFormField often loses to the previous field when
      // this widget is inserted after send-OTP; claim focus after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;
    final code = widget.controller.text;
    final arabicDisplay = l10n.locale.languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: Responsive.fontSm,
                  fontWeight: FontWeight.w800,
                  color: palette.textSecondary,
                ),
              ),
            ),
            ?widget.action,
          ],
        ),
        Responsive.spaceSm.gapH,
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) Responsive.spaceSm.gapW,
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 56.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.inputFill,
                          borderRadius: BorderRadius.circular(
                            Responsive.radiusMd,
                          ),
                          border: Border.all(
                            color: _focusNode.hasFocus && code.length == i
                                ? AppColors.brand500
                                : code.length > i
                                ? palette.brandSoftBorder
                                : palette.border,
                            width: _focusNode.hasFocus && code.length == i
                                ? 1.6
                                : 1,
                          ),
                        ),
                        child: Text(
                          i < code.length ? l10n.digits(code[i]) : '',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    validator: widget.validator,
                    inputFormatters: [
                      InputFormatters.localizedDigits(
                        arabicDisplay: arabicDisplay,
                        maxLength: widget.length,
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {});
                      final western = DigitUtils.westernDigitsOnly(value);
                      if (western.length == widget.length) {
                        widget.onCompleted?.call(western);
                      }
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
