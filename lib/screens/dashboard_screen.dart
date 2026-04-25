import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/snackbar_utils.dart';
import '../controllers/dashboard_controller.dart';
import '../routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardController controller = DashboardController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await controller.fetchData(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.menu, color: Colors.grey[700]),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            controller.filterSearchResults(value);
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search",
                          prefixIcon: Icon(Icons.search, color: Colors.black54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: controller.isLoading
                  ? Center(child: CircularProgressIndicator())
                  : controller.filteredGenerators.isEmpty
                      ? Center(child: Text("No data found"))
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: controller.filteredGenerators.length,
                          itemBuilder: (context, index) {
                            final item = controller.filteredGenerators[index];
                            return _buildGeneratorCard(index + 1, item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratorCard(int index, dynamic item) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.serviceReport,
          arguments: {
            'generator': item,
            'visitIndex': 1, // Defaulting to Visit 1
          },
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFBAD3F8),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$index",
              style: TextStyle(fontSize: 12, color: Color(0xFF6C8DBE), fontWeight: FontWeight.bold),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(4),
                  child: Image.asset("assets/images/logo.png", fit: BoxFit.contain),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow("Asset Number", item['asset_number'] ?? ""),
                      _buildInfoRow("Customer Name", item['client_name'] ?? item['customer_name'] ?? ""),
                      _buildInfoRow("Open Date", (item['open_date'] ?? item['created_at'] ?? "").split('T')[0]),
                      SizedBox(height: 8),
                      if (controller.userName.toLowerCase() != "mobilization" && 
                          controller.userName.toLowerCase() != "demobilization")
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildVisitButton("Visit-1", 1, item),
                              _buildVisitButton("Visit-2", 2, item),
                              _buildVisitButton("Visit-3", 3, item),
                              _buildVisitButton("Visit-4", 4, item),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 100, // Fixed width for labels to align values
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[800]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[900]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitButton(String label, int visitIndex, dynamic item) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.pdfDownload,
          arguments: {
            'generator': item,
            'visitIndex': visitIndex,
          },
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(horizontal: 8),
        height: 28,
        decoration: BoxDecoration(
          color: Color(0xFF009BDB), // Bright cyan from screenshot
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: 50, bottom: 20),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white),
            child: Column(
              children: [
                Image.asset("assets/images/logo.png", height: 80),
                SizedBox(height: 30),
                Text(
                  controller.userName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  controller.userEmail,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.home, color: Colors.black87),
            title: Text("Home", style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.share, color: Colors.black87),
            title: Text("Share", style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              Share.share("https://play.google.com/store/apps/details?id=com.pojo.jkgenerator");
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.black87),
            title: Text("Logout", style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              SnackbarUtils.showProfessionalSnackbar(context, "Logged out successfully");
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}
