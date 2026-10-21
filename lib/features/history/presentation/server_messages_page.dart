import 'package:flutter/material.dart';

import 'package:sms_sender_app/database.dart' as database;

/// Message texts stored on the backend (legacy history screen).
class ServerMessagesPage extends StatefulWidget {
  const ServerMessagesPage({super.key});

  @override
  State<ServerMessagesPage> createState() => _ServerMessagesPageState();
}

class _ServerMessagesPageState extends State<ServerMessagesPage> {
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
