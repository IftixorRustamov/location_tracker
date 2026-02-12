import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class AdminApiService {
  final String baseUrl;
  final String? token;

  AdminApiService({required this.baseUrl, this.token});

  // --- HEADERS ---
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // --- HELPER: Handle API Response ---
  dynamic _handleResponse(http.Response response, String endpoint) {
    debugPrint("🌐 API [$endpoint] Status: ${response.statusCode}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      debugPrint("📦 API [$endpoint] Raw Data: $json");

      // FIX: Unwrap 'data' if it exists
      if (json is Map<String, dynamic> && json.containsKey('data')) {
        return json['data'];
      }
      return json;
    } else {
      debugPrint("❌ API [$endpoint] Error: ${response.body}");
      return null;
    }
  }

  // ==========================================
  // 1. DASHBOARD & SESSIONS
  // ==========================================

  /// GET SESSIONS LIST (Paginated)
  Future<AdminSessionResponse?> getSessions({
    required DateTime date,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final String dateStr = DateFormat('yyyy-MM-dd').format(date);
      final uri = Uri.parse('$baseUrl/api/v1/sessions/admin').replace(queryParameters: {
        'date': dateStr,
        'page': page.toString(),
        'size': size.toString(),
      });

      final response = await http.get(uri, headers: _headers);
      final data = _handleResponse(response, "Get Sessions");

      if (data != null) {
        return AdminSessionResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint("🔥 Exception (Get Sessions): $e");
    }
    return null;
  }

  /// GET LIVE DATA FOR ONE SESSION
  Future<Map<String, dynamic>?> getLiveSessionData(String sessionId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/sessions/admin/live').replace(queryParameters: {
        'sessionId': sessionId,
      });

      final response = await http.get(uri, headers: _headers);
      final data = _handleResponse(response, "Live Data");

      return data as Map<String, dynamic>?;
    } catch (e) {
      debugPrint("🔥 Exception (Live Data): $e");
    }
    return null;
  }

  // ==========================================
  // 2. USER MANAGEMENT
  // ==========================================

  /// GET ALL USERS
  Future<AdminUserResponse?> getUsers({int page = 0, int size = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/users/all').replace(queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      });

      final response = await http.get(uri, headers: _headers);
      final data = _handleResponse(response, "Get Users");

      if (data != null) {
        return AdminUserResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint("🔥 Exception (Get Users): $e");
    }
    return null;
  }

  /// UPDATE USER
  Future<bool> updateUser(int userId, String name, String username) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/$userId/update'),
        headers: _headers,
        body: jsonEncode({
          "name": name,
          "username": username,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// GET ROLES
  Future<List<AdminRole>> getRoles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/roles/all'), headers: _headers);
      final data = _handleResponse(response, "Get Roles");

      if (data != null) {
        // If data is wrapped in pagination (content: []), extract it
        if (data is Map && data.containsKey('content')) {
          return (data['content'] as List).map((e) => AdminRole.fromJson(e)).toList();
        } else if (data is List) {
          return data.map((e) => AdminRole.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint("🔥 Exception (Get Roles): $e");
    }
    return [];
  }

  /// ASSIGN ROLE
  Future<bool> assignRoleToUser(int userId, int roleId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/add-role-to-user'),
        headers: _headers,
        body: jsonEncode({
          "userId": userId,
          "roleIds": [roleId]
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}

// ==========================================
// MODELS (Updated to match your API)
// ==========================================

class AdminSessionResponse {
  final List<AdminSession> content;
  final int totalPages;

  AdminSessionResponse({required this.content, required this.totalPages});

  factory AdminSessionResponse.fromJson(Map<String, dynamic> json) {
    return AdminSessionResponse(
      content: (json['content'] as List?)
          ?.map((e) => AdminSession.fromJson(e))
          .toList() ?? [],
      totalPages: json['totalPages'] ?? 0,
    );
  }
}

class AdminSession {
  final String id;
  final String name;

  AdminSession({required this.id, required this.name});

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Session',
    );
  }
}

class AdminUserResponse {
  final List<AdminUser> content;
  final int totalPages;

  AdminUserResponse({required this.content, required this.totalPages});

  factory AdminUserResponse.fromJson(Map<String, dynamic> json) {
    return AdminUserResponse(
      content: (json['content'] as List?)
          ?.map((e) => AdminUser.fromJson(e))
          .toList() ?? [],
      totalPages: json['totalPages'] ?? 0,
    );
  }
}

class AdminUser {
  final int id;
  final String name;
  final String username;
  final List<String> roleNames;

  AdminUser({required this.id, required this.name, required this.username, required this.roleNames});

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    List<String> roles = [];
    // Helper to find roles whether they are objects or strings
    if (json['roles'] != null && json['roles'] is List) {
      roles = (json['roles'] as List).map((r) {
        if (r is Map) return r['name'].toString();
        return r.toString();
      }).toList();
    }

    return AdminUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'No Name',
      username: json['username'] ?? 'No Username',
      roleNames: roles,
    );
  }
}

class AdminRole {
  final int id;
  final String name;

  AdminRole({required this.id, required this.name});

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    return AdminRole(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
    );
  }
}