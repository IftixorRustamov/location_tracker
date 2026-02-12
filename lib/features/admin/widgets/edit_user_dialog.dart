import 'package:flutter/material.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';

class EditUserDialog extends StatelessWidget {
  final AdminUser user;
  final Function(String, String) onSave;

  const EditUserDialog({super.key, required this.user, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = TextEditingController(text: user.name);
    final userCtrl = TextEditingController(text: user.username);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Edit Team Member"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: "Full Name",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: userCtrl,
            decoration: InputDecoration(
              labelText: "Username",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.alternate_email),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            Navigator.pop(context);
            onSave(nameCtrl.text, userCtrl.text);
          },
          child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

