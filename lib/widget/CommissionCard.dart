import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/models/Commission.dart';

class CommissionCard extends StatelessWidget {
  final Commission c;
  final String? displayName;
  final String? displayEmail;
  const CommissionCard({super.key, required this.c, this.displayName, this.displayEmail});

  String _fmtRupees(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }

  Color _badgeColor(String earningType) {
    switch (earningType.toLowerCase()) {
      case 'admin':
        return Colors.indigo;
      case 'subadmin':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt.toLocal());
    final nameLine = (displayName?.isNotEmpty == true || displayEmail?.isNotEmpty == true)
        ? '${displayName ?? ''}${(displayName?.isNotEmpty == true && displayEmail?.isNotEmpty == true) ? ' • ' : ''}${displayEmail ?? ''}'
        : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header same...
            Row(
              children: [
                Text(_fmtRupees(c.amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _badgeColor(c.earningType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _badgeColor(c.earningType).withOpacity(0.5)),
                  ),
                  child: Text(c.earningType.toUpperCase(),
                      style: TextStyle(color: _badgeColor(c.earningType), fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const Spacer(),
                // Text(c.id, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
              ],
            ),
            const SizedBox(height: 12),
            if (nameLine != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(nameLine, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            _infoRow(Icons.percent, 'Rate', '${c.commissionRate}%'),
            // _infoRow(Icons.perm_identity, 'User ID', c.userId),
            _infoRow(Icons.confirmation_number, 'Source Withdrawal', c.sourceWithdrawalId),
            _infoRow(Icons.calendar_today, 'Created At', dateStr),
          ],
        ),
      ),
    );
  }
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
