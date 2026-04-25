import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardController {
  List<dynamic> generators = [];
  List<dynamic> filteredGenerators = [];
  bool isLoading = true;
  String userName = "";
  String userEmail = "";

  Future<void> fetchData(BuildContext context) async {
    isLoading = true;
    final prefs = await SharedPreferences.getInstance();
    int? engineerId = prefs.getInt('engineer_id');
    userName = prefs.getString('name') ?? "";
    userEmail = prefs.getString('email') ?? "";

    if (engineerId == null) {
      isLoading = false;
      return;
    }

    try {
      String endpoint = "";
      bool isGet = false;
      if (userName.toLowerCase() == "mobilization") {
        endpoint = "mobilization/view";
        isGet = true;
      } else if (userName.toLowerCase() == "demobilization") {
        endpoint = "demobilization/view";
        isGet = true;
      } else {
        endpoint = "engineer";
      }

      http.Response response;
      if (isGet) {
        response = await http.get(Uri.parse("https://jkgenerator.com/api/$endpoint"));
      } else {
        response = await http.post(
          Uri.parse("https://jkgenerator.com/api/$endpoint"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"engineer_id": engineerId.toString()}),
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        generators = data['AssignGenerators'] ?? [];
        filteredGenerators = List.from(generators);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch data: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      isLoading = false;
    }
  }

  void filterSearchResults(String query) {
    if (query.isEmpty) {
      filteredGenerators = List.from(generators);
    } else {
      filteredGenerators = generators
          .where((item) => (item['asset_number'] ?? "")
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    }
  }
}
