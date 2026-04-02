import 'package:admin_qr_manager/AppConfig.dart';
import 'package:admin_qr_manager/AppConstants.dart';
import 'package:admin_qr_manager/QRService.dart';
import 'package:admin_qr_manager/SocketManager.dart';
import 'package:admin_qr_manager/widget/QrCardShimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppWriteService.dart';
import 'ManualHoldPage.dart';
import 'MyMetaApi.dart';
import 'TransactionPageNew.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';
import 'models/QrCode.dart';
import 'widget/QrCodeCard.dart';

// QrCodesPage.dart
class ManageQrScreen extends StatefulWidget {
  final String? userModeUserid;
  final bool userMode;
  final AppUser userMeta; // keep nullable if not always provided

  const ManageQrScreen({
    super.key,
    this.userMode = false,
    this.userModeUserid,
    required this.userMeta, // pass when userMode==true if you need it
  });

  @override
  State<ManageQrScreen> createState() => _ManageQrScreenState();
}

class _ManageQrScreenState extends State<ManageQrScreen> {
  final QrCodeService _qrCodeService = QrCodeService();
  List<QrCode> _qrCodes = [];
  List<AppUser> users = [];
  bool _isLoading = true;
  String? _jwtToken; // Placeholder for the JWT token
  final TextEditingController _qrIdController = TextEditingController();
  bool _isProcessing = false; // New state variable for showing progress

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final double QR_PayIn_Today_limit = AppConfig().qrLimitTodayPayIn;

  int userQrCount = 0;
  int activeUserQrCount = 0;
  late AppUser userMeta;

  String _managerScope = 'ALL'; // 'ALL' | 'ADMIN' | 'SUBADMIN' | 'USER' | 'UNASSIGNED'
  AppUser? _selectedAdmin;      // chosen admin for filtering (if scope == ADMIN)
  AppUser? _selectedSubadmin;   // chosen subadmin for filtering (if scope == SUBADMIN)
  AppUser? _selectedUser;       // chosen user for filtering (if scope == USER)

  bool showingFilters = false;

  // Sort state
  String _sortBy = 'createdAt_desc'; // 'createdAt_desc', 'createdAt_asc', 'todayPayIn_desc', 'todayPayIn_asc'

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // PAGINATION
  static const int _maxInMemoryQrCodes = 500;
  String? _nextCursor;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    userMeta = MyMetaApi.current!;
    _scrollController.addListener(_onScroll);

    if(!widget.userMode){
        _fetchQrCodes();
        _fetchUsers();
    }else{
      if(widget.userMeta.role.contains("subadmin")){
        _fetchUsers();
      }
      _fetchOnlyUserQrCodes();
    }
  }

  @override
  void dispose() {
    _qrIdController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> checkQrLimitTodayPayIn() async {
    for (QrCode qr in _qrCodes) {
      final todayPayIn = qr.todayTotalPayIn ?? 0;
      if (todayPayIn >= QR_PayIn_Today_limit) {
        SocketManager.instance.emitQrLimitAlert({
          "qrCodeId": qr.qrId,
          "todayPayIn": todayPayIn,
        });
      }
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isProcessing = true);
    try {
      final fetched = await UsersService.listUsers(jwtToken: await AppWriteService().getJWT());
      users = fetched.appUsers;
      _rebuildUserMap();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch users: $e')),
      );
    }
    if(!mounted) return;
    setState(() => _isProcessing = false);
  }

  Map<String, AppUser> _userMap = {};

  void _rebuildUserMap() {
    _userMap = {for (final u in users) u.id: u};
  }

  AppUser? getUserById(String id) {
    return _userMap[id];
  }

  // Helper: map role to a friendly label
  String roleLabel(String? role) {
    switch (role) {
      case 'subadmin':
        return 'Subadmin';
      case 'merchant':
        return 'Merchant';
      case 'employee':
        return 'Employee';
      case 'user':
        return 'User';
      default:
        return role ?? 'Unknown';
    }
  }

  String displayUserNameText(String appUserId){
    AppUser? user = getUserById(appUserId);
    String displayText = user != null
        ? '${user.name}\n${user.email}'
        : 'Unknown user';
    return displayText;
  }

  // All subadmins derived from local cache
  List<AppUser> get _subadminList =>
      users.where((u) => u.role == 'subadmin').toList();

