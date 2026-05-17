import 'package:flutter/material.dart';
import 'package:vehicle_maintance/MainScreens/Dashboard/dashboard_screen.dart';
import 'package:vehicle_maintance/MainScreens/Vehicles/vehicle_screen.dart';
import 'package:vehicle_maintance/MainScreens/booking/booking_screen.dart';
import 'package:vehicle_maintance/MainScreens/Maintance/maintenance_screen.dart';
import 'package:vehicle_maintance/MainScreens/Profile/profile_screen.dart';

class BottomMenu extends StatelessWidget {
  final int selectedIndex;

  const BottomMenu({super.key, required this.selectedIndex});

  void _navigate(BuildContext context, int index) {
    Widget page;

    switch (index) {
      case 0:
        page = const DashboardScreen();
        break;
      case 1:
        page = const VehicleScreen();
        break;
      case 2:
        page = const BookingScreen();
        break;
      case 3:
        page = const MaintenanceScreen();
        break;
      case 4:
        page = const ProfileScreen();
        break;
      default:
        page = const DashboardScreen();
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
            _navItem(context, 0, Icons.home),
            _navItem(context, 1, Icons.directions_car),

            // ⭐ CENTER HIGHLIGHT BUTTON
            _centerButton(context),

            _navItem(context, 3, Icons.build),
            _navItem(context, 4, Icons.person),
          ],
        ),
      ),
    );
  }

  /// 🔵 NORMAL ICONS
  Widget _navItem(BuildContext context, int index, IconData icon) {
    final bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => _navigate(context, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0F4DAB).withOpacity(0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: isActive ? 28 : 24,
          color: isActive ? const Color(0xFF0F4DAB) : Colors.grey,
        ),
      ),
    );
  }

  /// ⭐ CENTER BUTTON (DIFFERENT STYLE)
  Widget _centerButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context, 2),
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF0F4DAB),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }
}
