import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'database.dart' as database;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'sms_send_coordinator.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SMS Sender',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
  int maxLength = 160;
  bool isMessageTooLong = false;

  final ScrollController _scrollController = ScrollController();

  late final database.ApiService db;

  final TextEditingController numberController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  final TextEditingController nameController =
      TextEditingController();

  final Telephony telephony = Telephony.instance;
  final SmsSendCoordinator _sendCoordinator = SmsSendCoordinator();

  @override
  void initState() {
    super.initState();
    db = database.ApiService();
    requestPermission();
    loadCount();
    loadSentCount();
    loadContacts();

    _scrollController.addListener(_handleScrollReachedEnd);
    messageController.addListener(_handleMessageChanged);
  }

  void _handleScrollReachedEnd() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      loadMore();
    }
  }

  void _handleMessageChanged() {
    final text = messageController.text;

    if (!mounted) return;

    setState(() {
      isMessageTooLong = text.length > maxLength;
    });
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
    required bool isLongMessage,
    required bool isSeventySevenLimit,
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
      final completer = Completer<bool>();

      telephony.sendSms(
        to: normalizedPhone,
        message: message,
        isMultipart: isLongMessage || isSeventySevenLimit,
        statusListener: (SendStatus status) {
          if (completer.isCompleted) return;

          if (status == SendStatus.SENT || status == SendStatus.DELIVERED) {
            completer.complete(true);
          }
        },
      );

      final success = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (!success) {
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

    if (isMessageTooLong) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщение слишком длинное')),
      );
      return;
    }

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
        .where((e) => (e.phone_number ?? '').trim().isNotEmpty)
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

        const int singleSmsLimit = 160;
        const int seventySevenCharLimit = 70;

        final bool isLongMessage = message.length > singleSmsLimit;
        final bool isSeventySevenLimit = message.length > seventySevenCharLimit;

        int sent = 0;

        stopSending = false;

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
              isLongMessage: isLongMessage,
              isSeventySevenLimit: isSeventySevenLimit,
            );

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

          if (delayMs > 0 && mounted) {
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }

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
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  Widget buildCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            ClipOval(
              child: Image.asset(
                'assets/elite_logo.jpg',
                width: 33,
                height: 33,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(width: 10),

            RichText(
              text: const TextSpan(
                children: [

                  TextSpan(
                    text: 'elite',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  TextSpan(
                    text: '-elektronika',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],
              ),
            ),

          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              buildCard(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Поиск номера или имени',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();

                    _debounce = Timer(
                      const Duration(milliseconds: 200),
                      () async {
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
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Текст сообщения',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.message),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "${messageController.text.length} / $maxLength",
                          style: TextStyle(
                            color: isMessageTooLong ? Colors.red : Colors.grey,
                            fontWeight: isMessageTooLong ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [

                    SizedBox(
                      width: 220,
                      child: ElevatedButton(
                        onPressed: clearSentNumbers,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),

                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            Icon(Icons.cleaning_services),

                            SizedBox(width: 8),

                            Text(
                              'Очистить отправленные',
                            ),

                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddContactPage()),
                          );

                          await loadCount();
                          await loadContacts();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add),
                            SizedBox(width: 8),
                            Text('Добавить номер'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: numbers.isEmpty || isSending || isMessageTooLong
                          ? null
                          : () => openDelayDialog(),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send),
                            SizedBox(width: 8),
                            Text('Отправить всем'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: numbers.isEmpty ? null : clearAllNumbers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_sweep),
                            SizedBox(width: 8),
                            Text('Очистить список'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: openHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history),
                            SizedBox(width: 8),
                            Text('История'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Всего номеров",
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                        Text(
                          "$totalCount",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Отправлено",
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                        Text(
                          "$sentCount",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              ),

              Expanded(
                child: isFirstLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : numbers.isEmpty
                    ? const Center(child: Text('Нет номеров'))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: numbers.length + (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == numbers.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = numbers[index];

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(Icons.phone),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["title"] ?? "",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    item["phone_number"] ?? "",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.green,
                                    ),
                                    onPressed: () async {
                                      final localContext = context;
                                      final phone = item["phone_number"]!.toString();
                                      final message = messageController.text.trim();

                                      const int singleSmsLimit = 160;
                                      const int seventySevenCharLimit = 70;

                                      final bool isLongMessage = message.length > singleSmsLimit;
                                      final bool isSeventySevenLimit = message.length > seventySevenCharLimit;

                                      if (message.isEmpty) {
                                        ScaffoldMessenger.of(localContext).showSnackBar(
                                          const SnackBar(content: Text('Введите текст сообщения')),
                                        );
                                        return;
                                      }

                                      final alreadySent = await db.isNumberSent(phone);
                                      if (alreadySent) {
                                        ScaffoldMessenger.of(localContext).showSnackBar(
                                          const SnackBar(
                                            content: Text('На этот номер SMS уже была отправлена'),
                                          ),
                                        );
                                        return;
                                      }

                                      await showLoadingDialog('Отправка SMS...');

                                      final success = await sendSingleSms(
                                        phone: phone,
                                        message: message,
                                        isLongMessage: isLongMessage,
                                        isSeventySevenLimit: isSeventySevenLimit,
                                      );

                                      if (mounted && Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }

                                      if (!mounted) return;

                                      if (success) {
                                        await saveMessage(message);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Отправлено: $phone')),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Не удалось отправить: $phone')),
                                        );
                                      }
                                    }
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final phone = item["phone_number"]!;

                                      await showLoadingDialog("Удаление номера...");

                                      await db.deleteContact(phone);

                                      setState(() {
                                        numbers.removeWhere((n) => n["phone_number"] == phone);
                                        totalCount--; 
                                      });

                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Удалён: $phone")),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_handleScrollReachedEnd);
    messageController.removeListener(_handleMessageChanged);
    _scrollController.dispose();
    nameController.dispose();
    numberController.dispose();
    messageController.dispose();
    super.dispose();
  }  
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, Object?>> allMessages = [];
  List<Map<String, Object?>> filteredMessages = [];
  String searchQuery = '';
  final db = database.ApiService();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadMessages().then((_) {
    });
  }

  void filterMessages() {
    if (searchQuery.isEmpty) {
      filteredMessages = allMessages;
    } else {
      filteredMessages = allMessages.where((msg) {
        final text = msg['text'].toString().toLowerCase();
        return text.contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> loadMessages() async {
    setState(() {
      isLoading = true;
    });

    final data = await db.getMessages();
    if (!mounted) return;

    setState(() {
      allMessages = data
          .map((e) => {"id": e.id, "text": e.messageText, "date": e.date})
          .toList();
    });

    filterMessages();

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Истории отправленные'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              if (!mounted) return;
              final dialogContext = context;
              final confirm = await showDialog(
                context: dialogContext,
                builder: (_) => AlertDialog(
                  title: const Text("Удалить всё?"),
                  content: const Text("Это действие нельзя отменить"),
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

              if (!mounted) return;
              if (confirm == true) {
                setState(() => isLoading = true);

                await db.deleteAllMessages();
                await loadMessages();
                if (!mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('История очищена')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'Поиск сообщений...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                searchQuery = value;
                filterMessages();
                setState(() {});
              },
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
              : filteredMessages.isEmpty
                ? const Center(child: Text("История пуста"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      final data = filteredMessages[index];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.message,
                            color: Colors.indigo,
                          ),
                          title: Text((data['text'] as String?) ?? ''),
                          subtitle: Text((data['date'] as String?) ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final id = data['id'] as int?;
                              if (id != null) {
                                await db.deleteMessage(id);
                                await loadMessages();
                                filterMessages();
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  List<Map<String, dynamic>> numbers = [];
  List<Map<String, dynamic>> filteredNumbers = [];
  String searchQuery = '';
  String addMode = 'manual';
  late database.ApiService db;
  bool isFirstLoading = true;
  int totalCount = 0;
  int sentCount = 0;
  static const int maxContacts = 5000;
  bool isImporting = false;
  double importProgress = 0;
  bool isAdding = false;
  bool isAddingFromContacts = false;

  int importedCount = 0;
  int totalCountExcel = 0;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    db = database.ApiService();
    loadMode();
    loadNumbers();
    loadCount();
  }

  Future<void> showAddLoading() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "Добавление номера...",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool canAddMore(int countToAdd) {
    if (totalCount + countToAdd > maxContacts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Максимум $maxContacts номеров. Сейчас: $totalCount",
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null) return;

    setState(() {
      isImporting = true;
      importProgress = 0;
      importedCount = 0;
    });

    final file = result.files.first;

    late List<int> bytes;

    if (file.bytes != null) {
      bytes = file.bytes!;
    } else {
      final path = file.path!;
      bytes = await File(path).readAsBytes();
    }

    final excelFile = excel.Excel.decodeBytes(bytes);

    if (excelFile.tables.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel файл пустой')));
      setState(() => isImporting = false);
      return;
    }

    var sheet = excelFile.tables[excelFile.tables.keys.first]!;

    totalCountExcel = sheet.rows.length;

    int available = maxContacts - totalCount;

    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Достигнут лимит $maxContacts")),
      );
      setState(() => isImporting = false);
      return;
    }

    List<Map<String, String>> batch = [];

    const batchSize = 200;

    int limit = sheet.rows.length > available ? available : sheet.rows.length;

    for (int i = 0; i < limit; i++) {
      final row = sheet.rows[i];

      if (row.length < 4) continue;

      String name = row[2]?.value.toString() ?? "";
      String phone = row[3]?.value.toString() ?? "";

      phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
        
      if (phone.startsWith('993')) {
        phone = '+$phone';
      } else if (!phone.startsWith('+993')) {
        phone = '+993$phone';

      }

      batch.add({'title': name, 'phone_number': phone});

      if (batch.length >= batchSize || i == sheet.rows.length - 1) {
        await db.insertContactsBatch(batch);
        batch.clear();

        importedCount = i + 1;
        importProgress = importedCount / totalCountExcel;

        setState(() {});

        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    await loadCount();
    await loadNumbers();

    setState(() {
      isImporting = false;
      importProgress = 0;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Импортировано: $importedCount")));
  }

  Future<void> addNumber() async {
    String name = nameController.text.trim();
    String number = numberController.text.trim();

    if (isAdding) return;

    number = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final isValid = RegExp(r'^\+993\d{8}$').hasMatch(number);

    if (name.isEmpty) {
      name = "Без имени";
    }


    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный формат номера')),
      );
      return;
    }

    if (numbers.any((n) => n['phone_number'] == number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот номер уже добавлен')),
      );
      return;
    }

    if (!canAddMore(1)) return;

    setState(() {
      isAdding = true;
    });

    await showAddLoading();

    try {
      await db.insertContact(name, number);
      await loadCount();
      await loadNumbers();
      filterNumbers();
    } catch (e) {
      print(e);
    } finally {
      if (mounted) {
        setState(() {
          isAdding = false;
        });
      }
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Номер добавлен")),
    );

    setState(() {
      isAdding = false;
    });

    numberController.clear();
    nameController.clear();
  }

  Widget buildCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: child,
      ),
    );
  }

  Future<void> loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      addMode = prefs.getString('add_mode') ?? addMode;
    });
  }

  Future<void> loadCount() async {
    final count = await db.getContactsCount();

    setState(() {
      totalCount = count;
    });
  }

  Future<void> saveMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('add_mode', mode);
  }

  void filterNumbers() {
    if (searchQuery.isEmpty) {
      filteredNumbers = numbers;
    } else {
      filteredNumbers = numbers.where((item) {
        return item["phone_number"]!.contains(searchQuery) ||
            item["title"]!.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> loadNumbers() async {
    final data = await db.getAllContacts();

    numbers = data
        .map(
          (contact) => {
            'id': contact.id,
            'title': contact.title,
            'phone_number': contact.phone_number,
          },
        )
        .toList();

    if (!mounted) return;

    setState(() {
      isFirstLoading = false; 
      filterNumbers();
    });
  }

  Future<void> pickFromContacts() async {
    final contactPermission = await Permission.contacts.request();
    if (!contactPermission.isGranted) return;

    final allContacts = await FlutterContacts.getContacts(withProperties: true);
    
    if (!mounted) return;
    final sheetContext = context;

    Set<String> selectedPhones = {};


    await showModalBottomSheet(
      context: sheetContext,
      isScrollControlled: true,
      builder: (context) {

        TextEditingController searchController = TextEditingController();
        List<Contact> filteredContacts = allContacts;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Выбери контакты",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск контакта...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          filteredContacts = allContacts.where((c) {
                            final name = c.displayName.toLowerCase();
                            final phone = c.phones.isNotEmpty
                                ? c.phones.first.number
                                : "";

                            return name.contains(value.toLowerCase()) ||
                                phone.contains(value);
                          }).toList();
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Выбрано: ${selectedPhones.length} / ${allContacts.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (selectedPhones.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                selectedPhones.clear();
                              });
                            },
                            child: const Text("Снять все"),
                          ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              selectedPhones = allContacts
                                .where((c) => c.phones.isNotEmpty)
                                .map((c) => c.phones.first.number
                                    .replaceAll(RegExp(r'[^0-9+]'), ''))
                                .toSet();
                            });
                          },
                          child: const Text("Выбрать все"),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredContacts.length,
                      itemBuilder: (_, i) {
                        if (i == filteredContacts.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final c = filteredContacts[i];

                        if (c.phones.isEmpty) return const SizedBox();


                        final phoneRaw = c.phones.first.number;
                        final phone = phoneRaw.replaceAll(
                          RegExp(r'[^0-9+]'),
                          '',
                        );

                        final selected = selectedPhones.contains(phone);


                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              c.displayName.isNotEmpty ? c.displayName[0] : "?",
                            ),
                          ),
                          title: Text(c.displayName),
                          subtitle: Text(phoneRaw),

                          trailing: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected ? Colors.green : null,
                          ),

                          onTap: () {
                            setModalState(() {
                              final phone = c.phones.first.number
                                  .replaceAll(RegExp(r'[^0-9+]'), '');

                              if (selectedPhones.contains(phone)) {
                                selectedPhones.remove(phone);
                              } else {
                                selectedPhones.add(phone);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isAddingFromContacts
                          ? null
                          : () async {
                              if (selectedPhones.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Ничего не выбрано")),
                                );
                                return;
                              }

                              setState(() {
                                isAddingFromContacts = true;
                              });

                              await showAddLoading();

                              final localContext = context;

                              try {
                                List<Map<String, String>> contactsToAdd = [];

                                for (String phone in selectedPhones) {
                                  final c = allContacts.firstWhere(
                                    (contact) => contact.phones.any((p) => p.number.replaceAll(RegExp(r'[^0-9+]'), '') == phone),
                                    orElse: () => throw Exception("Contact not found"),
                                  );

                                  if (c.phones.isNotEmpty) {
                                    String phone = c.phones.first.number;
                                    phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

                                    if (!phone.startsWith('+993')) continue;

                                    contactsToAdd.add({
                                      'title': c.displayName,
                                      'phone_number': phone,
                                    });
                                  }
                                }

                                if (contactsToAdd.isNotEmpty) {
                                  final existing = await db.getAllContacts();
                                  final existingPhones =
                                      existing.map((e) => e.phone_number).toSet();

                                  final uniqueContacts = contactsToAdd.where((c) {
                                    return !existingPhones.contains(c['phone']);
                                  }).toList();

                                  if (uniqueContacts.isNotEmpty) {
                                    await db.insertContactsBatch(uniqueContacts);
                                    await loadCount();
                                  }
                                }

                                if (Navigator.canPop(localContext)) {
                                  Navigator.pop(localContext);
                                }

                                await loadNumbers();
                                filterNumbers();

                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Контакты добавлены")),
                                );

                              } catch (e) {
                                print(e);
                              } finally {
                                if (mounted && Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }

                                if (mounted) {
                                  setState(() {
                                    isAddingFromContacts = false;
                                  });
                                }
                              }
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),

                          elevation: 3,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Добавить",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    await loadNumbers();
    filterNumbers();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить номер')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              buildCard(
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя клиента',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              buildCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: numberController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Введите номер',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      tooltip: 'Сменить режим',
                      onPressed: () async {
                        final localContext = context;
                        final newMode = addMode == 'manual'
                            ? 'contacts'
                            : 'manual';

                        await saveMode(newMode);

                        if (!mounted) return;

                        setState(() {
                          addMode = newMode;
                        });

                        // 🔥 красивое сообщение
                        ScaffoldMessenger.of(localContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              newMode == 'manual'
                                  ? 'Режим: Ручное добавление'
                                  : 'Режим: Из контактов',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (isImporting)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.deepPurple.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Импорт контактов",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 🔥 Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: importProgress,
                            minHeight: 10,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(
                              Colors.deepPurple,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 🔥 проценты
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(importProgress * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Text(
                              "$importedCount / $totalCountExcel",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: isAdding
                        ? null
                        : (addMode == 'manual'
                            ? addNumber
                            : pickFromContacts),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          addMode == 'manual' ? Icons.add : Icons.contact_page,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          addMode == 'manual'
                              ? 'Добавить номер'
                              : 'Выбрать из контактов',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 🔥 НОВАЯ КНОПКА
                  ElevatedButton(
                    onPressed: isImporting ? null : importFromExcel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file),
                        SizedBox(width: 8),
                        Text("+ Excel"),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    super.dispose();
  }
}