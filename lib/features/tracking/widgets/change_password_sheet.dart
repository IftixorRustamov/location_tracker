import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_event.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';
import 'package:location_tracker/features/auth/widgets/login_button.dart';
import 'package:location_tracker/features/auth/widgets/password_field.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        ChangePasswordRequested(
          oldPassword: _oldController.text,
          newPassword: _newController.text,
          confirmPassword: _confirmController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get keyboard height
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is ChangePasswordSuccess) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated! Please log in again.'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        // 2. Add padding for keyboard here
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SingleChildScrollView(
          // 3. This ensures the content scrolls when keyboard opens
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 32,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Text
                  const Text(
                    "Secure Your Account",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create a strong password to keep your\naccount safe and secure.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Fields
                  _buildFieldSection(
                    controller: _oldController,
                    label: "Current Password",
                    obscure: _obscureOld,
                    onToggle: () => setState(() => _obscureOld = !_obscureOld),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldSection(
                    controller: _newController,
                    label: "New Password",
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                    validator: (val) {
                      if (val == null || val.length < 6) return 'Min 6 characters';
                      if (val == _oldController.text) return 'Cannot match old';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFieldSection(
                    controller: _confirmController,
                    label: "Confirm Password",
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (val) => val != _newController.text
                        ? 'Passwords do not match'
                        : null,
                    isLast: true,
                    onSubmitted: (_) => _submit(),
                  ),

                  const SizedBox(height: 32),

                  // Button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return LoginButton(
                        text: "Update Password",
                        isLoading: state is AuthLoading,
                        onPressed: _submit,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSection({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    bool isLast = false,
    Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        PasswordField(
          controller: controller,
          label: "Enter $label",
          obscureText: obscure,
          onToggle: onToggle,
          validator: validator,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}