import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';
import 'package:location_tracker/features/admin/widgets/user_management/edit_user_dialog.dart';
import 'package:location_tracker/features/admin/widgets/user_management/role_selection_dialog.dart';
import 'package:location_tracker/features/admin/widgets/user_management/user_card.dart';
import 'package:location_tracker/features/admin/widgets/user_management/user_list_empty_state.dart';
import 'package:location_tracker/features/admin/widgets/user_management/user_management_app_bar.dart';

class UserManagementScreen extends StatefulWidget {
  final AdminApiService apiService;

  const UserManagementScreen({super.key, required this.apiService});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AdminUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300)); // Smooth animation
    final result = await widget.apiService.getUsers();
    if (mounted) {
      setState(() {
        _users = result?.content ?? [];
        _isLoading = false;
      });
    }
  }

  void _showEditDialog(AdminUser user) {
    showDialog(
      context: context,
      builder: (_) => EditUserDialog(
        user: user,
        onSave: (name, username) async {
          final success = await widget.apiService.updateUser(
            user.id,
            name,
            username,
          );
          if (success) {
            _fetchUsers();
            _showSnack("User updated successfully");
          } else {
            _showSnack("Failed to update user", isError: true);
          }
        },
      ),
    );
  }

  void _confirmDelete(AdminUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User?"),
        content: Text("Are you sure you want to remove ${user.name}? This action cannot be undone."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog

              // Call API
              final success = await widget.apiService.deleteUser(user.id);

              if (success) {
                _fetchUsers(); // Refresh list
                _showSnack("User deleted successfully");
              } else {
                _showSnack("Failed to delete user", isError: true);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(AdminUser user) async {
    final roles = await widget.apiService.getRoles();
    if (!mounted) return;

    if (roles.isEmpty) {
      _showSnack("No roles available", isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => RoleSelectionDialog(
        user: user,
        roles: roles,
        onRoleSelected: (roleId) async {
          final errorMessage = await widget.apiService.assignRoleToUser(
            user.id,
            roleId,
          );

          if (errorMessage == null) {
            _fetchUsers();
            _showSnack("Role assigned successfully");
          } else {
            _showSnack(errorMessage, isError: true);
          }
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: isError
            ? Colors.redAccent
            : SecondaryConstants.kPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchUsers,
        backgroundColor: SecondaryConstants.kPrimaryGreen,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SecondaryConstants.kBackgroundStart,
              SecondaryConstants.kBackgroundEnd,
            ],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            UserManagementAppBar(innerBoxIsScrolled: innerBoxIsScrolled),
          ],
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: SecondaryConstants.kPrimaryGreen,
                  ),
                )
              : RefreshIndicator(
                  color: SecondaryConstants.kPrimaryGreen,
                  onRefresh: _fetchUsers,
                  child: _users.isEmpty
                      ? UserListEmptyState(onRefresh: _fetchUsers)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: _users.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            // Fade Animation for List Items
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds: 300 + (index * 50),
                              ),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(opacity: value, child: child),
                                );
                              },
                              child: UserCard(
                                user: _users[index],
                                onEdit: () => _showEditDialog(_users[index]),
                                onAssignRole: () =>
                                    _showRoleDialog(_users[index]),
                                onDelete: () => _confirmDelete(_users[index]),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ),
    );
  }
}
