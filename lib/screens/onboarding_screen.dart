import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openstreetmap/main.dart';
import 'package:openstreetmap/utils/app_strings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: AppStrings.welcomeTitle,
      description: AppStrings.welcomeDesc,
      image: AppStrings.logoImage,
    ),
    OnboardingContent(
      title: AppStrings.exploreTitle,
      description: AppStrings.exploreDesc,
      image: AppStrings.onboardingImage,
    ),
    OnboardingContent(
      title: AppStrings.navigationTitle,
      description: AppStrings.navigationDesc,
      image: AppStrings.onboardingImage,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Set system overlay style to dark
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 180), // Increased top padding
            // Image section
            SizedBox(
              height: 280, // Adjusted image container height
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _contents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Image.asset(
                      _contents[index].image,
                      height: 240,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return const Icon(Icons
                            .error); // Shows error icon if image fails to load
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 60), // Adjusted spacing
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _contents.length,
                (dotIndex) => buildDot(dotIndex),
              ),
            ),
            const SizedBox(height: 160), // Adjusted spacing
            // Title container
            Container(
              width: 400,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _contents[_currentPage].title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.6, // Added line height
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Description container
            Container(
              width: 335,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _contents[_currentPage].description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ),
            const Spacer(), // Use Spacer to push button to bottom
            // Button container
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: SizedBox(
                width: 335,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _contents.length - 1) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapScreen(),
                        ),
                      );
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeIn,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0171FF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _contents.length - 1
                        ? AppStrings.getStarted
                        : AppStrings.next,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDot(int index) {
    final Color dotColor = const Color(0xFF0171FF);
    final bool isSelected = _currentPage == index;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1.0 + (value * 0.1), // Subtle scale effect
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            height: 8,
            width: 8 + (value * 28), // Animate from 8 to 36
            margin: EdgeInsets.only(
              right: 8,
              left: index == 0 ? 32 : 0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: Color.lerp(
                dotColor.withOpacity(0.3),
                dotColor,
                value,
              ),
              boxShadow: [
                BoxShadow(
                  color: dotColor.withOpacity(0.3 * value),
                  spreadRadius: 1 * value,
                  blurRadius: 3 * value,
                  offset: Offset(0, 1 * value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final String image;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.image,
  });
}
