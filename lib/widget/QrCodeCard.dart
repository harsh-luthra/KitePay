import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

import '../models/AppUser.dart';
import '../models/QrCode.dart';
import '../AppConstants.dart';
import '../utils/CurrencyUtils.dart';

class QrCodeCard extends StatelessWidget {
  final QrCode qrCode;
  final String formattedDate;
  final AppUser userMeta;
  final bool userMode;
  final String? userModeUserid;
  final bool isProcessing;
  final double qrPayInTodayLimit;

  // Callbacks
  final String Function(String) displayUserNameText;
  final AppUser? Function(String) getUserById;
  final VoidCallback onToggleStatus;
  final VoidCallback onAssignUser;
  final VoidCallback onAssignUserOptions;
  final VoidCallback onAssignSubAdmin;
  final VoidCallback onAssignSubAdminOptions;
  final VoidCallback onViewTransactions;
  final VoidCallback onDelete;
  final VoidCallback onEditImage;
  final VoidCallback onManualHold;
  final VoidCallback? onNotifyServer;

  const QrCodeCard({
    super.key,
    required this.qrCode,
    required this.formattedDate,
    required this.userMeta,
    required this.userMode,
    this.userModeUserid,
    required this.isProcessing,
    required this.qrPayInTodayLimit,
    required this.displayUserNameText,
    required this.getUserById,
    required this.onToggleStatus,
    required this.onAssignUser,
    required this.onAssignUserOptions,
    required this.onAssignSubAdmin,
    required this.onAssignSubAdminOptions,
    required this.onViewTransactions,
    required this.onDelete,
    required this.onEditImage,
    required this.onManualHold,
    this.onNotifyServer,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 720;

    final String assignedId = qrCode.assignedUserId ?? '';
    final String managerId = qrCode.managedByUserId ?? '';

    final bool isSelf = assignedId == userMeta.id;
    final String assignedName = displayUserNameText(assignedId);
    final String assigneeLine = assignedId == ''
        ? 'Unassigned'
        : (isSelf
        ? 'Self'
        : [assignedName].where((s) => s.isNotEmpty).join(' • '));

    final String managerName = displayUserNameText(managerId);
    final bool isSelfManager = managerId == userMeta.id;
    final String managerLine = managerId == ''
        ? 'Unassigned'
        : (isSelfManager
        ? 'Self'
        : [managerName].where((s) => s.isNotEmpty).join(' • '));

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              'QR ID: ${qrCode.qrId}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if ((qrCode.todayTotalPayIn ?? 0) >= qrPayInTodayLimit)
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.redAccent,
                  ),
                  Text("Limit Reached For Today"),
                ],
              ),
            const SizedBox(height: 12),
            isMobile
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQrLeftSection(context),
                const SizedBox(height: 16),
                _rightMetricsBlock(context),
              ],
            )
                : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQrLeftSection(context),
                const SizedBox(width: 16),
                Expanded(child: _rightMetricsBlock(context)),
              ],
            ),

            const SizedBox(height: 12),
            Center(child: _buildActionButtons(context)),
            const Divider(height: 20),

            Row(
              children: [
                const SizedBox(width: 70, child: Text("User:")),
                const Icon(Icons.person, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    assigneeLine.isEmpty ? 'Unassigned' : assigneeLine,
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (!userMode)
              Row(
                children: [
                  const SizedBox(width: 70, child: Text("Manager:")),
                  const Icon(Icons.admin_panel_settings, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      managerLine.isEmpty ? 'Unassigned' : managerLine,
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrLeftSection(BuildContext context) {
    final statusColor = qrCode.isActive ? Colors.green : Colors.red;
    final statusBg = qrCode.isActive
        ? Colors.green.withValues(alpha: 0.1)
        : Colors.red.withValues(alpha: 0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 140,
                height: 140,
                child: qrCode.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: qrCode.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 280,
                  memCacheHeight: 280,
                  placeholder: (c, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (c, _, __) => Icon(Icons.broken_image, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  errorListener: (_) {},
                )
                    : const Icon(Icons.qr_code_2, size: 72, color: Colors.blueGrey),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openQrPreviewDialog(context, qrCode.imageUrl),
                ),
              ),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: Tooltip(
                message: 'Download QR',
                child: FloatingActionButton.small(
                  heroTag: 'dl-${qrCode.qrId}',
                  elevation: 1,
                  onPressed: () => _downloadQrImage(qrCode.imageUrl),
                  child: const Icon(Icons.download),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(qrCode.isActive ? Icons.check_circle : Icons.cancel, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(qrCode.isActive ? 'ACTIVE' : 'Suspicious', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  void _openQrPreviewDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: url.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (c, _) => const SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (c, _, __) => const Icon(Icons.error, size: 72),
                  errorListener: (_) {},
                )
                    : const Icon(Icons.qr_code_2, size: 120),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadQrImage(String url) async {
    try {
      if (url.isEmpty) return;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes]);
        final obj = html.Url.createObjectUrlFromBlob(blob);
        final a = html.AnchorElement(href: obj)
          ..download = "qr_${DateTime.now().millisecondsSinceEpoch}.png"
          ..style.display = 'none';
        html.document.body!.append(a);
        a.click();
        a.remove();
        html.Url.revokeObjectUrl(obj);
      } else {
        if (kDebugMode) debugPrint('Download failed (${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Download error: $e');
    }
  }

  Widget _rightMetricsBlock(BuildContext context) {
    final bool isAdmin = userMeta.role == "admin";
    final bool isSubAdmin = userMeta.role == "subadmin";
    final bool isEmployee = userMeta.role == "employee";
    String inr(num p) => CurrencyUtils.formatIndianCurrency(p / 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (ctx, cts) {
            final w = cts.maxWidth;

            final maxTileW = w >= 1000 ? 260.0 : w >= 760 ? 230.0 : w >= 560 ? 200.0 : 170.0;
            final minTileW = 150.0;
            final labelSmall = w < 420;
            final hideIcons = w < 340;

            final tileTheme = Theme.of(context);
            Widget metricTile(String label, String value, {IconData? icon, Color? color}) {
              return ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTileW, maxWidth: maxTileW),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: tileTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: Border.all(color: tileTheme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (!hideIcons && icon != null) ...[
                        Icon(icon, size: 16, color: color ?? Colors.blueGrey),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelSmall
                                  ? label
                                  .replaceAll('Avail. Withdrawal', 'Available')
                                  .replaceAll('Amount Received', 'Received')
                                  .replaceAll('Today Pay-In', 'Today')
                                  : label,
                              style: TextStyle(fontSize: 11, color: tileTheme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final tiles = <Widget>[
              metricTile('Today Pay-In', inr(qrCode.todayTotalPayIn ?? 0), icon: Icons.today, color: Colors.indigo),
              metricTile('Yesterday Pay-In', inr(qrCode.yesterdayTotalPayIn ?? 0), icon: Icons.history, color: Colors.deepPurple),
              metricTile('Transactions',
                  CurrencyUtils.formatIndianCurrencyWithoutSign(qrCode.totalTransactions ?? 0),
                  icon: Icons.receipt_long, color: Colors.teal),
              if (isAdmin || isSubAdmin || isEmployee)
                metricTile('Total Amount Rec', inr(qrCode.totalPayInAmount ?? 0),
                    icon: Icons.account_balance_wallet, color: Colors.deepPurple),
              metricTile('Avail. Withdrawal', inr(qrCode.amountAvailableForWithdrawal ?? 0),
                  icon: Icons.savings, color: Colors.green),
              metricTile('Withdrawable Amount', inr(qrCode.canWithdrawToday() ?? 0),
                  icon: Icons.savings, color: Colors.green),
            ];

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tiles,
            );
          },
        ),

        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kv(context, 'Requested', inr(qrCode.withdrawalRequestedAmount ?? 0)),
              _kv(context, 'Approved', inr(qrCode.withdrawalApprovedAmount ?? 0)),
              _kv(context, 'Comm On-Hold', inr(qrCode.commissionOnHold ?? 0)),
              _kv(context, 'Comm Paid', inr(qrCode.commissionPaid ?? 0)),
              _kv(context, 'Amt On-Hold', inr(qrCode.amountOnHold ?? 0)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Created: $formattedDate', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final canUserActions = (!userMode || (userMeta.role.contains("subadmin") && userMeta.labels.contains("users")));
    final canViewTx =
        (userMeta.role == "admin") ||
            (userMeta.role == "employee" && userMeta.labels.contains(AppConstants.viewAllTransactions)) ||
            (userMeta.role == "subadmin") ||
            (userMeta.role == "user");

    Widget action({required IconData icon, required String tip, required VoidCallback? onTap, Color? color}) {
      final c = color ?? Colors.blueGrey;
      return ActionChip(
        avatar: Icon(icon, size: 16, color: isProcessing ? Colors.grey : c),
        label: Text(
          tip,
          style: TextStyle(fontSize: 11, color: isProcessing ? Colors.grey : c),
        ),
        onPressed: isProcessing ? null : onTap,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (userMeta.role != "employee" && canUserActions)
          action(
            icon: qrCode.isActive ? Icons.toggle_on : Icons.toggle_off,
            tip: 'Toggle Status',
            onTap: onToggleStatus,
            color: qrCode.isActive ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        if (userMeta.role != "employee" && canUserActions)
          action(
            icon: qrCode.assignedUserId == null ? Icons.person_add_alt_1 : Icons.person_outline,
            tip: qrCode.assignedUserId == null ? 'Assign User' : 'Change User Assignment',
            onTap: qrCode.assignedUserId == null ? onAssignUser : onAssignUserOptions,
            color: Colors.blueAccent,
          ),
        if (userMeta.role != "employee" && canUserActions && userMeta.role == 'admin')
          action(
            icon: qrCode.managedByUserId == null ? Icons.admin_panel_settings_outlined : Icons.admin_panel_settings,
            tip: qrCode.managedByUserId == null ? 'Assign to Merchant' : 'Change Merchant Assignment',
            onTap: qrCode.managedByUserId == null ? onAssignSubAdmin : onAssignSubAdminOptions,
            color: Colors.blueAccent,
          ),
        if (canViewTx)
          action(
            icon: Icons.article_outlined,
            tip: 'View Transactions',
            onTap: onViewTransactions,
            color: Colors.deepPurple,
          ),
        if (!userMode && userMeta.role == "admin")
          action(
            icon: Icons.delete_outline,
            tip: 'Delete QR Code',
            onTap: onDelete,
            color: Colors.redAccent,
          ),
        if (!userMode && userMeta.role == "admin")
          action(
            icon: Icons.photo_camera,
            tip: 'Change QR Code Image',
            onTap: onEditImage,
            color: Colors.blueAccent,
          ),
        action(
          icon: Icons.lock_clock,
          tip: userMeta.role == "admin" ? 'Manual Hold / Release' : 'View Hold History',
          onTap: onManualHold,
          color: Colors.orange,
        ),
        if (userMode && qrCode.isActive && onNotifyServer != null)
          action(
            icon: Icons.add_alert,
            tip: 'Notify Server',
            onTap: onNotifyServer,
            color: Colors.orange,
          ),
      ],
    );
  }
}
