import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/core/sms/sms_sender.dart';

/// Source of incoming SMS (the operator answers the balance request by SMS).
abstract class IncomingSmsSource {
  void listen(void Function(String address, String body) onMessage);
}

class TelephonyIncomingSms implements IncomingSmsSource {
  TelephonyIncomingSms({Telephony? telephony})
      : _telephony = telephony ?? Telephony.instance;

  final Telephony _telephony;
  bool _started = false;

  @override
  void listen(void Function(String address, String body) onMessage) {
    if (_started) return;
    _started = true;
    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) =>
            onMessage(message.address ?? '', message.body ?? ''),
        listenInBackground: false,
      );
    } catch (error) {
      debugPrint('IncomingSms: cannot listen: $error');
    }
  }
}

/// Test double: call [emit] to simulate an incoming SMS.
class FakeIncomingSms implements IncomingSmsSource {
  void Function(String address, String body)? _handler;

  @override
  void listen(void Function(String address, String body) onMessage) {
    _handler = onMessage;
  }

  void emit(String address, String body) => _handler?.call(address, body);
}

/// Price and how to ask the operator for the balance.
class BalanceSettings {
  const BalanceSettings({
    this.pricePerPart = 0.01,
    this.requestNumber = '0800',
    this.requestText = 'BALANS',
  });

  /// Manat per SMS part (1 teňňe = 0.01 TMT by default).
  final double pricePerPart;
  final String requestNumber;
  final String requestText;

  BalanceSettings copyWith({
    double? pricePerPart,
    String? requestNumber,
    String? requestText,
  }) =>
      BalanceSettings(
        pricePerPart: pricePerPart ?? this.pricePerPart,
        requestNumber: requestNumber ?? this.requestNumber,
        requestText: requestText ?? this.requestText,
      );
}

class BalanceState {
  const BalanceState({
    this.balance,
    this.updatedAt,
    this.isChecking = false,
    this.lastReply,
    this.error,
    this.settings = const BalanceSettings(),
    this.selectedSim = -1,
  });

  /// Known balance in manat, `null` until checked or entered.
  final double? balance;
  final DateTime? updatedAt;
  final bool isChecking;
  final String? lastReply;
  final String? error;
  final BalanceSettings settings;

  /// Subscription id of the SIM to send from, `-1` = system default.
  final int selectedSim;

  /// Cost of sending [smsCount] messages of [parts] parts each.
  double cost(int smsCount, int parts) =>
      smsCount * parts * settings.pricePerPart;

  /// How many single-part SMS the balance still covers, `null` if unknown.
  int? get affordableSms => balance == null || settings.pricePerPart <= 0
      ? null
      : (balance! / settings.pricePerPart).floor();

  BalanceState copyWith({
    Object? balance = _unset,
    Object? updatedAt = _unset,
    bool? isChecking,
    Object? lastReply = _unset,
    Object? error = _unset,
    BalanceSettings? settings,
    int? selectedSim,
  }) =>
      BalanceState(
        balance: identical(balance, _unset) ? this.balance : balance as double?,
        updatedAt: identical(updatedAt, _unset)
            ? this.updatedAt
            : updatedAt as DateTime?,
        isChecking: isChecking ?? this.isChecking,
        lastReply:
            identical(lastReply, _unset) ? this.lastReply : lastReply as String?,
        error: identical(error, _unset) ? this.error : error as String?,
        settings: settings ?? this.settings,
        selectedSim: selectedSim ?? this.selectedSim,
      );
}

const Object _unset = Object();

/// Formats manat amounts: `12,30 TMT`.
String formatManat(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} TMT';

/// Balance of the SIM, SMS price and the SIM choice. The balance is read from
/// the operator's SMS reply to a request sent to [BalanceSettings.requestNumber]
/// and decreased locally after every sent SMS until the next check.
class BalanceController extends Notifier<BalanceState> {
  static const _keyBalance = 'balance_value';
  static const _keyUpdated = 'balance_updated';
  static const _keyPrice = 'balance_price';
  static const _keyNumber = 'balance_request_number';
  static const _keyText = 'balance_request_text';
  static const _keySim = 'balance_sim';

  static const Duration replyTimeout = Duration(seconds: 90);

  late IncomingSmsSource _incoming;
  bool _disposed = false;
  Completer<double>? _pending;

  @override
  BalanceState build() {
    _incoming = ref.watch(incomingSmsProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _restore();
    return const BalanceState();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final updated = prefs.getString(_keyUpdated);
      state = state.copyWith(
        balance: prefs.getDouble(_keyBalance),
        updatedAt: updated == null ? null : DateTime.tryParse(updated),
        settings: BalanceSettings(
          pricePerPart: prefs.getDouble(_keyPrice) ?? 0.01,
          requestNumber: prefs.getString(_keyNumber) ?? '0800',
          requestText: prefs.getString(_keyText) ?? 'BALANS',
        ),
        selectedSim: prefs.getInt(_keySim) ?? -1,
      );
    } catch (error) {
      debugPrint('Balance: restore failed: $error');
    }
  }

