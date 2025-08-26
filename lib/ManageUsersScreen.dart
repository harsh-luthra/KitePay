import 'package:admin_qr_manager/AppWriteService.dart';
import 'package:flutter/material.dart';
import 'TransactionPage.dart';
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

  // final List<String> availableLabels = [
  //   'user',
  //   'qr',
  //   'transactions',
  //   'withdrawal',
  //   'payout',
  // ];

  final List<String> availableLabels = [
    'SelfQr'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final password = passController.text.trim();

              if (name.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Name must be at least 3 characters.")),
                );
                return;
              }

              // Basic validation
              final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
              if (!emailRegex.hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter a valid email address.")),
                );
                return;
              }

              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password must be at least 6 characters.")),
                );
                return;
              }

              Navigator.pop(context); // Close the dialog

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final jwt = await AppWriteService().getJWT();
                await AdminUserService.createUser(email, password, name, jwt);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('User added successfully!')),
                );
                Navigator.pop(context); // Close loading
                print("User added successfully!");
                _fetchUsers(); // Refresh list
              } catch (e) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(content: Text('Failed to add user: $e')),
                );
                Navigator.pop(context); // Close loading
              }
            },
            child: const Text("Create"),
          ),
        ],
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
                    const Text('Labels:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: availableLabels.map((label) {
                        final normalizedLabel = label.trim().toLowerCase();
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
                      print('labelsChanged $tempLabels');
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
                        const Icon(Icons.person, color: Colors.blue),
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
                            user.email,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Labels
                    if (user.labels.isNotEmpty)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Status switch
                        Row(
                          children: [
                            const Text("Status:"),
                            const SizedBox(width: 6),
                            Switch(
                              value: user.status,
                              onChanged: (newStatus) => _confirmAndToggleUserStatus(context, user, newStatus),
                            ),
                          ],
                        ),

                        // Right side actions
                        Row(
                          children: [
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
