class WalletTransaction {
  final String id;
  final String walletId; // ✅ Added - FK to wallets
  final String userId;
  final double amount;
  final WalletTransactionStatus status;
  final WalletTransactionType type;
  final String? paymentId;
  final String? rrnNumber;
  final String? description;
  final double? commission;
  final bool isCredit;
  final Map<String, dynamic>? metadata; // ✅ Added
  final DateTime createdAt;
  final DateTime? updatedAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.type,
    this.paymentId,
    this.rrnNumber,
    this.description,
    this.commission,
    required this.isCredit,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['\$id'] ?? '',
        walletId: json['walletId'] ?? '',
        userId: json['userId'] ?? '',
        amount: (json['amount'] ?? 0.0).toDouble(),
        status: _parseStatus(json['status'] ?? 'pending'),
        type: _parseType(json['type'] ?? 'unknown'),
        paymentId: json['paymentId'],
        rrnNumber: json['rrnNumber'],
        description: json['description'],
        commission: json['commission']?.toDouble(),
        isCredit: json['isCredit'] ?? true,
        metadata: json['metadata'],
        createdAt: DateTime.parse(
          json['\$createdAt'] ?? DateTime.now().toIso8601String(),
        ),
        updatedAt:
            json['\$updatedAt'] != null
                ? DateTime.parse(json['\$updatedAt'])
                : null,
      );
}

enum WalletTransactionStatus { pending, success, failed, cancelled, expired }

enum WalletTransactionType { recharge, withdrawal, payment, commission, refund }

WalletTransactionStatus _parseStatus(String value) {
  switch (value.toLowerCase()) {
    case 'pending':
      return WalletTransactionStatus.pending;
    case 'success':
    case 'completed':
      return WalletTransactionStatus.success;
    case 'failed':
      return WalletTransactionStatus.failed;
    case 'cancelled':
    case 'canceled':
      return WalletTransactionStatus.cancelled;
    case 'expired':
      return WalletTransactionStatus.expired;
    default:
      return WalletTransactionStatus.pending;
  }
}

WalletTransactionType _parseType(String value) {
  switch (value.toLowerCase()) {
    case 'recharge':
      return WalletTransactionType.recharge;
    case 'withdrawal':
      return WalletTransactionType.withdrawal;
    case 'payment':
      return WalletTransactionType.payment;
    case 'commission':
      return WalletTransactionType.commission;
    case 'refund':
      return WalletTransactionType.refund;
    default:
      return WalletTransactionType.payment; // sensible default
  }
}