  /// Sends the balance request SMS and waits for the operator's reply.
  Future<bool> checkViaSms() async {
    if (state.isChecking) return false;
    final settings = state.settings;
    if (settings.requestNumber.trim().isEmpty) return false;

    _incoming.listen(_onIncoming);
    final completer = Completer<double>();
    _pending = completer;
    state = state.copyWith(isChecking: true, error: null);

    try {
      final result = await ref.read(smsSenderProvider).send(
            phone: settings.requestNumber.trim(),
            message: settings.requestText.trim().isEmpty
                ? '1'
                : settings.requestText.trim(),
            multipart: false,
          );
      if (!result.success) {
        _finish(error: result.error ?? 'Запрос не отправлен');
        return false;
      }
      final value = await completer.future.timeout(replyTimeout);
      _finish(balance: value);
      return true;
    } on TimeoutException {
      _finish(error: 'Ответ от оператора не получен');
      return false;
    } catch (error) {
      _finish(error: error.toString());
      return false;
    }
  }

  void _onIncoming(String address, String body) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    final digits = state.settings.requestNumber.replaceAll(RegExp(r'\D'), '');
    final fromOperator = digits.isNotEmpty && address.contains(digits);
    final looksLikeBalance =
        RegExp(r'баланс|balans|balance|TMT|манат', caseSensitive: false)
            .hasMatch(body);
    if (!fromOperator && !looksLikeBalance) return;
    final value = parseBalance(body);
    if (value == null) return;
    state = state.copyWith(lastReply: body);
    pending.complete(value);
  }

  void _finish({double? balance, String? error}) {
    _pending = null;
    if (_disposed) return;
    if (balance != null) {
      state = state.copyWith(
        balance: balance,
        updatedAt: DateTime.now(),
        isChecking: false,
        error: null,
      );
      _persist();
    } else {
      state = state.copyWith(isChecking: false, error: error);
    }
  }

  /// Manual entry when the operator does not answer by SMS.
  Future<void> setManual(double value) async {
    state = state.copyWith(
      balance: value,
      updatedAt: DateTime.now(),
      error: null,
    );
    await _persist();
  }

  /// Local estimate after a send; the next check replaces it.
  Future<void> deduct({required int smsCount, required int parts}) async {
    final current = state.balance;
    if (current == null || smsCount <= 0) return;
    final next = current - state.cost(smsCount, parts);
    state = state.copyWith(balance: next < 0 ? 0.0 : next);
    await _persist();
  }

  Future<void> setPrice(double pricePerPart) async {
    state = state.copyWith(
      settings: state.settings.copyWith(pricePerPart: pricePerPart),
    );
    await _persist();
  }

  Future<void> setRequest({String? number, String? text}) async {
    state = state.copyWith(
      settings: state.settings.copyWith(requestNumber: number, requestText: text),
    );
    await _persist();
  }

  Future<void> selectSim(int subscriptionId) async {
    state = state.copyWith(selectedSim: subscriptionId);
    await _persist();
  }

  /// `Balans: 12.30 TMT`, `Ваш баланс 5,00 манат`, `Balance 0.50 TMT` →
  /// the first amount next to a currency word, else the first decimal.
  static double? parseBalance(String body) {
    final withCurrency = RegExp(
      r'(\d+(?:[.,]\d{1,2})?)\s*(?:TMT|тмт|манат|manat|man\b|мт\b)',
      caseSensitive: false,
    ).firstMatch(body);
    final raw = withCurrency?.group(1) ??
        RegExp(r'\d+[.,]\d{1,2}').firstMatch(body)?.group(0) ??
        RegExp(r'\d+').firstMatch(body)?.group(0);
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = state;
      if (s.balance != null) await prefs.setDouble(_keyBalance, s.balance!);
      if (s.updatedAt != null) {
        await prefs.setString(_keyUpdated, s.updatedAt!.toIso8601String());
      }
      await prefs.setDouble(_keyPrice, s.settings.pricePerPart);
      await prefs.setString(_keyNumber, s.settings.requestNumber);
      await prefs.setString(_keyText, s.settings.requestText);
      await prefs.setInt(_keySim, s.selectedSim);
    } catch (error) {
      debugPrint('Balance: persist failed: $error');
    }
  }
}

final incomingSmsProvider = Provider<IncomingSmsSource>(
  (ref) => TelephonyIncomingSms(),
);

final balanceProvider =
    NotifierProvider<BalanceController, BalanceState>(BalanceController.new);

/// SIM the senders use; read lazily at send time.
final selectedSimProvider = Provider<int>(
  (ref) => ref.watch(balanceProvider.select((s) => s.selectedSim)),
);

/// The device SMS sender, bound to the selected SIM.
final smsSenderProvider = Provider<SmsSender>(
  (ref) => TelephonySmsSender(
    subscriptionId: () => ref.read(selectedSimProvider),
  ),
);
