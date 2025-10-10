class QrCode {
  final String qrId;
  final String fileId;
  final String imageUrl;
  final String? assignedUserId;
  final String? managedByUserId;

  final bool isActive;
  final String? createdAt;
  final int? totalTransactions;
  final int? totalPayInAmount;

  final int? withdrawalRequestedAmount;       // sum of pending withdrawal requests (paise)
  final int? withdrawalApprovedAmount;        // sum of approved withdrawals (paise)
  final int? amountAvailableForWithdrawal;    // derived or stored (paise)

  final int? commissionOnHold;
  final int? commissionPaid;

  final int? amountOnHold;

  final int? todayTotalPayIn;

  QrCode({
    required this.qrId,
    required this.fileId,
    required this.imageUrl,
    this.assignedUserId,
    this.managedByUserId,
    required this.isActive,
    this.createdAt,
    this.totalTransactions,
    this.totalPayInAmount,
    this.withdrawalRequestedAmount,
    this.withdrawalApprovedAmount,
    this.amountAvailableForWithdrawal,
    this.commissionOnHold,
    this.commissionPaid,
    this.amountOnHold,
    this.todayTotalPayIn,
  });

  factory QrCode.fromJson(Map<String, dynamic> json) {
    return QrCode(
      qrId: json['qrId'] as String? ?? '',
      fileId: json['fileId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      assignedUserId: json['assignedUserId'] as String?,
      managedByUserId : json['managedByUserId'] as String?,
      createdAt: json['createdAt'] as String?,
      isActive: json['isActive'] ?? true,
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      totalPayInAmount: json['totalPayInAmount'] as int? ?? 0,
      withdrawalRequestedAmount: json['withdrawalRequestedAmount'] as int? ?? 0,
      withdrawalApprovedAmount: json['withdrawalApprovedAmount'] as int? ?? 0,
      amountAvailableForWithdrawal: json['amountAvailableForWithdrawal'] as int? ?? 0,
      commissionOnHold: json['commissionOnHold'] as int? ?? 0,
      commissionPaid: json['commissionPaid'] as int? ?? 0,
      amountOnHold: json['amountOnHold'] as int? ?? 0,
      todayTotalPayIn: json['todayTotalPayIn'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qrId': qrId,
      'fileId': fileId,
      'imageUrl': imageUrl,
      'assignedUserId': assignedUserId,
      'managedByUserId' : managedByUserId,
      'createdAt': createdAt, // already a String in your model
      'isActive': isActive,
      'totalTransactions': totalTransactions,
      'totalPayInAmount': totalPayInAmount,
      'withdrawalRequestedAmount': withdrawalRequestedAmount,
      'withdrawalApprovedAmount': withdrawalApprovedAmount,
      'amountAvailableForWithdrawal': amountAvailableForWithdrawal,
      'commissionOnHold' : commissionOnHold,
      'commissionPaid' : commissionPaid,
      'amountOnHold': amountOnHold,
      'todayTotalPayIn': todayTotalPayIn,
    };
  }

  @override
  String toString() {
    return 'QrCode{qrId: $qrId, fileId: $fileId, imageUrl: $imageUrl, assignedUserId: $assignedUserId, managedByUserId: $managedByUserId, isActive: $isActive, createdAt: $createdAt, totalTransactions: $totalTransactions, totalPayInAmount: $totalPayInAmount, withdrawalRequestedAmount: $withdrawalRequestedAmount, withdrawalApprovedAmount: $withdrawalApprovedAmount, amountAvailableForWithdrawal: $amountAvailableForWithdrawal, commissionOnHold: $commissionOnHold, commissionPaid: $commissionPaid, amountOnHold: $amountOnHold, todayTotalPayIn: $todayTotalPayIn}';
  }

}