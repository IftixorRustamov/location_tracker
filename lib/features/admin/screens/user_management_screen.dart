import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';
import 'package:location_tracker/features/admin/widgets/edit_user_dialog.dart';
import 'package:location_tracker/features/admin/widgets/role_selection_dialog.dart';
import 'package:location_tracker/features/admin/widgets/user_card.dart';

class UserManagementScreen extends StatefulWidget {
  final AdminApiService apiService;

  const UserManagementScreen({super.key, required this.apiService});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AdminUser> _users = [];
  bool _isLoading = true;

  final Color kBackgroundStart = const Color(0xFFF0F4F8);
  final Color kBackgroundEnd = const Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
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
          final success = await widget.apiService.updateUser(user.id, name, username);
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
          final success = await widget.apiService.assignRoleToUser(user.id, roleId);
          if (success) {
            _fetchUsers();
            _showSnack("Role assigned successfully");
          } else {
            _showSnack("Failed to assign role", isError: true);
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
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : SecondaryConstants.kPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBackgroundStart, kBackgroundEnd],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              // 1. INCREASED HEIGHT: Gives space for Back Button -> Title -> Search
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: innerBoxIsScrolled ? Colors.white : Colors.transparent,
              elevation: innerBoxIsScrolled ? 2 : 0,
              iconTheme: IconThemeData(
                color: innerBoxIsScrolled ? Colors.black87 : Colors.black87,
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                // 2. MOVED TITLE UP: Keeps it away from the bottom search bar
                titlePadding: const EdgeInsets.only(left: 16, bottom: 70),
                title: Text(
                  "Team Members",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    // Scale text size slightly when scrolling
                    fontSize: innerBoxIsScrolled ? 20 : 22,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand, // Ensures background fills space
                  children: [
                    // Background Watermark Icon
                    Positioned(
                      right: -20,
                      top: 40, // Moved down slightly
                      child: Icon(
                        Icons.people,
                        size: 140,
                        color: SecondaryConstants.kPrimaryGreen.withOpacity(0.05),
                      ),
                    ),

                    // 3. SEARCH BAR ANCHORED TO BOTTOM
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16, // Fixed to bottom edge
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Text(
                              "Search member...",
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: SecondaryConstants.kPrimaryGreen),
                    onPressed: _fetchUsers,
                    tooltip: 'Refresh List',
                  ),
                ),
              ],
            ),
          ],
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: SecondaryConstants.kPrimaryGreen))
              : RefreshIndicator(
            color: SecondaryConstants.kPrimaryGreen,
            onRefresh: _fetchUsers,
            child: _users.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Added top padding
              itemCount: _users.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + (index * 50)),
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
                    onAssignRole: () => _showRoleDialog(_users[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SecondaryConstants.kPrimaryGreen.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            "No team members found",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try pulling down to refresh the list.",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}