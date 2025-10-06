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

  @override
  void initState() {
    super.initState();
    // Simulate a login to get a token, for a real app this would be a user action
    // _loginAsAdmin();
    // loadUserMeta();
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

  String? displayUserNameText(String? appUserId){
    if(appUserId == null){
      return "Unassigned";
    }
    AppUser? user = getUserById(appUserId);
    String displayText = user != null
        ? '${user.name}\n${user.email}'
        : 'Unknown user';
    return displayText;
  }

  Future<void> _assignUser(String? qrId, String? fileId) async {
    if (_jwtToken == null || qrId == null || fileId == null || _isProcessing) return;
    //
    // setState(() => _isProcessing = true);
    // List<AppUser> users = [];
    //
    // try {
    //   users = await AdminUserService.listUsers(await AppwriteService().getJWT());
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text("Failed to load users: $e")),
    //   );
    //   setState(() => _isProcessing = false);
    //   return;
    // }
    // setState(() => _isProcessing = false);

    AppUser? selectedUser = await showDialog<AppUser>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select User"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  onTap: () => Navigator.of(context).pop(user),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedUser != null) {
      setState(() => _isProcessing = true);
      bool success = await _qrCodeService.assignQrCode(qrId, fileId, selectedUser.id, _jwtToken!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'User assigned!' : 'Failed to assign user.')),
      );
      if(success){
        if(widget.userMeta.role == "subadmin"){
          _fetchOnlyUserQrCodes();
        }else{
          _fetchQrCodes();
        }
      }
      setState(() => _isProcessing = false);
    }
  }

  // Fetches QR codes from the server and updates the UI
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
      final codes = await _qrCodeService.getQrCodes(_jwtToken);
      setState(() {
        _qrCodes = codes.reversed.toList(); // Reversed so New Codes comes on top;
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
      bool success = await _qrCodeService.uploadQrCode(file, qrId, qrType, _jwtToken!);
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

  // Dialog to assign a user to a QR code with a confirmation dialog and progress indicator
  Future<void> _assignUserOld(String? qrId, String? fileId) async {
    if (_jwtToken == null || qrId == null || fileId == null || _isProcessing) return;

    final bool? shouldAssign = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Assignment'),
          content: const Text('Are you sure you want to assign a user to this QR code?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Proceed'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldAssign == true) {
      TextEditingController userIdController = TextEditingController();
      final bool? shouldConfirmAssignment = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Assign QR Code to User'),
            content: TextField(
              controller: userIdController,
              decoration: const InputDecoration(labelText: 'Enter User ID'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  userIdController.clear();
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (userIdController.text.isNotEmpty) {
                    Navigator.of(context).pop(true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a user ID.')),
                    );
                  }
                },
                child: const Text('Assign'),
              ),
            ],
          );
        },
      );

      if (shouldConfirmAssignment == true) {
        setState(() {
          _isProcessing = true;
        });
        String userId = userIdController.text;
        bool success = await _qrCodeService.assignQrCode(qrId, fileId, userId, _jwtToken!);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User assigned successfully!')),
          );
          _fetchQrCodes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to assign user.')),
          );
        }
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Function to prompt for a new user ID and assign it
  Future<void> _promptForNewUser(String qrId, String fileId) async {
    TextEditingController userIdController = TextEditingController();
    final bool? shouldConfirmAssignment = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign QR Code to User'),
          content: TextField(
            controller: userIdController,
            decoration: const InputDecoration(labelText: 'Enter User ID'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                userIdController.clear();
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (userIdController.text.isNotEmpty) {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a user ID.')),
                  );
                }
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );

    if (shouldConfirmAssignment == true) {
      setState(() {
        _isProcessing = true;
      });
      String userId = userIdController.text;
      bool success = await _qrCodeService.assignQrCode(qrId, fileId, userId, _jwtToken!);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User assigned successfully!')),
        );
        _fetchQrCodes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to assign user.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

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
      bool success = await _qrCodeService.assignQrCode(qrId, fileId, '', _jwtToken!);
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

  // New function to show the options for an assigned QR code
  Future<void> _showAssignOptions(QrCode qrCode) async {
    if (_jwtToken == null || _isProcessing) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manage User Assignment'),
          content: Text('This QR code is currently assigned to user: ${qrCode.assignedUserId}. What would you like to do?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Unlink User'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the current dialog
                _unlinkUser(qrCode.qrId, qrCode.fileId);
              },
            ),
            TextButton(
              child: const Text('Assign to Other User'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the current dialog
                _assignUser(qrCode.qrId, qrCode.fileId);
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

  void assignmentOptionForAdminSubAdmin(QrCode qrCode){
    // !widget.userMode ? _showAssignOptions(qrCode) : _showCannotAssign(qrCode);
    if(widget.userMeta.role.contains("subadmin")){
      // IF QR ASSIGNED TO SUB ADMIN THEN HE CAN ASSIGN TO OTHER USER
      if(qrCode.assignedUserId == widget.userMeta.id){
        _showAssignOptions(qrCode);
      }else{
        _showCannotAssign(qrCode);
      }
      return;
    }
    // IF IS ADMIN THEN SHOW ALL OPTIONS
    _showAssignOptions(qrCode);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.userMode ? "My QR Codes" : 'Manage All QR Codes'),
          actions: [
            if(!widget.userMode)
              IconButton(onPressed: _jwtToken != null && !_isProcessing ? _showUploadQrDialog : null, icon: Icon(Icons.add)),
            // if(widget.userMode && widget.userMeta.role != "user")
              // NewFeatureCornerButton(onPressed: !_isProcessing ? _createAssignUserQR : null, icon: Icon(Icons.add_box_rounded), label: Text('Create QR Code'),),
            // if(widget.userMode)
            //   NewFeatureCornerButton(
            //     onPressed: () {
            //       // call your create-qr API here
            //       _createAssignUserQR();
            //     },
            //   ),
            if(!widget.userMode)
              IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _jwtToken != null && !_isProcessing ? _fetchQrCodes : null,
            ),
            if(widget.userMode)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: !_isProcessing ? _fetchOnlyUserQrCodes : null,
              ),
          ],
        ),
        body: _isLoading
            ?  ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 5,
          itemBuilder: (_, __) => const QrCardShimmer(),
        )
            : _isProcessing
            ? ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 5,
          itemBuilder: (_, __) => const QrCardShimmer(),
        )
            : _qrCodes.isEmpty
            ? const Center(child: Text('No QR codes found.'))
            : Stack(
          children: [
            ListView.builder(
              itemCount: _qrCodes.length,
              itemBuilder: (context, index) {
                final qrCode = _qrCodes[index];
                final createdAt = qrCode.createdAt;
                String formattedDate = 'N/A';
                if (createdAt != null) {
                  try {
                    formattedDate = DateFormat.yMd()
                        .add_Hms()
                        .format(DateTime.parse(createdAt));
                  } catch (e) {
                    print('Error parsing date: $e');
                  }
                }

                return buildQrCodeCard(qrCode, formattedDate);
              },
            ),
            if (_isProcessing) ...[
              const Opacity(
                opacity: 0.8,
                child:
                ModalBarrier(dismissible: false, color: Colors.black),
              ),
              const Center(child: CircularProgressIndicator()),
            ]
          ],
        ),

        // floatingActionButton: FloatingActionButton(
        //   onPressed: _jwtToken != null && !_isProcessing ? _showUploadQrDialog : null,
        //   tooltip: 'Upload QR Code',
        //   backgroundColor: _jwtToken != null ? Theme.of(context).floatingActionButtonTheme.backgroundColor : Colors.grey,
        //   child: const Icon(Icons.add),
        // ),
      ),
    );
  }

  Widget buildQrCodeCard(QrCode qrCode, String formattedDate) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 720;

    final String? assignedId = qrCode.assignedUserId;
    final bool isSelf = assignedId != null && assignedId == widget.userMeta.id;
    final String assignedName = displayUserNameText(assignedId) ?? '';
    // final String assignedEmail = displayUserNameText?.call(assignedId) ?? ''; // if you have this helper
    final String assigneeLine = assignedId == null
        ? 'Unassigned'
        : (isSelf
        ? 'Self'
        : [assignedName].where((s) => s.isNotEmpty).join(' • '));

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

  /// Right: details and metrics
  Widget _buildQrRightSection(QrCode qrCode, String formattedDate) {
    final bool isAdmin = widget.userMeta.role == "admin";
    final assignedId = qrCode.assignedUserId;

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

    String inr(num p) => CurrencyUtils.formatIndianCurrency(p / 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick metrics grid
        LayoutBuilder(
          builder: (ctx, cts) {
            final cols = cts.maxWidth > 900 ? 4 : cts.maxWidth > 600 ? 3 : 2;
            final metrics = <Widget>[
              metric('Today Pay-In', inr(qrCode.todayTotalPayIn ?? 0), icon: Icons.today, color: Colors.indigo),
              metric('Transactions', CurrencyUtils.formatIndianCurrencyWithoutSign(qrCode.totalTransactions ?? 0),
                  icon: Icons.receipt_long, color: Colors.teal),
              if (isAdmin) metric('Amount Received', inr(qrCode.totalPayInAmount ?? 0), icon: Icons.account_balance_wallet),
              metric('Avail. Withdrawal', inr(qrCode.amountAvailableForWithdrawal ?? 0), icon: Icons.savings, color: Colors.green),
            ];

            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: metrics,
            );
          },
        ),
        const SizedBox(height: 12),
        // Ledger block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _kv('Requested', inr(qrCode.withdrawalRequestedAmount ?? 0)),
              _kv('Approved', inr(qrCode.withdrawalApprovedAmount ?? 0)),
              _kv('Commission On-Hold', inr(qrCode.commissionOnHold ?? 0)),
              _kv('Commission Paid', inr(qrCode.commissionPaid ?? 0)),
              _kv('Amount On-Hold', inr(qrCode.amountOnHold ?? 0)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Created: $formattedDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            if (!widget.userMode)
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Assigned: ${displayUserNameText(assignedId) ?? (assignedId ?? 'Unassigned')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

// Right: metrics + ledger + created line + actions (actions can stay at bottom of card if preferred)
  Widget _rightMetricsBlock(QrCode qrCode, String formattedDate) {
    final bool isAdmin = widget.userMeta.role == "admin";
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
              if (isAdmin)
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
            tip: qrCode.assignedUserId == null ? 'Assign User' : 'Change Assignment',
            onTap: () => qrCode.assignedUserId == null
                ? _assignUser(qrCode.qrId, qrCode.fileId)
                : assignmentOptionForAdminSubAdmin(qrCode),
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


  Widget buildQrCodeCardOld(QrCode qrCode, String formattedDate) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: QR Image or Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                          builder: (_) => Dialog(
                            child: Stack(
                              children: [
                                // 🔍 Zoomable QR Image
                                InteractiveViewer(
                                  child: qrCode.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                    imageUrl: qrCode.imageUrl,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) =>
                                    const Icon(Icons.error, size: 100),
                                  )
                                      : const Icon(Icons.qr_code, size: 100),
                                ),

                                // ⬇️ Download Button
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.download, size: 28, color: Colors.blue),
                                    onPressed: () {
                                      final anchor = html.AnchorElement(href: qrCode.imageUrl)
                                        ..download = "qr_${DateTime.now().millisecondsSinceEpoch}.png"
                                        ..target = 'blank';
                                      anchor.click();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      );
                    },
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: qrCode.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: qrCode.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.error),
                        ),
                      )
                          : const Icon(Icons.qr_code, size: 80),
                    ),
                  ),

                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: qrCode.isActive ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      qrCode.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: qrCode.isActive ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if(!widget.userMode)
                        IconButton(
                          icon: Icon(
                            qrCode.isActive ? Icons.toggle_on : Icons.toggle_off,
                            color: qrCode.isActive ? Colors.green : Colors.grey,
                          ),
                          tooltip: 'Toggle Status',
                          onPressed: _isProcessing ? null : () => _toggleStatus(qrCode),
                        ),
                      if(!widget.userMode)
                        IconButton(
                          icon: Icon(
                            qrCode.assignedUserId == null
                                ? Icons.person_add_alt_1
                                : Icons.person_outline,
                            color: Colors.blueAccent,
                          ),
                          tooltip: qrCode.assignedUserId == null ? 'Assign User' : 'Change Assignment',
                          onPressed: _isProcessing
                              ? null
                              : () => qrCode.assignedUserId == null
                              ? _assignUser(qrCode.qrId, qrCode.fileId)
                              : _showAssignOptions(qrCode),
                        ),
                      IconButton(
                        icon: const Icon(Icons.article_outlined, color: Colors.deepPurple),
                        tooltip: 'View Transactions',
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) {
                              if (widget.userMode) {
                                return TransactionPageNew(
                                  filterQrCodeId: qrCode.qrId,
                                  userMode: true,
                                  userModeUserid: widget.userModeUserid,
                                );
                              } else {
                                return TransactionPageNew(
                                  filterQrCodeId: qrCode.qrId,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      if(!widget.userMode && widget.userMeta.role == "admin")
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete QR Code',
                          onPressed:
                          _isProcessing ? null : () => _deleteQrCode(qrCode.qrId),
                        ),
                    ],
                  )

                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right: Info + Actions
            Expanded(
              child: SizedBox(
                height: 200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // QR ID
                    Text(
                      'ID: ${qrCode.qrId}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 6),

                    // QR ID
                    Text(
                      'Transactions: ${CurrencyUtils.formatIndianCurrencyWithoutSign(qrCode.totalTransactions!)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),

                    // QR ID
                    Text(
                      'Amount Received: ${CurrencyUtils.formatIndianCurrency(qrCode.totalPayInAmount! / 100)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 6),

                    if(!widget.userMode)
                    Text(
                      'Assigned to: ${displayUserNameText(qrCode.assignedUserId) ?? 'Unassigned'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Created: $formattedDate',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),

                    const SizedBox(height: 10),

                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

}