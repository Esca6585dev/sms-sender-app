import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/app/app_shell.dart' show ShellMenuButton;
import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/core/utils/phone_normalizer.dart';
import 'package:sms_sender_app/database.dart' as database;
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/contacts/add_contact_page.dart';
import 'package:sms_sender_app/features/groups/application/groups_controller.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/groups/application/groups_state.dart';
import 'package:sms_sender_app/features/groups/domain/group_source.dart';
import 'package:sms_sender_app/features/groups/domain/sms_recipient.dart';
import 'package:sms_sender_app/features/groups/presentation/group_actions.dart';
import 'package:sms_sender_app/features/groups/presentation/group_detail_page.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/group_card.dart';
import 'package:sms_sender_app/features/groups/presentation/widgets/groups_summary_panel.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/features/history/presentation/server_messages_page.dart';
import 'package:sms_sender_app/l10n/strings.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';
import 'package:sms_sender_app/shared/widgets/message_composer.dart';
import 'package:sms_sender_app/shared/widgets/stat_tile.dart';
import 'package:sms_sender_app/sms_send_coordinator.dart';

enum _SendAction { refresh, serverTexts, clearSent, clearAll }

/// How the backend contact list is ordered before it is cut into groups.
enum ServerSort {
  server,
  byName,
  byPhone,
  unsentFirst;

  static ServerSort fromName(String? name) => ServerSort.values
      .firstWhere((v) => v.name == name, orElse: () => ServerSort.server);

  String label(S s) => switch (this) {
        ServerSort.server => s.sortServer,
        ServerSort.byName => s.sortByName,
        ServerSort.byPhone => s.sortByPhone,
        ServerSort.unsentFirst => s.sortUnsentFirst,
      };
}

/// Pure: backend contacts → unique, normalised, sorted recipients.
List<SmsRecipient> serverContactsToRecipients(
  List<database.Contact> contacts,
  ServerSort sort,
) {
  final seen = <String>{};
  final list = <SmsRecipient>[];
  for (final c in contacts) {
    final raw = c.phone_number.trim();
    if (raw.isEmpty) continue;
    final phone = PhoneNormalizer.normalize(raw) ?? raw;
    if (!seen.add(phone)) continue;
    list.add(
      SmsRecipient(
        phone: phone,
        name: c.title,
        status: c.isSent ? RecipientStatus.sent : RecipientStatus.pending,
      ),
    );
  }
  switch (sort) {
    case ServerSort.server:
      break;
    case ServerSort.byName:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case ServerSort.byPhone:
      list.sort((a, b) => a.phone.compareTo(b.phone));
    case ServerSort.unsentFirst:
      final pending = list.where((r) => !r.isSent).toList();
      final sent = list.where((r) => r.isSent).toList();
      return [...pending, ...sent];
  }
  return list;
}

/// The backend contact list, cut into groups of 100 (A, B, C…). "Send to
/// all" queues the groups one after another; a phone SMS limit pauses the
/// queue and it resumes by itself.
class SendPage extends ConsumerStatefulWidget {
  const SendPage({super.key});

  @override
  ConsumerState<SendPage> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  static const GroupSource _source = GroupSource.server;
  static const String _sortKey = 'server_sort';

  late final database.ApiService db;
  late final TextEditingController messageController;
  final TextEditingController _searchController = TextEditingController();
  final SmsSendCoordinator _sendCoordinator = SmsSendCoordinator();

  Timer? _debounce;
  bool _searching = false;
  bool _searchLoading = false;
  List<database.Contact> _results = const [];
  int totalCount = 0;
  int sentCount = 0;
  bool _syncing = false;
  bool _errorDialogOpen = false;
  ServerSort _sort = ServerSort.server;

