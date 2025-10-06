import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Replace these imports with actual app paths if needed
import 'AppWriteService.dart';
import 'UsersService.dart';
import 'CommissionService.dart';
import 'models/AppUser.dart';
import 'AppConstants.dart';
import 'TransactionPageNew.dart';
import 'AppConfig.dart';

// ======================= Utils: Money formatting =======================
class MoneyFormat {
  static String fmtPaise(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }
}

// ======================= Utils: Async + Dialogs =======================
class AsyncUi {
  static void toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class DialogService {
  static Future<bool> confirm(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  static Future<T?> promptText<T>(
    BuildContext context, {
    required String title,
    required String label,
    String? initial,
    String? Function(String?)? validator,
    bool obscure = false,
    TextInputType? type,
    List<TextInputFormatter>? formatters,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final formKey = GlobalKey<FormState>();
    return await showDialog<T>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                obscureText: obscure,
                decoration: InputDecoration(labelText: label),
                keyboardType: type,
                inputFormatters: formatters,
                validator: validator,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(ctx, controller.text as T?);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  static Future<T> withProgress<T>(
    BuildContext context,
    Future<T> Function() task,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      return await task();
    } finally {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
}

// ======================= Capabilities =======================
class UsersCapabilities {
  final AppUser me;

  UsersCapabilities(this.me);

  bool canAddUser() => me.role != 'employee';

  bool canRefresh() => true;

  bool canToggleStatus(AppUser target) =>
      target.role != 'admin' && me.role != 'employee';

  bool canAssign(AppUser target) =>
      target.role == 'user' &&
      me.role != 'employee' &&
      (target.parentId == null || target.parentId!.isEmpty);

  bool canUnassign(AppUser target) =>
      target.role == 'user' &&
      me.role != 'employee' &&
      (target.parentId?.isNotEmpty ?? false);

  bool canEdit(AppUser target) => me.role != 'employee';

  bool canEditCommission(AppUser target) =>
      me.role != 'employee' && target.role != 'employee';

  bool canResetPassword(AppUser target) => me.role != 'employee';

  bool canDelete(AppUser target) => me.role != 'employee';

  bool canViewTransactions(AppUser target) =>
      me.role == 'admin' ||
      me.role == 'subadmin' ||
      (me.role == 'employee' &&
          me.labels.contains(AppConstants.viewAllTransactions));
}

// ======================= Controller =======================
class UsersController extends ChangeNotifier {
  final UsersService userService;
  final AppWriteService auth;

  UsersController({required this.userService, required this.auth});

  String? _nextCursor;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;

  final List<AppUser> users = [];
  final Map<String, int> todayPaise = {}; // userId -> paise
  String todayDate = '';

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    _nextCursor = null;
    hasMore = true;
    users.clear();
    await _loadInternal(first: true);
  }

  Future<void> loadMoreIfNeeded() async {
    if (!hasMore || loadingMore || loading) return;
    await _loadInternal(first: false);
  }

  Future<void> _loadInternal({required bool first}) async {
    if (first) {
      loading = true;
    } else {
      loadingMore = true;
    }
    notifyListeners();
    try {
      final jwt = await auth.getJWT();
      final resp = await UsersService.listUsers(
        cursor: _nextCursor,
        jwtToken: jwt,
      );
      // resp: expects fields appUsers: List<AppUser>, nextCursor: String?
      final existing = users.map((u) => u.id).toSet();
      final fresh =
          resp.appUsers.where((u) => !existing.contains(u.id)).toList();
      if (first) {
        users
          ..clear()
          ..addAll(resp.appUsers);
      } else {
        users.addAll(fresh);
      }
      _nextCursor = resp.nextCursor;
      if (_nextCursor == null || fresh.isEmpty) hasMore = false;
    } finally {
      loading = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadTodayCommissionsIfAdmin(AppUser me) async {
    if (me.role != 'admin') return;
    final jwt = await auth.getJWT();
    final snap = await CommissionService.fetchTodayPerUserCommissions(
      jwtToken: jwt,
    );
    // snap: expects fields paiseByUser: Map<String,int>, date: String
    todayPaise
      ..clear()
      ..addAll(snap.paiseByUser);
    todayDate = snap.date;
    notifyListeners();
  }
}

// ======================= Flows =======================
class AssignmentFlow {
  static Future<void> assignToSubadmin({
    required BuildContext context,
    required AppUser target,
    required Future<String> Function() getJwt,
    required Future<List<AppUser>> Function(String jwt, String search)
    listSubAdmins,
    required Future<void> Function({
      required String subAdminId,
      required String userId,
      required String jwtToken,
      bool unAssign,
    })
    assign,
    required VoidCallback onSuccess,
  }) async {
    final subadmin = await _pickSubadmin(context, getJwt, listSubAdmins);
    if (subadmin == null) return;
    await DialogService.withProgress(context, () async {
      final jwt = await getJwt();
      await assign(
        subAdminId: subadmin.id,
        userId: target.id,
        jwtToken: jwt,
        unAssign: false,
      );
    });
    AsyncUi.toast(context, 'Assigned to ${subadmin.name}');
    onSuccess();
  }

  static Future<void> unassign({
    required BuildContext context,
    required AppUser target,
    required String subadminId,
    required Future<String> Function() getJwt,
    required Future<void> Function({
      required String subAdminId,
      required String userId,
      required String jwtToken,
      bool unAssign,
    })
    assign,
    required VoidCallback onSuccess,
  }) async {
    final ok = await DialogService.confirm(
      context,
      'Un-assign User',
      'Remove this user from sub-admin?',
    );
    if (!ok) return;
    await DialogService.withProgress(context, () async {
      final jwt = await getJwt();
      await assign(
        subAdminId: subadminId,
        userId: target.id,
        jwtToken: jwt,
        unAssign: true,
      );
    });
    AsyncUi.toast(context, 'Unassigned successfully');
    onSuccess();
  }

  static Future<AppUser?> _pickSubadmin(
    BuildContext context,
    Future<String> Function() getJwt,
    Future<List<AppUser>> Function(String, String) listSubAdmins,
  ) async {
    String search = '';
    Timer? debouncer;
    return await showDialog<AppUser>(
      context: context,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder:
                (ctx, setState) => AlertDialog(
                  title: const Text('Select Sub-admin'),
                  content: SizedBox(
                    width: 320,
                    height: 380,
                    child: Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search by name or email',
                          ),
                          onChanged: (v) {
                            if (debouncer?.isActive ?? false)
                              debouncer!.cancel();
                            debouncer = Timer(
                              const Duration(milliseconds: 400),
                              () {
                                setState(() => search = v);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: FutureBuilder<List<AppUser>>(
                            future: getJwt().then(
                              (jwt) => listSubAdmins(jwt, search),
                            ),
                            builder: (c, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snap.hasError) {
                                return Center(
                                  child: Text('Error: ${snap.error}'),
                                );
                              }
                              final items = snap.data ?? [];
                              if (items.isEmpty)
                                return const Center(
                                  child: Text('No sub-admins found'),
                                );
                              return ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (_, i) {
                                  final sa = items[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text('${i + 1}'),
                                    ),
                                    title: Text(sa.name),
                                    subtitle: Text(sa.email),
                                    onTap: () => Navigator.pop(ctx, sa),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
          ),
    );
  }
}

class CommissionEditFlow {
  static Future<void> edit({
    required BuildContext context,
    required AppUser user,
    required double min,
    required double max,
    required Future<String> Function() getJwt,
    required Future<void> Function(String id, String jwt, {double? commission})
    editUser,
    required VoidCallback onSuccess,
  }) async {
    final value = await DialogService.promptText<String>(
      context,
      title: 'Edit Commission',
      label: 'Commission (%)',
      initial: user.commission?.toStringAsFixed(1),
      type: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Enter a commission value';
        final d = double.tryParse(v);
        if (d == null) return 'Enter a valid number';
        final okOneDecimal = RegExp(r'^\d+(\.\d{1})?$').hasMatch(v);
        if (!okOneDecimal) return 'Only one digit after decimal allowed';
        if (d < min || d > max) return 'Value must be between $min and $max';
        return null;
      },
      formatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
      ],
    );
    if (value == null) return;
    final newCommission = double.parse(value);
    await DialogService.withProgress(context, () async {
      final jwt = await getJwt();
      await editUser(user.id, jwt, commission: newCommission);
    });
    AsyncUi.toast(context, 'User Commission Updated Successfully');
    onSuccess();
  }
}

class PasswordResetFlow {
  static Future<void> reset({
    required BuildContext context,
    required String userId,
    required Future<String> Function() getJwt,
    required Future<void> Function(String id, String newPass, String jwt)
    resetPassword,
  }) async {
    final pwd = await DialogService.promptText<String>(
      context,
      title: 'Reset Password',
      label: 'New Password',
      obscure: true,
      validator:
          (v) =>
              (v == null || v.trim().length < 6)
                  ? 'Password must be at least 6 characters'
                  : null,
    );
    if (pwd == null) return;
    await DialogService.withProgress(context, () async {
      final jwt = await getJwt();
      await resetPassword(userId, pwd.trim(), jwt);
    });
    AsyncUi.toast(context, 'Password reset successfully');
  }
}

class UserEditFlow {
  static String _stripZeroWidth(String s) =>
      s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

  static String _normalizeName(String? v) {
    final t = _stripZeroWidth((v ?? '')).replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static String _normalizeEmail(String? v) {
    final t = _stripZeroWidth((v ?? '')).trim().toLowerCase();
    return t;
  }

  static Future<void> edit({
    required BuildContext context,
    required AppUser user,
    required AppUser me,
    required List<String> availableLabels,
    required Future<String> Function() getJwt,
    required Future<void> Function(
        String id,
        String jwt, {
        String? name,
        String? email,
        List<String>? labels,
        }) editUser,
    required VoidCallback onSuccess,
  }) async {
    // Prefill controllers with raw values; validators will normalize.
    final nameCtl = TextEditingController(text: user.name);
    final emailCtl = TextEditingController(text: user.email);
    final labels = List<String>.from(user.labels);
    final formKey = GlobalKey<FormState>();

    // Precompute normalized originals for later change detection
    final origNameN = _normalizeName(user.name);
    final origEmailN = _normalizeEmail(user.email);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit User'),
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) {
                      final t = _normalizeName(v);
                      if (t.length < 3) return 'Name must be at least 3 characters';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: emailCtl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final e = _normalizeEmail(v);
                      if (e.isEmpty) return 'Enter a valid email';
                      // Use either a normal string with \\s or a raw string without double escaping.
                      final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!re.hasMatch(e)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  if (me.role == 'admin') ...[
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Labels:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableLabels.map((label) {
                        final selected = labels.contains(label);
                        return FilterChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                if (!labels.contains(label)) labels.add(label);
                              } else {
                                labels.remove(label);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    // Normalize before comparing and submitting
    final newNameN = _normalizeName(nameCtl.text);
    final newEmailN = _normalizeEmail(emailCtl.text);

    final nameChanged = newNameN != origNameN;
    final emailChanged = newEmailN != origEmailN;
    final labelsChanged = !(Set.from(labels).containsAll(user.labels) &&
        Set.from(user.labels).containsAll(labels));

    if (!nameChanged && !emailChanged && !labelsChanged) {
      AsyncUi.toast(context, 'Nothing changed');
      return;
    }

    await DialogService.withProgress(context, () async {
      final jwt = await getJwt();
      await editUser(
        user.id,
        jwt,
        name: nameChanged ? newNameN : null,
        email: emailChanged ? newEmailN : null,
        labels: labelsChanged ? labels : null,
      );
    });
    AsyncUi.toast(context, 'User updated');
    onSuccess();
  }
}

// ======================= UI atoms =======================
class InfoToken extends StatelessWidget {
  final IconData icon;
  final String k;
  final String v;

  const InfoToken({
    super.key,
    required this.icon,
    required this.k,
    required this.v,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text('$k: $v'),
        ],
      ),
    );
  }
}

class LabelsStripe extends StatelessWidget {
  final List<String> labels;

  const LabelsStripe({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children:
            labels
                .map(
                  (l) => Chip(
                    label: Text(l),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
      ),
    );
  }
}

class ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;

  const ActionIcon({
    super.key,
    required this.icon,
    required this.tip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tip, icon: Icon(icon), onPressed: onTap);
  }
}

// ======================= User Card =======================
class UserCard extends StatelessWidget {
  final AppUser user;
  final UsersCapabilities caps;
  final int todayPaise;
  final VoidCallback onRefresh;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onAssign;
  final VoidCallback? onUnassign;
  final VoidCallback? onEdit;
  final VoidCallback? onEditCommission;
  final VoidCallback? onResetPassword;
  final VoidCallback? onDelete;
  final VoidCallback? onViewTransactions;

  const UserCard({
    super.key,
    required this.user,
    required this.caps,
    required this.todayPaise,
    required this.onRefresh,
    this.onToggleStatus,
    this.onAssign,
    this.onUnassign,
    this.onEdit,
    this.onEditCommission,
    this.onResetPassword,
    this.onDelete,
    this.onViewTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user.status == true || user.status == true;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (caps.canToggleStatus(user))
                      Switch(
                        value: isActive,
                        onChanged: (_) => onToggleStatus?.call(),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Info tokens
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (user.role != 'admin')
                  InfoToken(
                    icon: Icons.account_tree,
                    k: 'Parent',
                    v: (user.parentId?.isEmpty ?? true) ? 'Admin' : 'Sub-Admin',
                  ),
                InfoToken(icon: Icons.badge_outlined, k: 'Role', v: user.role),
                if (user.role != 'employee' && user.role != 'admin')
                  InfoToken(
                    icon: Icons.percent,
                    k: 'Commission',
                    v: '${user.commission ?? 0} %',
                  ),
                if (['admin', 'subadmin'].contains(user.role))
                  InfoToken(
                    icon: Icons.currency_rupee,
                    k: 'Today Commission',
                    v: MoneyFormat.fmtPaise(todayPaise),
                  ),
              ],
            ),
            LabelsStripe(labels: user.labels),
            const SizedBox(height: 10),
            // Toolbar
            Wrap(
              spacing: 4,
              children: [
                if (caps.canAssign(user))
                  ActionIcon(
                    icon: Icons.no_accounts_outlined,
                    tip: 'Assign to Sub-Admin',
                    onTap: onAssign,
                  ),
                if (caps.canUnassign(user))
                  ActionIcon(
                    icon: Icons.account_circle,
                    tip: 'Un-Assign',
                    onTap: onUnassign,
                  ),
                if (caps.canEdit(user))
                  ActionIcon(icon: Icons.edit, tip: 'Edit', onTap: onEdit),
                if (caps.canEditCommission(user))
                  ActionIcon(
                    icon: Icons.percent,
                    tip: 'Edit Commission',
                    onTap: onEditCommission,
                  ),
                if (caps.canResetPassword(user))
                  ActionIcon(
                    icon: Icons.lock_reset,
                    tip: 'Reset Password',
                    onTap: onResetPassword,
                  ),
                if (caps.canDelete(user))
                  ActionIcon(
                    icon: Icons.delete_outline,
                    tip: 'Delete',
                    onTap: onDelete,
                  ),
                if (caps.canViewTransactions(user))
                  ActionIcon(
                    icon: Icons.receipt_long,
                    tip: 'Transactions',
                    onTap: onViewTransactions,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= Users List =======================
class UsersListView extends StatefulWidget {
  final UsersController controller;
  final AppUser me;
  final List<String> availableLabels;

  const UsersListView({
    super.key,
    required this.controller,
    required this.me,
    required this.availableLabels,
  });

  @override
  State<UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends State<UsersListView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      widget.controller.loadMoreIfNeeded();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caps = UsersCapabilities(widget.me);
    final users = widget.controller.users;

    if (widget.controller.loading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        itemCount: users.length + (widget.controller.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= users.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final u = users[index];
          final today = widget.controller.todayPaise[u.id] ?? 0;

          return UserCard(
            user: u,
            caps: caps,
            todayPaise: today,
            onRefresh: widget.controller.refresh,
            onToggleStatus: () async {
              final newStatus = !(u.status == true || u.status == true);
              final ok = await DialogService.confirm(
                context,
                newStatus ? 'Enable User' : 'Disable User',
                'Are you sure you want to ${newStatus ? 'enable' : 'disable'} this user?',
              );
              if (!ok) return;
              await DialogService.withProgress(context, () async {
                final jwt = await AppWriteService().getJWT();
                await UsersService.updateUserStatus(
                  userId: u.id,
                  jwtToken: jwt,
                  status: newStatus,
                );
              });
              AsyncUi.toast(context, 'User status updated.');
              await widget.controller.refresh();
            },
            onAssign: () async {
              await AssignmentFlow.assignToSubadmin(
                context: context,
                target: u,
                getJwt: () => AppWriteService().getJWT(),
                listSubAdmins:
                    (jwt, search) =>
                        UsersService.listSubAdmins(jwt, search: search),
                assign:
                    ({
                      required String subAdminId,
                      required String userId,
                      required String jwtToken,
                      bool unAssign = false,
                    }) => UsersService.assignUserToSubAdmin(
                      subAdminId: subAdminId,
                      userId: userId,
                      jwtToken: jwtToken,
                      unAssign: unAssign,
                    ),
                onSuccess: widget.controller.refresh,
              );
            },
            onUnassign: () async {
              await AssignmentFlow.unassign(
                context: context,
                target: u,
                subadminId: u.parentId ?? '',
                getJwt: () => AppWriteService().getJWT(),
                assign:
                    ({
                      required String subAdminId,
                      required String userId,
                      required String jwtToken,
                      bool unAssign = false,
                    }) => UsersService.assignUserToSubAdmin(
                      subAdminId: subAdminId,
                      userId: userId,
                      jwtToken: jwtToken,
                      unAssign: true,
                    ),
                onSuccess: widget.controller.refresh,
              );
            },
            onEdit: () async {
              await UserEditFlow.edit(
                context: context,
                user: u,
                me: widget.me,
                availableLabels: widget.availableLabels,
                getJwt: () => AppWriteService().getJWT(),
                editUser:
                    (
                      id,
                      jwt, {
                      String? name,
                      String? email,
                      List<String>? labels,
                    }) => UsersService.editUser(
                      id,
                      jwt,
                      name: name,
                      email: email,
                      labels: labels,
                    ),
                onSuccess: widget.controller.refresh,
              );
            },
            onEditCommission: () async {
              await CommissionEditFlow.edit(
                context: context,
                user: u,
                min: AppConfig().minCommission,
                max: AppConfig().maxCommission,
                getJwt: () => AppWriteService().getJWT(),
                editUser:
                    (id, jwt, {double? commission}) =>
                        UsersService.editUser(id, jwt, commission: commission),
                onSuccess: widget.controller.refresh,
              );
            },
            onResetPassword: () async {
              await PasswordResetFlow.reset(
                context: context,
                userId: u.id,
                getJwt: () => AppWriteService().getJWT(),
                resetPassword:
                    (id, newPass, jwt) =>
                        UsersService.resetPassword(id, newPass, jwt),
              );
            },
            onDelete: () async {
              final ok = await DialogService.confirm(
                context,
                'Delete User',
                'This action cannot be undone. Continue?',
              );
              if (!ok) return;
              await DialogService.withProgress(context, () async {
                final jwt = await AppWriteService().getJWT();
                await UsersService.deleteUser(u.id, jwt);
              });
              AsyncUi.toast(context, 'User deleted.');
              await widget.controller.refresh();
            },
            onViewTransactions: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionPageNew(filterUserId: u.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ======================= Manage Users Screen (single file) =======================
class ManageUsersScreenRefactor extends StatefulWidget {
  final AppUser me;

  const ManageUsersScreenRefactor({
    super.key,
    required this.me,
  });

  @override
  State<ManageUsersScreenRefactor> createState() =>
      _ManageUsersScreenRefactorState();
}

class _ManageUsersScreenRefactorState extends State<ManageUsersScreenRefactor> {
  late final UsersController controller;

  final List<String> availableLabels = ['SelfQr', 'users', 'all_users', 'all_qr', 'manual_transactions','all_transactions', 'edit_transactions', 'all_withdrawals' , 'edit_withdrawals'];

  @override
  void initState() {
    super.initState();
    controller = UsersController(
      userService: UsersService(),
      auth: AppWriteService(),
    );
    controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.init();
      await controller.loadTodayCommissionsIfAdmin(widget.me);
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caps = UsersCapabilities(widget.me);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          if (caps.canRefresh())
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await controller.refresh();
                await controller.loadTodayCommissionsIfAdmin(widget.me);
              },
            ),
          if (caps.canAddUser())
            IconButton(
              tooltip: 'Add User',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () async {
                final nameCtl = TextEditingController();
                final emailCtl = TextEditingController();
                final passCtl = TextEditingController();
                String? selectedRole =
                    (widget.me.role == 'subadmin') ? 'user' : null;

                final formKey = GlobalKey<FormState>();

                final created = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => StatefulBuilder(
                        builder:
                            (ctx, setState) => AlertDialog(
                              title: const Text('Add New User'),
                              content: Form(
                                key: formKey,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                        controller: nameCtl,
                                        decoration: const InputDecoration(
                                          labelText: 'Name',
                                          hintText: 'Min 3 characters',
                                        ),
                                        validator:
                                            (v) =>
                                                (v == null ||
                                                        v.trim().length < 3)
                                                    ? 'Enter a valid name'
                                                    : null,
                                      ),
                                      TextFormField(
                                        controller: emailCtl,
                                        decoration: const InputDecoration(
                                          labelText: 'Email',
                                          hintText: 'e.g. user@example.com',
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator:
                                            (v) =>
                                                (v == null ||
                                                        !RegExp(
                                                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                                        ).hasMatch(v))
                                                    ? 'Enter a valid email'
                                                    : null,
                                      ),
                                      TextFormField(
                                        controller: passCtl,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Password',
                                          hintText: 'Min 6 characters',
                                        ),
                                        validator:
                                            (v) =>
                                                (v == null ||
                                                        v.trim().length < 6)
                                                    ? 'Password must be at least 6 characters'
                                                    : null,
                                      ),
                                      const SizedBox(height: 12),
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Select Role',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (widget.me.role == 'admin') ...[
                                        RadioListTile<String>(
                                          title: const Text('Sub-Admin'),
                                          value: 'subadmin',
                                          groupValue: selectedRole,
                                          onChanged:
                                              (val) => setState(
                                                () => selectedRole = val,
                                              ),
                                        ),
                                        RadioListTile<String>(
                                          title: const Text('Employee'),
                                          value: 'employee',
                                          groupValue: selectedRole,
                                          onChanged:
                                              (val) => setState(
                                                () => selectedRole = val,
                                              ),
                                        ),
                                      ],
                                      RadioListTile<String>(
                                        title: const Text('User'),
                                        value: 'user',
                                        groupValue: selectedRole,
                                        onChanged:
                                            (val) => setState(
                                              () => selectedRole = val,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (!(formKey.currentState?.validate() ??
                                        false))
                                      return;
                                    if (selectedRole == null) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please select a role'),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(ctx, true);
                                  },
                                  child: const Text('Create'),
                                ),
                              ],
                            ),
                      ),
                );
                if (created != true) return;

                await DialogService.withProgress(context, () async {
                  final jwt = await AppWriteService().getJWT();
                  await UsersService.createUser(
                    emailCtl.text.trim(),
                    passCtl.text.trim(),
                    nameCtl.text.trim(),
                    selectedRole!,
                    jwt,
                  );
                });
                AsyncUi.toast(context, 'User added successfully!');
                await controller.refresh();
              },
            ),
        ],
      ),
      body: UsersListView(
        controller: controller,
        me: widget.me,
        availableLabels: availableLabels,
      ),
    );
  }
}
