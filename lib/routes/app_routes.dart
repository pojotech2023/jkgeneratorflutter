import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/service_report_screen.dart';
import '../screens/pdf_view_screen.dart';

class AppRoutes {

  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String serviceReport = '/service_report';
  static const String pdfDownload = '/pdf_download';

  static Map<String, WidgetBuilder> routes = {
    splash: (context) => SplashScreen(),
    login: (context) => LoginScreen(),
    dashboard: (context) => DashboardScreen(),
    serviceReport: (context) => ServiceReportScreen(),
    pdfDownload: (context) => PDFViewScreen(),
  };
}