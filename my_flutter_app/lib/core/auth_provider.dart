import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String role; // "supervisor" | "guide"

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: json['role'],
      );
}

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  // Mock users for demonstration
  static const List<Map<String, String>> mockUsers = [
    {
      "id": "1",
      "name": "John Supervisor",
      "email": "supervisor@tracker.com",
      "password": "password123",
      "role": "supervisor",
    },
    {
      "id": "2",
      "name": "Maria Guide",
      "email": "guide@tracker.com",
      "password": "password123",
      "role": "guide",
    },
  ];

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('tracker_user');
      if (userStr != null) {
        _user = User.fromJson(jsonDecode(userStr));
      }
    } catch (e) {
      print('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final foundUser = mockUsers.firstWhere(
        (u) => u['email'] == email && u['password'] == password,
        orElse: () => {},
      );

      if (foundUser.isNotEmpty) {
        final user = User(
          id: foundUser['id']!,
          name: foundUser['name']!,
          email: foundUser['email']!,
          role: foundUser['role']!,
        );

        _user = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tracker_user', jsonEncode(user.toJson()));
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Login error: $e');
    }

    return false;
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracker_user');
    notifyListeners();
  }
}
