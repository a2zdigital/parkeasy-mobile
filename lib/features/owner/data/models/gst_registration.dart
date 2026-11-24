/// An owner's GST registration in one state, as the API reports it.
class GstRegistration {
  const GstRegistration({
    required this.id,
    required this.gstin,
    required this.legalName,
    required this.stateCode,
    required this.status,
    this.rejectionReason,
    this.serviceStatus,
    this.serviceLegalName,
    this.nameMatches,
  });

  factory GstRegistration.fromJson(Map<String, dynamic> json) =>
      GstRegistration(
        id: json['id'] as String,
        gstin: json['gstin'] as String,
        legalName: json['legal_name'] as String,
        stateCode: json['state_code'] as String,
        status: GstRegistrationStatus.from(json['status'] as String?),
        rejectionReason: json['rejection_reason'] as String?,
        serviceStatus: json['service_status'] as String?,
        serviceLegalName: json['service_legal_name'] as String?,
        nameMatches: json['name_matches'] as bool?,
      );

  final String id;
  final String gstin;
  final String legalName;
  final String stateCode;
  final GstRegistrationStatus status;
  final String? rejectionReason;

  /// What a GST verification service reported (active, inactive, cancelled,
  /// not_found, unavailable); null when none is configured.
  final String? serviceStatus;
  final String? serviceLegalName;
  final bool? nameMatches;
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

/// Why a GSTIN's format is wrong. The API checks the same rules; a correct
/// format does not mean the GSTIN is registered or active.
enum GstinProblem {
  characters,
  length,
  stateCode,
  pan,
  panHolderType,
  entityNumber,
  defaultCharacter,
  checksum,
}

const _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// GST state and union territory codes in use, plus 97 (other territory).
const gstStateCodes = {
  '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', //
  '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', //
  '26', '27', '29', '30', '31', '32', '33', '34', '35', '36', '37', //
  '38', '97',
};

/// The check character for the first 14 characters of a GSTIN.
String gstinCheckCharacter(String first14) {
  var sum = 0;
  for (var i = 0; i < first14.length; i++) {
    final product = _chars.indexOf(first14[i]) * (i.isEven ? 1 : 2);
    sum += product ~/ 36 + product % 36;
  }
  return _chars[(36 - sum % 36) % 36];
}

/// The first problem with [input] (read in upper case), or null when the
/// format is valid.
GstinProblem? gstinProblem(String input) {
  final gstin = input.trim().toUpperCase();
  if (!RegExp(r'^[0-9A-Z]*$').hasMatch(gstin)) return GstinProblem.characters;
  if (gstin.length != 15) return GstinProblem.length;
  if (!gstStateCodes.contains(gstin.substring(0, 2))) {
    return GstinProblem.stateCode;
  }
  if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(gstin.substring(2, 12))) {
    return GstinProblem.pan;
  }
  if (!'ABCFGHJLPT'.contains(gstin[5])) return GstinProblem.panHolderType;
  if (!RegExp(r'^[1-9A-Z]$').hasMatch(gstin[12])) {
    return GstinProblem.entityNumber;
  }
  if (gstin[13] != 'Z') return GstinProblem.defaultCharacter;
  if (gstinCheckCharacter(gstin.substring(0, 14)) != gstin[14]) {
    return GstinProblem.checksum;
  }
  return null;
}
