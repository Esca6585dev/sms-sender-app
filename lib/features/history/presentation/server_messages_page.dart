import 'package:flutter/material.dart';

import 'package:sms_sender_app/app/theme.dart';
import 'package:sms_sender_app/database.dart' as database;
import 'package:sms_sender_app/l10n/strings.dart';

/// Message texts stored on the backend (legacy history screen).
class ServerMessagesPage extends StatefulWidget {
  const ServerMessagesPage({super.key});

  @override
  State<ServerMessagesPage> createState() => _ServerMessagesPageState();
}

class _ServerMessagesPageState extends State<ServerMessagesPage> {
  final database.ApiService db = database.ApiService();

  List<database.Message> _all = const [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<database.Message> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return [
      for (final m in _all)
        if (m.messageText.toLowerCase().contains(q)) m,
    ];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await db.getMessages();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _clearAll() async {
    final s = S.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteEverything),
        content: Text(s.cannotUndo),
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
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    await db.deleteAllMessages();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.historyCleared)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = AppStyleTokens.of(context);
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.serverTextsTitle),
        actions: [
          IconButton(
            tooltip: s.deleteAll,
            icon: const Icon(Icons.delete_sweep),
            onPressed: _all.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: s.searchMessages,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(child: Text(s.historyEmpty))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final m = items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: Icon(Icons.message_outlined, color: t.accent),
                              title: Text(m.messageText),
                              subtitle: Text(m.date),
                              trailing: IconButton(
                                tooltip: s.delete,
                                icon: Icon(Icons.delete_outline, color: t.danger),
                                onPressed: () async {
                                  await db.deleteMessage(m.id);
                                  await _load();
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
