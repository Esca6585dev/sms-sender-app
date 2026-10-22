import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/core/utils/phone_normalizer.dart';
import 'package:sms_sender_app/database.dart' as database;
import 'package:sms_sender_app/features/groups/data/excel_contacts_parser.dart';
import 'package:sms_sender_app/l10n/strings.dart';

/// Adds numbers to the backend contact list: manually, from the phone's
/// contacts or from an Excel file.
class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  static const int maxContacts = 5000;
  static const String _modeKey = 'add_mode';

  final database.ApiService db = database.ApiService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();

  Set<String> _existingPhones = {};
  String addMode = 'manual';
  int totalCount = 0;
  bool isImporting = false;
  double importProgress = 0;
  int importedCount = 0;
  int totalCountExcel = 0;
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadMode();
    _loadExisting();
    _loadCount();
  }

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    super.dispose();
  }

  Future<void> _loadMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => addMode = prefs.getString(_modeKey) ?? addMode);
    } catch (_) {}
  }

  Future<void> _saveMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode);
    } catch (_) {}
  }

  Future<void> _loadCount() async {
    try {
      final count = await db.getContactsCount();
      if (!mounted) return;
      setState(() => totalCount = count);
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    try {
      final data = await db.getAllContacts();
      if (!mounted) return;
      setState(() => _existingPhones = {for (final c in data) c.phone_number});
    } catch (_) {}
  }

  bool _canAddMore(int countToAdd) {
    if (totalCount + countToAdd > maxContacts) {
      _snack(S.of(context).maxNumbers(maxContacts, totalCount));
      return false;
    }
    return true;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showLoading(String text) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
            ],
          ),
        ),
      ),
    );
  }

  void _closeLoading() {
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  // ------------------------------------------------------------- manual

  Future<void> _addNumber() async {
    final s = S.of(context);
    if (isAdding) return;
    var name = nameController.text.trim();
    if (name.isEmpty) name = s.noName;

    final number = PhoneNormalizer.normalize(numberController.text);
    if (number == null) {
      _snack(s.invalidNumber);
      return;
    }
    if (_existingPhones.contains(number)) {
      _snack(s.numberExists);
      return;
    }
    if (!_canAddMore(1)) return;

    setState(() => isAdding = true);
    await _showLoading(s.addingNumber);
    try {
      await db.insertContact(name, number);
      _existingPhones.add(number);
      await _loadCount();
    } catch (error) {
      debugPrint('AddContact: insert failed: $error');
    } finally {
      _closeLoading();
      if (mounted) setState(() => isAdding = false);
    }
    if (!mounted) return;
    _snack(s.numberAdded);
    numberController.clear();
    nameController.clear();
  }

  // -------------------------------------------------------------- excel

  Future<void> _importFromExcel() async {
    final s = S.of(context);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (picked.isEmpty || !mounted) return;

    setState(() {
      isImporting = true;
      importProgress = 0;
      importedCount = 0;
    });

    try {
      final bytes = await picked.first.readAsBytes();
      final parsed = await compute(ExcelContactsParser.parseBytes, bytes);
      if (!mounted) return;

      if (parsed.recipients.isEmpty) {
        _snack(parsed.totalRows == 0 ? s.excelEmpty : s.excelNoValid);
        return;
      }

      final available = maxContacts - totalCount;
      if (available <= 0) {
        _snack(s.limitReached(maxContacts));
        return;
      }

      final toImport = parsed.recipients
          .where((r) => !_existingPhones.contains(r.phone))
          .take(available)
          .toList();
      totalCountExcel = toImport.length;
      const batchSize = 200;

      for (var i = 0; i < toImport.length; i += batchSize) {
        final chunk =
            toImport.sublist(i, math.min(i + batchSize, toImport.length));
        await db.insertContactsBatch([
          for (final r in chunk) {'title': r.name, 'phone_number': r.phone},
        ]);
        for (final r in chunk) {
          _existingPhones.add(r.phone);
        }
        importedCount = i + chunk.length;
        importProgress =
            totalCountExcel == 0 ? 1 : importedCount / totalCountExcel;
        if (!mounted) return;
        setState(() {});
      }

      await _loadCount();
      final skipped = parsed.invalidCount +
          parsed.duplicateCount +
          (parsed.recipients.length - toImport.length);
      _snack(
        skipped > 0
            ? s.importedSkipped(importedCount, skipped)
            : s.importedN(importedCount),
      );
    } catch (error) {
      _snack(s.importError(error));
    } finally {
      if (mounted) {
        setState(() {
          isImporting = false;
          importProgress = 0;
        });
      }
    }
  }

  // ----------------------------------------------------------- contacts

  Future<void> _pickFromContacts() async {
    final s = S.of(context);
    final permission = await Permission.contacts.request();
    if (!permission.isGranted || !mounted) return;

    final allContacts = await FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;
    final withPhone = allContacts.where((c) => c.phones.isNotEmpty).toList();

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactPicker(contacts: withPhone),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    final toAdd = <Map<String, String>>[];
    for (final c in withPhone) {
      final phone = PhoneNormalizer.normalize(c.phones.first.number);
      if (phone == null || !selected.contains(phone)) continue;
      if (_existingPhones.contains(phone)) continue;
      toAdd.add({'title': c.displayName, 'phone_number': phone});
    }
    if (toAdd.isEmpty) {
      _snack(s.numberExists);
      return;
    }
    if (!_canAddMore(toAdd.length)) return;

    await _showLoading(s.addingNumber);
    try {
      await db.insertContactsBatch(toAdd);
      for (final c in toAdd) {
        _existingPhones.add(c['phone_number']!);
      }
      await _loadCount();
      _snack(s.contactsAdded);
    } catch (error) {
      _snack(error.toString());
    } finally {
      _closeLoading();
    }
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.addNumberTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: s.clientName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: numberController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                            ],
                            decoration: InputDecoration(
                              labelText: s.enterNumber,
                              prefixIcon: const Icon(Icons.phone_outlined),
                              hintText: '+993 65 123456',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: s.switchMode,
                          onPressed: () async {
                            final newMode =
                                addMode == 'manual' ? 'contacts' : 'manual';
                            await _saveMode(newMode);
                            if (!mounted) return;
                            setState(() => addMode = newMode);
                            _snack(
                              newMode == 'manual' ? s.modeManual : s.modeContacts,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.maxNumbers(maxContacts, totalCount),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (isImporting) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.importContacts,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: importProgress,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(importProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$importedCount / $totalCountExcel',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isAdding
                  ? null
                  : (addMode == 'manual' ? _addNumber : _pickFromContacts),
              icon: Icon(
                addMode == 'manual' ? Icons.add : Icons.contact_page_outlined,
              ),
              label: Text(
                addMode == 'manual' ? s.drawerAddNumber : s.pickFromContacts,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isImporting ? null : _importFromExcel,
              icon: Icon(Icons.upload_file, color: t.accent),
              label: Text(s.excelButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the phone's contacts with multi-select.
class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.contacts});

  final List<Contact> contacts;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  final Set<String> _selected = {};
  String _query = '';

  List<Contact> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return widget.contacts;
    return [
      for (final c in widget.contacts)
        if (c.displayName.toLowerCase().contains(q) ||
            c.phones.first.number.contains(q))
          c,
    ];
  }

  String? _phoneOf(Contact c) => PhoneNormalizer.normalize(c.phones.first.number);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            s.pickContacts,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: s.searchContact,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.selectedOf(_selected.length, widget.contacts.length),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: Text(s.unselectAll),
                      ),
                    TextButton(
                      onPressed: () => setState(() {
                        for (final c in widget.contacts) {
                          final phone = _phoneOf(c);
                          if (phone != null) _selected.add(phone);
                        }
                      }),
                      child: Text(s.selectAll),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final c = items[i];
                final phone = _phoneOf(c);
                final selected = phone != null && _selected.contains(phone);
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(c.displayName.isNotEmpty ? c.displayName[0] : '?'),
                  ),
                  title: Text(c.displayName),
                  subtitle: Text(c.phones.first.number),
                  enabled: phone != null,
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? scheme.primary : null,
                  ),
                  onTap: phone == null
                      ? null
                      : () => setState(() {
                            if (!_selected.remove(phone)) _selected.add(phone);
                          }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (_selected.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.nothingSelected)),
                    );
                    return;
                  }
                  Navigator.pop(context, _selected);
                },
                icon: const Icon(Icons.check),
                label: Text(s.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
