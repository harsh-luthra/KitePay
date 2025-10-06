import 'dart:async';

import 'package:admin_qr_manager/AppConstants.dart';
import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/MyMetaApi.dart';
import 'package:admin_qr_manager/widget/TransactionCardShimmer.dart';
import 'package:admin_qr_manager/widget/UsersCardShimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'AppConfig.dart';
import 'CommissionService.dart';
import 'TransactionPageNew.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';

class ManageUsersScreenBkup extends StatefulWidget {
  const ManageUsersScreenBkup({super.key});

  @override
  State<ManageUsersScreenBkup> createState() => _ManageUsersScreenBkupState();

}

class _ManageUsersScreenBkupState extends State<ManageUsersScreenBkup> {
  // final AdminUserService _userService = AdminUserService();

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();

  List<AppUser> _users = [];
  bool loading = true;

  late AppUser appUser;

  final List<String> availableLabels = ['SelfQr', 'users', 'all_users', 'all_qr', 'manual_transactions','all_transactions', 'edit_transactions', 'all_withdrawals' , 'edit_withdrawals'];

  late AppUser userMeta;

  // PAGINATION
  String? nextCursor;
  bool hasMore = true;
  bool loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  Map<String, int> _todayPaise = {};
  String _todayDate = '';

  final minCommissionLimit = AppConfig().minCommission;
  final maxCommissionLimit = AppConfig().maxCommission;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll); // PAGINATION listener
    // loadUserMeta();
    userMeta = MyMetaApi.current!;
    _fetchUsers(firstLoad: true);

    if(userMeta.role == 'admin') {
      loadTodayCommissions();
    }

  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // PAGINATION scroll listener
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchUsers();
    }
  }

  String _fmtRupees(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(rupees);
  }

  Future<void> loadTodayCommissions() async {
    try {
      final jwt = await AppWriteService().getJWT();
      final snap = await CommissionService.fetchTodayPerUserCommissions(jwtToken: jwt);
      setState(() {
        _todayPaise = snap.paiseByUser;
        _todayDate = snap.date;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load today commissions: $e')));
      }
    }
  }

  Future<void> assignUserToSubAdmin(BuildContext context, String userId) async {
    final pageContext = context;
    String jwtToken = await AppWriteService().getJWT();
    showDialog(
      context: pageContext,
      builder: (context) {
        String localSearchTerm = '';
        Timer? debounce;

        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: Text("Select Sub-admin"),
              content: Container(
                width: 300,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by name or email',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        if (debounce?.isActive ?? false) debounce!.cancel();
                        debounce = Timer(const Duration(milliseconds: 500), () {
                          setState(() {
                            localSearchTerm = value;
                          });
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: FutureBuilder<List<AppUser>>(
                        future: UsersService.listSubAdmins(
                          jwtToken,
                          search: localSearchTerm,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}");
                          }
                          final subadmins = snapshot.data ?? [];
                          if (subadmins.isEmpty) {
                            return Center(child: Text('No sub-admins found'));
                          }
                          return ListView.builder(
                            itemCount: subadmins.length,
                            itemBuilder: (context, index) {
                              final subadmin = subadmins[index];
                              return ListTile(
                                leading: Text(
                                  (index + 1).toString(),
                                  style: TextStyle(fontSize: 25),
                                ),
                                title: Text(subadmin.name),
                                subtitle: Text(subadmin.email),
                                onTap: () async {
                                  // Close the selection dialog using dialog context
                                  Navigator.of(dialogCtx).pop();
                                  // Show a progress dialog using page context
                                  showDialog(
                                    context: pageContext,
                                    barrierDismissible: false,
                                    builder:
                                        (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                  try {
                                    await UsersService.assignUserToSubAdmin(
                                      subAdminId: subadmin.id,
                                      userId: userId,
                                      jwtToken: jwtToken,
                                    );
                                    // Dismiss loading dialog
                                    if (pageContext.mounted) {
                                      Navigator.of(pageContext).pop();
                                    }
                                    // Now show snackbar using page context (has ScaffoldMessenger)
                                    if (pageContext.mounted) {
                                      ScaffoldMessenger.of(
                                        pageContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "User: $userId assigned to ${subadmin.id}",
                                          ),
                                        ),
                                      );
                                    }
                                    // Refresh list (ensure owning State is still mounted)
                                    if (pageContext.mounted) {
                                      _fetchUsers(firstLoad: true); // make sure this is safe to call
                                    }
                                  } catch (e) {
                                    // Dismiss loading dialog
                                    if (pageContext.mounted) {
                                      Navigator.of(pageContext).pop();
                                    }
                                    if (pageContext.mounted) {
                                      ScaffoldMessenger.of(
                                        pageContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to assign user: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
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
                  onPressed: () {
                    debounce?.cancel();
                    Navigator.pop(context);
                  },
                  child: Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> unAssignUser(
      BuildContext context,
      String userId,
      String subadminId,
      ) async {
    final pageContext = context;

    final confirm = await showDialog<bool>(
      context: pageContext,
      builder:
          (ctx) => AlertDialog(
        title: const Text('Un-assign User'),
        content: const Text(
          'Are you sure you want to un-assign this user from the sub-admin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, un-assign'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final jwtToken = await AppWriteService().getJWT();

    print("UNsassign call 1");

    // Show loader
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      print("UNsassign call 2");
      await UsersService.assignUserToSubAdmin(
        unAssign: true,
        subAdminId: subadminId,
        userId: userId,
        jwtToken: jwtToken,
      );
      if (pageContext.mounted) {
        Navigator.of(pageContext, rootNavigator: true).pop(); // dismiss loader
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(content: Text('User: $userId Unassigned Successfully')),
        );
        _fetchUsers(firstLoad: true); // make sure owner is still mounted if it triggers setState
      }
    } catch (e) {
      if (pageContext.mounted) {
        Navigator.of(pageContext, rootNavigator: true).pop(); // dismiss loader
        ScaffoldMessenger.of(
          pageContext,
        ).showSnackBar(SnackBar(content: Text('Failed to unassign user: $e')));
      }
    }
  }

  Future<void> loadUserMeta() async {
    userMeta = MyMetaApi.current!;
    print(userMeta.toString());
    // String jwtToken = await AppWriteService().getJWT();
    // userMeta = (await MyMetaApi.getMyMetaData(
    //       jwtToken: jwtToken,
    //       refresh: false, // set true to force re-fetch
    //     ))!;
  }

  Future<void> _fetchUsers({bool firstLoad = false}) async {
    if (loadingMore && !firstLoad) return;
    if (!hasMore && !firstLoad) return;

    if (firstLoad) {
      _users.clear();
      nextCursor = null;
      hasMore = true;
      setState(() => loading = true);
    } else {
      setState(() => loadingMore = true);
    }

    try {
      final fetched = await UsersService.listUsers(
        cursor: nextCursor,
        jwtToken: await AppWriteService().getJWT(),
      );

      if (firstLoad) {
        _users = fetched.appUsers.toList();
      } else {
        final existingIds = _users.map((e) => e.id).toSet();
        final newUsers = fetched.appUsers.where((e) => !existingIds.contains(e.id));

        if (newUsers.isEmpty) {
          // No new data, so stop further loading to prevent infinite loader
          hasMore = false;
        } else {
          _users.addAll(newUsers);
        }
      }

      nextCursor = fetched.nextCursor;
      if (fetched.nextCursor == null) {
        hasMore = false;
      }

      print("$nextCursor    $hasMore");

    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch users: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      loadingMore = false;
    });
  }

  void _showAddUserDialog(BuildContext parentContext) {
    final emailController = TextEditingController(text: "");
    final passController = TextEditingController(text: "");
    final nameController = TextEditingController(text: "");
    String? selectedRole =
    userMeta.role == "subadmin" ? "user" : null; // store chosen role

    showDialog(
      context: context,
      useRootNavigator: true,
      builder:
          (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add New User"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  obscureText: false,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Min 3 characters',
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'e.g. user@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Min 6 characters',
                  ),
                ),
                const SizedBox(height: 16),

                // --- Role selection ---
                const Text(
                  "Select Role",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (userMeta.role == "admin") ...[
                  RadioListTile<String>(
                    title: const Text("Sub-Admin"),
                    value: "subadmin",
                    groupValue: selectedRole,
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text("Employee"),
                    value: "employee",
                    groupValue: selectedRole,
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                ],

                RadioListTile<String>(
                  title: const Text("User"),
                  value: "user",
                  groupValue: selectedRole,
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(context, rootNavigator: true).pop(),
                // closes this dialog
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // validate...
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pop(); // close form dialog

                  // show loading on root navigator
                  showDialog(
                    context: parentContext,
                    barrierDismissible: false,
                    useRootNavigator: true,
                    builder:
                        (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  final navigator = Navigator.of(
                    parentContext,
                    rootNavigator: true,
                  );

                  try {
                    final jwt = await AppWriteService().getJWT();
                    final ok = await UsersService.createUser(
                      emailController.text.trim(),
                      passController.text.trim(),
                      nameController.text.trim(),
                      selectedRole!,
                      jwt,
                    );
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'User added successfully!'
                              : 'Failed to add user',
                        ),
                      ),
                    );
                    if (ok) await _fetchUsers(firstLoad: true);
                  } catch (e) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Failed to add user: $e')),
                    );
                  } finally {
                    if (navigator.canPop())
                      navigator.pop(); // close loader exactly once
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, String userId) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                hintText: 'Enter new password',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              child: const Text('Reset'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                Navigator.of(dialogContext).pop(); // Close password dialog

                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final jwt = await AppWriteService().getJWT();
                  await UsersService.resetPassword(
                    userId,
                    passwordController.text.trim(),
                    jwt,
                  );
                  if (context.mounted)
                    Navigator.of(context).pop(); // Close loading

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset successfully'),
                    ),
                  );
                } catch (e) {
                  if (context.mounted)
                    Navigator.of(context).pop(); // Close loading

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to reset password: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(
      AppUser user,
      String currentName,
      String currentEmail,
      BuildContext parentContext,
      ) {
    final nameController = TextEditingController(text: currentName);
    final emailController = TextEditingController(text: currentEmail);
    final tempLabels = List<String>.from(user.labels); // Clone user labels

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit User'),
              content: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        if (value == null ||
                            !RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    if (userMeta.role == "admin")
                      const Text(
                        'Labels:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (userMeta.role == "admin")
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children:
                        availableLabels.map((label) {
                          final normalizedLabel = label.trim();
                          final isSelected = tempLabels.contains(
                            normalizedLabel,
                          );

                          return FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  if (!tempLabels.contains(
                                    normalizedLabel,
                                  )) {
                                    tempLabels.add(normalizedLabel);
                                    // print('✅ Added: $normalizedLabel');
                                  }
                                } else {
                                  tempLabels.remove(normalizedLabel);
                                  // print('🗑️ Removed: $normalizedLabel');
                                }
                              });
                            },
                            selectedColor: Colors.blue.shade200,
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final newName = nameController.text.trim();
                    final newEmail = emailController.text.trim();

                    final nameChanged = newName != currentName;
                    final emailChanged = newEmail != currentEmail;
                    final labelsChanged =
                        !Set.from(tempLabels).containsAll(user.labels) ||
                            !Set.from(user.labels).containsAll(tempLabels);

                    if (!nameChanged && !emailChanged && !labelsChanged) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text('Nothing changed')),
                      );
                      return;
                    }

                    Navigator.of(context).pop();

                    BuildContext? dialogContext;
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) {
                          dialogContext = ctx;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      );
                    }

                    try {
                      final jwt = await AppWriteService().getJWT();
                      // print('labelsChanged $tempLabels');
                      await UsersService.editUser(
                        user.id,
                        jwt,
                        name: nameChanged ? newName : null,
                        email: emailChanged ? newEmail : null,
                        labels: labelsChanged ? tempLabels : null,
                      );

                      if (dialogContext != null)
                        Navigator.of(dialogContext!).pop();

                      _fetchUsers();
                    } catch (e) {
                      if (dialogContext != null)
                        Navigator.of(dialogContext!).pop();
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(content: Text('Failed to update user: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showCommissionEditDialog({
    required AppUser user,
    required double minCommission,
    required double maxCommission,
    required BuildContext parentContext,
  }) {
    final commissionController =
    TextEditingController(text: user.commission?.toStringAsFixed(1));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Commission'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: commissionController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Commission (%)',
                hintText: 'e.g. 1.2',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a commission value';
                }
                final commission = double.tryParse(value);
                if (commission == null) {
                  return 'Enter a valid number';
                }
                if (!RegExp(r'^\d+(\.\d{1})?$').hasMatch(value)) {
                  return 'Only one digit after the decimal allowed';
                }
                if (commission < minCommission || commission > maxCommission) {
                  return 'Value must be between $minCommission and $maxCommission';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newCommission =
                double.parse(commissionController.text.trim());

                Navigator.of(context).pop(); // close edit dialog

                BuildContext? progressDialogContext;
                showDialog(
                  context: parentContext,
                  barrierDismissible: false,
                  builder: (ctx) {
                    progressDialogContext = ctx;
                    return const Center(child: CircularProgressIndicator());
                  },
                );

                try {
                  final jwt = await AppWriteService().getJWT();
                  await UsersService.editUser(
                    user.id,
                    jwt,
                    commission: newCommission,
                  );
                  if (progressDialogContext != null) {
                    Navigator.of(progressDialogContext!).pop(); // close progress
                  }
                  _fetchUsers(firstLoad: true);
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('User Commission Updated Successfully')),
                    );
                  }
                } catch (e) {
                  if (progressDialogContext != null) {
                    Navigator.of(progressDialogContext!).pop();
                  }
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Failed to update commission: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _deleteUser(String userId, String name, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this user?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await UsersService.deleteUser(
          userId,
          await AppWriteService().getJWT(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User $name, Email $email Deleted Successfully'),
          ),
        );
        Navigator.of(context).pop(); // Dismiss the loading dialog
        _fetchUsers(); // Refresh user list
      } catch (e) {
        Navigator.of(context).pop(); // Dismiss loading dialog on error too
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete user: $e')));
      }
    }
  }

  String? getParentLabel(String role, String? parentId) {
    if (role == 'admin') {
      return null; // No parent label for admin
    }

    if (parentId == null || parentId.isEmpty) {
      return 'Admin'; // No parentId means parent is admin
    }

    return 'Subadmin'; // Has parentId means parent is subadmin
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manage Users"),
          actions: !loading
              ? [
            if (userMeta.role != "employee")
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: "Add User",
                onPressed: () => _showAddUserDialog(context),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Refresh",
              onPressed: () => _fetchUsers(firstLoad: true),
            ),
          ]
              : [],
        ),
        body: loading
            ? ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 8,
          itemBuilder: (_, __) => const UsersCardShimmer(),
        )
            : _users.isEmpty
            ? const Center(child: Text("No users found"))
            : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          itemCount: _users.length + (loadingMore && hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < _users.length) {
              final user = _users[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: avatar, name, role chip, email, status pill
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue.shade50,
                            child: Text(
                              (user.name?.isNotEmpty ?? false)
                                  ? user.name!.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.name ?? 'Unnamed',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _roleChip(user.role),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.email, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        user.email ?? '',
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusPill(user.status ?? false),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Info tokens
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (user.role != 'admin')
                            _infoToken(
                              Icons.account_tree,
                              'Parent',
                              (user.parentId == null || user.parentId!.isEmpty) ? 'Admin' : 'Sub-Admin',
                            ),
                          _infoToken(Icons.badge_outlined, 'Role', user.role),
                          if (user.role != 'employee' && user.role != 'admin')
                            _infoToken(Icons.percent, 'Commission', '${user.commission ?? 0} %'),
                          if (user.role == 'admin' || user.role == 'subadmin')
                            _infoToken(Icons.currency_rupee, 'Today Commission', _fmtRupees(_todayPaise[user.id] ?? 0)),
                        ],
                      ),

                      // Labels stripe
                      if (user.labels != null && user.labels.isNotEmpty && userMeta.role == "admin") ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: user.labels
                                .map<Widget>(
                                  (label) => Chip(
                                label: Text(label, overflow: TextOverflow.ellipsis),
                                backgroundColor: Colors.blue.shade50,
                                labelStyle: const TextStyle(color: Colors.blue),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                                .toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Action toolbar
                      if (userMeta.role == 'admin' || userMeta.role == 'employee' || userMeta.role == 'subadmin')
                        Row(
                          children: [
                            if (user.role != 'admin' && userMeta.role != "employee") ...[
                              const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              Switch(
                                value: user.status ?? false,
                                onChanged: (newStatus) =>
                                    _confirmAndToggleUserStatus(context, user, newStatus),
                              ),
                            ],
                            const Spacer(),
                            if (user.role != 'admin')
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (user.role == 'user' &&
                                      user.parentId == null &&
                                      userMeta.role != "employee")
                                    _iconBtn(Icons.no_accounts_outlined, 'Assign to Sub-Admin',
                                            () => assignUserToSubAdmin(context, user.id)),
                                  if (user.role == 'user' &&
                                      user.parentId != null &&
                                      userMeta.role != "employee")
                                    _iconBtn(Icons.account_circle, 'Un-Assign',
                                            () => unAssignUser(context, user.id, user.parentId!)),
                                  if (userMeta.role != "employee")
                                    _iconBtn(Icons.edit, 'Edit',
                                            () => _showEditDialog(user, user.name, user.email, context)),
                                  if (userMeta.role != "employee" && user.role != "employee")
                                    _iconBtn(Icons.percent_sharp, 'Commission %',
                                            () => showCommissionEditDialog(
                                          minCommission: minCommissionLimit,
                                          maxCommission: maxCommissionLimit,
                                          parentContext: context,
                                          user: user,
                                        )),
                                  if (userMeta.role != "employee")
                                    _iconBtn(Icons.lock_reset, 'Reset Password',
                                            () => _showResetPasswordDialog(context, user.id),
                                        color: Colors.orange),
                                  if (userMeta.role != "employee")
                                    _iconBtn(Icons.delete, 'Delete',
                                            () => _deleteUser(user.id, user.name, user.email),
                                        color: Colors.red),
                                  if (userMeta.role == 'admin' ||
                                      userMeta.role == 'subadmin' ||
                                      (userMeta.role == 'employee' &&
                                          userMeta.labels.contains(AppConstants.viewAllTransactions)))
                                    _iconBtn(Icons.receipt_long, 'View Transactions', () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TransactionPageNew(filterUserId: user.id),
                                        ),
                                      );
                                    }, color: Colors.teal),
                                ],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }

            // loading more sentinel
            return const TransactionCardShimmer();
          },
        ),
      ),
    );
  }

  Widget _roleChip(String role) {
    final r = role.toUpperCase();
    Color c; String t;
    switch (r) {
      case 'ADMIN':
        c = Colors.red; t = 'ADMIN'; break;
      case 'SUBADMIN':
        c = Colors.orange; t = 'SUBADMIN'; break;
      default:
        c = Colors.blue; t = r; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Widget _statusPill(bool status) {
    final color = status ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(status ? 'Active' : 'Inactive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoToken(IconData icon, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Text(v, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap, {Color? color}) {
    return IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color ?? Colors.blue),
      splashRadius: 20,
    );
  }

  Widget _buildStatusBadge(bool status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status ? "Active" : "Inactive",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: status ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget userRoleIcon({required String role, String? parentId}) {
    final r = role.toUpperCase();
    if (r == 'ADMIN') {
      return const Icon(Icons.shield, color: Colors.red);
    }
    if (r == 'SUBADMIN') {
      return const Icon(Icons.manage_accounts, color: Colors.orange);
    }
    // USER (or anything else)
    final isAssigned = parentId != null && parentId.isNotEmpty;
    return Icon(
      isAssigned ? Icons.person_add : Icons.person_outline,
      color: isAssigned ? Colors.green : Colors.blueGrey,
    );
  }

  Widget roleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return const Icon(Icons.shield, color: Colors.red);
      case 'SUBADMIN':
        return const Icon(Icons.manage_accounts, color: Colors.orange);
      case 'USER':
      default:
        return const Icon(Icons.person, color: Colors.blue);
    }
  }

  void _confirmAndToggleUserStatus(
      BuildContext context,
      AppUser user,
      bool newStatus,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
        title: Text(newStatus ? 'Enable User' : 'Disable User'),
        content: Text(
          'Are you sure you want to ${newStatus ? 'enable' : 'disable'} this user?',
        ),
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
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final jwt = await AppWriteService().getJWT();
    final success = await UsersService.updateUserStatus(
      userId: user.id,
      jwtToken: jwt,
      status: newStatus,
    );

    Navigator.pop(context); // Close loading

    if (success) {
      setState(() {
        user.status = newStatus;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User status updated.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to update user status')),
      );
    }
  }
}
