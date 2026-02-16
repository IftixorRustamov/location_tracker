import 'package:flutter/material.dart';

abstract class SecondaryConstants {
  // Assets
  static const String userArrow = 'assets/user_arrow.png';
  static const String carIcon = 'assets/car_icon.png'; // Add this

  static const String accessToken = 'accessToken';
  static const String refreshToken = 'refreshToken';
  static const String userRole = 'userRole';
  static const String username = 'username';

  // Colors
  static const Color kPrimaryGreen = Color(0xFF4CAF50);
  static const Color kBackgroundStart = Color(0xFFF0F4F8);
  static const Color kBackgroundEnd = Color(0xFFE8F5E9);

  // UI Colors
  static const Color kWhite = Colors.white;
  static const Color kBlackText = Colors.black87;
  static const Color kGreyText = Colors.grey;
  static const Color kShadow = Color(0x0D000000); // Black with 5% opacity
}