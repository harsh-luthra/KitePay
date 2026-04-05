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
  final String? imageUrl;
  final bool deleted;
  final String? editedBy;
  final DateTime? updatedAt  ;

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
    this.imageUrl,
    this.deleted = false,
    this.editedBy,
    this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: (json['\$id'] ?? json['id'] ?? '') as String,
      // payload: json['payload'],
      qrCodeId: (json['qrCodeId'] ?? '') as String,
      paymentId: (json['paymentId'] ?? '') as String,
      rrnNumber: (json['rrnNumber'] ?? '') as String,
      vpa: (json['vpa'] ?? '') as String,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
      editedBy: json['edited_by'] as String?,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  @override
  String toString() {
    return 'Transaction{id: $id, qrCodeId: $qrCodeId, paymentId: $paymentId, rrnNumber: $rrnNumber, vpa: $vpa, createdAt: $createdAt, amount: $amount, status: $status, imageUrl: $imageUrl, deleted: $deleted, editedBy: $editedBy}';
  }

  String get amountInRupees => '₹ ${(amount / 100).toStringAsFixed(2)}';
}
