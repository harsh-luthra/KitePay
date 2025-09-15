class QrCode {
  final String qrId;
  final String fileId;
  final String imageUrl;
  final String? assignedUserId;
  final bool isActive;
  final String? createdAt;
  final int? totalTransactions;
  final int? totalPayInAmount;

  final int? withdrawalRequestedAmount;       // sum of pending withdrawal requests (paise)
  final int? withdrawalApprovedAmount;        // sum of approved withdrawals (paise)
  final int? amountAvailableForWithdrawal;    // derived or stored (paise)

  QrCode({
    required this.qrId,
    required this.fileId,
    required this.imageUrl,
    this.assignedUserId,
    required this.isActive,
    this.createdAt,
    this.totalTransactions,
    this.totalPayInAmount,
    this.withdrawalRequestedAmount,
    this.withdrawalApprovedAmount,
    this.amountAvailableForWithdrawal,
  });

  factory QrCode.fromJson(Map<String, dynamic> json) {
    return QrCode(
      qrId: json['qrId'] as String? ?? '',
      fileId: json['fileId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      assignedUserId: json['assignedUserId'] as String?,
      createdAt: json['createdAt'] as String?,
      isActive: json['isActive'] ?? true,
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      totalPayInAmount: json['totalPayInAmount'] as int? ?? 0,
      withdrawalRequestedAmount: json['withdrawalRequestedAmount'] as int? ?? 0,
      withdrawalApprovedAmount: json['withdrawalApprovedAmount'] as int? ?? 0,
      amountAvailableForWithdrawal: json['amountAvailableForWithdrawal'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'QrCode{qrId: $qrId, fileId: $fileId, imageUrl: $imageUrl, assignedUserId: $assignedUserId, isActive: $isActive, createdAt: $createdAt, totalTransactions: $totalTransactions, totalPayInAmount: $totalPayInAmount, withdrawalRequestedAmount: $withdrawalRequestedAmount, withdrawalApprovedAmount: $withdrawalApprovedAmount, amountAvailableForWithdrawal: $amountAvailableForWithdrawal}';
  }
}