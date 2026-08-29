class BranchHandoff {
  const BranchHandoff({
    required this.required,
    required this.status,
    this.otp,
    this.otpDigitLength = 6,
    this.branchName,
    this.branchAddress,
    this.confirmedAt,
  });

  final bool required;
  final String status;
  final String? otp;
  final int otpDigitLength;
  final String? branchName;
  final String? branchAddress;
  final String? confirmedAt;

  bool get isConfirmed => status == 'confirmed';

  bool get isAwaitingTeller => required && !isConfirmed;

  factory BranchHandoff.fromResponse(Map<String, dynamic> response) {
    final raw = response['branch_handoff'];
    if (raw is! Map) {
      return const BranchHandoff(required: false, status: 'not_required');
    }

    final handoff = Map<String, dynamic>.from(raw);
    final rawBranch = handoff['branch'];
    final branch = rawBranch is Map
        ? Map<String, dynamic>.from(rawBranch)
        : const <String, dynamic>{};
    final otp = handoff['otp']?.toString();

    return BranchHandoff(
      required: handoff['required'] == true,
      status: handoff['status']?.toString() ?? 'awaiting_driver_and_teller',
      otp: otp != null && otp.isNotEmpty ? otp : null,
      otpDigitLength: _asInt(handoff['otp_digit_length']) ?? 6,
      branchName: _nonEmpty(branch['name']),
      branchAddress: _nonEmpty(branch['address']),
      confirmedAt: _nonEmpty(handoff['confirmed_at']),
    );
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}

class BranchHandoffSmsResult {
  const BranchHandoffSmsResult({
    required this.success,
    required this.code,
    required this.retryable,
    this.retryAfterSeconds,
    this.message,
  });

  final bool success;
  final String code;
  final bool retryable;
  final int? retryAfterSeconds;
  final String? message;

  factory BranchHandoffSmsResult.fromJson(Map<String, dynamic> json) {
    return BranchHandoffSmsResult(
      success: json['success'] == true,
      code: json['code']?.toString() ?? 'HANDOFF_SMS_RESEND_FAILED',
      retryable: json['retryable'] == true,
      retryAfterSeconds: BranchHandoff._asInt(json['retry_after_seconds']),
      message: BranchHandoff._nonEmpty(json['message']),
    );
  }
}
