import 'dart:io';
import 'package:admin_qr_manager/QRService.dart';
import 'package:admin_qr_manager/utils/CurrencyUtils.dart';
import 'package:appwrite/models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'AppWriteService.dart';
import 'NewFeatureCornerButton.dart';
import 'TransactionPage.dart';
import 'TransactionPageNew.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';
import 'models/QrCode.dart';

// QrCodesPage.dart
class ManageQrScreen extends StatefulWidget {
  final String? userModeUserid;
  final bool userMode;

  const ManageQrScreen({super.key, this.userMode = false, this.userModeUserid});

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

  @override
  void initState() {
    super.initState();
    // Simulate a login to get a token, for a real app this would be a user action
    // _loginAsAdmin();
    if(!widget.userMode){
        _fetchQrCodes();
        _fetchUsers();
    }else{
      // print("User Mode");
      _fetchOnlyUserQrCodes();
    }
  }

  // Navigator.push(
  // context,
  // MaterialPageRoute(
  // builder: (_) => const TransactionPage(filterQrCodeId: 'qr_code_id_here'),
  // ),
  // );

  @override
  void dispose() {
    _qrIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isProcessing = true);
    try {
      users = await AdminUserService.listUsers(await AppWriteService().getJWT());
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
      if (success) _fetchQrCodes();
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
        _qrCodes = codes;
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

    if(mounted) {
      setState(() {
      _isLoading = true;
    });
    }

    try{
      final codes = await _qrCodeService.getUserQrCodes(widget.userModeUserid!);
      setState(() {
        _qrCodes = codes;
        userQrCount = _qrCodes.length;
        activeUserQrCount = activeQrCount(_qrCodes);
        print('userQrCount: '+userQrCount.toString());
        print('activeUserQrCount: '+activeUserQrCount.toString());
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
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Upload New QR Code'),
          content: TextField(
            controller: _qrIdController,
            decoration: const InputDecoration(labelText: 'Enter QR ID'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _qrIdController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_qrIdController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _uploadQrCode(_qrIdController.text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a QR ID.')),
                  );
                }
              },
              child: const Text('Select File'),
            ),
          ],
        );
      },
    );
  }

  // This is the updated function that takes the QR ID and handles the file upload
  Future<void> _uploadQrCode(String qrId) async {
    if (_jwtToken == null) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      bool success = await _qrCodeService.uploadQrCode(file, qrId, _jwtToken!);
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

    final bool? shouldToggle = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Status Change'),
          content: Text('Are you sure you want to $statusText this QR code?'),
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
        _fetchQrCodes();
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
        _fetchQrCodes();
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

  Future<void> _createAssignUserQR() async {
    final user = await AppWriteService().account.get();
    print(user.labels.toString());
    if(!user.labels.contains('admin') && !user.labels.contains('SelfQr')){
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
      bool success = await _qrCodeService.createUserQrCode(widget.userModeUserid!);
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
            if(widget.userMode)
              NewFeatureCornerButton(onPressed: !_isProcessing ? _createAssignUserQR : null, icon: Icon(Icons.add_box_rounded), label: Text('Create QR Code'),),
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
            ? const Center(child: CircularProgressIndicator())
            : _isProcessing
            ? const Center(child: CircularProgressIndicator())
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
    final isMobile = MediaQuery.of(context).size.width < 600; // breakpoint

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: isMobile
            ? Column( // 📱 Mobile layout
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQrLeftSection(qrCode),   // QR + buttons
            const SizedBox(height: 12),
            _buildQrRightSection(qrCode, formattedDate), // Info
          ],
        )
            : Row( // 💻 Desktop layout
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQrLeftSection(qrCode),
            const SizedBox(width: 16),
            Expanded(child: _buildQrRightSection(qrCode, formattedDate)),
          ],
        ),
      ),
    );
  }

  /// Left section (QR image + status + actions)
  Widget _buildQrLeftSection(QrCode qrCode) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer( // allows pinch zoom
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
              placeholder: (c, _) => const Center(child: CircularProgressIndicator()),
              errorWidget: (c, _, __) => const Icon(Icons.error),
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
        _buildActionButtons(qrCode), // keep your Wrap of IconButtons
      ],
    );
  }

  /// Right section (Details)
  Widget _buildQrRightSection(QrCode qrCode, String formattedDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ID: ${qrCode.qrId}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Transactions: ${CurrencyUtils.formatIndianCurrencyWithoutSign(qrCode.totalTransactions!)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          'Amount Received: ${CurrencyUtils.formatIndianCurrency(qrCode.totalPayInAmount! / 100)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (!widget.userMode)
          Text('Assigned to: ${displayUserNameText(qrCode.assignedUserId) ?? 'Unassigned'}',
              style: const TextStyle(fontSize: 14)),
        Text('Created: $formattedDate',
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButtons(QrCode qrCode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8, // extra spacing between rows when wrapping
      alignment: WrapAlignment.center,
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
        if(!widget.userMode)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete QR Code',
            onPressed:
            _isProcessing ? null : () => _deleteQrCode(qrCode.qrId),
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
                          child: InteractiveViewer( // allows pinch zoom
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
                      if(!widget.userMode)
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