import 'package:flutter/material.dart';

import 'package:sms_sender_app/core/sms/sms_message_info.dart';

/// Multi-line message input without a hard character limit. Shows a live
/// counter with the encoding and the number of SMS parts the text needs.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    this.enabled = true,
    this.labelText = 'Текст сообщения',
    this.minLines = 2,
    this.maxLines = 6,
  });

  final TextEditingController controller;
  final bool enabled;
  final String labelText;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
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
            labelText: labelText,
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.message),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 6),
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
    final encoding = info.encoding == SmsEncoding.gsm7 ? 'GSM-7' : 'Unicode';
    final color = info.isEmpty
        ? Colors.grey
        : info.isMultipart
            ? Colors.orange.shade800
            : Colors.grey.shade700;

    return Tooltip(
      message: info.isMultipart
          ? 'Длинное сообщение: будет отправлено как ${info.parts} части'
          : 'Одно SMS, максимум ${info.singlePartLimit} символов ($encoding)',
      child: Text(
        '${info.length} / ${info.capacity} · SMS: ${info.parts} · $encoding',
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: info.isMultipart ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
