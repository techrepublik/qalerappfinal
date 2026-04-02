import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart'; // Added location 8.0.0

class FamilyContactsPage extends StatefulWidget {
  const FamilyContactsPage({super.key});

  @override
  State<FamilyContactsPage> createState() => _FamilyContactsPageState();
}

class _FamilyContactsPageState extends State<FamilyContactsPage> {
  List<Map<String, String>> contacts = [];
  final int maxContacts = 3;
  bool isLoading = true;

  // Initialize Location object
  final Location location = Location();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // --- NEW: Get User Position ---
  Future<LocationData?> _getUserPosition() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if service is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return null;
    }

    // Check permissions
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return null;
    }

    try {



      return await location.getLocation();




    } catch (e) {
      debugPrint("Error getting location: $e");
      return null;
    }
  }

  // Load contacts from SharedPreferences
  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString('family_contacts');

    if (contactsJson != null) {
      setState(() {
        contacts = List<Map<String, String>>.from(
            jsonDecode(contactsJson).map((x) => Map<String, String>.from(x)));
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('family_contacts', jsonEncode(contacts));
  }

  void _addContact(String name, String number) {
    if (contacts.length >= maxContacts) {
      _showErrorSnackBar('You can only add up to 3 emergency contacts.');
      return;
    }
    setState(() {
      contacts.add({'name': name, 'number': number});
    });
    _saveContacts();
  }

  void _deleteContact(int index) {
    setState(() {
      contacts.removeAt(index);
    });
    _saveContacts();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _makeCall(String number) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showErrorSnackBar('Could not launch dialer.');
    }
  }

  // // --- UPDATED: Send SMS with Location ---
  Future<void> _sendSms(String number) async {
    // Show a loading indicator if location takes a moment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fetching location..."), duration: Duration(seconds: 1)),
    );

    LocationData? position = await _getUserPosition();

    String message = position != null
        ? "SOS! I Need Help GPS: ${position.latitude},${position.longitude} or maps.google.com?q=${position.latitude},${position.longitude}"
        : "EMERGENCY SOS! I need help. Location unavailable";

    // Use Uri.encodeFull and manually replace + with %20 if necessary
    // Or simply construct the string without queryParameters to prevent double-encoding


    final String url = "sms:$number?body=${Uri.encodeComponent(message).replaceAll('+', '%20')}";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showErrorSnackBar('Could not launch SMS.');
    }
  }

  // ... [Keep _showAddContactDialog, build, _buildHeader, etc. from original code] ...

  // Note: I have truncated the UI code for brevity,
  // but it remains exactly as you provided it in your original snippet.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Family Contacts',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showAddContactDialog,
            icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: Color(0xFFDC143C),
                size: 28
            ),
            tooltip: 'Add Contact',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child:isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: contacts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    return _buildContactCard(index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... [Other UI helper methods remain unchanged] ...

  Widget _buildContactCard(int index) {
    final contact = contacts[index];
    return Dismissible(
      key: Key(contact['number']!),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.red[700]),
      ),
      onDismissed: (direction) => _deleteContact(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        color: Color(0xFFDC143C), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contact['number'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.grey[400], size: 20),
                    onPressed: () => _deleteContact(index),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.phone_rounded,
                      label: 'Call',
                      color: const Color(0xFF10B981),
                      onTap: () => _makeCall(contact['number']!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.message_rounded,
                      label: 'Send SOS',
                      color: const Color(0xFF3B82F6),
                      onTap: () => _sendSms(contact['number']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... [Other original UI helpers] ...
  void _showAddContactDialog() {
    if (contacts.length >= maxContacts) {
      _showErrorSnackBar('Maximum limit of 3 contacts reached.');
      return;
    }

    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 70,
            top: 20,
            left: 20,
            right: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Family Contact',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name (e.g., Mom, Wife)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC143C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      numberController.text.isNotEmpty) {
                    _addContact(nameController.text, numberController.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save Contact',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),

            ),
          ],
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDC143C).withOpacity(0.8),
            const Color(0xFFDC143C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC143C).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'People to notify in case of emergency.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_alt_1_rounded,
              size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No contacts added yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + icon above to add contacts',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}