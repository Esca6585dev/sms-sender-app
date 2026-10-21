import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/core/utils/phone_normalizer.dart';
import 'package:sms_sender_app/database.dart' as database;
import 'package:sms_sender_app/features/groups/data/excel_contacts_parser.dart';

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
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );

    if (picked.isEmpty) return;

    setState(() {
      isImporting = true;
      importProgress = 0;
      importedCount = 0;
    });

    final file = picked.first;
    final bytes = await file.readAsBytes();

    // Parsing + phone normalisation runs on a background isolate.
    final parsed = await compute(ExcelContactsParser.parseBytes, bytes);
    if (!mounted) return;

    if (parsed.recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parsed.totalRows == 0
                ? 'Excel файл пустой'
                : 'В файле не найдено корректных номеров',
          ),
        ),
      );
      setState(() => isImporting = false);
      return;
    }

    final int available = maxContacts - totalCount;

    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Достигнут лимит $maxContacts")),
      );
      setState(() => isImporting = false);
      return;
    }

    final toImport = parsed.recipients.take(available).toList();
    totalCountExcel = toImport.length;

    const batchSize = 200;

    for (int i = 0; i < toImport.length; i += batchSize) {
      final chunk = toImport.sublist(
        i,
        math.min(i + batchSize, toImport.length),
      );

      await db.insertContactsBatch([
        for (final r in chunk) {'title': r.name, 'phone_number': r.phone},
      ]);

      importedCount = i + chunk.length;
      importProgress = importedCount / totalCountExcel;

      if (!mounted) return;
      setState(() {});
    }

    await loadCount();
    await loadNumbers();

    if (!mounted) return;
    setState(() {
      isImporting = false;
      importProgress = 0;
    });

    final skipped = parsed.invalidCount + parsed.duplicateCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skipped > 0
              ? "Импортировано: $importedCount · пропущено: $skipped"
              : "Импортировано: $importedCount",
        ),
      ),
    );
  }

  Future<void> addNumber() async {
    String name = nameController.text.trim();
    String number = numberController.text.trim();

    if (isAdding) return;

    final normalized = PhoneNormalizer.normalize(number);
    final isValid = normalized != null;
    if (normalized != null) number = normalized;

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