import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/features/groups/domain/sms_group.dart';

/// Persistence boundary for groups. The controller only talks to this
/// interface, so storage can be swapped (or faked in tests).
abstract class GroupsRepository {
  Future<List<SmsGroup>> load();

  Future<void> save(List<SmsGroup> groups);
}

/// Keeps groups in memory. Used by tests and previews.
class InMemoryGroupsRepository implements GroupsRepository {
  InMemoryGroupsRepository([List<SmsGroup>? initial])
      : _groups = List<SmsGroup>.of(initial ?? const []);

  List<SmsGroup> _groups;
  int saveCount = 0;

  List<SmsGroup> get groups => List<SmsGroup>.unmodifiable(_groups);

  @override
  Future<List<SmsGroup>> load() async => List<SmsGroup>.of(_groups);

  @override
  Future<void> save(List<SmsGroup> groups) async {
    _groups = List<SmsGroup>.of(groups);
    saveCount++;
  }
}

/// Stores groups as one JSON document in `SharedPreferences`. A few thousand
/// numbers serialise to a few hundred kilobytes, which is well within limits
/// and survives app restarts.
class SharedPrefsGroupsRepository implements GroupsRepository {
  SharedPrefsGroupsRepository({this.storageKey = defaultStorageKey});

  static const String defaultStorageKey = 'sms_groups_v1';

  final String storageKey;

  @override
  Future<List<SmsGroup>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in decoded)
          SmsGroup.fromJson(item as Map<String, dynamic>),
      ];
    } catch (error) {
      debugPrint('GroupsRepository: stored groups are corrupt, ignoring: $error');
      return const [];
    }
  }

  @override
  Future<void> save(List<SmsGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([for (final g in groups) g.toJson()]);
    await prefs.setString(storageKey, encoded);
  }
}
