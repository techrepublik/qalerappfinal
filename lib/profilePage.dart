import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:joma/services/analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'GoogleSignUpPage.dart';
import 'completeProfilePage.dart';
import 'package:url_launcher/url_launcher.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color mintGreen = Color(0xFF00BFA5);
  static const Color darkMint = Color(0xFF3EB489);
  static const Color crimson = Color(0xFFDC143C);

  // User data from SharedPreferences
  String name = '';
  String userId = '';
  String email = '';
  String phone = '';
  String image = '';
  String role = '';
  String municipality = '';
  String barangay = '';
  String province = '';
  String lguCode = '';
  bool _isDeleting = false;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  bool get _isProfileIncomplete =>    phone.isEmpty || municipality.isEmpty || barangay.isEmpty;


  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _loadUserData();

    AnalyticsService.trackEvent(
      eventName: 'Load Profile',
      lguCode: 'NOT_SET',
      screen: 'Profile Screen',
    );

  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId      = prefs.getString('user_id') ?? '';
      name        = prefs.getString('name') ?? '';
      email       = prefs.getString('email') ?? '';
      phone       = prefs.getString('phone') ?? '';
      image       = prefs.getString('image') ?? '';
      role        = prefs.getString('role') ?? 'user';
      municipality = prefs.getString('municipality') ?? '';
      barangay    = prefs.getString('barangay') ?? '';
      province    = prefs.getString('province') ?? '';
      lguCode     = prefs.getString('lguCode') ?? '';
      _isLoading  = false;
    });

    debugPrint('this is userId: $userId');
  }



  Future<void> _handleDeleteAccount() async {
    final confirm = await _showDeleteDialog();
    if (!confirm) return;

    setState(() => _isDeleting = true);

    try {
      final url = Uri.parse('https://ems.qalertapp.com/api/users/$userId');

      final response = await http.delete(url);

      if (response.statusCode == 200) {
        // Clear local data
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        await _googleSignIn.signOut();


        AnalyticsService.trackEvent(
          eventName: 'Delete Account',
          lguCode: lguCode,
          screen: 'Profile Screen',
        );


        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const GoogleSignUpPage()),
                (route) => false,
          );
        }
      } else {
        throw Exception('Delete failed');
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      _showError('Failed to delete account. Please try again.');
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await _showLogoutDialog();
    if (!confirm) return;

    setState(() => _isLoggingOut = true);

    try {
      await _googleSignIn.signOut();
      final prefs = await SharedPreferences.getInstance();
      // await prefs.clear();

      final keysToRemove = ['email', 'user_Id', 'phone','name','role','municipality','barangay','province'];
      for (String key in keysToRemove) {
        await prefs.remove(key);
      }

      AnalyticsService.trackEvent(
        eventName: 'SignOut',
        lguCode: lguCode,
        screen: 'Profile Screen',
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GoogleSignUpPage()),
              (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoggingOut = false);
      _showError('Logout failed. Please try again.');
    }
  }

  Future<bool> _showLogoutDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: crimson, size: 24),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of Q-ALERT?',
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black26,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }


  Future<bool> _showDeleteDialog() async {
    bool isChecked = false;

    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: crimson, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Delete Account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This will permanently delete your account and all your data.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ Checkbox Row
                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        activeColor: crimson,
                        onChanged: (value) {
                          setState(() {
                            isChecked = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'This action cannot be undone',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isChecked
                      ? () => Navigator.pop(context, true)
                      : null, // ❗ Disabled until checked
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crimson,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    ) ?? false;
  }

  void _openUrl(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: crimson,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: mintGreen)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildCompleteProfileBanner(), // 👈 add this
                if (_isProfileIncomplete) const SizedBox(height: 16), // spacing only when visible
                _buildInfoSection(),
                const SizedBox(height: 16),
                _buildLocationSection(),
                const SizedBox(height: 16),
                _buildAccountSection(),
                const SizedBox(height: 24),
                _buildLogoutButton(),
                const SizedBox(height: 15),
                _buildDeleteAccountButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: mintGreen,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [mintGreen, darkMint],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                  child: image.isEmpty
                      ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: mintGreen,
                    ),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name.isNotEmpty ? name : 'Q-ALERT User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return _buildCard(
      title: 'Personal Information',
      icon: Icons.person_rounded,
      children: [
        _buildInfoRow(Icons.email_outlined, 'Email', email),
        _buildDivider(),
        _buildInfoRow(Icons.phone_outlined, 'Phone', phone.isNotEmpty ? phone : 'Not set'),
        _buildDivider(),

      ],
    );
  }

  Widget _buildLocationSection() {
    return _buildCard(
      title: 'Location',
      icon: Icons.location_on_rounded,
      children: [
        _buildInfoRow(Icons.location_city_outlined, 'Municipality', municipality.isNotEmpty ? municipality : 'Not set'),
        _buildDivider(),
        _buildInfoRow(Icons.home_outlined, 'Barangay', barangay.isNotEmpty ? barangay : 'Not set'),
        if (province.isNotEmpty) ...[
          _buildDivider(),
          _buildInfoRow(Icons.shield_outlined, 'Province', province.isNotEmpty ? province : 'Not set'),
        ],
      ],
    );
  }

  Widget _buildAccountSection() {
    return _buildCard(
        title: 'Q-ALERT',
      icon: Icons.manage_accounts_rounded,
      children: [
        _buildTappableRow(
          icon: Icons.lock_outline_rounded,
          label: 'Terms of Service',
          onTap: (){
            _openUrl('https://qalertapp.com/policy');
          },
        ),
        _buildDivider(),
        _buildTappableRow(
          icon: Icons.help_outline_rounded,
          label: 'Help & Support',
          onTap: () {
            _openUrl('https://qalertapp.com');
          },
        ),
        _buildDivider(),
        _buildTappableRow(
          icon: Icons.info_outline_rounded,
          label: 'About Q-ALERT Version 2.0.38',
          onTap: () {
            _openUrl('https://qalertapp.com/#download');
          },
        ),

      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoggingOut ? null : _handleLogout,
          icon: _isLoggingOut
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Icon(Icons.logout_rounded, size: 20),
          label: Text(
            _isLoggingOut ? 'Signing out...' : 'Sign Out',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black45,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isDeleting ? null : _handleDeleteAccount,
          icon: _isDeleting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Icon(Icons.delete_forever, size: 20),
          label: Text(
            _isDeleting ? 'Deleting...' : 'Delete account',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black12,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  // ─── Reusable Widgets ───────────────────────────────────────────

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: mintGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: mintGreen, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTappableRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[400]),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 54, color: Color(0xFFF5F5F5));
  }


  Widget _buildCompleteProfileBanner() {
    if (!_isProfileIncomplete) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFCA28), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCA28).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: Color(0xFFF9A825), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Incomplete',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7B5800),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Complete your profile to access all features.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A6F00),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompleteProfilePage(userId: userId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mintGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Complete',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }







}
