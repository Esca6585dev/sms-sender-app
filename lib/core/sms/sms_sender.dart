import 'dart:async';

import 'package:another_telephony/telephony.dart';

/// Outcome of a single SMS send attempt.
class SmsSendResult {
  const SmsSendResult.success()
      : success = true,
        error = null;

  const SmsSendResult.failure(this.error) : success = false;

  final bool success;
  final String? error;
}

/// Thrown when the platform refuses to send at all (operator limit reached,
/// missing permission, no SIM…). Callers should stop the whole batch instead
/// of retrying the next number.
class SmsSendException implements Exception {
  SmsSendException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SmsSendException: $message';
}

/// Abstraction over the device SMS stack so business logic can be tested
/// with a fake implementation.
abstract class SmsSender {
  /// Sends [message] to [phone]. Returns a failure result when the network
  /// did not confirm the send in time and throws [SmsSendException] when the
  /// platform itself rejects the request.
  Future<SmsSendResult> send({
    required String phone,
    required String message,
    required bool multipart,
  });
}

/// [SmsSender] backed by the `another_telephony` plugin.
class TelephonySmsSender implements SmsSender {
  TelephonySmsSender({
    Telephony? telephony,
    this.timeout = const Duration(seconds: 10),
  }) : _telephony = telephony ?? Telephony.instance;

  final Telephony _telephony;

  /// How long to wait for the SENT/DELIVERED callback before giving up.
  final Duration timeout;

  @override
  Future<SmsSendResult> send({
    required String phone,
    required String message,
    required bool multipart,
  }) async {
    final completer = Completer<bool>();

    try {
      await _telephony.sendSms(
        to: phone,
        message: message,
        isMultipart: multipart,
        statusListener: (SendStatus status) {
          if (completer.isCompleted) return;
          if (status == SendStatus.SENT || status == SendStatus.DELIVERED) {
            completer.complete(true);
          }
        },
      );
    } catch (error) {
      throw SmsSendException(error.toString(), error);
    }

    final confirmed = await completer.future.timeout(
      timeout,
      onTimeout: () => false,
    );

    return confirmed
        ? const SmsSendResult.success()
        : const SmsSendResult.failure('Нет подтверждения отправки (таймаут)');
  }
}
