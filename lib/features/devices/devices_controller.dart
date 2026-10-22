import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/core/device/device_bridge.dart';
import 'package:sms_sender_app/l10n/strings.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';

/// A phone running this app and talking to the same backend.
class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    this.number = '',
    this.balance,
    this.sentToday = 0,
    this.lastSeen,
    this.isThisDevice = false,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        id: json['device_id']?.toString() ?? json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Устройство',
        number: json['number'] as String? ?? '',
        balance: (json['balance'] as num?)?.toDouble(),
        sentToday: (json['sent_today'] as num?)?.toInt() ?? 0,
        lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? ''),
      );

  final String id;
  final String name;
  final String number;
  final double? balance;
  final int sentToday;
  final DateTime? lastSeen;
  final bool isThisDevice;

  Map<String, dynamic> toJson() => {
        'device_id': id,
        'name': name,
        'number': number,
        if (balance != null) 'balance': balance,
        'sent_today': sentToday,
        'last_seen': (lastSeen ?? DateTime.now()).toIso8601String(),
      };
}

class DevicesState {
  const DevicesState({
    this.deviceId = '',
    this.deviceName = '',
    this.sims = const [],
    this.others = const [],
    this.isLoading = false,
    this.remoteSupported,
    this.error,
  });

  final String deviceId;
  final String deviceName;
  final List<SimInfo> sims;

  /// Other phones reported by the backend (`GET /devices/`).
  final List<DeviceInfo> others;
  final bool isLoading;

  /// `null` until the first request; `false` when the backend has no
  /// `/devices/` endpoint yet (see docs/DEVICES_API.md).
  final bool? remoteSupported;
  final String? error;

  DevicesState copyWith({
    String? deviceId,
    String? deviceName,
    List<SimInfo>? sims,
    List<DeviceInfo>? others,
    bool? isLoading,
    bool? remoteSupported,
    Object? error = _unset,
  }) =>
      DevicesState(
        deviceId: deviceId ?? this.deviceId,
        deviceName: deviceName ?? this.deviceName,
        sims: sims ?? this.sims,
        others: others ?? this.others,
        isLoading: isLoading ?? this.isLoading,
        remoteSupported: remoteSupported ?? this.remoteSupported,
        error: identical(error, _unset) ? this.error : error as String?,
      );
}

const Object _unset = Object();

/// This phone's identity + SIMs, and the list of other phones on the same
/// backend. Remote calls are best effort: the backend may not have the
/// endpoints yet, in which case the UI says so.
class DevicesController extends Notifier<DevicesState> {
  static const _keyDeviceId = 'device_id';

  late DeviceBridge _bridge;
  late Dio _dio;
  bool _disposed = false;

  @override
  DevicesState build() {
    _bridge = ref.watch(deviceBridgeProvider);
    _dio = ref.watch(apiServiceProvider).dio;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _init();
    return const DevicesState();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_keyDeviceId);
      if (id == null) {
        id = 'dev-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
        await prefs.setString(_keyDeviceId, id);
      }
      if (_disposed) return;
      state = state.copyWith(deviceId: id);
    } catch (_) {
      // Keep the empty id; nothing else depends on it locally.
    }
    await refreshLocal();
  }

  /// Re-reads the device name and SIM list from the phone.
  Future<void> refreshLocal() async {
    final name = await _bridge.deviceName();
    final sims = await _bridge.sims();
    if (_disposed) return;
    state = state.copyWith(deviceName: name, sims: sims);
  }

  /// Loads other devices from the backend.
  Future<void> refreshRemote() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get<dynamic>('/devices/');
      final data = response.data;
      final list = data is List
          ? data
          : (data is Map && data['results'] is List)
              ? data['results'] as List
              : const [];
      final others = [
        for (final item in list)
          if (item is Map)
            DeviceInfo.fromJson(Map<String, dynamic>.from(item)),
      ].where((d) => d.id != state.deviceId).toList();
      if (_disposed) return;
      state = state.copyWith(
        others: others,
        isLoading: false,
        remoteSupported: true,
      );
    } on DioException catch (error) {
      if (_disposed) return;
      final status = error.response?.statusCode;
      state = state.copyWith(
        isLoading: false,
        remoteSupported: status == 404 || status == 405 ? false : null,
        error: status == null
            ? S.current.noServerConnection
            : S.current.serverStatus(status),
      );
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// Publishes this phone's status; errors are ignored (optional endpoint).
  Future<void> heartbeat({double? balance, required int sentToday}) async {
    if (state.deviceId.isEmpty) return;
    final sim = state.sims.isEmpty ? null : state.sims.first;
    final info = DeviceInfo(
      id: state.deviceId,
      name: state.deviceName,
      number: sim?.number ?? '',
      balance: balance,
      sentToday: sentToday,
      lastSeen: DateTime.now(),
    );
    try {
      await _dio.post<dynamic>('/devices/heartbeat/', data: info.toJson());
    } catch (error) {
      debugPrint('Devices: heartbeat skipped: $error');
    }
  }
}

final devicesProvider =
    NotifierProvider<DevicesController, DevicesState>(DevicesController.new);
