/// An owner's GST registration in one state, as the API reports it.
class GstRegistration {
  const GstRegistration({
    required this.id,
    required this.gstin,
    required this.legalName,
    required this.stateCode,
    required this.status,
    this.rejectionReason,
  });

  factory GstRegistration.fromJson(Map<String, dynamic> json) =>
      GstRegistration(
        id: json['id'] as String,
        gstin: json['gstin'] as String,
        legalName: json['legal_name'] as String,
        stateCode: json['state_code'] as String,
        status: GstRegistrationStatus.from(json['status'] as String?),
        rejectionReason: json['rejection_reason'] as String?,
      );

  final String id;
  final String gstin;
  final String legalName;
  final String stateCode;
  final GstRegistrationStatus status;
  final String? rejectionReason;
}

enum GstRegistrationStatus {
  pending,
  verified,
  rejected,
  unknown;

  static GstRegistrationStatus from(String? value) => switch (value) {
    'pending' => pending,
    'verified' => verified,
    'rejected' => rejected,
    _ => unknown,
  };
}

/// The 15-character GSTIN shape, checked before sending. The API also
/// checks the check character.
final RegExp gstinPattern = RegExp(
  r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
);
