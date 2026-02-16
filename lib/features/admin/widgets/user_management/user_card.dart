import 'package:flutter/material.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';
import 'package:location_tracker/features/admin/widgets/role_badge.dart';
import 'package:location_tracker/features/admin/widgets/user_avatar.dart';

class UserCard extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onEdit;
  final VoidCallback onAssignRole;
  final VoidCallback onDelete;

  const UserCard({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onAssignRole,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdmin =
        user.roleNames.contains('ADMIN') ||
        user.roleNames.contains('ROLE_ADMIN');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1. Avatar
                UserAvatar(name: user.name, isAdmin: isAdmin),
                const SizedBox(width: 16),

                // 2. Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "@${user.username}",
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      // Roles
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: user.roleNames.isEmpty
                            ? [
                                const RoleBadge(
                                  label: "User",
                                  color: Colors.blueGrey,
                                ),
                              ]
                            : user.roleNames.map((role) {
                                Color color = Colors.blue;
                                if (role.contains("ADMIN")) {
                                  color = Colors.redAccent;
                                }
                                if (role.contains("MANAGER")) {
                                  color = Colors.orange;
                                }
                                return RoleBadge(label: role, color: color);
                              }).toList(),
                      ),
                    ],
                  ),
                ),

                // 3. Actions
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'role') onAssignRole();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    _buildPopupItem('edit', Icons.edit, "Edit Details"),
                    _buildPopupItem('role', Icons.security, "Manage Roles"),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                          const SizedBox(width: 12),
                          const Text("Delete User", style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String text,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}
