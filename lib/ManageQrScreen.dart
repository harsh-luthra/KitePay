import 'dart:io';
import 'package:admin_qr_manager/AppConstants.dart';
import 'package:admin_qr_manager/QRService.dart';
import 'package:admin_qr_manager/SocketManager.dart';
import 'package:admin_qr_manager/utils/CurrencyUtils.dart';
import 'package:admin_qr_manager/widget/QrCardShimmer.dart';
import 'package:appwrite/models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html; // only works on Flutter web
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'AppWriteService.dart';
import 'MyMetaApi.dart';
import 'TransactionPageNew.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';
import 'models/QrCode.dart';

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

  int userQrCount = 0;
  int activeUserQrCount = 0;
  // late AppUser userMeta;
  late AppUser userMeta;

  String _managerScope = 'ALL'; // 'ALL' | 'SUBADMIN'
  AppUser? _selectedSubadmin;   // chosen subadmin for filtering (if scope == SUBADMIN)

  bool showingFilters = false;

  @override
  void initState() {
    super.initState();
    // Simulate a login to get a token, for a real app this would be a user action
    // _loginAsAdmin();
    // loadUserMeta();
    userMeta = MyMetaApi.current!;

    // if (userMeta.role.toLowerCase() == 'employee') {
    //   _roleFilter = RoleFilter.all;  // Use "All" but scoped to assigned
    // } else if (userMeta.role.toLowerCase() == 'subadmin') {
    //   _roleFilter = RoleFilter.users;
    // } else {
    //   _roleFilter = RoleFilter.all;
    // }

    if(!widget.userMode){
        _fetchQrCodes();
        _fetchUsers();
    }else{
      // print("User Mode");
      if(widget.userMeta.role.contains("subadmin")){
        _fetchUsers();
      }
      _fetchOnlyUserQrCodes();
    }
  }

  // Future<void> loadUserMeta() async {
  //   String jwtToken = await AppWriteService().getJWT();
  //   userMeta = (await MyMetaApi.getMyMetaData(
  //     jwtToken: jwtToken,
  //     refresh: false, // set true to force re-fetch
  //   ))!;
  // }

  @override
  void dispose() {
    _qrIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isProcessing = true);
    try {
      final fetched = await UsersService.listUsers(jwtToken: await AppWriteService().getJWT());
      users = fetched.appUsers;
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch users: $e')),
      );
    }
    if(!mounted) return;
    setState(() => _isProcessing = false);
  }

  AppUser? getUserById(String id) {
    try {
      return users.firstWhere((user) => user.id == id);
    } catch (e) {
      return null; // if not found
    }
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
    if(appUserId == null){
      return "Unassigned";
    }
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
  List<QrCode> get _visibleQrCodes {
    switch (_managerScope) {
      case 'ALL':
        return _qrCodes;
      case 'UNASSIGNED':
        return _qrCodes.where((q) => q.assignedUserId == null || q.managedByUserId == null).toList();
      case 'SUBADMIN':
        if (_selectedSubadmin == null) return const <QrCode>[];
        return _qrCodes.where((q) => q.managedByUserId == _selectedSubadmin!.id).toList();
      default:
        return _qrCodes;
    }
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

    // Resolve the current assigned user (if any)
    final String? assignedId = qr?.assignedUserId;
    final AppUser? assignedUser =
    assignedId == null ? null : users.firstWhere((u) => u.id == assignedId, orElse: () => null as AppUser);

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

    // Optional: if required, deduplicate and ensure the parent subadmin (if exists) is present
    if (assignedUser?.parentId != null) {
      final AppUser? parentSub = users.firstWhere(
            (u) => u.id == assignedUser!.parentId && u.role == 'subadmin',
        orElse: () => null as AppUser,
      );
      if (parentSub != null && !filtered.any((s) => s.id == parentSub.id)) {
        filtered.insert(0, parentSub);
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
                            color: Colors.deepPurple.withOpacity(0.1),
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
    if (_jwtToken == null) {
      // Don't fetch if not logged in
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try{
      _jwtToken = await AppWriteService().getJWT();
      final codes = await _qrCodeService.getQrCodes(_jwtToken);
      setState(() {
        _qrCodes = codes.reversed.toList(); // Reversed so New Codes comes on top;
        // _qrCodes.clear();
        // _qrCodes = codes.where((q) => q.qrId == 'qr_R9jZFGVNtKDQRc').toList();
      });
    } catch (e) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch Qr Codes: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  int activeQrCount(List<QrCode> qrCodes) {
    return qrCodes.where((qr) => qr.isActive == true).length;
  }

  Future<void> _fetchOnlyUserQrCodes() async {
    if (widget.userModeUserid == null) {
      // In User Mode no UserId Passed
      return;
    }

    _jwtToken = await AppWriteService().getJWT();

    if(mounted) {
      setState(() {
      _isLoading = true;
    });
    }
    // createdByUserId
    try{
      final codes = await _qrCodeService.getUserQrCodes(widget.userModeUserid!, await AppWriteService().getJWT());
      setState(() {
        _qrCodes = codes.reversed.toList(); // Reversed so New Codes comes on top
        // print(_qrCodes[0].toString());
        userQrCount = _qrCodes.length;
        activeUserQrCount = activeQrCount(_qrCodes);
        // print('userQrCount: '+userQrCount.toString());
        // print('activeUserQrCount: '+activeUserQrCount.toString());
      });
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch User Qr Codes: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
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
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
      contentForDialog = "Are you sure you want to deactivate this QR code? It cannot be re-activated by sub-admins. Only an admin can activate deactivated QR codes.”";
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
    print(widget.userMeta.labels.toString());
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

    //
    // bool success = await _qrCodeService.createUserQrCode(widget.userModeUserid!);
    //
    // if(_jwtToken != null){
    //
    // }else{
    //
    // }

  }

  Future<void> _createAssignAdminQR() async {
    bool success = await _qrCodeService.createAdminQrCode(widget.userModeUserid!, _jwtToken!);
  }

  void assignmentOptionForAdminSubAdminUser(QrCode qrCode){
    // !widget.userMode ? _showAssignOptions(qrCode) : _showCannotAssign(qrCode);
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
          title: Text(widget.userMode ? 'My QR Codes' : 'Manage All QR Codes'),
          actions: [
            if(widget.userMeta.role == 'admin')
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
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: (_jwtToken != null && !_isProcessing)
                  ? (widget.userMode ? _fetchOnlyUserQrCodes : _fetchQrCodes)
                  : null,
            ),
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
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final qr = list[index];
                  // compute formatted date as you already do
                  String formattedDate = 'NA';
                  final createdAt = qr.createdAt;
                  if (createdAt != null) {
                    try {
                      formattedDate = DateFormat.yMd().add_Hms().format(DateTime.parse(createdAt));
                    } catch (_) {}
                  }
                  return buildQrCodeCard(qr, formattedDate);
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

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: _managerScope,
            decoration: const InputDecoration(
              labelText: 'Manager Scope',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('ALL')),
              DropdownMenuItem(value: 'SUBADMIN', child: Text('Subadmin')),
              DropdownMenuItem(value: 'UNASSIGNED', child: Text('UNASSIGNED')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _managerScope = val;
                if (_managerScope != 'SUBADMIN') {
                  _selectedSubadmin = null;
                }
              });
            },
          ),
        ),
        if (_managerScope == 'SUBADMIN')
          SizedBox(
            width: 330,
            child: DropdownButtonFormField<AppUser>(
              value: _selectedSubadmin,
              decoration: const InputDecoration(
                labelText: 'Select Subadmin',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: subs.map((s) {
                final label = s.name.isNotEmpty ? '${s.name} • ${s.email}' : s.email;
                return DropdownMenuItem(value: s, child: Text(label, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: (val) => setState(() => _selectedSubadmin = val),
            ),
          ),
      ],
    );
  }

  Widget buildQrCodeCard(QrCode qrCode, String formattedDate) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 720;

    final String assignedId = qrCode.assignedUserId ?? '';
    final String managerId = qrCode.managedByUserId ?? '';

    final bool isSelf = assignedId == widget.userMeta.id;
    final String assignedName =  displayUserNameText(assignedId) ?? '';
    // final String assignedEmail = displayUserNameText?.call(assignedId) ?? ''; // if you have this helper
    final String assigneeLine = assignedId == ''
        ? 'Unassigned'
        : (isSelf
        ? 'Self'
        : [assignedName].where((s) => s.isNotEmpty).join(' • '));

    final String managerName = displayUserNameText(managerId!) ?? '';
    final bool isSelfManager = managerId == widget.userMeta.id;
    // final String assignedEmail = displayUserNameText?.call(assignedId) ?? ''; // if you have this helper
    final String managerLine = managerId == ''
        ? 'Unassigned'
        : (isSelfManager
        ? 'Self'
        : [managerName].where((s) => s.isNotEmpty).join(' • '));

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always show full QR ID on top
            SelectableText(
              'QR ID: ${qrCode.qrId}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            // Content row/column
            isMobile
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQrLeftSection(qrCode),      // image, status chip, download/zoom
                const SizedBox(height: 16),
                _rightMetricsBlock(qrCode, formattedDate), // metrics + ledger + created
                // const Divider(height: 20),
                // _buildActionButtons(qrCode),
              ],
            )
                : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQrLeftSection(qrCode),
                const SizedBox(width: 16),
                Expanded(child: _rightMetricsBlock(qrCode, formattedDate)),
              ],
            ),

            const SizedBox(height: 12),
            Center(child: _buildActionButtons(qrCode)),
            const Divider(height: 20),

            // Always show name & email at the bottom
            Row(
              children: [
                SizedBox(width: 70, child: Text("User:")),
                const Icon(Icons.person, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    assigneeLine.isEmpty ? (assignedId ?? 'Unassigned') : assigneeLine,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if(!widget.userMode)
            Row(
              children: [
                SizedBox(width: 70, child: Text("Manager:")),
                const Icon(Icons.admin_panel_settings, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    managerLine.isEmpty ? (managerId ?? 'Unassigned') : managerLine,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Optional: show raw assigned id in a subtle line under name/email
            // if (assignedId != null) ...[
            //   const SizedBox(height: 4),
            //   Row(
            //     children: [
            //       const SizedBox(width: 26),
            //       Expanded(
            //         child: Text(
            //           'User ID: $assignedId',
            //           style: const TextStyle(fontSize: 12, color: Colors.grey),
            //           overflow: TextOverflow.ellipsis,
            //         ),
            //       ),
            //     ],
            //   ),
            // ],
          ],
        ),
      ),
    );
  }
  // Header with QR ID and assignment chip
  Widget _qrHeader(QrCode qrCode) {
    final String? assignedId = qrCode.assignedUserId;
    final bool isSelf = assignedId != null && assignedId == widget.userMeta.id;
    final String assignedDisplay = assignedId == null
        ? 'Unassigned'
        : (isSelf ? 'Self' : (displayUserNameText(assignedId) ?? assignedId));

    return Row(
      children: [
        Expanded(
          child: Text(
            'QR • ${qrCode.qrId}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        InputChip(
          label: Text(assignedDisplay, overflow: TextOverflow.ellipsis),
          avatar: const Icon(Icons.person, size: 18),
          onPressed: null,
        ),
      ],
    );
  }

  /// Left: QR image, status, quick actions
  Widget _buildQrLeftSection(QrCode qrCode) {
    final statusColor = qrCode.isActive ? Colors.green : Colors.red;
    final statusBg = qrCode.isActive ? Colors.green.shade50 : Colors.red.shade50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // QR thumb with loader/error
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 140,
                height: 140,
                child: qrCode.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: qrCode.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (c, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (c, _, __) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                )
                    : const Icon(Icons.qr_code_2, size: 72, color: Colors.blueGrey),
              ),
            ),
            // Zoom tap overlay
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openQrPreviewDialog(qrCode.imageUrl),
                ),
              ),
            ),
            // Download FAB
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
              Text(qrCode.isActive ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  void _openQrPreviewDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        debugPrint('Download failed (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

// Right: metrics + ledger + created line + actions (actions can stay at bottom of card if preferred)
  Widget _rightMetricsBlock(QrCode qrCode, String formattedDate) {
    final bool isAdmin = widget.userMeta.role == "admin";
    final bool isSubAdmin = widget.userMeta.role == "subadmin";
    String inr(num p) => CurrencyUtils.formatIndianCurrency(p / 100);

    Widget metric(String label, String value, {IconData? icon, Color? color}) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color ?? Colors.blueGrey),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        LayoutBuilder(
          builder: (ctx, cts) {
            final w = cts.maxWidth;

            // Adaptive tile sizing
            final maxTileW = w >= 1000 ? 260.0 : w >= 760 ? 230.0 : w >= 560 ? 200.0 : 170.0;
            final minTileW = 150.0;
            final labelSmall = w < 420;
            final hideIcons = w < 340;

            Widget metricTile(String label, String value, {IconData? icon, Color? color}) {
              return ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTileW, maxWidth: maxTileW),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
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
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
              metricTile('Transactions',
                  CurrencyUtils.formatIndianCurrencyWithoutSign(qrCode.totalTransactions ?? 0),
                  icon: Icons.receipt_long, color: Colors.teal),
              if (isAdmin || isSubAdmin)
                metricTile('Amount Received', inr(qrCode.totalPayInAmount ?? 0),
                    icon: Icons.account_balance_wallet, color: Colors.deepPurple),
              metricTile('Avail. Withdrawal', inr(qrCode.amountAvailableForWithdrawal ?? 0),
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
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kv('Requested', inr(qrCode.withdrawalRequestedAmount ?? 0)),
              _kv('Approved', inr(qrCode.withdrawalApprovedAmount ?? 0)),
              _kv('Comm On-Hold', inr(qrCode.commissionOnHold ?? 0)),
              _kv('Comm Paid', inr(qrCode.commissionPaid ?? 0)),
              _kv('Amt On-Hold', inr(qrCode.amountOnHold ?? 0)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Created: $formattedDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
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

  /// Actions
  Widget _buildActionButtons(QrCode qrCode) {
    final canUserActions = (!widget.userMode || (widget.userMeta.role.contains("subadmin") && widget.userMeta.labels.contains("users")));
    final canViewTx =
        (widget.userMeta.role == "admin") ||
            (widget.userMeta.role == "employee" && widget.userMeta.labels.contains(AppConstants.viewAllTransactions)) ||
            (widget.userMeta.role == "subadmin") ||
            (widget.userMeta.role == "user") ;

    IconButton action({required IconData icon, required String tip, required VoidCallback? onTap, Color? color}) {
      return IconButton(
        icon: Icon(icon, color: color ?? Colors.blueGrey),
        tooltip: tip,
        onPressed: _isProcessing ? null : onTap,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (widget.userMeta.role != "employee" && canUserActions)
          action(
            icon: qrCode.isActive ? Icons.toggle_on : Icons.toggle_off,
            tip: 'Toggle Status',
            onTap: () => _toggleStatus(qrCode),
            color: qrCode.isActive ? Colors.green : Colors.grey,
          ),
        if (widget.userMeta.role != "employee" && canUserActions)
          action(
            icon: qrCode.assignedUserId == null ? Icons.person_add_alt_1 : Icons.person_outline,
            tip: qrCode.assignedUserId == null ? 'Assign User' : 'Change User Assignment',
            onTap: () => qrCode.assignedUserId == null
                ? _assignUser(qrCode.qrId, qrCode.fileId, qr: qrCode)
                : assignmentOptionForAdminSubAdminUser(qrCode),
            color: Colors.blueAccent,
          ),
        if (widget.userMeta.role != "employee" && canUserActions && widget.userMeta.role == 'admin')
          action(
            icon: qrCode.managedByUserId == null ? Icons.admin_panel_settings_outlined : Icons.admin_panel_settings,
            tip: qrCode.managedByUserId == null ? 'Assign to Merchant' : 'Change Merchant Assignment',
            onTap: () => qrCode.managedByUserId == null
                ? _assignSubAdmin(qrCode.qrId, qrCode.fileId, qr: qrCode)
                : assignmentOptionForAdminManager(qrCode),
            color: Colors.blueAccent,
          ),
        if (canViewTx)
          action(
            icon: Icons.article_outlined,
            tip: 'View Transactions',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => widget.userMode
                    ? TransactionPageNew(filterQrCodeId: qrCode.qrId, userMode: true, userModeUserid: widget.userModeUserid)
                    : TransactionPageNew(filterQrCodeId: qrCode.qrId),
              ),
            ),
            color: Colors.deepPurple,
          ),
        if (!widget.userMode && widget.userMeta.role == "admin")
          action(
            icon: Icons.delete_outline,
            tip: 'Delete QR Code',
            onTap: () => _deleteQrCode(qrCode.qrId),
            color: Colors.redAccent,
          ),
        if (!widget.userMode && widget.userMeta.role == "admin")
          action(
            icon: Icons.photo_camera,
            tip: 'Change QR Code Image',
            onTap: () => _editQrCode(qrCode.qrId),
            color: Colors.blueAccent,
          ),
        if (widget.userMode && qrCode.isActive)
          action(
            icon: Icons.add_alert,
            tip: 'Notify Server',
            onTap: () => SocketManager.instance.sendQrCodeAlert(qrCode),
            color: Colors.orange,
          ),
      ],
    );
  }


  // Widget buildQrCodeCardOld(QrCode qrCode, String formattedDate) {
  //   return Card(
  //     elevation: 4,
  //     margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12.0),
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // Left: QR Image or Icon
  //           ClipRRect(
  //             borderRadius: BorderRadius.circular(12),
  //             child: Column(
  //               children: [
  //                 GestureDetector(
  //                   onTap: () {
  //                     showDialog(
  //                       context: context,
  //                         builder: (_) => Dialog(
  //                           child: Stack(
  //                             children: [
  //                               // 🔍 Zoomable QR Image
  //                               InteractiveViewer(
  //                                 child: qrCode.imageUrl.isNotEmpty
  //                                     ? CachedNetworkImage(
  //                                   imageUrl: qrCode.imageUrl,
  //                                   fit: BoxFit.contain,
  //                                   placeholder: (context, url) => const Padding(
  //                                     padding: EdgeInsets.all(20),
  //                                     child: Center(child: CircularProgressIndicator()),
  //                                   ),
  //                                   errorWidget: (context, url, error) =>
  //                                   const Icon(Icons.error, size: 100),
  //                                 )
  //                                     : const Icon(Icons.qr_code, size: 100),
  //                               ),
  //
  //                               // ⬇️ Download Button
  //                               Positioned(
  //                                 top: 8,
  //                                 right: 8,
  //                                 child: IconButton(
  //                                   icon: const Icon(Icons.download, size: 28, color: Colors.blue),
  //                                   onPressed: () {
  //                                     final anchor = html.AnchorElement(href: qrCode.imageUrl)
  //                                       ..download = "qr_${DateTime.now().millisecondsSinceEpoch}.png"
  //                                       ..target = 'blank';
  //                                     anchor.click();
  //                                   },
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                     );
  //                   },
  //                   child: SizedBox(
  //                     width: 100,
  //                     height: 100,
  //                     child: qrCode.imageUrl.isNotEmpty
  //                         ? CachedNetworkImage(
  //                       imageUrl: qrCode.imageUrl,
  //                       fit: BoxFit.cover,
  //                       placeholder: (context, url) => const Center(
  //                         child: CircularProgressIndicator(),
  //                       ),
  //                       errorWidget: (context, url, error) => const Center(
  //                         child: Icon(Icons.error),
  //                       ),
  //                     )
  //                         : const Icon(Icons.qr_code, size: 80),
  //                   ),
  //                 ),
  //
  //                 const SizedBox(height: 15),
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //                   decoration: BoxDecoration(
  //                     color: qrCode.isActive ? Colors.green.shade100 : Colors.red.shade100,
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                   child: Text(
  //                     qrCode.isActive ? 'ACTIVE' : 'INACTIVE',
  //                     style: TextStyle(
  //                       color: qrCode.isActive ? Colors.green.shade800 : Colors.red.shade800,
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 12,
  //                     ),
  //                   ),
  //                 ),
  //
  //                 const SizedBox(height: 20),
  //                 // Action buttons
  //                 Wrap(
  //                   spacing: 8,
  //                   runSpacing: 8,
  //                   children: [
  //                     if(!widget.userMode)
  //                       IconButton(
  //                         icon: Icon(
  //                           qrCode.isActive ? Icons.toggle_on : Icons.toggle_off,
  //                           color: qrCode.isActive ? Colors.green : Colors.grey,
  //                         ),
  //                         tooltip: 'Toggle Status',
  //                         onPressed: _isProcessing ? null : () => _toggleStatus(qrCode),
  //                       ),
  //                     if(!widget.userMode)
  //                       IconButton(
  //                         icon: Icon(
  //                           qrCode.assignedUserId == null
  //                               ? Icons.person_add_alt_1
  //                               : Icons.person_outline,
  //                           color: Colors.blueAccent,
  //                         ),
  //                         tooltip: qrCode.assignedUserId == null ? 'Assign User' : 'Change Assignment',
  //                         onPressed: _isProcessing
  //                             ? null
  //                             : () => qrCode.assignedUserId == null
  //                             ? _assignUser(qrCode.qrId, qrCode.fileId)
  //                             : _showAssignOptions(qrCode),
  //                       ),
  //                     IconButton(
  //                       icon: const Icon(Icons.article_outlined, color: Colors.deepPurple),
  //                       tooltip: 'View Transactions',
  //                       onPressed: _isProcessing
  //                           ? null
  //                           : () => Navigator.push(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder: (_) {
  //                             if (widget.userMode) {
  //                               return TransactionPageNew(
  //                                 filterQrCodeId: qrCode.qrId,
  //                                 userMode: true,
  //                                 userModeUserid: widget.userModeUserid,
  //                               );
  //                             } else {
  //                               return TransactionPageNew(
  //                                 filterQrCodeId: qrCode.qrId,
  //                               );
  //                             }
  //                           },
  //                         ),
  //                       ),
  //                     ),
  //                     if(!widget.userMode && widget.userMeta.role == "admin")
  //                       IconButton(
  //                         icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
  //                         tooltip: 'Delete QR Code',
  //                         onPressed:
  //                         _isProcessing ? null : () => _deleteQrCode(qrCode.qrId),
  //                       ),
  //                   ],
  //                 )
  //
  //               ],
  //             ),
  //           ),
  //           const SizedBox(width: 16),
  //
  //           // Right: Info + Actions
  //           Expanded(
  //             child: SizedBox(
  //               height: 200,
  //               child: Column(
  //                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   // QR ID
  //                   Text(
  //                     'ID: ${qrCode.qrId}',
  //                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //                   ),
  //
  //                   const SizedBox(height: 6),
  //
  //                   // QR ID
  //                   Text(
  //                     'Transactions: ${CurrencyUtils.formatIndianCurrencyWithoutSign(qrCode.totalTransactions!)}',
  //                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //                   ),
  //
  //                   // QR ID
  //                   Text(
  //                     'Amount Received: ${CurrencyUtils.formatIndianCurrency(qrCode.totalPayInAmount! / 100)}',
  //                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //                   ),
  //
  //                   const SizedBox(height: 6),
  //
  //                   if(!widget.userMode)
  //                   Text(
  //                     'Assigned to: ${displayUserNameText(qrCode.assignedUserId) ?? 'Unassigned'}',
  //                     style: const TextStyle(fontSize: 14),
  //                   ),
  //                   Text(
  //                     'Created: $formattedDate',
  //                     style: const TextStyle(fontSize: 13, color: Colors.grey),
  //                   ),
  //
  //                   const SizedBox(height: 10),
  //
  //                 ],
  //               ),
  //             ),
  //           ),
  //
  //         ],
  //       ),
  //     ),
  //   );
  // }

}