import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_helper.dart';

class AuthService with ChangeNotifier {
  bool _isAuthenticated = false;
  int? _userId;

  bool get isAuthenticated => _isAuthenticated;
  int? get userId => _userId;

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isLoggedIn') ?? false;
    _userId = prefs.getInt('userId');
    notifyListeners();
  }

  Future<String?> register(String username, String email, String password) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Check if email already exists
      final maps = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );

      if (maps.isNotEmpty) {
        return 'Email already registered';
      }

      final user = User(
        username: username,
        email: email,
        password: password,
      );

      await db.insert('users', user.toMap());
      return null; // Success
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      final maps = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      if (maps.isNotEmpty) {
        final user = User.fromMap(maps.first);
        _isAuthenticated = true;
        _userId = user.id;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('userId', user.id!);

        notifyListeners();
        return null; // Success
      } else {
        return 'Invalid email or password';
      }
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
