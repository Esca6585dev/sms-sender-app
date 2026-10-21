import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sms_sender_app/app/app_shell.dart' show ShellMenuButton;
import 'package:sms_sender_app/core/device/device_bridge.dart';
import 'package:sms_sender_app/core/sms/sms_message_info.dart';
import 'package:sms_sender_app/database.dart' as database;
import 'package:sms_sender_app/features/balance/balance_controller.dart';
import 'package:sms_sender_app/features/contacts/add_contact_page.dart';
import 'package:sms_sender_app/features/groups/application/groups_providers.dart';
import 'package:sms_sender_app/features/history/application/campaign_log_controller.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';
import 'package:sms_sender_app/features/history/presentation/server_messages_page.dart';
import 'package:sms_sender_app/shared/providers/app_providers.dart';
import 'package:sms_sender_app/shared/widgets/message_composer.dart';
import 'package:sms_sender_app/shared/widgets/stat_tile.dart';
import 'package:sms_sender_app/sms_send_coordinator.dart';

enum _SendAction { refresh, serverTexts, clearSent, clearAll }

class SendPage extends ConsumerStatefulWidget {
  const SendPage({super.key});

  @override
  ConsumerState<SendPage> createState() => _SendPageState();
}

class _SendPageState extends ConsumerState<SendPage> {
  List<Map<String, dynamic>> numbers = [];
  List<Map<String, dynamic>> allNumbers = [];
  List<Map<String, dynamic>> filteredNumbers = [];
  String searchQuery = '';
  Timer? _debounce;
  bool isFirstLoading = true;
  int totalCount = 0;
  int sentCount = 0;
  String? nextCursor;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool isSearching = false;
  bool isSending = false;
  bool stopSending = false;

  final ScrollController _scrollController = ScrollController();

  late final database.ApiService db;

  final TextEditingController numberController = TextEditingController();
  final TextEditingController nameController =
      TextEditingController();

  /// Shared with [GroupsPage] through [messageControllerProvider].
  late final TextEditingController messageController;

  final SmsSendCoordinator _sendCoordinator = SmsSendCoordinator();

  @override
  void initState() {
    super.initState();
    db = ref.read(apiServiceProvider);
    messageController = ref.read(messageControllerProvider);
    requestPermission();
    loadCount();
    loadSentCount();
    loadContacts();

    _scrollController.addListener(_handleScrollReachedEnd);
  }

