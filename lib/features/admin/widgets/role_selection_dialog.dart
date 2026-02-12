import 'package:flutter/material.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';

class RoleSelectionDialog extends StatelessWidget {
  final AdminUser user;
  final List<AdminRole> roles;
  final Function(int) onRoleSelected;

  const RoleSelectionDialog({
    super.key,
    required this.user,
    required this.roles,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          const Icon(Icons.security, size: 32, color: Colors.orange),
          const SizedBox(height: 8),
          Text(
            "Assign Role to ${user.name.split(' ')[0]}",
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: roles.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (ctx, index) {
            final role = roles[index];
            final bool isSelected = user.roleNames.contains(role.name);
            return ListTile(
              title: Text(
                role.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: Icon(
                Icons.check_circle,
                color: isSelected ? Colors.green : Colors.grey[300],
              ),
              onTap: () {
                Navigator.pop(ctx);
                onRoleSelected(role.id);
              },
            );
          },
        ),
      ),
    );
  }
}
