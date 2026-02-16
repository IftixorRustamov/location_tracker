import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/features/admin/screens/admin_dashboard_screen.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_event.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';
import 'package:location_tracker/features/tracking/screens/history_screen.dart';
import 'package:location_tracker/features/tracking/widgets/change_password_sheet.dart'; // Verify this import path matches your project

class ProfileSheet extends StatelessWidget {
  final String? username;

  const ProfileSheet({super.key, required this.username});

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for the password sheet to avoid keyboard overlap
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    bool isAdmin = false;

    if (state is Authenticated) {
      isAdmin = state.role == 'ADMIN' || state.role == 'ROLE_ADMIN';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // 1. FIX: Added SingleChildScrollView to prevent overflow
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // User Header
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Text(
                  (username?.isNotEmpty == true) ? username![0].toUpperCase() : "U",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                username ?? "User",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.blue[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAdmin
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isAdmin ? "Administrator" : "Driver Account",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAdmin ? Colors.blue[700] : Colors.green[700],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- MENU ---

              // 1. Trip History
              _buildMenuOption(
                icon: Icons.history_rounded,
                title: "Trip History",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
              ),

              // 2. Admin Dashboard (Conditional)
              if (isAdmin)
                _buildMenuOption(
                  icon: Icons.admin_panel_settings_rounded,
                  title: "Fleet Dashboard",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminDashboardScreen()),
                    );
                  },
                ),

              // 3. Change Password
              _buildMenuOption(
                icon: Icons.lock_outline_rounded,
                title: "Change Password",
                onTap: () {
                  Navigator.pop(context); // Close profile sheet first
                  _showChangePassword(context); // Open password sheet
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 32),
              ),

              // 4. Logout
              _buildMenuOption(
                icon: Icons.logout_rounded,
                title: "Log Out",
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  context.read<AuthBloc>().add(LogoutRequested());
                },
              ),

              // Version Info
              const SizedBox(height: 24),
              Text(
                "Version 1.0.0",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red[50] : const Color(0xFFF5F5F5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.redAccent : Colors.black87,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.redAccent : Colors.black87,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.grey[400], size: 24),
      onTap: onTap,
    );
  }
}