import 'package:flutter/material.dart';
import 'package:vehicle_maintance/screens/auth/login_screen.dart';
import 'package:vehicle_maintance/screens/auth/onboarding/onboarding_slide1.dart';
import 'package:vehicle_maintance/screens/auth/onboarding/onboarding_slide3.dart';

class OnboardSlideTwo extends StatelessWidget {
  const OnboardSlideTwo({super.key});

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
                      builder: (_) => const OnboardSlideOne(),
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
                child: const Text(
                  "Skip",
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 15, 77, 171),
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

                      // Image/Icon
                      Image.asset(
                        "assets/onboard/service_providers.png",
                        height: 180,
                      ),

                      const SizedBox(height: 30),

                      // Title
                      const Text(
                        "Find Service Providers",
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
                        "Locate trusted service centers nearby for your maintenance needs.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),

                  // Page Indicator (●●○)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _indicator(false),
                      const SizedBox(width: 8),
                      _indicator(true),
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
                            builder: (_) => const OnboardingThree(),
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

  // ------------------ PAGE DOT WIDGET ------------------
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
