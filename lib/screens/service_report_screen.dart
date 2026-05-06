import 'package:flutter/material.dart';
import '../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../base_url.dart';

class ServiceReportScreen extends StatefulWidget {
  @override
  _ServiceReportScreenState createState() => _ServiceReportScreenState();
}

class _ServiceReportScreenState extends State<ServiceReportScreen> {
  final SignatureController _customerSignatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final SignatureController _engineerSignatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  String? selectedVisit;
  String? selectedPurpose;
  DateTime selectedDate = DateTime.now();
  TimeOfDay inTime = TimeOfDay.now();
  TimeOfDay outTime = TimeOfDay.now();
  DateTime selectedOSDate = DateTime.now();

  final List<String> dropdownOptions = ['Good', 'Bad', 'Normal', 'Need Top Up'];
  Map<String, String?> dropdownValues = {
    'Engine Oil Level': null,
    'Battery Water Level': null,
    'Radiator Water Level': null,
    'Diesel Filter': null,
    'Air Filter': null,
    'Engine Fan Belt': null,
    'Engine Noise': null,
    'Water Pump and Hoses': null,
    'DG Maintenance Site': null,
  };

  // Image storage
  final List<XFile?> _selectedImages = List.generate(7, (_) => null);
  final ImagePicker _picker = ImagePicker();

  // Controllers for text fields
  final Map<String, TextEditingController> _controllers = {
    'Address': TextEditingController(),
    'Spared Replaced': TextEditingController(),
    'Current Hour Meter': TextEditingController(),
    'HR Remarks': TextEditingController(),
    'R': TextEditingController(),
    'Y': TextEditingController(),
    'B': TextEditingController(),
    'Load Current Remarks': TextEditingController(),
    'Last OS Hour': TextEditingController(),
    'Engineer Remarks': TextEditingController(),
    'Customer Remarks': TextEditingController(),
     'Customer Name': TextEditingController(),
    'Customer Number': TextEditingController(),
    'Engineer Name': TextEditingController(),
  };