// Apply local filter to qrCodes according to current dropdown state
  Widget _sortMenuItem(String label, String value) {
    return Row(
      children: [
        if (_sortBy == value)
          const Icon(Icons.check, size: 18, color: Colors.green)
        else
          const SizedBox(width: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  List<QrCode> get _visibleQrCodes {
    List<QrCode> scopeFiltered;
    switch (_managerScope) {
      case 'UNASSIGNED':
        scopeFiltered = _qrCodes.where((q) => q.assignedUserId == null && q.managedByUserId == null).toList();
        break;
      case 'ADMIN':
        if (_selectedAdmin == null) return const <QrCode>[];
        scopeFiltered = _qrCodes.where((q) => q.assignedUserId == _selectedAdmin!.id).toList();
        break;
      case 'SUBADMIN':
        if (_selectedSubadmin == null) return const <QrCode>[];
        scopeFiltered = _qrCodes.where((q) => q.managedByUserId == _selectedSubadmin!.id).toList();
        break;
      case 'USER':
        if (_selectedUser == null) return const <QrCode>[];
        scopeFiltered = _qrCodes.where((q) => q.assignedUserId == _selectedUser!.id).toList();
        break;
      case 'ALL':
      default:
        scopeFiltered = _qrCodes;
    }

    // Apply search filter
    List<QrCode> result;
    if (_searchQuery.trim().isEmpty) {
      result = List.of(scopeFiltered);
    } else {
      final q = _searchQuery.trim().toLowerCase();
      result = scopeFiltered.where((qr) {
        if (qr.qrId.toLowerCase().contains(q)) return true;
        final assignedUser = qr.assignedUserId != null ? getUserById(qr.assignedUserId!) : null;
        if (assignedUser != null &&
            (assignedUser.name.toLowerCase().contains(q) ||
             assignedUser.email.toLowerCase().contains(q))) return true;
        final manager = qr.managedByUserId != null ? getUserById(qr.managedByUserId!) : null;
        if (manager != null &&
            (manager.name.toLowerCase().contains(q) ||
             manager.email.toLowerCase().contains(q))) return true;
        return false;
      }).toList();
    }

    // Apply sort
    switch (_sortBy) {
      case 'createdAt_desc':
        result.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
        break;
      case 'createdAt_asc':
        result.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
        break;
      case 'todayPayIn_desc':
        result.sort((a, b) => (b.todayTotalPayIn ?? 0).compareTo(a.todayTotalPayIn ?? 0));
        break;
      case 'todayPayIn_asc':
        result.sort((a, b) => (a.todayTotalPayIn ?? 0).compareTo(b.todayTotalPayIn ?? 0));
        break;
      case 'yesterdayPayIn_desc':
        result.sort((a, b) => (b.yesterdayTotalPayIn ?? 0).compareTo(a.yesterdayTotalPayIn ?? 0));
        break;
      case 'yesterdayPayIn_asc':
        result.sort((a, b) => (a.yesterdayTotalPayIn ?? 0).compareTo(b.yesterdayTotalPayIn ?? 0));
        break;
    }

    return result;
  }

  Future<void> _assignUser(String? qrId, String? fileId, {QrCode? qr}) async {
    if (_jwtToken == null || qrId == null || fileId == null || _isProcessing) return;

    // Determine manager scope (if any)
    final String? managerId = qr?.managedByUserId;

    // Base role filter: only end users
    Iterable<AppUser> base = users.where((u) => u.role == 'user');

    // If QR has a manager, restrict to users under that manager
    final List<AppUser> filtered = managerId == null
        ? base.toList()
        : base.where((u) => u.parentId == managerId).toList();

    // Optional: early UX for empty list
    if (filtered.isEmpty) {
      // Show info and return, or proceed to dialog with disabled state
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible users under this manager.')),
      );
      return;
    }

    final AppUser? selectedUser = await showDialog<AppUser>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(managerId == null ? 'Select User' : 'Select User (under ${displayUserNameText(managerId)})'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final user = filtered[index];
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.name),
                  subtitle: Text('${user.email} · ${user.parentId ?? "no-parent"}'),
                  onTap: () => Navigator.of(context).pop(user),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedUser == null) return;

    setState(() => _isProcessing = true);
    _jwtToken = await AppWriteService().getJWT();
    final bool success = await _qrCodeService.assignQrCodeToUser(
      qrId: qrId,
      fileId: fileId,
      assignedUserId: selectedUser.id,
      jwtToken: _jwtToken!,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'User assigned!' : 'Failed to assign user.')),
    );
    if (success) {
      if (widget.userMeta.role == 'subadmin') {
        _fetchOnlyUserQrCodes();
      } else {
        _fetchQrCodes();
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _assignSubAdmin(String? qrId, String? fileId, {QrCode? qr}) async {
    if (_jwtToken == null || qrId == null || fileId == null || _isProcessing) return;

    final String? assignedId = qr?.assignedUserId;
    final assignedMatch = assignedId == null ? <AppUser>[] : users.where((u) => u.id == assignedId);
    final AppUser? assignedUser = assignedMatch.isNotEmpty ? assignedMatch.first : null;

    // Base: subadmins only
    final Iterable<AppUser> allSubs = users.where((u) => u.role == 'subadmin');

    // If QR has an assigned user with a parent, restrict to that parent subadmin; also ensure that subadmin is included even if filters change later.
    List<AppUser> filtered;
    if (assignedUser != null) {
      final String? parentId = assignedUser.parentId;
      if (parentId == null) {
        // Assigned user has no parent → no eligible subadmins by rule
        filtered = <AppUser>[];
      } else {
        // Only the parent subadmin
        filtered = allSubs.where((s) => s.id == parentId).toList();
      }
    } else {
      // No assigned user → show all subadmins
      filtered = allSubs.toList();
    }

    if (assignedUser?.parentId != null) {
      final parentMatch = users.where(
            (u) => u.id == assignedUser!.parentId && u.role == 'subadmin',
      );
      if (parentMatch.isNotEmpty && !filtered.any((s) => s.id == parentMatch.first.id)) {
        filtered.insert(0, parentMatch.first);
      }
    }

    // Guard: empty list UX
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignedUser == null
                ? 'No subadmins available.'
                : 'Assigned user has no parent subadmin; cannot assign manager.',
          ),
        ),
      );
      return;
    }

    // Highlight the parent subadmin in the list (if any)
    final String? highlightId = assignedUser?.parentId;

    final AppUser? selectedUser = await showDialog<AppUser>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            assignedUser == null
                ? 'Select Subadmin as QR Manager'
                : 'Select Assigned User’s Subadmin',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final sub = filtered[index];
                final bool isParent = sub.id == highlightId;
                return ListTile(
                  leading: Icon(
                    Icons.admin_panel_settings,
                    color: isParent ? Colors.deepPurple : Colors.blueGrey,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(sub.name)),
                      if (isParent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Assigned user’s subadmin',
                            style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(sub.email),
                  onTap: () => Navigator.of(context).pop(sub),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ],
        );
      },
    );

    if (selectedUser == null) return;

    setState(() => _isProcessing = true);
    _jwtToken = await AppWriteService().getJWT();
    final bool success = await _qrCodeService.assignQrCodeManager(
      qrId: qrId,
      fileId: fileId,
      managedByUserId: selectedUser.id,
      jwtToken: _jwtToken!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Subadmin assigned!' : 'Failed to assign subadmin.')),
    );

    if (success) {
      if (widget.userMeta.role == 'subadmin') {
        _fetchOnlyUserQrCodes();
      } else {
        _fetchQrCodes();
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _fetchQrCodes() async {
    _jwtToken = await AppWriteService().getJWT();
    if (_jwtToken == null) return;

    setState(() {
      _isLoading = true;
      _qrCodes.clear();
    });

    try {
      final codes = await _qrCodeService.getAllQrCodes(jwtToken: _jwtToken!);
      _qrCodes = codes.reversed.toList();
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch QR codes: $e')),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    checkQrLimitTodayPayIn();
  }

  int activeQrCount(List<QrCode> qrCodes) {
    return qrCodes.where((qr) => qr.isActive == true).length;
  }

  Future<void> _fetchOnlyUserQrCodes({bool firstLoad = true, String? userId}) async {
    final targetUserId = userId ?? widget.userModeUserid;
    if (targetUserId == null) return;
    if (!firstLoad && (_loadingMore || !_hasMore)) return;

    _jwtToken = await AppWriteService().getJWT();

    if (firstLoad) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _qrCodes.clear();
          _nextCursor = null;
          _hasMore = true;
        });
      }
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final fetched = await _qrCodeService.getUserQrCodesPaginated(
        userId: targetUserId,
        cursor: _nextCursor,
        jwtToken: _jwtToken!,
      );

      if (firstLoad) {
        _qrCodes = fetched.qrCodes.reversed.toList();
      } else {
        final existingIds = _qrCodes.map((q) => q.qrId).toSet();
        final newOnes = fetched.qrCodes.where((q) => !existingIds.contains(q.qrId));
        _qrCodes.addAll(newOnes);
      }

      _nextCursor = fetched.nextCursor;
      _hasMore = fetched.nextCursor != null &&
          _qrCodes.length < _maxInMemoryQrCodes;

      userQrCount = _qrCodes.length;
      activeUserQrCount = activeQrCount(_qrCodes);
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to fetch user QR codes: $e')),
      );
    }

    if (!mounted) return;
    if (firstLoad) {
      setState(() => _isLoading = false);
    } else {
      setState(() => _loadingMore = false);
    }

    checkQrLimitTodayPayIn();
  }

  // PAGINATION scroll listener (only applies to userMode paginated fetch)
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.userMode) {
        _fetchOnlyUserQrCodes(firstLoad: false);
      }
    }
  }

  // The main function for the floating action button now shows a dialog
  Future<void> _showUploadQrDialog() async {
    if (_jwtToken == null) return;

    final qrIdCtl = _qrIdController; // reuse existing controller
    String? qrType; // 'paytm' | 'pinelabs' | 'cashfree' | 'razorpay' | 'other'

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Upload New QR Code'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: qrIdCtl,
                    decoration: const InputDecoration(labelText: 'Enter QR ID'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Please enter a QR ID';
                      if (t.length < 4) return 'QR ID must be at least 4 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('QR Type', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),

                  // Radio options
                  RadioListTile<String>(
                    dense: true,
                    title: const Text('Paytm'),
                    value: 'paytm',
                    groupValue: qrType,
                    onChanged: (val) => setState(() => qrType = val),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    title: const Text('Pinelabs'),
                    value: 'pinelabs',
                    groupValue: qrType,
                    onChanged: (val) => setState(() => qrType = val),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    title: const Text('Cashfree'),
                    value: 'cashfree',
                    groupValue: qrType,
                    onChanged: (val) => setState(() => qrType = val),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    title: const Text('Razorpay'),
                    value: 'razorpay',
                    groupValue: qrType,
                    onChanged: (val) => setState(() => qrType = val),
                  ),
                  RadioListTile<String>(
                    dense: true,
                    title: const Text('Other'),
                    value: 'other',
                    groupValue: qrType,
                    onChanged: (val) => setState(() => qrType = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                qrIdCtl.clear();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = formKey.currentState?.validate() ?? false;
                if (!ok) return;
                if (qrType == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please select a QR type.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();

                final id = qrIdCtl.text.trim();
                // Call upload with both args; adapt signature as needed
                await _uploadQrCode(id, qrType!); // e.g., _uploadQrCode(String id, String type)
              },
              child: const Text('Select File'),
            ),
          ],
        ),
      ),
    );
  }

  // This is the updated function that takes the QR ID and handles the file upload
  Future<void> _uploadQrCode(String qrId, String qrType) async {
    if (_jwtToken == null) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );

    if (result != null) {
      PlatformFile file = result.files.first;

      // 2. Show progress during entire operation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.1),
                    blurRadius: 40,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Uploading QR Code File',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Processing your file upload...',
                    style: TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 4,
                    child: LinearProgressIndicator(
                      value: null,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );


      try {
        _jwtToken = await AppWriteService().getJWT();
        bool success = await _qrCodeService.uploadQrCode(
            file, qrId, qrType, _jwtToken!);
        Navigator.pop(context); // Close loader
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code uploaded successfully!')),
          );
          _fetchQrCodes(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload QR Code.')),
          );
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    _qrIdController.clear();
  }

  // This is the updated function that takes the QR ID and handles the file upload
  Future<void> _editQrCode(String qrId) async {
    if (_jwtToken == null) return;

    // 1. File picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );

    if (result != null) {
      PlatformFile file = result.files.first;

      // 2. Show progress during entire operation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.1),
                    blurRadius: 40,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Updating QR Code File',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Processing your file upload...',
                    style: TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 4,
                    child: LinearProgressIndicator(
                      value: null,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        _jwtToken = await AppWriteService().getJWT();
        bool success = await _qrCodeService.editQrCodeFile(file, qrId, _jwtToken!);

        Navigator.pop(context); // Close loader

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code updated successfully!')),
          );
          _fetchQrCodes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update QR Code.')),
          );
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    _qrIdController.clear();
  }

  // Handles deleting a QR code with a confirmation dialog and progress indicator
  Future<void> _deleteQrCode(String qrId) async {
    if (_jwtToken == null || _isProcessing) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this QR code? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      setState(() {
        _isProcessing = true;
      });
      _jwtToken = await AppWriteService().getJWT();
      bool success = await _qrCodeService.deleteQrCode(qrId, _jwtToken!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code deleted successfully!')),
        );
        _fetchQrCodes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete QR Code.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Toggles the isActive status of a QR code with a confirmation dialog and progress indicator
  Future<void> _toggleStatus(QrCode qrCode) async {
    if (_jwtToken == null || _isProcessing) return;
    final bool newStatus = !qrCode.isActive;
    final String statusText = newStatus ? 'activate' : 'deactivate';

    if (widget.userMeta.role == 'subadmin' && newStatus == true) {
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Action not allowed'),
          content: const Text(
            'Sub-admins can only deactivate QR codes.\n'
                'Contact an admin with the QR code ID to get it re-activated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      return; // early exit: do not proceed
    }

    String contentForDialog = "Are you sure you want to $statusText this QR code?";

    if (widget.userMeta.role == 'subadmin' && newStatus == false){
      contentForDialog = "Are you sure you want to deactivate this QR code? It cannot be re-activated by sub-admins. Only an admin can activate deactivated QR codes.";
    }

    final bool? shouldToggle = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Status Change'),
          content: Text(contentForDialog),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldToggle == true) {
      setState(() {
        _isProcessing = true;
      });
      _jwtToken = await AppWriteService().getJWT();
      bool success = await _qrCodeService.toggleQrCodeStatus(qrCode.qrId, newStatus, _jwtToken!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Code status changed to $newStatus')),
        );
        if(widget.userMeta.role == "subadmin"){
          _fetchOnlyUserQrCodes();
        }else{
          _fetchQrCodes();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to change QR code status.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }

  }

  // // Dialog to assign a user to a QR code with a confirmation dialog and progress indicator
  // Future<void> _assignUserOld(String? qrId, String? fileId) async {
  //   if (_jwtToken == null || qrId == null || fileId == null || _isProcessing) return;
  //
  //   final bool? shouldAssign = await showDialog<bool>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Confirm Assignment'),
  //         content: const Text('Are you sure you want to assign a user to this QR code?'),
  //         actions: <Widget>[
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.of(context).pop(false),
  //           ),
  //           TextButton(
  //             child: const Text('Proceed'),
  //             onPressed: () => Navigator.of(context).pop(true),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  //
  //   if (shouldAssign == true) {
  //     TextEditingController userIdController = TextEditingController();
  //     final bool? shouldConfirmAssignment = await showDialog<bool>(
  //       context: context,
  //       builder: (context) {
  //         return AlertDialog(
  //           title: const Text('Assign QR Code to User'),
  //           content: TextField(
  //             controller: userIdController,
  //             decoration: const InputDecoration(labelText: 'Enter User ID'),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () {
  //                 userIdController.clear();
  //                 Navigator.of(context).pop(false);
  //               },
  //               child: const Text('Cancel'),
  //             ),
  //             ElevatedButton(
  //               onPressed: () {
  //                 if (userIdController.text.isNotEmpty) {
  //                   Navigator.of(context).pop(true);
  //                 } else {
  //                   ScaffoldMessenger.of(context).showSnackBar(
  //                     const SnackBar(content: Text('Please enter a user ID.')),
  //                   );
  //                 }
  //               },
  //               child: const Text('Assign'),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //
  //     if (shouldConfirmAssignment == true) {
  //       setState(() {
  //         _isProcessing = true;
  //       });
  //       String userId = userIdController.text;
  //       bool success = await _qrCodeService.assignQrCode(qrId: qrId, fileId:  fileId, assignedUserId:  userId, jwtToken: _jwtToken!);
  //       if (success) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('User assigned successfully!')),
  //         );
  //         _fetchQrCodes();
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('Failed to assign user.')),
  //         );
  //       }
  //       setState(() {
  //         _isProcessing = false;
  //       });
  //     }
  //   }
  // }
  //
  // // Function to prompt for a new user ID and assign it
  // Future<void> _promptForNewUser(String qrId, String fileId) async {
  //   TextEditingController userIdController = TextEditingController();
  //   final bool? shouldConfirmAssignment = await showDialog<bool>(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text('Assign QR Code to User'),
  //         content: TextField(
  //           controller: userIdController,
  //           decoration: const InputDecoration(labelText: 'Enter User ID'),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               userIdController.clear();
  //               Navigator.of(context).pop(false);
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () {
  //               if (userIdController.text.isNotEmpty) {
  //                 Navigator.of(context).pop(true);
  //               } else {
  //                 ScaffoldMessenger.of(context).showSnackBar(
  //                   const SnackBar(content: Text('Please enter a user ID.')),
  //                 );
  //               }
  //             },
  //             child: const Text('Assign'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  //
  //   if (shouldConfirmAssignment == true) {
  //     setState(() {
  //       _isProcessing = true;
  //     });
  //     String userId = userIdController.text;
  //     bool success = await _qrCodeService.assignQrCode(qrId: qrId, fileId:  fileId, assignedUserId:  userId, jwtToken: _jwtToken!);
  //     if (success) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('User assigned successfully!')),
  //       );
  //       _fetchQrCodes();
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Failed to assign user.')),
  //       );
  //     }
  //     setState(() {
  //       _isProcessing = false;
  //     });
  //   }
  // }

  // Function to handle unlinking a user from a QR code
  Future<void> _unlinkUser(String qrId, String fileId) async {
    if (_jwtToken == null || _isProcessing) return;

    final bool? shouldUnlink = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Unlinking'),
          content: const Text('Are you sure you want to unlink this user from the QR code?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Unlink'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldUnlink == true) {
      setState(() {
        _isProcessing = true;
      });
      // The assignQrCode function can handle a null userId for unlinking
      _jwtToken = await AppWriteService().getJWT();
      bool success = await _qrCodeService.assignQrCodeToUser(qrId: qrId, fileId:  fileId, assignedUserId: '', jwtToken: _jwtToken!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unlinked successfully!')),
        );
        if(widget.userMeta.role == "subadmin"){
          _fetchOnlyUserQrCodes();
        }else{
          _fetchQrCodes();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unlink user.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _unlinkManager(String qrId, String fileId) async {
    if (_jwtToken == null || _isProcessing) return;

    final bool? shouldUnlink = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Unlinking'),
          content: const Text('Are you sure you want to unlink this Manager from the QR code?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Unlink'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldUnlink == true) {
      setState(() {
        _isProcessing = true;
      });
      // The assignQrCode function can handle a null userId for unlinking
      _jwtToken = await AppWriteService().getJWT();
      bool success = await _qrCodeService.assignQrCodeManager(qrId: qrId, fileId:  fileId, managedByUserId: '', jwtToken: _jwtToken!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manager unlinked successfully!')),
        );
        if(widget.userMeta.role == "subadmin"){
          _fetchOnlyUserQrCodes();
        }else{
          _fetchQrCodes();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unlink Manager.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Optional: build a rich subtitle line from available data
  String buildAssigneeSubtitle({
    required String? userId,
    required AppUser? user,
  }) {
    if (userId == null) return 'Not assigned';
    final label = roleLabel(user?.role);
    final name = user?.name; // you mentioned this helper exists
    final email = user?.email;
    if (email != null && email.isNotEmpty) {
      return 'Currently assigned to $label\n$name · $email';
    }
    return 'Currently assigned to $label\n$name';
  }

// Updated dialog using the helpers above
  Future<void> _showAssignOptionsUser(QrCode qrCode) async {
    if (_jwtToken == null || _isProcessing) return;

    final AppUser? assignee = getUserById(qrCode.assignedUserId!);
    final String subtitle = buildAssigneeSubtitle(
      userId: qrCode.assignedUserId,
      user: assignee, // inject your helper
    );

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manage User Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current assignment details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    assignee?.role == 'subadmin'
                        ? Icons.admin_panel_settings
                        : Icons.person_outline,
                    color: assignee?.role == 'subadmin'
                        ? Colors.deepPurple
                        : Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(subtitle)),
                ],
              ),
              const SizedBox(height: 8),
              // if (qrCode.managedByUserId != null && assignee != null && assignee.parentId != qrCode.managedByUserId)
              //   Row(
              //     children: [
              //       const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              //       const SizedBox(width: 6),
              //       Expanded(
              //         child: Text(
              //           'Warning: Assigned user is not under the current manager.',
              //           style: Theme.of(context).textTheme.bodySmall?.copyWith(
              //             color: Colors.orange[800],
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Unlink User'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _unlinkUser(qrCode.qrId, qrCode.fileId);
              },
            ),
            TextButton(
              child: const Text('Assign to Other User'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _assignUser(qrCode.qrId, qrCode.fileId, qr: qrCode);
              },
            ),
          ],
        );
      },
    );
  }

  String buildManagerSubtitle({
    required String? managerId,
    required AppUser? manager,
    required String Function(String) displayUserNameText,
  }) {
    if (managerId == null) return 'No manager assigned';
    final label = roleLabel(manager?.role);
    final name = manager?.name;
    final email = manager?.email;
    if (email != null && email.isNotEmpty) {
      return 'Currently managed by $label\n$name · $email';
    }
    return 'Currently managed by $label\n$name';
  }

  // New function to show the options for an assigned QR code
  Future<void> _showAssignOptionsManager(QrCode qrCode) async {
    if (_jwtToken == null || _isProcessing) return;

    final String? managerId = qrCode.managedByUserId;         // Only merchant/subadmin id
      final AppUser? manager = getUserById(managerId!);          // May be null
      final String managerSubtitle = buildManagerSubtitle(
        managerId: managerId,
        manager: manager,
        displayUserNameText: displayUserNameText,
      );

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manage Manager Assignment'),
          // content: Text('This QR code is currently assigned to Manager : ${qrCode.assignedUserId}. What would you like to do?'),
          content:
          Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                managerSubtitle,
                // Ensure no null interpolation
              ),
            ),
          ],
        ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Unlink Manager'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the current dialog
                _unlinkManager(qrCode.qrId, qrCode.fileId);
              },
            ),
            TextButton(
              child: const Text('Assign to Other Manager'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the current dialog
                _assignSubAdmin(qrCode.qrId, qrCode.fileId, qr: qrCode);
              },
            ),
          ],
        );
      },
    );
  }

  // New function to show the options for an assigned QR code
  Future<void> _showCannotAssign(QrCode qrCode) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manage User Assignment'),
          content: Text('You Can\'t Change QR Assignment Once Assigned'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createAssignUserQR() async {
    if(!widget.userMeta.labels.contains('admin') && !widget.userMeta.labels.contains('SelfQr')){
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Not Allowed'),
            content: Text('You are not allowed to create QR codes.\nPlease contact the administrator for this facility'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          );
        },
      );

      return;
    }

    if(activeUserQrCount >= 6){

      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Qr Limit Reached'),
            content: Text('You already Have 5 QR Codes Assigned and Active on your Account!'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          );
        },
      );

      return;
    }

    if (_isProcessing) return;

    final bool? shouldToggle = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Qr Generation'),
          content: Text('Are you sure you want to Create & Assign New QR code for Yourself'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldToggle == true) {
      setState(() {
        _isProcessing = true;
      });
      _jwtToken = await AppWriteService().getJWT();
      bool success = await _qrCodeService.createUserQrCode(widget.userModeUserid!,_jwtToken!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New QR code Generated and Assigned')),
        );
        _fetchOnlyUserQrCodes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to Generate QR code.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _createAssignAdminQR() async {
    bool success = await _qrCodeService.createAdminQrCode(widget.userModeUserid!, _jwtToken!);
  }

  void assignmentOptionForAdminSubAdminUser(QrCode qrCode){
    if(widget.userMeta.role.contains("subadmin")){
      // IF QR ASSIGNED TO SUB ADMIN THEN HE CAN ASSIGN TO OTHER USER
      if(qrCode.assignedUserId == widget.userMeta.id){
        _showAssignOptionsUser(qrCode);
      }else{
        _showCannotAssign(qrCode);
      }
      return;
    }
    // IF IS ADMIN THEN SHOW ALL OPTIONS
    _showAssignOptionsUser(qrCode);
  }

  void assignmentOptionForAdminManager(QrCode qrCode){
    _showAssignOptionsManager(qrCode);
  }

  @override
  Widget build(BuildContext context) {
    final list = _visibleQrCodes; // filtered locally

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by QR ID...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              suffixIcon: IconButton(
                icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                tooltip: 'Clear search',
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _isSearching = false;
                  });
                },
              ),
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            onChanged: (val) => setState(() => _searchQuery = val),
          )
              : Text(widget.userMode ? 'My QR Codes' : 'Manage All QR Codes'),
          actions: [
            if (!_isSearching) ...[
              if (widget.userMeta.role == 'admin')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Toggle Filters: '),
                    Switch.adaptive(
                      value: showingFilters,
                      onChanged: (val) => setState(() => showingFilters = val),
                    ),
                  ],
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort by',
                onSelected: (val) => setState(() => _sortBy = val),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'createdAt_desc', child: _sortMenuItem('Created (Newest)', 'createdAt_desc')),
                  PopupMenuItem(value: 'createdAt_asc', child: _sortMenuItem('Created (Oldest)', 'createdAt_asc')),
                  PopupMenuItem(value: 'todayPayIn_desc', child: _sortMenuItem('Today Pay-In (High)', 'todayPayIn_desc')),
                  PopupMenuItem(value: 'todayPayIn_asc', child: _sortMenuItem('Today Pay-In (Low)', 'todayPayIn_asc')),
                  PopupMenuItem(value: 'yesterdayPayIn_desc', child: _sortMenuItem('Yesterday Pay-In (High)', 'yesterdayPayIn_desc')),
                  PopupMenuItem(value: 'yesterdayPayIn_asc', child: _sortMenuItem('Yesterday Pay-In (Low)', 'yesterdayPayIn_asc')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search QR',
                onPressed: () => setState(() => _isSearching = true),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Scroll to top',
                onPressed: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: (_jwtToken != null && !_isProcessing)
                    ? (widget.userMode ? _fetchOnlyUserQrCodes : _fetchQrCodes)
                    : null,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 5,
          itemBuilder: (_, __) => const QrCardShimmer(),
        )
            : Column(
          children: [
            // Filters row
            if (showingFilters && (widget.userMeta.role == 'admin'))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: _buildManagerFilters(),
            ),
            // Results
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No QR codes found.'))
                  : ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: list.length + (_loadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= list.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final qr = list[index];
                  String formattedDate = 'NA';
                  final createdAt = qr.createdAt;
                  if (createdAt != null) {
                    try {
                      formattedDate = DateFormat.yMd().add_Hms().format(DateTime.parse(createdAt));
                    } catch (_) {}
                  }
                  return QrCodeCard(
                    qrCode: qr,
                    formattedDate: formattedDate,
                    userMeta: widget.userMeta,
                    userMode: widget.userMode,
                    userModeUserid: widget.userModeUserid,
                    isProcessing: _isProcessing,
                    qrPayInTodayLimit: QR_PayIn_Today_limit,
                    displayUserNameText: displayUserNameText,
                    getUserById: getUserById,
                    onToggleStatus: () => _toggleStatus(qr),
                    onAssignUser: () => _assignUser(qr.qrId, qr.fileId, qr: qr),
                    onAssignUserOptions: () => assignmentOptionForAdminSubAdminUser(qr),
                    onAssignSubAdmin: () => _assignSubAdmin(qr.qrId, qr.fileId, qr: qr),
                    onAssignSubAdminOptions: () => assignmentOptionForAdminManager(qr),
                    onViewTransactions: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => widget.userMode
                            ? TransactionPageNew(filterQrCodeId: qr.qrId, userMode: true, userModeUserid: widget.userModeUserid)
                            : TransactionPageNew(filterQrCodeId: qr.qrId),
                      ),
                    ),
                    onDelete: () => _deleteQrCode(qr.qrId),
                    onEditImage: () => _editQrCode(qr.qrId),
                    onManualHold: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManualHoldPage(
                          userMeta: widget.userMeta,
                          qrCode: qr,
                          assignedUser: qr.assignedUserId != null ? getUserById(qr.assignedUserId!) : null,
                        ),
                      ),
                    ),
                    onNotifyServer: widget.userMode && qr.isActive
                        ? () => SocketManager.instance.sendQrCodeAlert(qr)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: (_jwtToken != null && !_isProcessing && !widget.userMode)
            ? FloatingActionButton(
          onPressed: _showUploadQrDialog,
          child: const Icon(Icons.add),
        )
            : null,
      ),
    );
  }

  Widget _buildManagerFilters() {
    final subs = users.where((u) => u.role == 'subadmin').toList();
    final adminCount = _qrCodes.where((q) => q.assignedUserId != null && users.any((u) => u.id == q.assignedUserId && u.role == 'admin')).length;
    final subadminCount = _qrCodes.where((q) => q.managedByUserId != null).length;
    final userCount = _qrCodes.where((q) => q.assignedUserId != null).length;
    final unassignedCount = _qrCodes.where((q) => q.assignedUserId == null && q.managedByUserId == null).length;

    final scopes = <String, String>{
      'ALL': 'All (${_qrCodes.length})',
      'ADMIN': 'Admin ($adminCount)',
      'SUBADMIN': 'Subadmin ($subadminCount)',
      'USER': 'User ($userCount)',
      'UNASSIGNED': 'Unassigned ($unassignedCount)',
    };

    final needsDropdown = {'ADMIN', 'SUBADMIN', 'USER'}.contains(_managerScope);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: scopes.entries.map((e) {
                  final selected = _managerScope == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _managerScope = e.key;
                          if (_managerScope != 'ADMIN') _selectedAdmin = null;
                          if (_managerScope != 'SUBADMIN') _selectedSubadmin = null;
                          if (_managerScope != 'USER') _selectedUser = null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            if (needsDropdown) ...[
              const SizedBox(height: 10),
              _buildUserDropdown(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserDropdown() {
    switch (_managerScope) {
      case 'ADMIN':
        return DropdownButtonFormField<AppUser>(
          isExpanded: true,
          value: _selectedAdmin,
          decoration: InputDecoration(
            labelText: 'Select Admin',
            prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: users.where((u) => u.role == 'admin').map((a) {
            final count = _qrCodes.where((q) => q.assignedUserId == a.id).length;
            final label = a.name.isNotEmpty ? '${a.name} • ${a.email} ($count)' : '${a.email} ($count)';
            return DropdownMenuItem(value: a, child: Text(label, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (val) => setState(() => _selectedAdmin = val),
        );
      case 'SUBADMIN':
        final subs = users.where((u) => u.role == 'subadmin').toList();
        return DropdownButtonFormField<AppUser>(
          isExpanded: true,
          value: _selectedSubadmin,
          decoration: InputDecoration(
            labelText: 'Select Subadmin',
            prefixIcon: const Icon(Icons.supervisor_account_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: subs.map((s) {
            final count = _qrCodes.where((q) => q.managedByUserId == s.id).length;
            final label = s.name.isNotEmpty ? '${s.name} • ${s.email} ($count)' : '${s.email} ($count)';
            return DropdownMenuItem(value: s, child: Text(label, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (val) => setState(() => _selectedSubadmin = val),
        );
      case 'USER':
        return DropdownButtonFormField<AppUser>(
          isExpanded: true,
          value: _selectedUser,
          decoration: InputDecoration(
            labelText: 'Select User',
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: users.where((u) => u.role == 'user').map((u) {
            final count = _qrCodes.where((q) => q.assignedUserId == u.id).length;
            final label = u.name.isNotEmpty ? '${u.name} • ${u.email} ($count)' : '${u.email} ($count)';
            return DropdownMenuItem(value: u, child: Text(label, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (val) => setState(() => _selectedUser = val),
        );
      default:
        return const SizedBox.shrink();
    }
  }

}