  void _handleScrollReachedEnd() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      loadMore();
    }
  }

  Future<void> showLoadingDialog(String text) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showProgressDialog({
    required String title,
    required Future<void> Function(Function(int, String)) task,
    bool showStopButton = false,
  }) async {
    int progress = 0;
    String stepText = "Начало...";

    late StateSetter setStateDialog;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            setStateDialog = setState;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(title),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress / 100,
                  ),

                  const SizedBox(height: 12),

                  Text("$progress%"),

                  const SizedBox(height: 8),

                  Text(stepText),
                ],
              ),

              actions: [

                if (showStopButton)
                  TextButton.icon(
                    icon: const Icon(
                      Icons.stop_circle,
                      color: Colors.red,
                    ),

                    label: const Text(
                      "Остановить",
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),

                    onPressed: () {

                      setState(() {
                        stopSending = true;
                      });

                    },
                  ),

              ],
            );
          },
        );
      },
    );


    await Future.delayed(
      const Duration(milliseconds: 100),
    );


    await task((p, text) {

      if (mounted) {
        setStateDialog(() {

          progress = p;
          stepText = text;

        });
      }

    });
  }

  Future<void> loadAllContacts() async {

    final contacts = await db.getAllContacts();

    if (!mounted) return;

    setState(() {

      numbers = contacts.map((e) => {
        "title": e.title,
        "phone_number": e.phone_number,
      }).toList();

      isFirstLoading = false;

    });

  }

  Future<void> loadContacts() async {

    final result = await db.getContacts();


    setState(() {

      numbers = List<Map<String,dynamic>>.from(
        result["results"].map((e)=>{

          "title": e["title"],
          "phone_number": e["phone_number"],

        })
      );


      nextCursor = result["next"];

      hasMore = nextCursor != null;

      isFirstLoading = false;

    });

  }

  Future<void> loadMore() async {

    if(isLoadingMore || !hasMore){
      return;
    }


    setState(() {
      isLoadingMore = true;
    });


    final result = await db.getContacts(
      nextUrl: nextCursor,
    );


    final newItems = List<Map<String,dynamic>>.from(
      result["results"].map((e)=>{

        "title": e["title"],
        "phone_number": e["phone_number"],

      })
    );


    setState(() {

      numbers.addAll(newItems);

      nextCursor = result["next"];

      hasMore = nextCursor != null;

      isLoadingMore = false;

    });

  }

  Future<void> clearSentNumbers() async {

    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Очистить отправленные?"),
        content: const Text(
          "Будут удалены все номера из списка отправленных SMS",
        ),
        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить"),
          ),

        ],
      ),
    );


    if (confirm != true) return;


    await showLoadingDialog(
      "Удаление отправленных номеров...",
    );


    try {

      await db.resetAllSent();

      await loadSentCount();


      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Список отправленных номеров очищен",
          ),
        ),
      );


    } catch (e) {

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Ошибка удаления: $e",
          ),
        ),
      );

    }
  }

  Future<void> loadSentCount() async {
    final count = await db.getSentNumbersCount();

    if (!mounted) return;

    setState(() {
      sentCount = count;
    });
  }

  Future<void> openDelayDialog() async {
    int delayMs = 500;

    final result = await showDialog<int>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Задержка отправки"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Выбери задержку между SMS"),

                  const SizedBox(height: 12),

                  RadioListTile(
                    title: const Text("Без задержки"),
                    value: 0,
                    groupValue: delayMs,
                    onChanged: (v) => setState(() => delayMs = v!),
                  ),

                  RadioListTile(
                    title: const Text("0.5 сек"),
                    value: 500,
                    groupValue: delayMs,
                    onChanged: (v) => setState(() => delayMs = v!),
                  ),

                  RadioListTile(
                    title: const Text("1 сек"),
                    value: 1000,
                    groupValue: delayMs,
                    onChanged: (v) => setState(() => delayMs = v!),
                  ),

                  RadioListTile(
                    title: const Text("2 сек"),
                    value: 2000,
                    groupValue: delayMs,
                    onChanged: (v) => setState(() => delayMs = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Отмена"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, delayMs),
                  child: const Text("Старт"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      sendSMS(delayMs);
    }
  }


  Future<void> loadAllNumbers() async {
    final data = await db.getAllContacts();

    allNumbers = data
        .map((e) => {"title": e.title, "phone_number": e.phone_number})
        .toList();
  }


  Future<void> clearAllNumbers() async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Очистить список?"),
        content: const Text("Все номера будут удалены"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await showProgressDialog(
      title: "Удаление...",
      task: (update) async {
        update(10, "Подготовка...");

        await Future.delayed(const Duration(milliseconds: 300));

        update(40, "Удаляем контакты...");
        await db.deleteAllContactsBatch();

        update(80, "Обновляем данные...");
        await loadCount();
        await loadContacts();

        update(100, "Готово");

        await Future.delayed(const Duration(milliseconds: 500));

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> loadCount() async {
    final count = await db.getContactsCount();

    setState(() {
      totalCount = count;
    });
  }

  Future<void> requestPermission() async {
    await Permission.sms.request();
  }

  Future<void> removeNumber(String phone) async {
    await db.deleteContact(phone);
    await loadCount();
    await loadContacts();
  }

  Future<void> saveMessage(String text) async {
    await db.insertMessage(text);
  }

  Future<bool> sendSingleSms({
    required String phone,
    required String message,
    required bool multipart,
  }) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      return false;
    }

    final bool alreadySent = await db.isNumberSent(normalizedPhone);
    if (alreadySent) {
      return false;
    }

    return _sendCoordinator.runPhoneSend(normalizedPhone, () async {
      final result = await ref.read(smsSenderProvider).send(
            phone: normalizedPhone,
            message: message,
            multipart: multipart,
          );

      if (!result.success) {
        return false;
      }

      final marked = await db.markNumberAsSentIfNeeded(normalizedPhone);
      if (!marked) {
        return false;
      }

      if (mounted) {
        setState(() {
          sentCount += 1;
        });
      }

      return true;
    });
  }

  Future<void> sendSMS([int delayMs = 0]) async {
    final message = messageController.text.trim();

    if (message.isEmpty || totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполни поля')),
      );
      return;
    }

    if (isSending) return;

    if (!mounted) return;

    setState(() {
      isSending = true;
    });

    final contacts = await db.getAllContacts();
    final sendList = contacts
        .where((e) => e.phone_number.trim().isNotEmpty)
        .map((e) => {
              'title': e.title,
              'phone_number': e.phone_number,
              'is_sent': e.isSent,
            })
        .toList();

    if (sendList.isEmpty) {
      if (!mounted) return;
      setState(() {
        isSending = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Нет номеров для отправки"),
        ),
      );

      return;
    }

    await showProgressDialog(
      title: "Отправка SMS",
      showStopButton: true,
      task: (update) async {
        final int total = sendList.length;
        final info = SmsMessageInfo.analyze(message);
        final bool multipart = info.isMultipart;
        final bridge = ref.read(deviceBridgeProvider);
        final balance = ref.read(balanceProvider.notifier);

        int sent = 0;
        final startedAt = DateTime.now();
        final processed = <CampaignRecipient>[];

        stopSending = false;
        unawaited(bridge.startSending('Рассылка SMS', 'Все номера: 0 / $total'));
        unawaited(bridge.keepScreenOn(true));

        for (int i = 0; i < sendList.length; i++) {
          if (stopSending || !mounted) {
            break;
          }

          final phone = sendList[i]['phone_number'].toString();
          final alreadySent = await db.isNumberSent(phone);
          if (alreadySent) {
            continue;
          }

          try {
            final success = await sendSingleSms(
              phone: phone,
              message: message,
              multipart: multipart,
            );
            processed.add(
              CampaignRecipient(
                phone: phone,
                name: (sendList[i]['title'] ?? '').toString(),
                sent: success,
                error: success ? null : 'Не отправлено',
                sentAt: success ? DateTime.now() : null,
              ),
            );
            if (success) {
              unawaited(balance.deduct(smsCount: 1, parts: info.parts));
            }

            if (!success) {
              if (delayMs > 0 && mounted) {
                await Future.delayed(Duration(milliseconds: delayMs));
              }
              continue;
            }
          } catch (e, stack) {
            debugPrint('ERROR: $e');
            debugPrintStack(stackTrace: stack);
            stopSending = true;
            processed.add(
              CampaignRecipient(
                phone: phone,
                name: (sendList[i]['title'] ?? '').toString(),
                sent: false,
                error: e.toString(),
              ),
            );
            unawaited(bridge.stopSending());
            unawaited(bridge.keepScreenOn(false));
            await _recordCampaign(
              message: message,
              startedAt: startedAt,
              processed: processed,
            );

            if (!mounted) return;
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 30),
                    SizedBox(width: 10),
                    Text('Отправка остановлена'),
                  ],
                ),
                content: const Text(
                  'Достигнут лимит отправки SMS или оператор временно запретил отправку.\n\nПопробуйте позже.',
                  style: TextStyle(fontSize: 16),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Понятно'),
                  )
                ],
              ),
            );

            return;
          }

          sent++;
          final percent = ((sent / total) * 100).toInt();
          update(percent, 'Отправлено $sent из $total');
          unawaited(
            bridge.updateSending('Рассылка SMS', 'Все номера: $sent / $total'),
          );

          if (delayMs > 0 && mounted) {
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }

        unawaited(bridge.stopSending());
        unawaited(bridge.keepScreenOn(false));
        await _recordCampaign(
          message: message,
          startedAt: startedAt,
          processed: processed,
        );
        await saveMessage(message);

        if (stopSending) {
          update(100, 'Остановлено пользователем');
        } else {
          update(100, 'Завершено');
        }

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SMS отправлены')),
    );

    if (mounted) {
      setState(() {
        isSending = false;
      });
    }
  }

  void openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServerMessagesPage()),
    );
  }

  // ------------------------------------------------------------------ UI

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (value.trim().isEmpty) {
        isSearching = false;
        await loadContacts();
        return;
      }

      isSearching = true;
      final data = await db.searchContacts(value);
      if (!mounted) return;

      setState(() {
        numbers = data
            .map((e) => {"title": e.title, "phone_number": e.phone_number})
            .toList();
      });
    });
  }

  Future<void> _openAddContact() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddContactPage()),
    );
    await loadCount();
    await loadContacts();
  }

  Future<void> _onAction(_SendAction action) async {
    switch (action) {
      case _SendAction.refresh:
        await loadCount();
        await loadSentCount();
        await loadContacts();
      case _SendAction.serverTexts:
        openHistory();
      case _SendAction.clearSent:
        await clearSentNumbers();
      case _SendAction.clearAll:
        await clearAllNumbers();
    }
  }

  Future<void> _sendToOne(String phone) async {
    final message = messageController.text.trim();
    final bool multipart = SmsMessageInfo.analyze(message).isMultipart;

    if (message.isEmpty) {
      _snack('Введите текст сообщения');
      return;
    }

    final alreadySent = await db.isNumberSent(phone);
    if (!mounted) return;
    if (alreadySent) {
      _snack('На этот номер SMS уже была отправлена');
      return;
    }

    await showLoadingDialog('Отправка SMS...');
    final startedAt = DateTime.now();
    var success = false;
    String? error;

    try {
      success = await sendSingleSms(
        phone: phone,
        message: message,
        multipart: multipart,
      );
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

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    if (!mounted) return;

    await _recordCampaign(
      message: message,
      startedAt: startedAt,
      source: CampaignSource.single,
      label: phone,
      processed: [
        CampaignRecipient(
          phone: phone,
          sent: success,
          error: success ? null : (error ?? 'Не отправлено'),
          sentAt: success ? DateTime.now() : null,
        ),
      ],
    );

    if (success) {
      await saveMessage(message);
      _snack('Отправлено: $phone');
    } else {
      _snack('Не удалось отправить: $phone');
    }
  }

  Future<void> _deleteOne(String phone) async {
    await showLoadingDialog("Удаление номера...");
    await db.deleteContact(phone);
    if (!mounted) return;

    setState(() {
      numbers.removeWhere((n) => n["phone_number"] == phone);
      totalCount--;
    });

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    _snack("Удалён: $phone");
  }

  Future<void> _recordCampaign({
    required String message,
    required DateTime startedAt,
    required List<CampaignRecipient> processed,
    CampaignSource source = CampaignSource.all,
    String label = 'Все номера',
  }) async {
    if (processed.isEmpty) return;
    await ref.read(campaignLogProvider.notifier).record(
          SmsCampaign.fromRun(
            message: message,
            source: source,
            sourceLabel: label,
            startedAt: startedAt,
            recipients: processed,
          ),
        );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSend = numbers.isNotEmpty && !isSending;
    final remaining = math.max(totalCount - sentCount, 0);

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('Рассылка'),
        actions: [
          IconButton(
            tooltip: 'Добавить номер',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _openAddContact,
          ),
          PopupMenuButton<_SendAction>(
            tooltip: 'Ещё',
            onSelected: _onAction,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _SendAction.refresh,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh),
                  title: Text('Обновить список'),
                ),
              ),
              const PopupMenuItem(
                value: _SendAction.serverTexts,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('Тексты на сервере'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _SendAction.clearSent,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.cleaning_services_outlined,
                      color: Colors.orange),
                  title: Text('Сбросить отправленные'),
                ),
              ),
              PopupMenuItem(
                value: _SendAction.clearAll,
                enabled: numbers.isNotEmpty,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_sweep_outlined, color: Colors.red),
                  title: Text('Удалить все номера'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canSend ? openDelayDialog : null,
        backgroundColor: canSend ? null : scheme.surfaceContainerHighest,
        foregroundColor: canSend ? null : scheme.onSurfaceVariant,
        icon: Icon(isSending ? Icons.hourglass_top : Icons.send),
        label: Text(isSending ? 'Отправка…' : 'Отправить всем'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: MessageComposer(
                    controller: messageController,
                    enabled: !isSending,
                    minLines: 2,
                    maxLines: 5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Всего номеров',
                      value: '$totalCount',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      label: 'Отправлено',
                      value: '$sentCount',
                      subtitle: totalCount > 0 ? 'осталось $remaining' : null,
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Поиск номера или имени',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: isFirstLoading
                  ? const Center(child: CircularProgressIndicator())
                  : numbers.isEmpty
                      ? _EmptyContacts(onAdd: _openAddContact)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                          itemCount: numbers.length + (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == numbers.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final item = numbers[index];
                            final phone = (item["phone_number"] ?? '').toString();
                            return _ContactTile(
                              name: (item["title"] ?? '').toString(),
                              phone: phone,
                              enabled: !isSending,
                              onSend: () => _sendToOne(phone),
                              onDelete: () => _deleteOne(phone),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_handleScrollReachedEnd);
    _scrollController.dispose();
    nameController.dispose();
    numberController.dispose();
    // messageController is owned by messageControllerProvider.
    super.dispose();
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.name,
    required this.phone,
    required this.enabled,
    required this.onSend,
    required this.onDelete,
  });

  final String name;
  final String phone;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
        subtitle: name.isNotEmpty
            ? Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Отправить этому номеру',
              icon: const Icon(Icons.send_outlined, color: Colors.green),
              onPressed: enabled ? onSend : null,
            ),
            IconButton(
              tooltip: 'Удалить номер',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: enabled ? onDelete : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contact_phone_outlined, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text(
              'Номеров пока нет',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Добавьте номера вручную, из контактов или импортируйте Excel.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Добавить номер'),
            ),
          ],
        ),
      ),
    );
  }
}
