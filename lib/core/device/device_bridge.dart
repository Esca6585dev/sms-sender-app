import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One SIM card of the phone.
class SimInfo {
  const SimInfo({
    required this.subscriptionId,
    required this.slot,
    required this.displayName,
    required this.carrier,
    required this.number,
    required this.isDefaultSms,
  });

  factory SimInfo.fromMap(Map<Object?, Object?> map) => SimInfo(
        subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? -1,
        slot: (map['slot'] as num?)?.toInt() ?? 0,
        displayName: map['displayName'] as String? ?? '',
        carrier: map['carrier'] as String? ?? '',
        number: map['number'] as String? ?? '',
        isDefaultSms: map['isDefaultSms'] as bool? ?? false,
      );

  final int subscriptionId;
  final int slot;
  final String displayName;
  final String carrier;
  final String number;
  final bool isDefaultSms;

  String get label {
    final name = displayName.isNotEmpty ? displayName : carrier;
    final base = name.isNotEmpty ? name : 'SIM ${slot + 1}';
    return number.isNotEmpty ? '$base · $number' : base;
  }
}

/// Native helpers implemented in `MainActivity.kt`: SIM list, the foreground
/// service that keeps a long send alive in the background, keep-screen-on.
abstract class DeviceBridge {
  Future<String> deviceName();

  Future<List<SimInfo>> sims();

  Future<void> startSending(String title, String text);

  Future<void> updateSending(String title, String text);

  Future<void> stopSending();

  Future<void> keepScreenOn(bool on);

  /// Fires when the user taps "Stop" on the service notification.
  Stream<void> get stopRequests;
}

class MethodChannelDeviceBridge implements DeviceBridge {
  MethodChannelDeviceBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopRequested') _stopRequests.add(null);
      return null;
    });
  }

  static const MethodChannel _channel = MethodChannel('elite_sms/device');

  final StreamController<void> _stopRequests = StreamController.broadcast();

  @override
  Stream<void> get stopRequests => _stopRequests.stream;

  @override
  Future<String> deviceName() async =>
      await _invoke<String>('deviceName') ?? 'Android';

  @override
  Future<List<SimInfo>> sims() async {
    final raw = await _invoke<List<Object?>>('sims');
    if (raw == null) return const [];
    return [
      for (final item in raw)
        if (item is Map<Object?, Object?>) SimInfo.fromMap(item),
    ];
  }

  @override
  Future<void> startSending(String title, String text) =>
      _invoke<void>('startSending', {'title': title, 'text': text});

  @override
  Future<void> updateSending(String title, String text) =>
      _invoke<void>('updateSending', {'title': title, 'text': text});

  @override
  Future<void> stopSending() => _invoke<void>('stopSending');

  @override
  Future<void> keepScreenOn(bool on) =>
      _invoke<void>('keepScreenOn', {'on': on});

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // tests, web, desktop
    } on PlatformException catch (error) {
      debugPrint('DeviceBridge.$method failed: ${error.message}');
      return null;
    }
  }
}

/// Does nothing; used in tests and on platforms without the native side.
class NoopDeviceBridge implements DeviceBridge {
  final StreamController<void> _stopRequests = StreamController.broadcast();
  final List<String> log = [];
  List<SimInfo> fakeSims = const [];

  @override
  Stream<void> get stopRequests => _stopRequests.stream;

  void requestStop() => _stopRequests.add(null);

  @override
  Future<String> deviceName() async => 'Test device';

  @override
  Future<List<SimInfo>> sims() async => fakeSims;

  @override
  Future<void> startSending(String title, String text) async =>
      log.add('start:$title:$text');

  @override
  Future<void> updateSending(String title, String text) async =>
      log.add('update:$text');

  @override
  Future<void> stopSending() async => log.add('stop');

  @override
  Future<void> keepScreenOn(bool on) async => log.add('screen:$on');
}

final deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) => MethodChannelDeviceBridge(),
);
