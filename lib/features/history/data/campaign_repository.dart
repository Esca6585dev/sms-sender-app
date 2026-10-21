import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';

/// Storage boundary for the send history.
abstract class CampaignRepository {
  /// Summaries, newest first.
  Future<List<CampaignSummary>> loadIndex();

  Future<SmsCampaign?> load(String id);

  Future<void> save(SmsCampaign campaign);

  Future<void> delete(String id);

  Future<void> clear();
}

/// Test double.
class InMemoryCampaignRepository implements CampaignRepository {
  final Map<String, SmsCampaign> _campaigns = {};

  @override
  Future<List<CampaignSummary>> loadIndex() async {
    final list = _campaigns.values.map((c) => c.summary).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  @override
  Future<SmsCampaign?> load(String id) async => _campaigns[id];

  @override
  Future<void> save(SmsCampaign campaign) async {
    _campaigns[campaign.summary.id] = campaign;
  }

  @override
  Future<void> delete(String id) async {
    _campaigns.remove(id);
  }

  @override
  Future<void> clear() async => _campaigns.clear();
}

/// Index of summaries under one key, every campaign's number list under its
/// own key, so opening the history never deserialises thousands of numbers.
class SharedPrefsCampaignRepository implements CampaignRepository {
  SharedPrefsCampaignRepository({this.keyPrefix = 'sms_campaign_'});

  final String keyPrefix;

  String get _indexKey => '${keyPrefix}index_v1';

  String _detailKey(String id) => '$keyPrefix$id';

  @override
  Future<List<CampaignSummary>> loadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = [
        for (final item in decoded)
          CampaignSummary.fromJson(item as Map<String, dynamic>),
      ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    } catch (error) {
      debugPrint('CampaignRepository: index is corrupt, ignoring: $error');
      return const [];
    }
  }

  @override
  Future<SmsCampaign?> load(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_detailKey(id));
    if (raw == null) return null;
    try {
      return SmsCampaign.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('CampaignRepository: campaign $id is corrupt: $error');
      return null;
    }
  }

  @override
  Future<void> save(SmsCampaign campaign) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await loadIndex();
    final updated = [
      campaign.summary,
      ...index.where((s) => s.id != campaign.summary.id),
    ];
    await prefs.setString(
      _detailKey(campaign.summary.id),
      jsonEncode(campaign.toJson()),
    );
    await prefs.setString(
      _indexKey,
      jsonEncode([for (final s in updated) s.toJson()]),
    );
  }

  @override
  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await loadIndex();
    await prefs.remove(_detailKey(id));
    await prefs.setString(
      _indexKey,
      jsonEncode([for (final s in index) if (s.id != id) s.toJson()]),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final index = await loadIndex();
    for (final s in index) {
      await prefs.remove(_detailKey(s.id));
    }
    await prefs.remove(_indexKey);
  }
}
