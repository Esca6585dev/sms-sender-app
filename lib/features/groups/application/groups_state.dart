import 'package:sms_sender_app/features/groups/domain/sms_group.dart';
import 'package:sms_sender_app/l10n/strings.dart';

const Object _unset = Object();

/// What an Excel import produced; shown to the operator after the import.
class ImportSummary {
  const ImportSummary({
    required this.imported,
    required this.groupsCreated,
    required this.invalid,
    required this.duplicates,
    required this.empty,
    required this.totalRows,
  });

  final int imported;
  final int groupsCreated;
  final int invalid;
  final int duplicates;
  final int empty;
  final int totalRows;

  String describe() {
    final s = S.current;
    if (imported == 0) return s.importNothing(totalRows);
    final buffer = StringBuffer(s.importResult(imported, groupsCreated));
    if (invalid > 0) buffer.write(s.importInvalid(invalid));
    if (duplicates > 0) buffer.write(s.importDuplicates(duplicates));
    return buffer.toString();
  }
}

/// Immutable UI state of the groups feature.
class GroupsState {
  const GroupsState({
    this.groups = const [],
    this.isLoading = true,
    this.isImporting = false,
    this.activeGroupId,
    this.stopRequested = false,
    this.errorMessage,
    this.lastImport,
    this.queue = const [],
    this.selectedIds = const {},
    this.pausedUntil,
  });

  final List<SmsGroup> groups;

  /// Set while the send loop waits for the phone's SMS limit to clear.
  final DateTime? pausedUntil;

  bool get isPaused => pausedUntil != null;

  /// Groups waiting to be sent after [activeGroupId], in order.
  final List<String> queue;

  /// Groups ticked by the operator for "send selected".
  final Set<String> selectedIds;

  /// `true` until the persisted groups have been restored.
  final bool isLoading;

  final bool isImporting;

  /// Id of the group being sent right now, `null` when idle.
  final String? activeGroupId;

  /// The operator pressed "Stop"; the loop ends after the current number.
  final bool stopRequested;

  /// Fatal send error (operator limit etc.) to show in a dialog.
  final String? errorMessage;

  final ImportSummary? lastImport;

  bool get isSending => activeGroupId != null;

  bool get isBusy => isSending || isImporting;

  bool get isEmpty => groups.isEmpty;

  /// Counters summed over every group.
  GroupCounters get totals {
    var acc = GroupCounters.zero;
    for (final g in groups) {
      acc = acc + g.counters;
    }
    return acc;
  }

  /// Groups that still have at least one number to send.
  int get pendingGroupsCount =>
      groups.where((g) => g.counters.remaining > 0).length;

  SmsGroup? get activeGroup =>
      activeGroupId == null ? null : groupById(activeGroupId!);

  bool isQueued(String id) => queue.contains(id);

  /// 1-based place in the queue, `null` when not queued.
  int? queuePosition(String id) {
    final i = queue.indexOf(id);
    return i < 0 ? null : i + 1;
  }

  bool isSelected(String id) => selectedIds.contains(id);

  bool get hasSelection => selectedIds.isNotEmpty;

  /// Selected groups that still have numbers to send.
  List<SmsGroup> get selectedSendable => [
        for (final g in groups)
          if (selectedIds.contains(g.id) && g.counters.remaining > 0) g,
      ];

  SmsGroup? groupById(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  GroupsState copyWith({
    List<SmsGroup>? groups,
    bool? isLoading,
    bool? isImporting,
    Object? activeGroupId = _unset,
    bool? stopRequested,
    Object? errorMessage = _unset,
    Object? lastImport = _unset,
    List<String>? queue,
    Set<String>? selectedIds,
    Object? pausedUntil = _unset,
  }) {
    return GroupsState(
      pausedUntil: identical(pausedUntil, _unset)
          ? this.pausedUntil
          : pausedUntil as DateTime?,
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      activeGroupId: identical(activeGroupId, _unset)
          ? this.activeGroupId
          : activeGroupId as String?,
      stopRequested: stopRequested ?? this.stopRequested,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastImport: identical(lastImport, _unset)
          ? this.lastImport
          : lastImport as ImportSummary?,
      queue: queue ?? this.queue,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}
