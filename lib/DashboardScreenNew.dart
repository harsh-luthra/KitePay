import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' show User;
import 'AppWriteService.dart';
import 'ManageUsersScreen.dart';
import 'ManageQrScreen.dart';
import 'TransactionPageNew.dart';
import 'ManageWithdrawals.dart';
import 'WithdrawalFormPage.dart';
import 'adminLoginPage.dart';

class DashboardScreenNew extends StatefulWidget {
  final User user;

  const DashboardScreenNew({super.key, required this.user});

  @override
  State<DashboardScreenNew> createState() => _DashboardScreenNewState();
}

class _DashboardScreenNewState extends State<DashboardScreenNew> {
  final AppWriteService _appWriteService = AppWriteService();

  // Paint/interaction state
  bool _sidebarCollapsed = false;
  int _activeIndex = 0;
  final Map<int, bool> _hovering = {};

  // Responsive breakpoint where sidebar becomes a drawer
  static const double kDesktopBreakpoint = 900;

  // Menu definition: label, icon, and builder to return corresponding screen
  late final List<_MenuItem> _allMenuItems;

  @override
  void initState() {

    super.initState();

    if(widget.user.labels.contains("admin")){
      _activeIndex = 0;
    }else{
      _activeIndex = 2;
    }

    _allMenuItems = [
      _MenuItem(
        id: 0,
        label: 'Manage Users',
        icon: Icons.person,
        visibleFor: (labels) => labels.contains('user') || labels.contains('admin'),
        builder: (_) => const ManageUsersScreen(),
      ),
      _MenuItem(
        id: 1,
        label: 'Manage All QR Codes',
        icon: Icons.qr_code,
        visibleFor: (labels) => labels.contains('qr') || labels.contains('admin'),
        builder: (_) => ManageQrScreen(),
      ),
      _MenuItem(
        id: 2,
        label: 'My QR Codes',
        icon: Icons.qr_code_scanner,
        visibleFor: (_) => true,
        builder: (user) => ManageQrScreen(userMode: true, userModeUserid: user.$id),
      ),
      _MenuItem(
        id: 3,
        label: 'View All Transactions',
        icon: Icons.receipt_long,
        visibleFor: (labels) => labels.contains('transactions') || labels.contains('admin'),
        builder: (_) => const TransactionPageNew(),
      ),
      _MenuItem(
        id: 4,
        label: 'View My Transactions',
        icon: Icons.receipt,
        visibleFor: (_) => true,
        builder: (user) => TransactionPageNew(userMode: true, userModeUserid: user.$id),
      ),
      _MenuItem(
        id: 5,
        label: 'All Withdrawals',
        icon: Icons.account_balance_wallet_outlined,
        visibleFor: (labels) => labels.contains('withdrawal') || labels.contains('admin'),
        builder: (_) => ManageWithdrawals(),
      ),
      _MenuItem(
        id: 6,
        label: 'My Withdrawals',
        icon: Icons.account_balance_wallet,
        visibleFor: (_) => true,
        builder: (user) => ManageWithdrawals(userMode: true, userModeUserid: user.$id),
      ),
      _MenuItem(
        id: 7,
        label: 'Settings',
        icon: Icons.settings,
        visibleFor: (labels) => labels.contains('payout') || labels.contains('admin'),
        builder: (_) => WithdrawalFormPage(),
      ),
    ];

    // init hovering states
    for (var item in _allMenuItems) {
      _hovering[item.id] = false;
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _appWriteService.account.deleteSession(sessionId: 'current');
        if (!mounted) return;

        // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              (route) => false,
        );

      } catch (e) {
        print(e);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Logout failed: ${e.toString()}')));
      }
    }
  }

  List<_MenuItem> get _visibleMenuItems {
    final labels = widget.user.labels.map((e) => e.toString()).toList();
    return _allMenuItems.where((m) => m.visibleFor(labels)).toList();
  }

  void _onSelectMenu(_MenuItem item, bool isDesktop) {
    setState(() {
      _activeIndex = item.id;
    });
    if (!isDesktop) Navigator.pop(context); // close drawer on mobile
  }

  // Build sidebar item widget
  Widget _buildSidebarItem(_MenuItem item, bool isActive, bool collapsed) {
    final hovering = _hovering[item.id] ?? false;
    final bg = isActive
        ? Colors.blue.shade700
        : (hovering ? Colors.grey.shade200 : Colors.transparent);
    final fg = isActive ? Colors.white : Colors.black87;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering[item.id] = true),
      onExit: (_) => setState(() => _hovering[item.id] = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _onSelectMenu(item, true),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: collapsed ? 8 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                // active left indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.yellow.shade700 : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(item.icon, color: isActive ? Colors.white : Colors.black54),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      overflow: TextOverflow.ellipsis, // no overflow
                      item.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (isActive && !collapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(bool collapsed, bool isDesktop) {
    final items = _visibleMenuItems;
    return Container(
      width: collapsed ? 110 : 260,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // header (profile + collapse)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.shade700,
                  child: Text(
                    (widget.user.name?.isNotEmpty ?? false)
                        ? widget.user.name!.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.name ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.user.email ?? '',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _sidebarCollapsed ? 'Expand' : 'Collapse',
                    onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                    icon: Icon(_sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left),
                  )
                ] else
                  IconButton(
                    onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                    icon: const Icon(Icons.menu),
                    tooltip: 'Expand',
                  )
              ],
            ),
          ),

          const SizedBox(height: 8),
          // menu list
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: items.map((mi) {
                  final isActive = _activeIndex == mi.id;
                  return _buildSidebarItem(mi, isActive, collapsed);
                }).toList(),
              ),
            ),
          ),

          // bottom quick actions
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      onPressed: () => _logout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const SizedBox(width: 8),
          Text(
            '${widget.user.name ?? "Dashboard"}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // small profile + quick logout
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.user.name ?? ''),
                  Text(widget.user.email ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Logout',
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build content area; uses AnimatedSwitcher for smooth transitions
  Widget _buildContent() {
    final menuItem = _allMenuItems.firstWhere((m) => m.id == _activeIndex, orElse: () => _allMenuItems.first);
    final Widget page = menuItem.builder(widget.user);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) {
        final offsetAnim = Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(anim);
        return SlideTransition(position: offsetAnim, child: FadeTransition(opacity: anim, child: child));
      },
      child: SizedBox(
        key: ValueKey<int>(_activeIndex),
        width: double.infinity,
        height: double.infinity,
        child: page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= kDesktopBreakpoint;

    return Scaffold(
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(false, false)),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar for desktop
            if (isDesktop) _buildSidebar(_sidebarCollapsed, true),

            // Main area (topbar + content)
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(isDesktop),
                  Expanded(
                    child: Container(
                      color: Theme.of(context).colorScheme.background,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small helper class for menu metadata
class _MenuItem {
  final int id;
  final String label;
  final IconData icon;
  final bool Function(List<String> userLabels) visibleFor;
  final Widget Function(User user) builder;

  _MenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.visibleFor,
    required this.builder,
  });
}
