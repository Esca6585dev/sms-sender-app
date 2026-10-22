import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/core/device/device_bridge.dart';
import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/core/sms/sms_sender.dart';
import 'package:sms_sender_app/core/utils/date_format.dart';
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/application/groups_state.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/data/sent_numbers_sync.dart';
import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';
import 'package:sms_sender_app/features/groups/domain/group_source.dart';
import 'package:sms_sender_app/features/groups/domain/sms_group.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/l10n/strings.dart';

/// Business logic of one set of groups (Excel or server): import, batching,
/// a send queue with live counters, SMS-limit pauses, stop, reset and
/// persistence.
///
/// The UI never mutates groups directly; it calls methods here and watches
/// [GroupsState].
class GroupsController extends Notifier<GroupsState> {
  GroupsController(this.source);

  final GroupSource source;

  late GroupsRepository _repository;
  late SmsSender _sender;
  late ExcelParser _parser;
  late GroupBatcher _batcher;
  SentNumbersSync? _sync;
  late DeviceBridge _bridge;
  late List<Duration> _limitWaits;
  late Future<void> _ready;

  Timer? _persistTimer;
  StreamSubscription<void>? _stopSubscription;
  bool _stopRequested = false;
  bool _resumeRequested = false;
  bool _disposed = false;
  int _limitStrikes = 0;

  static const Duration _persistDebounce = Duration(milliseconds: 400);

  @override
  GroupsState build() {
    _repository = ref.watch(groupsRepositoryProvider(source));
    _sender = ref.watch(smsSenderProvider);
    _parser = ref.watch(excelParserProvider);
    _batcher = ref.watch(groupBatcherProvider);
    _sync = ref.watch(sentNumbersSyncProvider);
    _bridge = ref.watch(deviceBridgeProvider);
    _limitWaits = ref.watch(limitWaitScheduleProvider);
    _disposed = false;

    // "Stop" on the foreground-service notification.
    _stopSubscription?.cancel();
    _stopSubscription = _bridge.stopRequests.listen((_) => stop());

    ref.onDispose(() {
      _disposed = true;
      _stopRequested = true;
      _persistTimer?.cancel();
      _stopSubscription?.cancel();
    });

    _ready = _restore();
    return const GroupsState();
  }

  /// Completes once the persisted groups have been restored.
  Future<void> get ready => _ready;

  // ---------------------------------------------------------------- import

  /// Parses [bytes], splits the numbers into groups of 100 and stores them.
  ///
  /// With [replace] the current groups are discarded first; otherwise the new
  /// groups continue the numbering and numbers already present are skipped.
  Future<ImportSummary> importFromBytes(
    Uint8List bytes, {
    bool replace = false,
  }) async {
    await _ready;
    _checkCanImport();
    _emit(state.copyWith(isImporting: true));
    try {
      final parsed = await _parser(bytes);
      return await _import(
        parsed.recipients,
        replace: replace,
        invalid: parsed.invalidCount,
        duplicates: parsed.duplicateCount,
        totalRows: parsed.totalRows,
      );
    } catch (_) {
      _emit(state.copyWith(isImporting: false));
      rethrow;
    }
  }

  /// Splits already-parsed numbers (e.g. the backend contact list) into
  /// groups. With [keepNames] custom group names survive a [replace] when the
  /// group index is the same.
  Future<ImportSummary> importRecipients(
    List<SmsRecipient> recipients, {
    bool replace = false,
    bool keepNames = false,
  }) async {
    await _ready;
    _checkCanImport();
    _emit(state.copyWith(isImporting: true));
    try {
      return await _import(
        recipients,
        replace: replace,
        keepNames: keepNames,
        totalRows: recipients.length,
      );
    } catch (_) {
      _emit(state.copyWith(isImporting: false));
      rethrow;
    }
  }

  void _checkCanImport() {
    if (state.isSending) throw StateError('import while sending');
    if (state.isImporting) throw StateError('import already running');
  }

