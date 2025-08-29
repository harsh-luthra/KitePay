import 'dart:async';

import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:admin_qr_manager/MyMetaApi.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'TransactionPageNew.dart';
import 'UsersService.dart';
import 'models/AppUser.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  // final AdminUserService _userService = AdminUserService();

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  List<AppUser> _users = [];
  bool _loading = true;

  late AppUser appUser;

  // final List<String> availableLabels = [
  //   'user',
  //   'qr',
  //   'transactions',
  //   'withdrawal',
  //   'payout',
  // ];

  final List<String> availableLabels = [
    'SelfQr',
    'users'
  ];

  late AppUser userMeta;

  @override
  void initState() {
    super.initState();
    loadUserMeta();
    _fetchUsers();
  }

  @override
  void dispose() {
    super.dispose();
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
                        future: AdminUserService.listSubadmins(jwtToken, search: localSearchTerm),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
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
                                    builder: (_) => const Center(child: CircularProgressIndicator()),
                                  );
                                  try {
                                    await AdminUserService.assignUserToSubadmin(
                                      subadminId: subadmin.id,
                                      userId: userId,
                                      jwtToken: jwtToken,
                                    );
                                    // Dismiss loading dialog
                                    if (pageContext.mounted) {
                                      Navigator.of(pageContext).pop();
                                    }
                                    // Now show snackbar using page context (has ScaffoldMessenger)
                                    if (pageContext.mounted) {
                                      ScaffoldMessenger.of(pageContext).showSnackBar(
                                        SnackBar(content: Text("User: $userId assigned to ${subadmin.id}")),
                                      );
                                    }
                                    // Refresh list (ensure owning State is still mounted)
                                    if (pageContext.mounted) {
                                      _fetchUsers(); // make sure this is safe to call
                                    }
                                  } catch (e) {
                                    // Dismiss loading dialog
                                    if (pageContext.mounted) {
                                      Navigator.of(pageContext).pop();
                                    }
                                    if (pageContext.mounted) {
                                      ScaffoldMessenger.of(pageContext).showSnackBar(
                                        SnackBar(content: Text('Failed to assign user: $e')),
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

  Future<void> unAssignUser(BuildContext context, String userId, String subadminId) async {
    final pageContext = context;

    final confirm = await showDialog<bool>(
      context: pageContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Un-assign User'),
        content: const Text('Are you sure you want to un-assign this user from the sub-admin?'),
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

    // Show loader
    await showDialog(
      context: pageContext,
      barrierDismissible: false,
      useRootNavigator: true, // safer with nested navigators
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AdminUserService.assignUserToSubadmin(
        unassign: true,
        subadminId: subadminId,
        userId: userId,
        jwtToken: jwtToken,
      );
      if (pageContext.mounted) {
        Navigator.of(pageContext, rootNavigator: true).pop(); // dismiss loader
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(content: Text('User: $userId Unassigned Successfully')),
        );
        _fetchUsers(); // make sure owner is still mounted if it triggers setState
      }
    } catch (e) {
      if (pageContext.mounted) {
        Navigator.of(pageContext, rootNavigator: true).pop(); // dismiss loader
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(content: Text('Failed to unassign user: $e')),
        );
      }
    }
  }

  Future<void> loadUserMeta() async {
    String jwtToken = await AppWriteService().getJWT();
    userMeta = (await MyMetaApi.getMyMetaData(
      jwtToken: jwtToken,
      refresh: false, // set true to force re-fetch
    ))!;
  }

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    try {
      _users = await AdminUserService.listUsers(await AppWriteService().getJWT());
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('❌ Failed to fetch users: $e')),
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _showAddUserDialog(BuildContext parentContext) {
    final emailController = TextEditingController(text: "test@gmail.com");
    final passController = TextEditingController(text: "Test@1234");
    final nameController = TextEditingController(text: "Test");
    String? selectedRole = userMeta.role == "subadmin" ? "user" : null; // store chosen role

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => StatefulBuilder(
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
                const Text("Select Role",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if(userMeta.role == "admin")
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
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(), // closes this dialog
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // validate...
                  Navigator.of(context, rootNavigator: true).pop(); // close form dialog

                  // show loading on root navigator
                  showDialog(
                    context: parentContext,
                    barrierDismissible: false,
                    useRootNavigator: true,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );
                  final navigator = Navigator.of(parentContext, rootNavigator: true);

                  try {
                    final jwt = await AppWriteService().getJWT();
                    final ok  = await AdminUserService.createUser(
                      emailController.text.trim(),
                      passController.text.trim(),
                      nameController.text.trim(),
                      selectedRole!,
                      jwt,
                    );
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text(ok ? 'User added successfully!' : 'Failed to add user')),
                    );
                    if (ok) await _fetchUsers();
                  } catch (e) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Failed to add user: $e')),
                    );
                  } finally {
                    if (navigator.canPop()) navigator.pop(); // close loader exactly once
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
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final jwt = await AppWriteService().getJWT();
                  await AdminUserService.resetPassword(
                    userId,
                    passwordController.text.trim(),
                    jwt,
                  );
                  if (context.mounted) Navigator.of(context).pop(); // Close loading

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset successfully')),
                  );
                } catch (e) {
                  if (context.mounted) Navigator.of(context).pop(); // Close loading

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

  void _showEditDialog(AppUser user, String currentName, String currentEmail, BuildContext parentContext) {
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
                        if (value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    if(userMeta.role == "admin")
                    const Text('Labels:', style: TextStyle(fontWeight: FontWeight.bold)),
                    if(userMeta.role == "admin")
                      Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: availableLabels.map((label) {
                        final normalizedLabel = label.trim();
                        final isSelected = tempLabels.contains(normalizedLabel);

                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                if (!tempLabels.contains(normalizedLabel)) {
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
                    final labelsChanged = !Set.from(tempLabels).containsAll(user.labels) ||
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
                          return const Center(child: CircularProgressIndicator());
                        },
                      );
                    }

                    try {
                      final jwt = await AppWriteService().getJWT();
                      // print('labelsChanged $tempLabels');
                      await AdminUserService.editUser(
                        user.id,
                        jwt,
                        name: nameChanged ? newName : null,
                        email: emailChanged ? newEmail : null,
                        labels: labelsChanged ? tempLabels : null,
                      );

                      if (dialogContext != null) Navigator.of(dialogContext!).pop();

                      _fetchUsers();
                    } catch (e) {
                      if (dialogContext != null) Navigator.of(dialogContext!).pop();
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(content: Text('Failed to update user: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                )
              ],
            );
          },
        );
      },
    );

  }

  Future<void> _deleteUser(String userId, String name, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this user?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm ?? false) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        await AdminUserService.deleteUser(userId, await AppWriteService().getJWT());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $name, Email $email Deleted Successfully')),
        );
        Navigator.of(context).pop(); // Dismiss the loading dialog
        _fetchUsers(); // Refresh user list
      } catch (e) {
        Navigator.of(context).pop(); // Dismiss loading dialog on error too
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user: $e')),
        );
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
          actions: !_loading
              ? [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "Add User",
              onPressed: () => _showAddUserDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Refresh",
              onPressed: _fetchUsers,
            ),
          ]
              : [],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
            ? const Center(child: Text("No users found"))
            : ListView.builder(
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            // print(user.toString());
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Email
                    Row(
                      children: [
                        userRoleIcon(role: user.role, parentId: user.parentId),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.name ?? 'Unnamed',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        _buildStatusBadge(user.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.email ?? '',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Parent Role Label Logic
                    if (user.role != 'admin')
                      Row(
                        children: [
                          const Icon(Icons.account_tree, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            "Parent: ${(user.parentId == null || user.parentId!.isEmpty)
                                    ? 'Admin'
                                    : 'Sub-Admin'}",
                            style: const TextStyle(fontSize: 14, color: Colors.black54, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),

                    Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text("Role : ${user.role}" , style: const TextStyle(fontSize: 14, color: Colors.black54, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Labels
                    if (user.labels != null && user.labels.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: user.labels
                            .map((label) => Chip(
                          label: Text(label),
                          backgroundColor: Colors.blue.shade50,
                          labelStyle: const TextStyle(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ))
                            .toList(),
                      ),

                    const SizedBox(height: 12),

                    // Action Buttons
                    if (user.role != 'admin')
                      Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Status switch
                        Row(
                          children: [
                            const Text("Status:"),
                            const SizedBox(width: 6),
                            Switch(
                              value: user.status ?? false,
                              onChanged: (newStatus) => _confirmAndToggleUserStatus(context, user, newStatus),
                            ),
                          ],
                        ),

                        // Right side actions
                        if (user.role != 'admin')
                        Row(
                          children: [
                            if(user.role == 'user' && user.parentId == null)
                            IconButton(
                              icon: const Icon(Icons.no_accounts_outlined, color: Colors.blue),
                              tooltip: "Assign User to Sub-Admin",
                              onPressed: () => assignUserToSubAdmin(context,user.id),
                            ),
                            if(user.role == 'user' && user.parentId != null)
                              IconButton(
                                icon: const Icon(Icons.account_circle, color: Colors.blue),
                                tooltip: "Un-Assign User",
                                onPressed: () => unAssignUser(context, user.id, user.parentId!),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: "Edit User",
                              onPressed: () => _showEditDialog(user, user.name, user.email, context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.lock_reset, color: Colors.orange),
                              tooltip: "Reset Password",
                              onPressed: () => _showResetPasswordDialog(context, user.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Delete User",
                              onPressed: () => _deleteUser(user.id, user.name, user.email),
                            ),
                            IconButton(
                              icon: const Icon(Icons.receipt_long, color: Colors.teal),
                              tooltip: "View Transactions",
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionPageNew(filterUserId: user.id),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
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

  Widget userRoleIcon({
    required String role,
    String? parentId,
  }) {
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

  void _confirmAndToggleUserStatus(BuildContext context, AppUser user, bool newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus ? 'Enable User' : 'Disable User'),
        content: Text('Are you sure you want to ${newStatus ? 'enable' : 'disable'} this user?'),
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
    final success = await AdminUserService.updateUserStatus(
      userId: user.id,
      jwtToken: jwt,
      status: newStatus,
    );

    Navigator.pop(context); // Close loading

    if (success) {
      setState(() {
        user.status = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User status updated.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Failed to update user status')));
    }
  }

}
