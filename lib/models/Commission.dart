class Commission {
  final String id;
  final String userId;
  final String sourceWithdrawalId;
  final int amount; // paise
  final double commissionRate; // e.g., 1.5 or 2
  final String earningType; // 'admin' | 'subadmin'
  final DateTime createdAt;

  Commission({
    required this.id,
    required this.userId,
    required this.sourceWithdrawalId,
    required this.amount,
    required this.commissionRate,
    required this.earningType,
    required this.createdAt,
  });

  factory Commission.fromJson(Map<String, dynamic> j) {
    return Commission(
      id: j['id'] ?? j['\$id'],
      userId: j['userId'],
      sourceWithdrawalId: j['sourceWithdrawalId'],
      amount: j['amount'],
      commissionRate: (j['commissionRate'] is int)
          ? (j['commissionRate'] as int).toDouble()
          : (j['commissionRate'] as num).toDouble(),
      earningType: j['earningType'],
      createdAt: DateTime.parse(j['createdAt']),
    );
  }
}

class PaginatedCommissions {
  final List<Commission> commissions;
  final String? nextCursor;

  PaginatedCommissions({required this.commissions, required this.nextCursor});
}
