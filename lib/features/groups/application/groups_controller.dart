import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/core/sms/sms_sender.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/application/groups_state.dart';
import 'package:sms_sender_app/features/groups/data/groups_repository.dart';
import 'package:sms_sender_app/features/groups/data/sent_numbers_sync.dart';
import 'package:sms_sender_app/features/groups/domain/group_batcher.dart';
import 'package:sms_sender_app/features/groups/domain/sms_group.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';

/// Business logic of the groups feature: import, batching, sequential
/// sending with live counters, stop, reset and persistence.
///
/// The UI never mutates groups directly; it calls methods here and watches
/// [GroupsState].
class GroupsController extends Notifier<GroupsState> {
  late GroupsRepository _repository;
  late SmsSender _sender;
  late ExcelParser _parser;
  late GroupBatcher _batcher;
  SentNumbersSync? _sync;
  late Future<void> _ready;

  Timer? _persistTimer;
  bool _stopRequested = false;
  bool _disposed = false;

  static const Duration _persistDebounce = Duration(milliseconds: 400);

  @override
  GroupsState build() {
    _repository = ref.watch(groupsRepositoryProvider);
    _sender = ref.watch(smsSenderProvider);
    _parser = ref.watch(excelParserProvider);
    _batcher = ref.watch(groupBatcherProvider);
    _sync = ref.watch(sentNumbersSyncProvider);
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
      _stopRequested = true;
      _persistTimer?.cancel();
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
    if (state.isSending) {
      throw StateError('Импорт недоступен во время отправки');
    }
    if (state.isImporting) {
      throw StateError('Импорт уже выполняется');
    }

    _emit(state.copyWith(isImporting: true));
    try {
      final parsed = await _parser(bytes);
      final existing = replace ? const <SmsGroup>[] : state.groups;

      final known = <String>{
        for (final g in existing)
          for (final r in g.recipients) r.phone,
      };
      final fresh = <SmsRecipient>[];
      var duplicates = parsed.duplicateCount;
      for (final r in parsed.recipients) {
        if (known.add(r.phone)) {
          fresh.add(r);
        } else {
          duplicates++;
        }
      }

      final created = _batcher.split(
        fresh,
        firstIndex: existing.isEmpty ? 1 : existing.last.index + 1,
        firstNumber: existing.isEmpty ? 1 : existing.last.endNumber + 1,
      );

      final summary = ImportSummary(
        imported: fresh.length,
        groupsCreated: created.length,
        invalid: parsed.invalidCount,
        duplicates: duplicates,
        empty: parsed.emptyCount,
        totalRows: parsed.totalRows,
      );

      _emit(
        state.copyWith(
          groups: [...existing, ...created],
          isImporting: false,
          lastImport: summary,
        ),
      );
      await _persistNow();
      return summary;
    } catch (_) {
      _emit(state.copyWith(isImporting: false));
      rethrow;
    }
  }

  // ------------------------------------------------------------------ send

  /// Sends [message] to every number of the group that is not sent yet.
  /// Returns `false` when nothing was started (empty text, already sending).
  Future<bool> sendGroup(
    String groupId, {
    required String message,
    Duration delay = Duration.zero,
  }) =>
      _send([groupId], message: message, delay: delay);

  /// Sends every group that still has pending numbers, one after another.
  Future<bool> sendAllPending({
    required String message,
    Duration delay = Duration.zero,
  }) async {
    await _ready;
    final ids = [
      for (final g in state.groups)
        if (g.counters.remaining > 0) g.id,
    ];
    return _send(ids, message: message, delay: delay);
  }

  /// Asks the running send loop to stop after the current number.
  void stop() {
    if (!state.isSending) return;
    _stopRequested = true;
    _emit(state.copyWith(stopRequested: true));
  }

  Future<bool> _send(
    List<String> groupIds, {
    required String message,
    required Duration delay,
  }) async {
    await _ready;
    final text = message.trim();
    if (text.isEmpty || groupIds.isEmpty || state.isBusy) return false;

    final multipart = SmsMessageInfo.analyze(text).isMultipart;
    _stopRequested = false;
    _emit(state.copyWith(stopRequested: false, errorMessage: null));

    try {
      for (final id in groupIds) {
        if (_stopRequested || _disposed) break;
        final group = state.groupById(id);
        if (group == null) continue;

        _emit(state.copyWith(activeGroupId: id));
        final startedAt = DateTime.now();
        final processed = <CampaignRecipient>[];
        await _sendRecipients(
          groupId: id,
          count: group.total,
          message: text,
          multipart: multipart,
          delay: delay,
          processed: processed,
        );
        _recordCampaign(
          message: text,
          group: group,
          startedAt: startedAt,
          processed: processed,
        );
      }
    } finally {
      _emit(state.copyWith(activeGroupId: null, stopRequested: false));
      await _persistNow();
    }
    return true;
  }

  Future<void> _sendRecipients({
    required String groupId,
    required int count,
    required String message,
    required bool multipart,
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
        processed.add(_logEntry(recipient, sent: false, error: error.message));
        _abort(groupId, i, error.message);
        return;
      } catch (error) {
        processed.add(_logEntry(recipient, sent: false, error: '$error'));
        _abort(groupId, i, error.toString());
        return;
      }

      if (result.success) {
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
      } else {
        final error = result.error ?? 'Не отправлено';
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
              source: CampaignSource.group,
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
    _emit(
      state.copyWith(
        errorMessage: 'Достигнут лимит отправки SMS или оператор временно '
            'запретил отправку.\n\nПопробуйте позже.\n\n$details',
      ),
    );
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
      ),
    );
    await _persistNow();
  }

  /// Deletes every group.
  Future<void> clearAll() async {
    await _ready;
    if (state.isSending) return;
    _emit(state.copyWith(groups: const [], lastImport: null));
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

final groupsControllerProvider =
    NotifierProvider<GroupsController, GroupsState>(GroupsController.new);
