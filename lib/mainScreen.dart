import 'package:flutter/material.dart';
import 'package:joma/services/analytics.dart';
import 'emergencyH3.dart';
import 'profilePage.dart';



class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _newsVisited = false;


  Widget _buildBody() {
    return Stack(
      children: [
        Offstage(
          offstage: _currentIndex != 0,
          child: const QAlertWithUpdates(),
        ),

        Offstage(
          offstage: _currentIndex != 1,
          child: const MarketScreen(),
        ),
        Offstage(
          offstage: _currentIndex != 2,
          child: const ProfileScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF00BFA5),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 1) _newsVisited = true; // only mount News after first tap
          });


        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}



class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});



  @override
  Widget build(BuildContext context) {
    const Color darkMint = Color(0xFF3EB489);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Matches your news feed bg
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics_outlined, size: 64, color: darkMint),
              const SizedBox(height: 24),
              const Text(
                "In Progress",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "We're currently setting up this space. Interested in promoting your services here?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  AnalyticsService.trackEvent(
                    eventName: 'Market Contact Us',
                    lguCode: 'NOT_SET',
                    screen: 'Services Screen',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkMint,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const SelectableText(
                  "Email Us for Ads: support@qalertapp.com",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),              ),
            ],
          ),
        ),
      ),
    );
  }}

