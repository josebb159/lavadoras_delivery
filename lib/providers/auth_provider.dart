import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../core/constants.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  int _driverStatus = 0;
  int get driverStatus => _driverStatus;

  Future<void> checkDriverStatus() async {
    if (_user == null) return;
    try {
      final userIdInt = int.tryParse(_user!.id) ?? 0;
      if (userIdInt == 0) return;

      final response = await _apiService.getStatusDriver(userIdInt);
      if (response['status'] == 'ok') {
        _driverStatus = response['activo'];
        notifyListeners();
      }
    } catch (e) {
      print('Error getting driver status: $e');
    }
  }

  Future<bool> toggleDriverStatus(bool isActive) async {
    if (_user == null) return false;
    final newStatus = isActive ? 1 : 0;

    // Optimistic update
    final oldStatus = _driverStatus;
    _driverStatus = newStatus;
    notifyListeners();

    try {
      final userIdInt = int.tryParse(_user!.id) ?? 0;
      if (userIdInt == 0) {
        _driverStatus = oldStatus;
        notifyListeners();
        return false;
      }

      final response = await _apiService.changeStatus(userIdInt, newStatus);
      if (response['status'] == 'ok') {
        return true;
      } else {
        // Revert on failure
        _driverStatus = oldStatus;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error toggling driver status: $e');
      _driverStatus = oldStatus;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    if (userData != null) {
      _user = User.fromJson(json.decode(userData));
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = {'correo': email.trim(), 'contrasena': password.trim()};

      final response = await _apiService.post(AppConstants.actionLogin, data);

      if (response['status'] == 'ok') {
        _user = User.fromJson(response['user']);
        await _saveUserToPrefs(_user!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth
          .GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final firebase_auth.UserCredential authResult = await firebase_auth
          .FirebaseAuth
          .instance
          .signInWithCredential(credential);

      final firebaseUser = authResult.user;
      if (firebaseUser == null) {
        throw Exception('Firebase auth failed');
      }

      // Verify with backend
      final data = {'correo': firebaseUser.email};
      final response = await _apiService.post(
        AppConstants.actionLoginGoogle,
        data,
      );

      if (response['status'] == 'ok') {
        _user = User.fromJson(response['user']);
        await _saveUserToPrefs(_user!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Handle registration needed case if applicable, for now just return false or throw
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Google Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await firebase_auth.FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    _user = null;
    notifyListeners();
  }

  Future<void> _saveUserToPrefs(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(user.toJson()));
  }
}
