import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_event.dart';
import 'package:location_tracker/features/tracking/widgets/change_password_sheet.dart';

class ProfileSheet extends StatelessWidget {
  final String? username;

  const ProfileSheet({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
            child: Text(
              username?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
            ),
          ),
          const SizedBox(height: 16),
          Text(username ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Online', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),

          _buildActionItem(
            icon: Icons.lock_outline,
            color: Colors.blue,
            text: 'Change Password',
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const ChangePasswordSheet());
            },
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            icon: Icons.logout_rounded,
            color: Colors.red,
            text: 'Logout',
            onTap: () {
              final authBloc = context.read<AuthBloc>();
              Navigator.pop(context);
              _showLogoutDialog(context, authBloc);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionItem({required IconData icon, required Color color, required String text, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: color == Colors.red ? Colors.red : Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, AuthBloc authBloc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              authBloc.add(LogoutRequested());
              Navigator.pop(ctx);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}