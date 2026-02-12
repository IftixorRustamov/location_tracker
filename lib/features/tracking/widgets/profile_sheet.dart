import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/features/admin/screens/admin_dashboard_screen.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_event.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart'; // Import AuthState
import 'package:location_tracker/features/tracking/screens/history_screen.dart';

class ProfileSheet extends StatelessWidget {
  final String? username;

  const ProfileSheet({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    // 1. Get the current Auth State
    final state = context.read<AuthBloc>().state;

    // 2. Determine if user is Admin
    bool isAdmin = false;
    if (state is Authenticated) {
      // Check the role we saved in AuthBloc (adjust 'ADMIN' if your backend uses 'ROLE_ADMIN')
      isAdmin = state.role == 'ADMIN' || state.role == 'ROLE_ADMIN';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Drag Handle ---
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // --- User Info ---
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(Icons.person, size: 30, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 16),
          Text(
            username ?? "User",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            isAdmin ? "Admin Account" : "Driver Account", // Show role badge
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // --- MENU OPTIONS ---

          // 1. Trip History (For everyone)
          _buildMenuOption(
            icon: Icons.history,
            title: "Trip History",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),

          // 2. Fleet Dashboard (ONLY FOR ADMINS)
          if (isAdmin)
            _buildMenuOption(
              icon: Icons.admin_panel_settings,
              title: "Fleet Dashboard",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                );
              },
            ),


          const Divider(height: 32),

          // 4. Logout
          _buildMenuOption(
            icon: Icons.logout,
            title: "Log Out",
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),

          const SizedBox(height: 20),
        ],
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
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red[50] : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.black87,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}