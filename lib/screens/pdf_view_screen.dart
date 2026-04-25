import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/snackbar_utils.dart';

class PDFViewScreen extends StatefulWidget {
  @override
  _PDFViewScreenState createState() => _PDFViewScreenState();
}

class _PDFViewScreenState extends State<PDFViewScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localPath == null) {
      _fetchPDF();
    }
  }

  Future<void> _fetchPDF() async {
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final generator = args['generator'];
    final visitIndex = args['visitIndex']; // 1, 2, 3, 4

    try {
      final prefs = await SharedPreferences.getInstance();
      final engineerId = prefs.getInt('engineer_id');

      final userRole = prefs.getString('name')?.toLowerCase();
      String url = "";
      bool isGet = false;

      if (userRole == "mobilization") {
        url = "https://jkgenerator.com/public/api/mobilization/pdf?asset_number=${generator['asset_number']}";
        isGet = true;
      } else if (userRole == "demobilization" || userRole == "DeMobilization") {
        url = "https://jkgenerator.com/public/api/Demobilization/pdf?asset_number=${generator['asset_number']}";
        isGet = true;
      } else {
        String endpoint = "";
        if (visitIndex == 1) endpoint = "visitone/download";
        else if (visitIndex == 2) endpoint = "visittwo/download";
        else if (visitIndex == 3) endpoint = "visitthree/download";
        else if (visitIndex == 4) endpoint = "visitfour/download";
        url = "https://jkgenerator.com/api/$endpoint";
      }

      http.Response response;
      if (isGet) {
        response = await http.get(Uri.parse(url));
      } else {
        response = await http.post(
          Uri.parse(url),
          body: {
            "engineer_id": engineerId?.toString() ?? "",
            "asset_number": generator['asset_number'] ?? "",
            "status": "0",
          },
        );
      }

      debugPrint("PDF API Response ($url): ${response.statusCode}");

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final path = "${directory.path}/temp_report_${visitIndex}.pdf";
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          _localPath = path;
          _isLoading = false;
        });
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Visit not added"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading report"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadPDF() async {
    if (_localPath == null) return;

    try {
      String path = "";
      if (Platform.isAndroid) {
        path = "/storage/emulated/0/Download/report_${DateTime.now().millisecondsSinceEpoch}.pdf";
      } else {
        final directory = await getExternalStorageDirectory();
        path = "${directory!.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf";
      }
      
      final sourceFile = File(_localPath!);
      await sourceFile.copy(path);

      SnackbarUtils.showProfessionalSnackbar(context, "PDF saved to Downloads");
    } catch (e) {
      // Fallback if public download folder is restricted
      try {
        final directory = await getExternalStorageDirectory();
        final path = "${directory!.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf";
        final sourceFile = File(_localPath!);
        await sourceFile.copy(path);
        SnackbarUtils.showProfessionalSnackbar(context, "PDF saved to Downloads");
      } catch (e2) {
        SnackbarUtils.showProfessionalSnackbar(context, "Download failed: $e2");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PDF Download", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF3F00B5),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_localPath != null)
            IconButton(
              icon: Icon(Icons.download),
              onPressed: _downloadPDF,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _localPath != null
              ? PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: false,
                  pageFling: false,
                )
              : Center(child: Text("Unable to display PDF")),
    );
  }
}
