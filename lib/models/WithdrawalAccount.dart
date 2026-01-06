class WithdrawalAccount {
  final String? id;
  final String? userId;
  final String mode;
  final String? notes;
  final String? upiId;
  final String? holderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? createdAt;
  final String? updatedAt;

  WithdrawalAccount({
    this.id,
    this.userId,
    required this.mode,
    this.notes,
    this.upiId,
    this.holderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.createdAt,
    this.updatedAt,
  });

  factory WithdrawalAccount.fromJson(Map<String, dynamic> json) {
    return WithdrawalAccount(
      id: json['\$id'],
      mode: json['mode'] ?? '',
      notes: json['notes'],
      upiId: json['upiId'],
      holderName: json['holderName'],
      accountNumber: json['accountNumber'],
      ifscCode: json['ifscCode'],
      bankName: json['bankName'],
      createdAt: json['\$createdAt'],
      updatedAt: json['\$updatedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    if (notes != null) 'notes': notes,
    if (upiId != null) 'upiId': upiId,
    if (holderName != null) 'holderName': holderName,
    if (accountNumber != null) 'accountNumber': accountNumber,
    if (ifscCode != null) 'ifscCode': ifscCode,
    if (bankName != null) 'bankName': bankName,
  };

  @override
  String toString() {
    return 'WithdrawalAccount('
        'id: $id, '
        'userId: $userId, '
        'mode: $mode, '
        'notes: $notes, '
        'upiId: $upiId, '
        'holderName: $holderName, '
        'accountNumber: $accountNumber, '
        'ifscCode: $ifscCode, '
        'bankName: $bankName, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt'
        ')';
  }



}
