import 'package:admin_qr_manager/utils/CurrencyUtils.dart';
import 'package:flutter/material.dart';
import '../models/Transaction.dart';
import 'package:intl/intl.dart';

// Define a typedef for clarity
typedef TxnActionAsync = Future<void> Function(Transaction txn);

enum TxnStatus { normal, cyber, refund, chargeback }

class TransactionCard extends StatelessWidget {
  final Transaction txn;
  final TxnActionAsync? onEdit;
  final TxnActionAsync? onDelete;
  final TxnActionAsync? onStatus;

  const TransactionCard({
    super.key,
    required this.txn,
    this.onEdit,
    this.onDelete,
    this.onStatus,
  });

  TxnStatus? txnStatusFromString(String? value) {
    if (value == null) return null; // keep nullability explicit [18]
    // Safe lookup: returns null if not found
    final map = TxnStatus.values.asNameMap(); // { 'normal': TxnStatus.normal, ... } [15]
    return map[value.toLowerCase()]; // ensure incoming strings match enum names [15]
    // Alternatively, strict lookup (throws if missing):
    // return TxnStatus.values.byName(value); // throws ArgumentError on unknown [10][7]
  }

  @override
  Widget build(BuildContext context) {
    final date =
    DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt.toLocal());
    final status = txnStatusFromString(txn.status); // txn.status is String? [10]
    return Card(
      color: cardColorForStatus(status),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title + trailing actions
            const SizedBox(height: 8),
            _infoRow(Icons.currency_rupee, 'Amount', CurrencyUtils.formatIndianCurrency(txn.amount / 100)),
            _infoRow(Icons.qr_code, 'QR Code ID', txn.qrCodeId),
            _infoRow(Icons.payment, 'Payment ID', txn.paymentId),
            _infoRow(Icons.receipt_long, 'RRN Number', txn.rrnNumber),
            _infoRow(Icons.alternate_email, 'VPA', txn.vpa),
            _infoRow(Icons.calendar_today, 'Created At', date),
            _infoRow(Icons.confirmation_number, 'Transaction ID', txn.id),
            if(!(txn.status == '' || txn.status == 'normal'))
              _infoRow(Icons.confirmation_number, 'Status: ', "${txn.status} Hold"),
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  // Trailing actions
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      tooltip: 'Edit',
                      // onPressed: () => onEdit?.call(txn),
                      onPressed: () async => await onEdit?.call(txn),
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      tooltip: 'Delete',
                      onPressed: () async => await onDelete?.call(txn),
                    ),
                  if (onStatus != null)
                    IconButton(
                      icon: const Icon(Icons.change_circle_outlined, color: Colors.green),
                      tooltip: 'Change Status',
                      onPressed: () async => await onStatus?.call(txn),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Color cardColorForStatus(TxnStatus? status) {
    switch (status) {
      case TxnStatus.normal:
        return Colors.white; // normal [21]
      case TxnStatus.cyber:
        return Colors.red; // cyber [21]
      case TxnStatus.refund:
        return Colors.orange; // refund [22]
      case TxnStatus.chargeback:
        return Colors.yellow; // chargeback [22]
      case null:
        return Colors.white; // fallback for null [21]
    }
  }

}
