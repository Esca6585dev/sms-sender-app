import 'package:flutter/foundation.dart';

import 'package:sms_sender_app/database.dart' as database;

/// Optional hook that mirrors a successful group send into the backend so the
/// home screen counters and the "already sent" protection stay consistent.
abstract class SentNumbersSync {
  Future<void> markSent(String phone);
}

/// Best-effort implementation: a number that does not exist on the backend
/// (404) or a network hiccup must never break the local sending loop.
class ApiSentNumbersSync implements SentNumbersSync {
  ApiSentNumbersSync(this._api);

  final database.ApiService _api;

  @override
  Future<void> markSent(String phone) async {
    try {
      await _api.markNumberAsSent(phone);
    } catch (error) {
      debugPrint('SentNumbersSync: could not mark $phone as sent: $error');
    }
  }
}
