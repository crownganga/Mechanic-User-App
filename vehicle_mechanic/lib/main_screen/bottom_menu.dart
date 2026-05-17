import 'package:flutter/material.dart';
import 'package:vehicle_mechanic/main_screen/booking/booking.dart';
import 'package:vehicle_mechanic/main_screen/dashboard/mechanic_dashboard_screen.dart';
import 'package:vehicle_mechanic/main_screen/history/history.dart';
import 'package:vehicle_mechanic/main_screen/profile/profile.dart';

class BottomMenu extends StatelessWidget {
  final int selectedIndex;

  const BottomMenu({super.key, required this.selectedIndex});

  void _navigate(BuildContext context, int index) {
    Widget page;

    switch (index) {
      case 0:
        page = const MechanicDashboardScreen();
        break;
      case 1:
        page = const BookingScreen(); // Booking Details
        break;
      case 2:
        page = const History(); // Service History
        break;
      case 3:
        page = const MechanicProfileScreen();
        break;
      default:
        page = const MechanicDashboardScreen();
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 12, right: 12),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, 0, Icons.home, "Home"),
            _navItem(context, 1, Icons.book_online, "Booking"),
            _navItem(context, 2, Icons.history, "Service"),
            _navItem(context, 3, Icons.person, "Profile"),
          ],
        ),
      ),
    );
  }

  /// 🔵 MENU ITEM
  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => _navigate(context, index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF0F4DAB).withOpacity(0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: isActive ? 26 : 22,
              color: isActive ? const Color(0xFF0F4DAB) : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? const Color(0xFF0F4DAB) : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
