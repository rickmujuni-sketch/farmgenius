class ExternalPartnerEntry {
  final String id;
  final String partnerType;
  final String entryKind;
  final String partnerName;
  final DateTime? serviceDate;
  final String? description;
  final double amountTzs;
  final String paymentStatus;
  final String verificationStatus;
  final String submittedBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  const ExternalPartnerEntry({
    required this.id,
    required this.partnerType,
    required this.entryKind,
    required this.partnerName,
    required this.serviceDate,
    required this.description,
    required this.amountTzs,
    required this.paymentStatus,
    required this.verificationStatus,
    required this.submittedBy,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.createdAt,
  });

  factory ExternalPartnerEntry.fromMap(Map<String, dynamic> map) {
    return ExternalPartnerEntry(
      id: (map['id'] ?? '').toString(),
      partnerType: (map['partner_type'] ?? '').toString(),
      entryKind: (map['entry_kind'] ?? '').toString(),
      partnerName: (map['partner_name'] ?? '').toString(),
      serviceDate: map['service_date'] != null
          ? DateTime.tryParse(map['service_date'].toString())
          : null,
      description: map['description']?.toString(),
      amountTzs: _toDouble(map['amount_tzs']),
      paymentStatus: (map['payment_status'] ?? '').toString(),
      verificationStatus: (map['verification_status'] ?? '').toString(),
      submittedBy: (map['submitted_by'] ?? '').toString(),
      reviewedBy: map['reviewed_by']?.toString(),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.tryParse(map['reviewed_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
