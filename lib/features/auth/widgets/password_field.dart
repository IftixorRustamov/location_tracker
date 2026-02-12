import 'package:flutter/material.dart';

class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggle;
  final String label;
  final String? Function(String?)? validator;
  final Function(String)? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    required this.obscureText,
    required this.onToggle,
    this.label = 'Password',
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: onSubmitted != null
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,

        filled: true,
        fillColor: Colors.grey[100],

        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4CAF50)),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator:
          validator ??
          (val) {
            if (val == null || val.isEmpty) return 'Please enter a password';
            if (val.length < 5) return 'Min 5 characters';
            return null;
          },
    );
  }
}
