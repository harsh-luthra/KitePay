import 'package:flutter/material.dart';
import '../models/Transaction.dart';
import 'package:intl/intl.dart';

class TransactionCard extends StatelessWidget {
  final Transaction txn;

  const TransactionCard({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(txn.createdAt.toLocal());

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.currency_rupee, 'Amount', '₹${txn.amount / 100}'),
            _infoRow(Icons.qr_code, 'QR Code ID', txn.qrCodeId),
            _infoRow(Icons.payment, 'Payment ID', txn.paymentId),
            _infoRow(Icons.receipt_long, 'RRN Number', txn.rrnNumber),
            _infoRow(Icons.alternate_email, 'VPA', txn.vpa),
            _infoRow(Icons.calendar_today, 'Created At', date),
            _infoRow(Icons.confirmation_number, 'Transaction ID', txn.id),
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
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
