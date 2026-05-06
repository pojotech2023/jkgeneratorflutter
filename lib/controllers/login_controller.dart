import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/snackbar_utils.dart';
import '../base_url.dart';

class LoginController {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  Future<bool> login(BuildContext context) async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      SnackbarUtils.showProfessionalSnackbar(context, "Please enter all fields");
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse("$baseApiUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['User'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('id', data['User']['id']);
          await prefs.setString('name', data['User']['name']);
          await prefs.setString('email', data['User']['email']);
          await prefs.setInt('engineer_id', data['User']['engineer_id'] ?? 0);
          
          SnackbarUtils.showProfessionalSnackbar(context, "Welcome back, ${data['User']['name']}");
          return true;
        } else {
          SnackbarUtils.showProfessionalSnackbar(context, "Login failed: User data not found");
          return false;
        }
      } else {
        SnackbarUtils.showProfessionalSnackbar(context, "Login failed: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      SnackbarUtils.showProfessionalSnackbar(context, "Error: $e");
      return false;
    }
  }
}