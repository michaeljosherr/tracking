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
  static const String _userStorageKey = 'tracker_user';
  static final User _defaultUser = User(
    id: 'local-ops',
    name: 'Operations Team',
    email: 'local@tracker.app',
    role: 'local',
  );

  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_userStorageKey);
      if (userStr != null) {
        _user = User.fromJson(jsonDecode(userStr));
      } else {
        _user = _defaultUser;
        await _persistUser(_defaultUser);
      }
    } catch (e) {
      debugPrint('Error loading local session: $e');
      _user = _defaultUser;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userStorageKey, jsonEncode(user.toJson()));
  }

  Future<void> setUser(User user) async {
    _user = user;
    await _persistUser(user);
    notifyListeners();
  }

  Future<void> resetLocalSession() async {
    await setUser(_defaultUser);
  }

  Future<void> clearSession() async {
    try {
      _user = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userStorageKey);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing local session: $e');
    }
  }
}
