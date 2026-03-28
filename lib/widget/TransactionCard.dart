import 'package:admin_qr_manager/AppConfig.dart';
import 'package:admin_qr_manager/utils/CurrencyUtils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/Transaction.dart';
import '../TransactionService.dart' show TxnStatus;
import 'package:intl/intl.dart';
import 'package:admin_qr_manager/utils/date_utils.dart';

typedef TxnActionAsync = Future<void> Function(Transaction txn);

class TransactionCard extends StatelessWidget {
  final Transaction txn;
  final TxnActionAsync? onEdit;
  final TxnActionAsync? onDelete;
  final TxnActionAsync? onStatus;
  final TxnActionAsync? onViewProof;
  final TxnActionAsync? onUploadImage;
  final TxnActionAsync? onDeleteImage;
  final bool compactMode;

  const TransactionCard({
    super.key,
    required this.txn,
    this.onEdit,
    this.onDelete,
    this.onStatus,
    this.onViewProof,
    this.onUploadImage,
    this.onDeleteImage,
    required this.compactMode,
  });

  TxnStatus? txnStatusFromString(String? value) {
    if (value == null) return null;
    final map = TxnStatus.values.asNameMap();
    return map[value.toLowerCase()];
  }

  @override
  Widget build(BuildContext context) {
    final date =
    DateFormat('dd MMM yyyy, hh:mm a').format(toIST(txn.createdAt));
    final status = txnStatusFromString(txn.status);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if(!compactMode){
      return Card(
        color: _cardColor(status, theme, isDark),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _infoRow(context, Icons.currency_rupee, 'Amount', CurrencyUtils.formatIndianCurrency(txn.amount / 100)),
              _infoRow(context, Icons.qr_code, 'QR Code ID', txn.qrCodeId),
              _infoRow(context, Icons.payment, 'Payment ID', txn.paymentId),
              _infoRow(context, Icons.receipt_long, 'RRN Number', txn.rrnNumber, copyable: true),
              _infoRow(context, Icons.alternate_email, 'VPA', txn.vpa),
              _infoRow(context, Icons.calendar_today, 'Created At', date),
              _infoRow(context, Icons.confirmation_number, 'Transaction ID', txn.id),
              if(!(txn.status == '' || txn.status == 'normal'))
                _statusBadge(context, status),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 8),
                  if (onEdit != null)
                    IconButton(
                      icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                      tooltip: 'Edit',
                      onPressed: () async => await onEdit?.call(txn),
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete, color: theme.colorScheme.error),
                      tooltip: 'Delete',
                      onPressed: () async => await onDelete?.call(txn),
                    ),
                  if (onStatus != null)
                    IconButton(
                      icon: Icon(Icons.change_circle_outlined, color: isDark ? Colors.greenAccent : Colors.green),
                      tooltip: 'Change Status',
                      onPressed: () async => await onStatus?.call(txn),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }else{
      return Card(
        color: _cardColor(status, theme, isDark),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _infoRow(context, Icons.currency_rupee, 'Amount', CurrencyUtils.formatIndianCurrency(txn.amount / 100)),
              _infoRow(context, Icons.qr_code, 'QR Code ID', txn.qrCodeId),
              _infoRow(context, Icons.receipt_long, 'RRN Number', txn.rrnNumber, copyable: true),
              _infoRow(context, Icons.calendar_today, 'Created At', date),
              if(!(txn.status == '' || txn.status == 'normal'))
                _statusBadge(context, status),
              Row(
                children: [
                  if((txn.status == 'chargeback' && AppConfig().txnImageSupport))...[
                    if (onViewProof != null)
                      IconButton(
                        icon: Icon(Icons.attach_email, color: txn.imageUrl == '' ? theme.colorScheme.error : (isDark ? Colors.greenAccent : Colors.green)),
                        tooltip: 'View Image',
                        onPressed: () async => await onViewProof?.call(txn),
                      ),
                  if (onUploadImage != null)
                      txn.imageUrl == '' ? IconButton(
                      icon: Icon(Icons.upload_file_sharp , color: isDark ? Colors.greenAccent : Colors.green),
                      tooltip: 'Upload Image',
                      onPressed: () async => await onUploadImage?.call(txn),
                    ) : IconButton(
                      icon: Icon(Icons.recycling , color: theme.colorScheme.primary),
                      tooltip: 'Re Upload Image',
                      onPressed: () async => await onUploadImage?.call(txn),
                    ),
                  if(txn.imageUrl != '' && onDeleteImage != null)
                    IconButton(
                      icon: Icon(Icons.delete_forever_outlined , color: theme.colorScheme.error),
                      tooltip: 'Delete Image',
                      onPressed: () async => await onDeleteImage?.call(txn),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    }

  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value, {bool copyable = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
          copyable
              ? SelectableText(value, style: TextStyle(color: theme.colorScheme.onSurface))
              : Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurface))),

          if (copyable && value != '-' && value.isNotEmpty)
            IconButton(
              tooltip: 'Copy $label',
              icon: Icon(Icons.copy, size: 16, color: theme.colorScheme.onSurfaceVariant),
              padding: const EdgeInsets.only(left: 10),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
              },
            ),

        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, TxnStatus? status) {
    final (Color bg, Color fg, String label) = switch (status) {
      TxnStatus.cyber => (Colors.red.shade100, Colors.red.shade800, 'Cyber Hold'),
      TxnStatus.refund => (Colors.orange.shade100, Colors.orange.shade800, 'Refund Hold'),
      TxnStatus.chargeback => (Colors.amber.shade100, Colors.amber.shade900, 'Chargeback Hold'),
      TxnStatus.failed => (Colors.grey.shade200, Colors.grey.shade800, 'Failed'),
      _ => (Colors.grey.shade200, Colors.grey.shade700, '${txn.status} Hold'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fg)),
      ),
    );
  }

  Color _cardColor(TxnStatus? status, ThemeData theme, bool isDark) {
    switch (status) {
      case TxnStatus.normal:
      case null:
        return theme.cardColor;
      case TxnStatus.cyber:
        return isDark ? Colors.red.shade900.withValues(alpha: 0.4) : Colors.red.shade50;
      case TxnStatus.refund:
        return isDark ? Colors.orange.shade900.withValues(alpha: 0.4) : Colors.orange.shade50;
      case TxnStatus.chargeback:
        return isDark ? Colors.amber.shade900.withValues(alpha: 0.4) : Colors.amber.shade50;
      case TxnStatus.failed:
        return isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100;
    }
  }

}
