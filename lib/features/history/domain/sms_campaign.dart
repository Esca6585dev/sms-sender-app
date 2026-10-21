/// Where a send run came from.
enum CampaignSource {
  group,
  all,
  single;

  static CampaignSource fromName(String? name) => CampaignSource.values
      .firstWhere((v) => v.name == name, orElse: () => CampaignSource.all);
}

extension CampaignSourcePresentation on CampaignSource {
  String get label => switch (this) {
        CampaignSource.group => 'Группа',
        CampaignSource.all => 'Все номера',
        CampaignSource.single => 'Один номер',
      };
}

/// One number inside a recorded send run.
class CampaignRecipient {
  const CampaignRecipient({
    required this.phone,
    this.name = '',
    required this.sent,
    this.error,
    this.sentAt,
  });

  factory CampaignRecipient.fromJson(Map<String, dynamic> json) {
    final sentAtRaw = json['sentAt'] as String?;
    return CampaignRecipient(
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sent: json['sent'] as bool? ?? false,
      error: json['error'] as String?,
      sentAt: sentAtRaw == null ? null : DateTime.tryParse(sentAtRaw),
    );
  }

  final String phone;
  final String name;
  final bool sent;
  final String? error;
  final DateTime? sentAt;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'sent': sent,
        if (error != null) 'error': error,
        if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
      };
}

/// Lightweight description of a send run, kept in the history index so the
/// list and the statistics never need to load the full number lists.
class CampaignSummary {
  const CampaignSummary({
    required this.id,
    required this.startedAt,
    required this.finishedAt,
    required this.message,
    required this.source,
    required this.sourceLabel,
    required this.total,
    required this.sent,
    required this.failed,
  });

  factory CampaignSummary.fromJson(Map<String, dynamic> json) =>
      CampaignSummary(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: DateTime.parse(json['finishedAt'] as String),
        message: json['message'] as String? ?? '',
        source: CampaignSource.fromName(json['source'] as String?),
        sourceLabel: json['sourceLabel'] as String? ?? '',
        total: json['total'] as int? ?? 0,
        sent: json['sent'] as int? ?? 0,
        failed: json['failed'] as int? ?? 0,
      );

  final String id;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String message;
  final CampaignSource source;

  /// Human label of the source, e.g. `Группа 3`.
  final String sourceLabel;
  final int total;
  final int sent;
  final int failed;

  double get successRate => total == 0 ? 0 : sent / total;

  Duration get duration => finishedAt.difference(startedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt.toIso8601String(),
        'message': message,
        'source': source.name,
        'sourceLabel': sourceLabel,
        'total': total,
        'sent': sent,
        'failed': failed,
      };
}

/// A recorded send run: summary plus every number with its result.
class SmsCampaign {
  SmsCampaign({
    required this.summary,
    required List<CampaignRecipient> recipients,
  }) : recipients = List<CampaignRecipient>.unmodifiable(recipients);

  /// Builds a campaign from the numbers processed in one send run.
  factory SmsCampaign.fromRun({
    required String message,
    required CampaignSource source,
    required String sourceLabel,
    required DateTime startedAt,
    required List<CampaignRecipient> recipients,
    DateTime? finishedAt,
    String? id,
  }) {
    final sent = recipients.where((r) => r.sent).length;
    final end = finishedAt ?? DateTime.now();
    return SmsCampaign(
      summary: CampaignSummary(
        id: id ?? 'c${startedAt.microsecondsSinceEpoch}',
        startedAt: startedAt,
        finishedAt: end,
        message: message,
        source: source,
        sourceLabel: sourceLabel,
        total: recipients.length,
        sent: sent,
        failed: recipients.length - sent,
      ),
      recipients: recipients,
    );
  }

  factory SmsCampaign.fromJson(Map<String, dynamic> json) => SmsCampaign(
        summary:
            CampaignSummary.fromJson(json['summary'] as Map<String, dynamic>),
        recipients: ((json['recipients'] as List?) ?? const [])
            .map((e) => CampaignRecipient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final CampaignSummary summary;
  final List<CampaignRecipient> recipients;

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'recipients': [for (final r in recipients) r.toJson()],
      };
}