  Future<ImportSummary> _import(
    List<SmsRecipient> recipients, {
    required bool replace,
    bool keepNames = false,
    int invalid = 0,
    int duplicates = 0,
    int totalRows = 0,
  }) async {
    final existing = replace ? const <SmsGroup>[] : state.groups;
    final oldNames = {
      for (final g in state.groups)
        if (g.name != null) g.index: g.name!,
    };

    final known = <String>{
      for (final g in existing)
        for (final r in g.recipients) r.phone,
    };
    final fresh = <SmsRecipient>[];
    var skipped = duplicates;
    for (final r in recipients) {
      if (known.add(r.phone)) {
        fresh.add(r);
      } else {
        skipped++;
      }
    }

    var created = _batcher.split(
      fresh,
      firstIndex: existing.isEmpty ? 1 : existing.last.index + 1,
      firstNumber: existing.isEmpty ? 1 : existing.last.endNumber + 1,
    );
    if (keepNames && replace) {
      created = [
        for (final g in created)
          oldNames.containsKey(g.index) ? g.rename(oldNames[g.index]) : g,
      ];
    }

    final summary = ImportSummary(
      imported: fresh.length,
      groupsCreated: created.length,
      invalid: invalid,
      duplicates: skipped,
      empty: 0,
      totalRows: totalRows,
    );

    _emit(
      state.copyWith(
        groups: [...existing, ...created],
        isImporting: false,
        lastImport: summary,
        selectedIds: const {},
      ),
    );
    await _persistNow();
    return summary;
  }

  // ------------------------------------------------------------------ send

  /// Sends [message] to every number of the group that is not sent yet,
  /// queued behind whatever is already sending.
  Future<bool> sendGroup(
    String groupId, {
    required String message,
    Duration delay = Duration.zero,
  }) =>
      enqueue([groupId], message: message, delay: delay);

  /// Queues every group that still has pending numbers, in order.
  Future<bool> sendAllPending({
    required String message,
    Duration delay = Duration.zero,
  }) async {
    await _ready;
    return enqueue(
      [
        for (final g in state.groups)
          if (g.counters.remaining > 0) g.id,
      ],
      message: message,
      delay: delay,
    );
  }

  /// Queues the groups ticked by the operator and clears the selection.
  Future<bool> sendSelected({
    required String message,
    Duration delay = Duration.zero,
  }) async {
    await _ready;
    final ids = [for (final g in state.selectedSendable) g.id];
    if (ids.isEmpty) return false;
    _emit(state.copyWith(selectedIds: const {}));
    return enqueue(ids, message: message, delay: delay);
  }

  /// Adds groups to the send queue and starts it when nothing is sending.
  /// Returns `false` when nothing was added (empty text, import running,
  /// groups already queued).
  Future<bool> enqueue(
    List<String> groupIds, {
    required String message,
    Duration delay = Duration.zero,
  }) async {
    await _ready;
    final text = message.trim();
    if (text.isEmpty || state.isImporting) return false;

    final fresh = [
      for (final id in groupIds)
        if (!state.queue.contains(id) &&
            id != state.activeGroupId &&
            state.groupById(id) != null)
          id,
    ];
    if (fresh.isEmpty) return false;

    _emit(state.copyWith(queue: [...state.queue, ...fresh]));
    if (state.isSending) return true; // the running loop picks them up
    await _runQueue(text, delay);
    return true;
  }

  /// Removes a waiting group from the queue; the active one keeps going.
  void dequeue(String groupId) => _emit(
        state.copyWith(
          queue: [
            for (final id in state.queue)
              if (id != groupId) id,
          ],
        ),
      );

  /// Stops after the current number and drops the rest of the queue.
  void stop() {
    if (!state.isSending) return;
    _stopRequested = true;
    _emit(state.copyWith(stopRequested: true, queue: const []));
  }

  /// Ends an SMS-limit pause early and retries right away.
  void resumeNow() => _resumeRequested = true;

  // ------------------------------------------------------------- selection

  void toggleSelected(String groupId) {
    final next = {...state.selectedIds};
    if (!next.remove(groupId)) next.add(groupId);
    _emit(state.copyWith(selectedIds: next));
  }

  void selectAllPending() => _emit(
        state.copyWith(
          selectedIds: {
            for (final g in state.groups)
              if (g.counters.remaining > 0) g.id,
          },
        ),
      );

  void clearSelection() => _emit(state.copyWith(selectedIds: const {}));

  /// Custom group name; empty restores the default letter name.
  Future<void> renameGroup(String groupId, String? name) async {
    await _ready;
    _replaceGroup(groupId, (g) => g.rename(name));
    await _persistNow();
  }

