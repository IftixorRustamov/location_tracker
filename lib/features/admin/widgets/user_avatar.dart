import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final bool isAdmin;

  const UserAvatar({super.key, required this.name, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final String initials = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isAdmin ? Colors.red[50] : Colors.blue[50],
        shape: BoxShape.circle,
        border: Border.all(
          color: isAdmin
              ? Colors.red.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isAdmin ? Colors.red : Colors.blue,
          ),
        ),
      ),
    );
  }
}
