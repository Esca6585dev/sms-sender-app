/// Delivery state of one phone number inside a group.
enum RecipientStatus {
  pending,
  sending,
  sent,
  failed;

  static RecipientStatus fromName(String? name) => RecipientStatus.values
      .firstWhere((v) => v.name == name, orElse: () => RecipientStatus.pending);
}

const Object _unset = Object();

/// One phone number imported from Excel together with its send status.
class SmsRecipient {
  const SmsRecipient({
    required this.phone,
    this.name = '',
    this.status = RecipientStatus.pending,
    this.error,
    this.sentAt,
  });

  factory SmsRecipient.fromJson(Map<String, dynamic> json) {
    final sentAtRaw = json['sentAt'] as String?;
    return SmsRecipient(
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: RecipientStatus.fromName(json['status'] as String?),
      error: json['error'] as String?,
      sentAt: sentAtRaw == null ? null : DateTime.tryParse(sentAtRaw),
    );
  }

  /// Canonical `+993XXXXXXXX` number.
  final String phone;
  final String name;
  final RecipientStatus status;
  final String? error;
  final DateTime? sentAt;

  bool get isSent => status == RecipientStatus.sent;

  /// `true` for numbers that still have to be (re)sent: pending or failed.
  bool get needsSend => status != RecipientStatus.sent;

  SmsRecipient copyWith({
    String? name,
    RecipientStatus? status,
    Object? error = _unset,
    Object? sentAt = _unset,
  }) {
    return SmsRecipient(
      phone: phone,
      name: name ?? this.name,
      status: status ?? this.status,
      error: identical(error, _unset) ? this.error : error as String?,
      sentAt: identical(sentAt, _unset) ? this.sentAt : sentAt as DateTime?,
    );
  }

  /// Fresh copy with the status cleared back to [RecipientStatus.pending].
  SmsRecipient reset() =>
      copyWith(status: RecipientStatus.pending, error: null, sentAt: null);

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'status': status.name,
        if (error != null) 'error': error,
        if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is SmsRecipient &&
      other.phone == phone &&
      other.name == name &&
      other.status == status &&
      other.error == error &&
      other.sentAt == sentAt;

  @override
  int get hashCode => Object.hash(phone, name, status, error, sentAt);

  @override
  String toString() => 'SmsRecipient($phone, ${status.name})';
}