  Future<void> _runQueue(String message, Duration delay) async {
    final info = SmsMessageInfo.analyze(message);
    _stopRequested = false;
    _limitStrikes = 0;
    _emit(state.copyWith(stopRequested: false, errorMessage: null));
    unawaited(_bridge.startSending(S.current.serviceTitle, S.current.preparing));
    unawaited(_bridge.keepScreenOn(true));

    try {
      while (!_stopRequested && !_disposed && state.queue.isNotEmpty) {
        final id = state.queue.first;
        final group = state.groupById(id);
        _emit(
          state.copyWith(queue: state.queue.sublist(1), activeGroupId: group?.id),
        );
        if (group == null) continue;

        final startedAt = DateTime.now();
        final processed = <CampaignRecipient>[];
        await _sendRecipients(
          groupId: id,
          count: group.total,
          message: message,
          multipart: info.isMultipart,
          parts: info.parts,
          delay: delay,
          processed: processed,
        );
        _recordCampaign(
          message: message,
          group: group,
          startedAt: startedAt,
          processed: processed,
        );
      }
    } finally {
      _emit(
        state.copyWith(
          activeGroupId: null,
          stopRequested: false,
          queue: const [],
          pausedUntil: null,
        ),
      );
      unawaited(_bridge.stopSending());
      unawaited(_bridge.keepScreenOn(false));
      await _persistNow();
    }
  }

