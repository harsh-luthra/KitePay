class Transaction {
  final String id;
  final String? payload;
  final String qrCodeId;
  final String paymentId;
  final String rrnNumber;
  final String vpa;
  final DateTime createdAt;
  final int amount;
  final String? status;

  Transaction({
    required this.id,
    this.payload,
    required this.qrCodeId,
    required this.paymentId,
    required this.rrnNumber,
    required this.vpa,
    required this.createdAt,
    required this.amount,
    this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['\$id'],
      // payload: json['payload'],
      qrCodeId: json['qrCodeId'],
      paymentId: json['paymentId'],
      rrnNumber: json['rrnNumber'],
      vpa: json['vpa'],
      createdAt: DateTime.parse(json['created_at']),
      amount: json['amount'],
      status: json['status'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'Transaction{id: $id, qrCodeId: $qrCodeId, paymentId: $paymentId, rrnNumber: $rrnNumber, vpa: $vpa, createdAt: $createdAt, amount: $amount, status: $status }';
  }

  String get amountInRupees => '₹ ${(amount / 100).toStringAsFixed(2)}';
}
