import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/features/history/data/campaign_repository.dart';
import 'package:sms_sender_app/features/history/domain/sms_campaign.dart';

/// Sent SMS per calendar day (for the 7-day chart).
class DayStat {
  const DayStat({required this.day, required this.sent, required this.failed});

  final DateTime day;
  final int sent;
  final int failed;
}

/// Numbers derived from the history index. Pure, so it is unit-testable.
class CampaignStats {
  const CampaignStats({
    required this.totalCampaigns,
    required this.totalNumbers,
    required this.totalSent,
    required this.totalFailed,
    required this.sentToday,
    required this.campaignsToday,
    required this.sentLast7Days,
    required this.last7Days,
    required this.sentBySource,
  });

  factory CampaignStats.from(List<CampaignSummary> campaigns, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    var totalNumbers = 0;
    var totalSent = 0;
    var totalFailed = 0;
    var sentToday = 0;
    var campaignsToday = 0;
    var sentLast7Days = 0;
    final perDaySent = <DateTime, int>{};
    final perDayFailed = <DateTime, int>{};
    final bySource = <CampaignSource, int>{};

    for (final c in campaigns) {
      totalNumbers += c.total;
      totalSent += c.sent;
      totalFailed += c.failed;
      bySource[c.source] = (bySource[c.source] ?? 0) + c.sent;

      final day = DateTime(c.startedAt.year, c.startedAt.month, c.startedAt.day);
      if (day == today) {
        sentToday += c.sent;
        campaignsToday++;
      }
      if (!day.isBefore(weekStart) && !day.isAfter(today)) {
        sentLast7Days += c.sent;
        perDaySent[day] = (perDaySent[day] ?? 0) + c.sent;
        perDayFailed[day] = (perDayFailed[day] ?? 0) + c.failed;
      }
    }

    final last7Days = [
      for (var i = 6; i >= 0; i--)
        () {
          final day = today.subtract(Duration(days: i));
          return DayStat(
            day: day,
            sent: perDaySent[day] ?? 0,
            failed: perDayFailed[day] ?? 0,
          );
        }(),
    ];

    return CampaignStats(
      totalCampaigns: campaigns.length,
      totalNumbers: totalNumbers,
      totalSent: totalSent,
      totalFailed: totalFailed,
      sentToday: sentToday,
      campaignsToday: campaignsToday,
      sentLast7Days: sentLast7Days,
      last7Days: last7Days,
      sentBySource: bySource,
    );
  }

  final int totalCampaigns;
  final int totalNumbers;
  final int totalSent;
  final int totalFailed;
  final int sentToday;
  final int campaignsToday;
  final int sentLast7Days;

  /// Oldest first, always 7 entries.
  final List<DayStat> last7Days;
  final Map<CampaignSource, int> sentBySource;

  int get maxDaySent =>
      last7Days.fold(0, (max, d) => d.sent > max ? d.sent : max);

  double get successRate =>
      totalNumbers == 0 ? 0 : totalSent / totalNumbers;
}

class CampaignLogState {
  const CampaignLogState({this.campaigns = const [], this.isLoading = true});

  /// Newest first.
  final List<CampaignSummary> campaigns;
  final bool isLoading;

  bool get isEmpty => campaigns.isEmpty;

  CampaignStats stats([DateTime? now]) =>
      CampaignStats.from(campaigns, now ?? DateTime.now());

  CampaignLogState copyWith({
    List<CampaignSummary>? campaigns,
    bool? isLoading,
  }) =>
      CampaignLogState(
        campaigns: campaigns ?? this.campaigns,
        isLoading: isLoading ?? this.isLoading,
      );
}

/// Keeps the send history: every finished send run is recorded here by the
/// senders (groups screen, send-all, single send) and read by the history
/// and statistics screens.
class CampaignLogController extends Notifier<CampaignLogState> {
  late CampaignRepository _repository;
  late Future<void> _ready;
  bool _disposed = false;

  @override
  CampaignLogState build() {
    _repository = ref.watch(campaignRepositoryProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _ready = _restore();
    return const CampaignLogState();
  }

  Future<void> get ready => _ready;

  Future<void> record(SmsCampaign campaign) async {
    await _ready;
    if (campaign.recipients.isEmpty) return;
    try {
      await _repository.save(campaign);
    } catch (error) {
      debugPrint('CampaignLog: could not persist campaign: $error');
    }
    _emit(
      state.copyWith(
        campaigns: [
          campaign.summary,
          ...state.campaigns.where((c) => c.id != campaign.summary.id),
        ],
      ),
    );
  }

  Future<SmsCampaign?> details(String id) async {
    await _ready;
    return _repository.load(id);
  }

  Future<void> delete(String id) async {
    await _ready;
    await _repository.delete(id);
    _emit(
      state.copyWith(
        campaigns: [
          for (final c in state.campaigns)
            if (c.id != id) c,
        ],
      ),
    );
  }

  Future<void> clear() async {
    await _ready;
    await _repository.clear();
    _emit(state.copyWith(campaigns: const []));
  }

  Future<void> _restore() async {
    try {
      final index = await _repository.loadIndex();
      _emit(state.copyWith(campaigns: index, isLoading: false));
    } catch (error) {
      debugPrint('CampaignLog: restore failed: $error');
      _emit(state.copyWith(isLoading: false));
    }
  }

  void _emit(CampaignLogState next) {
    if (_disposed) return;
    state = next;
  }
}

final campaignRepositoryProvider = Provider<CampaignRepository>(
  (ref) => SharedPrefsCampaignRepository(),
);

final campaignLogProvider =
    NotifierProvider<CampaignLogController, CampaignLogState>(
  CampaignLogController.new,
);
