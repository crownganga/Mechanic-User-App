import 'package:flutter/material.dart';
import 'package:vehicle_maintance/screens/auth/login_screen.dart';
import 'package:vehicle_maintance/screens/auth/onboarding/onboarding_slide2.dart';

class OnboardingThree extends StatelessWidget {
  const OnboardingThree({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Stack(
          children: [
            // ------------------ BACK BUTTON (Top Left) ------------------
            Positioned(
              left: 20,
              top: 10,
              child: InkWell(
                enableFeedback: false, // 🔇 Removes click sound
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OnboardSlideTwo(),
                    ), // change per slide
                  );
                },
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: const Color.fromARGB(255, 15, 77, 171),
                  size: 22,
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

                      // Slide Image
                      Image.asset(
                        "assets/onboard/log_history.png", // <-- your asset image
                        height: 180,
                      ),

                      const SizedBox(height: 30),

                      // Title
                      const Text(
                        "Log Service History",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 15, 77, 171),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Subtitle
                      const Text(
                        "Keep a detailed record of all your vehicle’s past services and repairs.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),

                  // ------------------ PAGE INDICATOR ------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _indicator(false),
                      const SizedBox(width: 8),
                      _indicator(false),
                      const SizedBox(width: 8),
                      _indicator(true),
                    ],
                  ),

                  // ------------------ GET STARTED BUTTON ------------------
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
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
                      child: const Text(
                        "Get Started",
                        style: TextStyle(fontSize: 18),
                      ),
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

  // ------------------ DOT INDICATOR WIDGET ------------------
  Widget _indicator(bool isActive) {
    return Container(
      height: 10,
      width: 10,
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromARGB(255, 15, 77, 171)
            : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }
}