  @override
  void initState() {
    super.initState();
    db = ref.read(apiServiceProvider);
    messageController = ref.read(messageControllerProvider);
    Permission.sms.request();
    _loadCounts();
    _restoreSort();
    Future.microtask(() async {
      await ref.read(groupsControllerProvider(_source).notifier).ready;
      if (!mounted) return;
      if (ref.read(groupsControllerProvider(_source)).isEmpty) await _sync();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    // messageController is owned by messageControllerProvider.
    super.dispose();
  }

  // ------------------------------------------------------------ backend

  Future<void> _loadCounts() async {
    try {
      final total = await db.getContactsCount();
      final sent = await db.getSentNumbersCount();
      if (!mounted) return;
      setState(() {
        totalCount = total;
        sentCount = sent;
      });
    } catch (error) {
      debugPrint('SendPage: counts failed: $error');
    }
  }

  Future<void> _restoreSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_sortKey);
      if (stored == null || !mounted) return;
      setState(() => _sort = ServerSort.fromName(stored));
    } catch (_) {}
  }

  Future<void> _selectSort(ServerSort sort) async {
    setState(() => _sort = sort);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortKey, sort.name);
    } catch (_) {}
    await _sync();
  }

  /// Loads every contact from the backend and rebuilds the server groups.
  /// Backend "sent" flags become sent statuses; custom group names survive.
  Future<void> _sync() async {
    if (_syncing) return;
    final s = S.of(context);
    final state = ref.read(groupsControllerProvider(_source));
    if (state.isSending) return;
    setState(() => _syncing = true);
    try {
      final contacts = await db.getAllContacts();
      final recipients = serverContactsToRecipients(contacts, _sort);
      final summary = await ref
          .read(groupsControllerProvider(_source).notifier)
          .importRecipients(recipients, replace: true, keepNames: true);
      await _loadCounts();
      _snack(s.syncResult(summary.imported, summary.groupsCreated));
    } catch (error) {
      _snack('${s.syncError}: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ------------------------------------------------------------- search

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final query = value.trim();
      if (query.isEmpty) {
        if (mounted) setState(() => _searching = false);
        return;
      }
      setState(() {
        _searching = true;
        _searchLoading = true;
      });
      try {
        final data = await db.searchContacts(query);
        if (!mounted) return;
        setState(() {
          _results = data;
          _searchLoading = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() => _searchLoading = false);
        _snack(error.toString());
      }
    });
  }

  // ------------------------------------------------------------ actions

  Future<void> _openAddContact() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddContactPage()),
    );
    await _sync();
  }

  Future<void> _onAction(_SendAction action) async {
    switch (action) {
      case _SendAction.refresh:
        await _sync();
      case _SendAction.serverTexts:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ServerMessagesPage()),
        );
      case _SendAction.clearSent:
        await _clearSent();
      case _SendAction.clearAll:
        await _clearAll();
    }
  }

  Future<void> _clearSent() async {
    final s = S.of(context);
    final ok = await _confirm(s.clearSentTitle, s.clearSentBody, s.reset);
    if (!ok || !mounted) return;
    try {
      await db.resetAllSent();
      await ref.read(groupsControllerProvider(_source).notifier).resetAll();
      await _loadCounts();
      _snack(s.clearSentDone);
    } catch (error) {
      _snack(s.deleteError(error));
    }
  }

  Future<void> _clearAll() async {
    final s = S.of(context);
    final ok = await _confirm(s.clearListTitle, s.clearListBody, s.delete);
    if (!ok || !mounted) return;
    try {
      await db.deleteAllContactsBatch();
      await ref.read(groupsControllerProvider(_source).notifier).clearAll();
      await _loadCounts();
    } catch (error) {
      _snack(s.deleteError(error));
    }
  }

  Future<bool> _confirm(String title, String body, String confirm) async {
    final s = S.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _sendSingleSms(String phone, String message) async {
    final multipart = SmsMessageInfo.analyze(message).isMultipart;
    final alreadySent = await db.isNumberSent(phone);
    if (alreadySent) return false;
    return _sendCoordinator.runPhoneSend(phone, () async {
      final result = await ref.read(smsSenderProvider).send(
            phone: phone,
            message: message,
            multipart: multipart,
          );
      if (!result.success) return false;
      final marked = await db.markNumberAsSentIfNeeded(phone);
      if (!marked) return false;
      if (mounted) setState(() => sentCount += 1);
      return true;
    });
  }

  Future<void> _sendToOne(String phone) async {
    final s = S.of(context);
    final message = messageController.text.trim();
    if (message.isEmpty) {
      _snack(s.enterMessage);
      return;
    }
    final alreadySent = await db.isNumberSent(phone);
    if (!mounted) return;
    if (alreadySent) {
      _snack(s.alreadySentToNumber);
      return;
    }

    final startedAt = DateTime.now();
    var success = false;
    String? error;
    try {
      success = await _sendSingleSms(phone, message);
      if (success) {
        unawaited(
          ref.read(balanceProvider.notifier).deduct(
                smsCount: 1,
                parts: SmsMessageInfo.analyze(message).parts,
              ),
        );
      }
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;

    await ref.read(campaignLogProvider.notifier).record(
          SmsCampaign.fromRun(
            message: message,
            source: CampaignSource.single,
            sourceLabel: phone,
            startedAt: startedAt,
            recipients: [
              CampaignRecipient(
                phone: phone,
                sent: success,
                error: success ? null : (error ?? s.notSent),
                sentAt: success ? DateTime.now() : null,
              ),
            ],
          ),
        );
    if (success) {
      try {
        await db.insertMessage(message);
      } catch (_) {}
      _snack(s.sentTo(phone));
    } else {
      _snack(s.failedTo(phone));
    }
  }

  Future<void> _deleteOne(String phone) async {
    final s = S.of(context);
    try {
      await db.deleteContact(phone);
      if (!mounted) return;
      setState(() {
        _results = [for (final c in _results) if (c.phone_number != phone) c];
        totalCount = math.max(totalCount - 1, 0);
      });
      _snack(s.deleted(phone));
      unawaited(_sync());
    } catch (error) {
      _snack(s.deleteError(error));
    }
  }

  void _showError(String message) {
    if (_errorDialogOpen) return;
    _errorDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _errorDialogOpen = false;
        return;
      }
      final s = S.of(context);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 10),
              Expanded(child: Text(s.sendStopped)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.understood),
            ),
          ],
        ),
      );
      _errorDialogOpen = false;
      if (mounted) {
        ref.read(groupsControllerProvider(_source).notifier).dismissError();
      }
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    ref.listen<String?>(
      groupsControllerProvider(_source).select((st) => st.errorMessage),
      (previous, next) {
        if (next != null && next != previous) _showError(next);
      },
    );

    final state = ref.watch(groupsControllerProvider(_source));
    final delayMs = ref.watch(sendDelayProvider);
    final balance = ref.watch(balanceProvider);
    final parts = SmsMessageInfo.analyze(messageController.text).parts;
    final partsForCost = parts == 0 ? 1 : parts;
    final actions = GroupActions(context, ref, source: _source);
    final notifier = ref.read(groupsControllerProvider(_source).notifier);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final remaining = math.max(totalCount - sentCount, 0);
    final canSendAll =
        !_searching && !state.isImporting && state.pendingGroupsCount > 0;

    return Scaffold(
      appBar: state.hasSelection
          ? AppBar(
              leading: IconButton(
                tooltip: s.clearSelection,
                icon: const Icon(Icons.close),
                onPressed: notifier.clearSelection,
              ),
              title: Text(s.selected(state.selectedIds.length)),
              actions: [
                IconButton(
                  tooltip: s.selectAll,
                  icon: const Icon(Icons.select_all),
                  onPressed: notifier.selectAllPending,
                ),
                IconButton(
                  tooltip: s.sendSelected,
                  icon: const Icon(Icons.send),
                  onPressed: state.isImporting ? null : actions.sendSelected,
                ),
              ],
            )
          : AppBar(
              leading: const ShellMenuButton(),
              title: Text(s.sendTitle),
              actions: [
                IconButton(
                  tooltip: s.syncFromServer,
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: _syncing || state.isSending ? null : _sync,
                ),
                PopupMenuButton<ServerSort>(
                  tooltip: s.sortLabel,
                  icon: const Icon(Icons.sort),
                  enabled: !_syncing && !state.isSending,
                  onSelected: _selectSort,
                  itemBuilder: (_) => [
                    for (final sort in ServerSort.values)
                      PopupMenuItem(
                        value: sort,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            sort == _sort
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(sort.label(s)),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: s.drawerAddNumber,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: _openAddContact,
                ),
                PopupMenuButton<_SendAction>(
                  tooltip: s.more,
                  onSelected: _onAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _SendAction.refresh,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.refresh),
                        title: Text(s.refreshList),
                      ),
                    ),
                    PopupMenuItem(
                      value: _SendAction.serverTexts,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.cloud_outlined),
                        title: Text(s.drawerServerTexts),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: _SendAction.clearSent,
                      enabled: !state.isSending,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.cleaning_services_outlined, color: t.warning),
                        title: Text(s.clearSent),
                      ),
                    ),
                    PopupMenuItem(
                      value: _SendAction.clearAll,
                      enabled: totalCount > 0 && !state.isSending,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_sweep_outlined, color: t.danger),
                        title: Text(s.deleteAllNumbers),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: _searching
          ? null
          : FloatingActionButton.extended(
              onPressed: canSendAll ? actions.sendAll : null,
              backgroundColor: canSendAll ? null : scheme.surfaceContainerHighest,
              foregroundColor: canSendAll ? null : scheme.onSurfaceVariant,
              icon: Icon(state.isSending ? Icons.playlist_add : Icons.send),
              label: Text(state.isSending ? s.queueAll(state.pendingGroupsCount) : s.sendToAll),
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: MessageComposer(
                      controller: messageController,
                      enabled: !state.isSending,
                      minLines: 2,
                      maxLines: 5,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: s.totalNumbers,
                        value: '$totalCount',
                        icon: Icons.people_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: s.sentLabel,
                        value: '$sentCount',
                        subtitle: totalCount > 0 ? s.remainingN(remaining) : null,
                        icon: Icons.check_circle_outline,
                        color: t.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: s.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _searching
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            if (_searching)
              _buildSearchResults(s, scheme)
            else ...[
              if (_syncing)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      children: [
                        const LinearProgressIndicator(),
                        const SizedBox(height: 6),
                        Text(
                          s.syncing,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!state.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: GroupsSummaryPanel(
                      state: state,
                      delayMs: delayMs,
                      onDelayChanged: (ms) =>
                          ref.read(sendDelayProvider.notifier).select(ms),
                      onSendAll: actions.sendAll,
                      onStop: actions.stop,
                      onResumeNow: actions.resumeNow,
                      balance: balance,
                      onCheckBalance: () =>
                          ref.read(balanceProvider.notifier).checkViaSms(),
                      onDequeue: (id) {
                        final group = state.groupById(id);
                        if (group != null) actions.dequeue(group);
                      },
                    ),
                  ),
                ),
              _buildGroups(state, actions, balance, partsForCost),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroups(
    GroupsState state,
    GroupActions actions,
    BalanceState balance,
    int partsForCost,
  ) {
    if (state.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _syncing
            ? const SizedBox.shrink()
            : _EmptyNumbers(onAdd: _openAddContact, onSync: _sync),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 96),
      sliver: SliverList.builder(
        itemCount: state.groups.length,
        itemBuilder: (context, index) {
          final group = state.groups[index];
          final c = group.counters;
          return GroupCard(
            key: ValueKey(group.id),
            group: group,
            isActive: state.activeGroupId == group.id,
            actionsEnabled: !state.isImporting && !_syncing,
            queuePosition: state.queuePosition(group.id),
            selectionMode: state.hasSelection,
            selected: state.isSelected(group.id),
            onToggleSelected: () => ref
                .read(groupsControllerProvider(_source).notifier)
                .toggleSelected(group.id),
            onDequeue: () => actions.dequeue(group),
            onRename: () => actions.rename(group),
            costLabel: c.remaining > 0
                ? '≈ ${formatManat(balance.cost(c.remaining, partsForCost))}'
                : null,
            onSend: () => actions.sendGroup(group),
            onReset: () => actions.resetGroup(group),
            onRemove: () => actions.removeGroup(group),
            onOpen: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    GroupDetailPage(groupId: group.id, source: _source),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(S s, ColorScheme scheme) {
    if (_searchLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_results.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(s.noMatches, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      sliver: SliverList.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final c = _results[index];
          return _ContactTile(
            name: c.title,
            phone: c.phone_number,
            isSent: c.isSent,
            onSend: () => _sendToOne(c.phone_number),
            onDelete: () => _deleteOne(c.phone_number),
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.name,
    required this.phone,
    required this.isSent,
    required this.onSend,
    required this.onDelete,
  });

  final String name;
  final String phone;
  final bool isSent;
  final VoidCallback onSend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '#';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        title: Text(
          phone,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [if (name.isNotEmpty) name, if (isSent) s.statusSent].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: s.sendToThisNumber,
              icon: Icon(Icons.send_outlined, color: t.success),
              onPressed: onSend,
            ),
            IconButton(
              tooltip: s.deleteNumber,
              icon: Icon(Icons.delete_outline, color: t.danger),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNumbers extends StatelessWidget {
  const _EmptyNumbers({required this.onAdd, required this.onSync});

  final VoidCallback onAdd;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contact_phone_outlined, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              s.noNumbersTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              s.noNumbersHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(s.drawerAddNumber),
                ),
                OutlinedButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(s.syncFromServer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