  bool _isSubmitting = false;
  String? userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString('name')?.toLowerCase();
    });
  }

  @override
  void dispose() {
    _customerSignatureController.dispose();
    _engineerSignatureController.dispose();
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _pickImage(int index) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Gallery'),
              onTap: () async {
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) setState(() => _selectedImages[index] = image);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Camera'),
              onTap: () async {
                final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                if (image != null) setState(() => _selectedImages[index] = image);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _submitForm(Map<String, dynamic>? generator) async {
    if (selectedVisit == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please select a Visit type")));
      return;
    }
    
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final engineerId = prefs.getInt('engineer_id');

      String url = "";
      if (selectedVisit == 'Visit 1') url = "$baseApiUrl/visitone/all";
      else if (selectedVisit == 'Visit 2') url = "$baseApiUrl/visittwo/all";
      else if (selectedVisit == 'Visit 3') url = "$baseApiUrl/visitthree/all";
      else if (selectedVisit == 'Visit 4') url = "$baseApiUrl/visitfour/all";
      else if (selectedVisit == 'Mobilization') url = "$basePublicApiUrl/mobilization/pdf_form";
      else if (selectedVisit == 'Demobilization') url = "$basePublicApiUrl/Demobilization/pdf_form";

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add text fields with exact keys from API
      request.fields['engineer_name'] = _controllers['Engineer Name']?.text ?? "";
      request.fields['date'] = DateFormat('dd-MM-yyyy').format(selectedDate);
      request.fields['intime'] = _formatTime(inTime);
      request.fields['outtime'] = _formatTime(outTime);
      String assetNumber = (generator?['asset_number'] ?? "").toString().trim();
      if (assetNumber.isEmpty) {
        SnackbarUtils.showProfessionalSnackbar(context, "Error: Asset Number is missing. Cannot submit.");
        setState(() => _isSubmitting = false);
        return;
      }

      request.fields['asset_number'] = assetNumber;
      request.fields['engineer_id'] = engineerId?.toString() ?? "";
      
      // Additional identifiers to help backend find the record (only for Visit 1-4)
      if (selectedVisit != 'Mobilization' && selectedVisit != 'Demobilization') {
        if (generator != null) {
          if (generator['id'] != null) {
            request.fields['id'] = generator['id'].toString();
          }
          if (generator['generator_id'] != null) {
            request.fields['generator_id'] = generator['generator_id'].toString();
          }
        }
      }
      
      String clientName = _controllers['Customer Name']?.text ?? "";
      if (clientName.isEmpty) {
        clientName = generator?['client_name'] ?? generator?['customer_name'] ?? "";
      }

      if (selectedVisit == 'Demobilization' || selectedVisit == 'Mobilization') {
        // Both Mobilization and Demobilization require most fields
        request.fields['date'] = DateFormat('dd-MM-yyyy').format(selectedDate);
        request.fields['intime'] = _formatTime(inTime);
        request.fields['outtime'] = _formatTime(outTime);
        request.fields['asset_number'] = assetNumber;
        request.fields['client_name'] = clientName.trim();
        request.fields['customer_name'] = clientName.trim(); // Required by some endpoints
        request.fields['customer_number'] = _controllers['Customer Number']?.text ?? "";
        
        request.fields['range'] = (generator?['dg_range'] ?? generator?['range'] ?? "").toString();
        request.fields['engine_make'] = generator?['engine_make'] ?? "";
        request.fields['engine_serial_no'] = (generator?['engine_srno'] ?? generator?['engine_serial_no'] ?? "").toString();
        request.fields['alternator_make'] = generator?['alternator_make'] ?? "";
        request.fields['alternator_serial_no'] = generator?['alternator_srno'] ?? generator?['alternator_serial_no'] ?? "";
        request.fields['battery_make'] = generator?['battery_make'] ?? "";
        request.fields['battery_serial_no'] = generator?['battery_srno'] ?? generator?['battery_serial_no'] ?? "";
        
        request.fields['address'] = _controllers['Address']?.text ?? "";
        request.fields['spared_replaced'] = _controllers['Spared Replaced']?.text ?? "";
        request.fields['current_hour_meter'] = _controllers['Current Hour Meter']?.text ?? "";
        request.fields['hr_remarks'] = _controllers['HR Remarks']?.text ?? "";
        request.fields['load_current_r'] = _controllers['R']?.text ?? "";
        request.fields['load_current_y'] = _controllers['Y']?.text ?? "";
        request.fields['load_current_b'] = _controllers['B']?.text ?? "";
        request.fields['load_current_remarks'] = _controllers['Load Current Remarks']?.text ?? "";
        request.fields['last_os_hour'] = _controllers['Last OS Hour']?.text ?? "";
        request.fields['engineer_remarks'] = _controllers['Engineer Remarks']?.text ?? "";
        request.fields['customer_remarks'] = _controllers['Customer Remarks']?.text ?? "";
        request.fields['os_date'] = DateFormat('dd-MM-yyyy').format(selectedOSDate);

        // Required maintenance dropdowns
        request.fields['engine_oil_level'] = dropdownValues['Engine Oil Level'] ?? "Good";
        request.fields['battery_water_level'] = dropdownValues['Battery Water Level'] ?? "Good";
        request.fields['ratiator_water_level'] = dropdownValues['Radiator Water Level'] ?? "Good";
        request.fields['diesel_filter'] = dropdownValues['Diesel Filter'] ?? "Good";
        request.fields['air_filter'] = dropdownValues['Air Filter'] ?? "Good";
        request.fields['engine_fan_belt'] = dropdownValues['Engine Fan Belt'] ?? "Good";
        request.fields['engine_noise'] = dropdownValues['Engine Noise'] ?? "Good";
        request.fields['water_pumb&hoses'] = dropdownValues['Water Pump and Hoses'] ?? "Good";
        request.fields['dg_maintenece'] = dropdownValues['DG Maintenance Site'] ?? "Good";

        if (engineerId != null) request.fields['engineer_id'] = engineerId.toString();
        
      } else {
        // Standard mapping for Visit 1-4
        request.fields['engineer_name'] = _controllers['Engineer Name']?.text ?? "";
        request.fields['date'] = DateFormat('dd-MM-yyyy').format(selectedDate);
        request.fields['intime'] = _formatTime(inTime);
        request.fields['outtime'] = _formatTime(outTime);
        request.fields['asset_number'] = assetNumber;
        request.fields['purpose_visit'] = selectedPurpose ?? "";
        request.fields['engineer_id'] = engineerId?.toString() ?? "";
        request.fields['client_name'] = clientName.trim();
        request.fields['customer_name'] = clientName.trim();
        request.fields['customer_number'] = _controllers['Customer Number']?.text ?? "";
        request.fields['range'] = generator?['dg_range'] ?? generator?['range'] ?? "";
        request.fields['engine_make'] = generator?['engine_make'] ?? "";
        request.fields['engine_serial_no'] = generator?['engine_srno'] ?? generator?['engine_serial_no'] ?? "";
        request.fields['alternator_make'] = generator?['alternator_make'] ?? "";
        request.fields['alternator_serial_no'] = generator?['alternator_srno'] ?? generator?['alternator_serial_no'] ?? "";
        request.fields['battery_make'] = generator?['battery_make'] ?? "";
        request.fields['battery_serial_no'] = generator?['battery_srno'] ?? generator?['battery_serial_no'] ?? "";
        request.fields['address'] = _controllers['Address']?.text ?? "";
        request.fields['spared_replaced'] = _controllers['Spared Replaced']?.text ?? "";
        request.fields['current_hour_meter'] = _controllers['Current Hour Meter']?.text ?? "";
        request.fields['hr_remarks'] = _controllers['HR Remarks']?.text ?? "";
        request.fields['load_current_r'] = _controllers['R']?.text ?? "";
        request.fields['load_current_y'] = _controllers['Y']?.text ?? "";
        request.fields['load_current_b'] = _controllers['B']?.text ?? "";
        request.fields['load_current_remarks'] = _controllers['Load Current Remarks']?.text ?? "";
        request.fields['last_os_hour'] = _controllers['Last OS Hour']?.text ?? "";
        request.fields['engineer_remarks'] = _controllers['Engineer Remarks']?.text ?? "";
        request.fields['customer_remarks'] = _controllers['Customer Remarks']?.text ?? "";
        request.fields['os_date'] = DateFormat('dd-MM-yyyy').format(selectedOSDate);

        // Add maintenance dropdowns
        request.fields['engine_oil_level'] = dropdownValues['Engine Oil Level'] ?? "Good";
        request.fields['battery_water_level'] = dropdownValues['Battery Water Level'] ?? "Good";
        request.fields['ratiator_water_level'] = dropdownValues['Radiator Water Level'] ?? "Good";
        request.fields['diesel_filter'] = dropdownValues['Diesel Filter'] ?? "Good";
        request.fields['air_filter'] = dropdownValues['Air Filter'] ?? "Good";
        request.fields['engine_fan_belt'] = dropdownValues['Engine Fan Belt'] ?? "Good";
        request.fields['engine_noise'] = dropdownValues['Engine Noise'] ?? "Good";
        request.fields['water_pumb&hoses'] = dropdownValues['Water Pump and Hoses'] ?? "Good";
        request.fields['dg_maintenece'] = dropdownValues['DG Maintenance Site'] ?? "Good";
      }

      // Add selected images
      for (int i = 0; i < 7; i++) {
        if (_selectedImages[i] != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'images-${i + 1}',
            _selectedImages[i]!.path,
          ));
        }
      }

      // Add signatures
      final customerSig = await _customerSignatureController.toPngBytes();
      if (customerSig != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'customer_signature',
          customerSig,
          filename: 'customer_signature.png',
        ));
      }

      if (_engineerSignatureController.isNotEmpty) {
        final signatureBytes = await _engineerSignatureController.toPngBytes();
        if (signatureBytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'engineer_signature',
            signatureBytes,
            filename: 'engineer_signature.png',
          ));
        }
      }

      // DEBUG: Print all fields being sent
      debugPrint("--- Sending Request to $url ---");
      request.fields.forEach((key, value) {
        debugPrint("Field: $key = $value");
      });

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      debugPrint("API Response ($url): $responseData");

      if (response.statusCode == 200) {
        String successMsg = "Service History Stored Successfully!";
        if (selectedVisit == 'Demobilization') {
          successMsg = "DeMobilization Pdf Values Store Successfully!";
        } else if (selectedVisit == 'Mobilization') {
          successMsg = "Mobilization Pdf Values Store Successfully!";
        }
        
        SnackbarUtils.showProfessionalSnackbar(context, successMsg);
        Navigator.pop(context);
      } else {
        String errorMsg = "Submission failed";
        try {
          final Map<String, dynamic> errorData = jsonDecode(responseData);
          if (errorData['error'] is Map) {
            // Laravel validation errors often come as a Map
            errorMsg = (errorData['error'] as Map).values.first.toString();
          } else {
            errorMsg = errorData['error'] ?? errorData['message'] ?? "Submission failed";
          }
        } catch (_) {}
        
        // Truncate very long error messages to prevent SnackBar crash
        if (errorMsg.length > 100) errorMsg = errorMsg.substring(0, 97) + "...";
        SnackbarUtils.showProfessionalSnackbar(context, "Error: $errorMsg");
      }
    } catch (e) {
      debugPrint("Error submitting form: $e");
      SnackbarUtils.showProfessionalSnackbar(context, "Error: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final generator = args?['generator'];
    
    if (generator != null) {
      if (_controllers['Customer Name']?.text.isEmpty ?? false) {
        _controllers['Customer Name']?.text = generator['client_name'] ?? generator['customer_name'] ?? "";
      }
      if (_controllers['Address']?.text.isEmpty ?? false) {
        _controllers['Address']?.text = generator['address'] ?? "";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final generator = args?['generator'];
    final visitIndex = args?['visitIndex'];

    // Only pre-select if a visit index was explicitly passed from the dashboard
    if (selectedVisit == null && visitIndex != null) {
      selectedVisit = "Visit $visitIndex";
    }

    List<String> visitOptions = ['Visit 1', 'Visit 2', 'Visit 3', 'Visit 4'];
    if (userRole == "mobilization") {
      visitOptions = ["Mobilization"];
    } else if (userRole == "demobilization" || userRole == "DeMobilization") {
      visitOptions = ["Demobilization"];
    }

    // Safety Fix: If the selected value is not in the current options list, reset it to null
    // This prevents the "There should be exactly one item with DropdownButton's value" crash
    if (selectedVisit != null && !visitOptions.contains(selectedVisit)) {
      selectedVisit = null;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Are you sure you want to exit?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("NO", style: TextStyle(color: Color(0xFF3F00B5), fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("YES", style: TextStyle(color: Color(0xFF3F00B5), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (shouldPop == true) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("DG Set Service Report", style: TextStyle(color: Color(0xFF009BDB))),
        backgroundColor: Color(0xFFC4DFFF).withOpacity(0.5),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField("Visits", selectedVisit, visitOptions, (val) => setState(() => selectedVisit = val)),
            SizedBox(height: 16),
            if (userRole == "mobilization" || userRole == "demobilization" || userRole == "DeMobilization")
              _buildTextField("Engineer Name")
            else
              _buildDropdownField("Purpose of Visit", selectedPurpose, ['General', 'Oil', 'Repair'], (val) => setState(() => selectedPurpose = val)),
            SizedBox(height: 24),
            
            _buildInfoRow("Date", DateFormat('dd-MM-yyyy').format(selectedDate), onTap: () => _selectDate(context, true)),
            _buildInfoRow("In Time", inTime.format(context), onTap: () => _selectTime(context, true)),
            _buildInfoRow("Out Time", outTime.format(context), onTap: () => _selectTime(context, false)),
            
            _buildInfoRow("Asset No (DG No.)", generator?['asset_number'] ?? "N/A"),
            _buildInfoRow("Range KVA", generator?['dg_range'] ?? "N/A"),
            _buildInfoRow("Engine Make", generator?['engine_make'] ?? "N/A"),
            _buildInfoRow("Engine Seriel Number", generator?['engine_srno'] ?? "N/A"),
            _buildInfoRow("Alternate Make", generator?['alternator_make'] ?? "N/A"),
            _buildInfoRow("Alternate Seriel Number", generator?['alternator_srno'] ?? "N/A"),
            _buildInfoRow("Battery Make", generator?['battery_make'] ?? "N/A"),
            _buildInfoRow("Battery Seriel Number", generator?['battery_srno'] ?? "N/A"),
            
            SizedBox(height: 16),
            _buildTextField("Address", maxLines: 4),
            _buildTextField("Spared Replaced", maxLines: 3),
            _buildTextField("Current Hour Meter", keyboardType: TextInputType.number),
            _buildTextField("HR Remarks", maxLines: 2),
            
            Text("Load Current(A)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTextField("R", keyboardType: TextInputType.number)),
                SizedBox(width: 8),
                Expanded(child: _buildTextField("Y", keyboardType: TextInputType.number)),
                SizedBox(width: 8),
                Expanded(child: _buildTextField("B", keyboardType: TextInputType.number)),
              ],
            ),
            
            _buildTextField("Load Current Remarks", maxLines: 2),
            _buildTextField("Last OS Hour"),
            
            _buildInfoRow("Select OS Date", DateFormat('dd-MM-yyyy').format(selectedOSDate), onTap: () => _selectDate(context, false)),
            
            ...dropdownValues.keys.map((key) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildDropdownField(key, dropdownValues[key], dropdownOptions, (val) => setState(() => dropdownValues[key] = val)),
            )).toList(),
            
            _buildTextField("Engineer Remarks", maxLines: 3),
            _buildTextField("Customer Remarks", maxLines: 3),
            
            SizedBox(height: 16),
            Column(
              children: List.generate(7, (index) => _buildUploadButton("UPLOAD PIC${index + 1}", index)),
            ),
            
            SizedBox(height: 24),
            _buildTextField("Customer Name"),
            _buildTextField("Customer Number", keyboardType: TextInputType.phone),
            
            _buildSignaturePad("Customer Signature", _customerSignatureController),
            _buildSignaturePad("Engineer Signature", _engineerSignatureController),
            
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submitForm(generator),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3F00B5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: _isSubmitting 
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("SUBMIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDropdownField(String label, String? value, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!, width: 1.0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              items: options.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: _controllers[label],
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
          alignLabelWithHint: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildUploadButton(String label, int index) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: () => _pickImage(index),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedImages[index] != null ? Colors.green : Color(0xFF3F00B5),
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          _selectedImages[index] != null ? "IMAGE ${index + 1} SELECTED" : label,
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSignaturePad(String label, SignatureController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              icon: Icon(Icons.close, size: 20),
              onPressed: () => controller.clear(),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: controller,
              height: 150,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isMainDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isMainDate ? selectedDate : selectedOSDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isMainDate) {
          selectedDate = picked;
        } else {
          selectedOSDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isInTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isInTime ? inTime : outTime,
    );
    if (picked != null) {
      setState(() {
        if (isInTime) {
          inTime = picked;
        } else {
          outTime = picked;
        }
      });
    }
  }
}
