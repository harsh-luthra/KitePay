class WithdrawalRequest {
  final String? id;
  final String userId;
  final String? qrId;
  final String holderName;
  final int amount;
  final int preAmount;
  final int commission;
  final String mode; // 'upi' or 'bank'
  final String? upiId;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;

  // Optional fields (used in admin panel)
  final String? status; // 'pending', 'approved', 'rejected'
  final String? utrNumber;
  final String? rejectionReason;
  final DateTime? createdAt;

  WithdrawalRequest({
    this.id,
    required this.userId,
    this.qrId,
    required this.holderName,
    required this.amount,
    required this.preAmount,
    required this.commission,
    required this.mode,
    this.upiId,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.status,
    this.utrNumber,
    this.rejectionReason,
    this.createdAt,
  });

  /// Convert object to JSON map for API request
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'qrId': qrId,
    'holderName': holderName,
    'amount': amount,
    'preAmount': preAmount,
    'commission': commission,
    'mode': mode,
    'upiId': upiId,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'ifscCode': ifscCode,
    'status': status,
    'utrNumber': utrNumber,
    'rejectionReason': rejectionReason,
    'createdAt': createdAt?.toIso8601String(),
  };

  /// Create object from JSON (e.g. from API response)
  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequest(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      qrId: json['qrId'] ?? '',
      holderName: json['holderName'] ?? '',
      amount: json['amount'] ?? 0,
      preAmount: json['preAmount'] ?? 0,
      commission: json['commission'] ?? 0,
      mode: json['mode'] ?? '',
      upiId: json['upiId'],
      bankName: json['bankName'],
      accountNumber: json['accountNumber'],
      ifscCode: json['ifscCode'],
      status: json['status'],
      utrNumber: json['utrNumber'],
      rejectionReason: json['rejectionReason'],
      createdAt:
      json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  @override
  String toString() {
    return 'WithdrawalRequest{id: $id, userId: $userId, qrId: $qrId, holderName: $holderName, amount: $amount, mode: $mode, upiId: $upiId, bankName: $bankName, accountNumber: $accountNumber, ifscCode: $ifscCode, status: $status, utrNumber: $utrNumber, rejectionReason: $rejectionReason, createdAt: $createdAt}';
  }

}
