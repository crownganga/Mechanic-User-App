import 'package:flutter/material.dart';
import 'package:vehicle_maintance/screens/auth/login_screen.dart';
import 'package:vehicle_maintance/screens/auth/onboarding/onboarding_slide2.dart';

class OnboardSlideOne extends StatelessWidget {
  const OnboardSlideOne({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Stack(
          children: [
            // ------------------ SKIP BUTTON (Top Right) ------------------
            Positioned(
              right: 20,
              top: 10,
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: ButtonStyle(
                  enableFeedback: false, // 👈 Removes click sound
                ),
                child: const Text(
                  "Skip",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 15, 77, 171),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // ------------------ MAIN CONTENT ------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 60),

                      // Top Image
                      Image.asset(
                        "assets/onboard/maintenance.png",
                        height: 180,
                      ),

                      const SizedBox(height: 30),

                      // Title
                      const Text(
                        "Track Maintenance",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 15, 77, 171),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Description
                      const Text(
                        "Stay on top of your vehicle’s health with automatic maintenance reminders.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),

                  // Page Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _indicator(true),
                      const SizedBox(width: 8),
                      _indicator(false),
                      const SizedBox(width: 8),
                      _indicator(false),
                    ],
                  ),

                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OnboardSlideTwo(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 15, 77, 171),
                        foregroundColor: Colors.white,
                        enableFeedback: false, // 🔇 Disables click sound
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text("Next", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Page Indicator Widget
  Widget _indicator(bool isActive) {
    return Container(
      height: 10,
      width: 10,
      decoration: BoxDecoration(
        color: isActive ? const Color.fromARGB(255, 15, 77, 171) : Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
