class Wallet {
  final String id;           // $id
  final String userId;
  final double balance;
  final double holdBalance;
  final int totalRecharges;
  final int totalWithdrawals;
  final int totalAmountRecharged;   // ← NEW
  final int totalAmountWithdrawn;   // ← NEW
  final DateTime createdAt;
  final DateTime? updatedAt;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.holdBalance,
    required this.totalRecharges,
    required this.totalWithdrawals,
    required this.totalAmountRecharged,
    required this.totalAmountWithdrawn,
    required this.createdAt,
    this.updatedAt,
  });

  double get availableBalance => balance - holdBalance;
  int get totalActivity => totalAmountRecharged + totalAmountWithdrawn;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['\$id'] ?? '',
      userId: json['userId'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      holdBalance: (json['holdBalance'] ?? 0.0).toDouble(),
      totalRecharges: int.tryParse(json['totalRecharges']?.toString() ?? '0') ?? 0,
      totalWithdrawals: int.tryParse(json['totalWithdrawals']?.toString() ?? '0') ?? 0,
      totalAmountRecharged: int.tryParse(json['totalAmountRecharged']?.toString() ?? '0') ?? 0,
      totalAmountWithdrawn: int.tryParse(json['totalAmountWithdrawn']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.parse(json['\$createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['\$updatedAt'] != null ? DateTime.parse(json['\$updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'balance': balance,
      'holdBalance': holdBalance,
      'totalRecharges': totalRecharges,
      'totalWithdrawals': totalWithdrawals,
      'totalAmountRecharged': totalAmountRecharged,
      'totalAmountWithdrawn': totalAmountWithdrawn
    };
  }
}