  Future<void> _sendRecipients({
    required String groupId,
    required int count,
    required String message,
    required bool multipart,
    required int parts,
    required Duration delay,
    required List<CampaignRecipient> processed,
  }) async {
    for (var i = 0; i < count; i++) {
      if (_stopRequested || _disposed) return;

      final group = state.groupById(groupId);
      if (group == null || i >= group.total) return; // removed meanwhile
      final recipient = group.recipients[i];
      if (recipient.isSent) continue;

      _patch(
        groupId,
        i,
        (r) => r.copyWith(status: RecipientStatus.sending, error: null),
      );

      SmsSendResult result;
      try {
        result = await _sender.send(
          phone: recipient.phone,
          message: message,
          multipart: multipart,
        );
      } on SmsSendException catch (error) {
        // The phone refused to send: usually the SMS limit. Put the number
        // back, wait, then retry it; give up only after the whole schedule.
        if (_limitStrikes >= _limitWaits.length + 2) {
          processed.add(_logEntry(recipient, sent: false, error: error.message));
          _abort(groupId, i, error.message);
          return;
        }
        final wait =
            _limitWaits[math.min(_limitStrikes, _limitWaits.length - 1)];
        _limitStrikes++;
        _patch(
          groupId,
          i,
          (r) => r.copyWith(status: RecipientStatus.pending, error: null),
        );
        await _pause(wait);
        if (_stopRequested || _disposed) return;
        i--; // retry the same number
        continue;
      } catch (error) {
        processed.add(_logEntry(recipient, sent: false, error: '$error'));
        _abort(groupId, i, error.toString());
        return;
      }

      if (result.success) {
        _limitStrikes = 0;
        final sentAt = DateTime.now();
        _patch(
          groupId,
          i,
          (r) => r.copyWith(
            status: RecipientStatus.sent,
            error: null,
            sentAt: sentAt,
          ),
        );
        processed.add(_logEntry(recipient, sent: true, sentAt: sentAt));
        final sync = _sync;
        if (sync != null) unawaited(sync.markSent(recipient.phone));
        unawaited(
          ref.read(balanceProvider.notifier).deduct(smsCount: 1, parts: parts),
        );
        final updated = state.groupById(groupId);
        if (updated != null) {
          unawaited(
            _bridge.updateSending(
              S.current.serviceTitle,
              '${updated.title}: ${updated.counters.sent} / ${updated.total}',
            ),
          );
        }
      } else {
        final error = result.error ?? S.current.notSent;
        _patch(
          groupId,
          i,
          (r) => r.copyWith(status: RecipientStatus.failed, error: error),
        );
        processed.add(_logEntry(recipient, sent: false, error: error));
      }
      _schedulePersist();

      if (delay > Duration.zero && !_stopRequested && i < count - 1) {
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Waits for [wait] (or until stop / resume), showing the time in the UI
  /// and the notification.
  Future<void> _pause(Duration wait) async {
    final until = DateTime.now().add(wait);
    _resumeRequested = false;
    _emit(state.copyWith(pausedUntil: until));
    unawaited(
      _bridge.updateSending(
        S.current.serviceTitle,
        S.current.pausedUntil(DateFormatting.time(until)),
      ),
    );
    while (!_stopRequested && !_disposed && !_resumeRequested) {
      final remaining = until.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < const Duration(seconds: 1)
            ? remaining
            : const Duration(seconds: 1),
      );
    }
    _emit(state.copyWith(pausedUntil: null));
  }

  static CampaignRecipient _logEntry(
    SmsRecipient recipient, {
    required bool sent,
    String? error,
    DateTime? sentAt,
  }) =>
      CampaignRecipient(
        phone: recipient.phone,
        name: recipient.name,
        sent: sent,
        error: error,
        sentAt: sentAt,
      );

  /// Stores the finished run in the history (best effort, never blocks).
  void _recordCampaign({
    required String message,
    required SmsGroup group,
    required DateTime startedAt,
    required List<CampaignRecipient> processed,
  }) {
    if (processed.isEmpty || _disposed) return;
    unawaited(
      ref.read(campaignLogProvider.notifier).record(
            SmsCampaign.fromRun(
              message: message,
              source: source == GroupSource.server
                  ? CampaignSource.serverGroup
                  : CampaignSource.group,
              sourceLabel: '${group.title} (${group.rangeLabel})',
              startedAt: startedAt,
              recipients: processed,
            ),
          ),
    );
  }

  void _abort(String groupId, int index, String details) {
    _patch(
      groupId,
      index,
      (r) => r.copyWith(status: RecipientStatus.failed, error: details),
    );
    _stopRequested = true;
    _emit(state.copyWith(errorMessage: S.current.limitError(details)));
  }

  // ----------------------------------------------------------------- reset

  /// Statuses of one group back to pending; numbers are kept.
  Future<void> resetGroup(String groupId) async {
    await _ready;
    if (state.activeGroupId == groupId) return;
    _replaceGroup(groupId, (g) => g.reset());
    await _persistNow();
  }

  /// Statuses of every group back to pending.
  Future<void> resetAll() async {
    await _ready;
    if (state.isSending) return;
    _emit(state.copyWith(groups: [for (final g in state.groups) g.reset()]));
    await _persistNow();
  }

  Future<void> removeGroup(String groupId) async {
    await _ready;
    if (state.activeGroupId == groupId) return;
    _emit(
      state.copyWith(
        groups: [
          for (final g in state.groups)
            if (g.id != groupId) g,
        ],
        queue: [
          for (final id in state.queue)
            if (id != groupId) id,
        ],
        selectedIds: {
          for (final id in state.selectedIds)
            if (id != groupId) id,
        },
      ),
    );
    await _persistNow();
  }

  /// Deletes every group.
  Future<void> clearAll() async {
    await _ready;
    if (state.isSending) return;
    _emit(
      state.copyWith(
        groups: const [],
        lastImport: null,
        queue: const [],
        selectedIds: const {},
      ),
    );
    await _persistNow();
  }

  void dismissError() => _emit(state.copyWith(errorMessage: null));

  // ------------------------------------------------------------- internals

  Future<void> _restore() async {
    try {
      final groups = await _repository.load();
      _emit(state.copyWith(groups: groups, isLoading: false));
    } catch (error, stack) {
      debugPrint('GroupsController: restore failed: $error\n$stack');
      _emit(state.copyWith(isLoading: false));
    }
  }

  void _emit(GroupsState next) {
    if (_disposed) return;
    state = next;
  }

  void _patch(
    String groupId,
    int index,
    SmsRecipient Function(SmsRecipient current) update,
  ) {
    _replaceGroup(groupId, (g) => g.updateRecipient(index, update));
  }

  void _replaceGroup(String groupId, SmsGroup Function(SmsGroup) update) {
    final groups = List<SmsGroup>.of(state.groups);
    final position = groups.indexWhere((g) => g.id == groupId);
    if (position < 0) return;
    groups[position] = update(groups[position]);
    _emit(state.copyWith(groups: groups));
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () => unawaited(_persistNow()));
  }

  Future<void> _persistNow() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (_disposed) return;
    try {
      await _repository.save(state.groups);
    } catch (error) {
      debugPrint('GroupsController: persist failed: $error');
    }
  }
}

/// One controller per [GroupSource]: Excel groups and server groups.
final groupsControllerProvider =
    NotifierProvider.family<GroupsController, GroupsState, GroupSource>(
  GroupsController.new,
);
