import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/l10n/strings.dart';

/// Multi-line message input without a hard character limit. Shows a live
/// counter with the encoding and the number of SMS parts the text needs.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    this.enabled = true,
    this.minLines = 2,
    this.maxLines = 6,
  });

  final TextEditingController controller;
  final bool enabled;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: s.messageText,
            hintText: s.messageHint,
            prefixIcon: const Icon(Icons.message_outlined),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4, top: 6),
          child: Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) =>
                  SmsCounterLabel(info: SmsMessageInfo.analyze(value.text)),
            ),
          ),
        ),
      ],
    );
  }
}

/// `123 / 160 · SMS: 1 · GSM-7` style label.
class SmsCounterLabel extends StatelessWidget {
  const SmsCounterLabel({super.key, required this.info});

  final SmsMessageInfo info;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final encoding =
        info.encoding == SmsEncoding.gsm7 ? s.encodingGsm : s.encodingUnicode;
    final color = info.isEmpty
        ? scheme.onSurfaceVariant
        : info.isMultipart
            ? t.warning
            : scheme.onSurfaceVariant;

    return Tooltip(
      message: info.isMultipart
          ? s.tooltipMultipart(info.parts)
          : s.tooltipSingle(info.singlePartLimit, encoding),
      child: Text(
        s.counterLabel(info.length, info.capacity, info.parts, encoding),
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: info.isMultipart ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
