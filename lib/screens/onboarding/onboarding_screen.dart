import 'package:flutter/material.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahlete_semay_project/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingInfo {
  final String title;
  final String description;
  final IconData icon;
  _OnboardingInfo(this.title, this.description, this.icon);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  double _currentPage = 0;

  final List<_OnboardingInfo> _pages = [
    _OnboardingInfo(
      'Welcome to Your Vocal Companion',
      'Everything you need to grow as a worship singer, all in one place.',
      Icons.music_note_rounded,
    ),
    _OnboardingInfo(
      'Find Any Lyric',
      'Access a vast, searchable library of song lyrics, complete with artist and album details.',
      Icons.text_fields_rounded,
    ),
    _OnboardingInfo(
      'Train Your Voice',
      'Follow structured daily, weekly, and monthly vocal exercise plans to improve your skills.',
      Icons.fitness_center_rounded,
    ),
    _OnboardingInfo(
      'Master the Stage',
      'Discover lessons, mashup ideas, and performance tips to elevate your ministry.',
      Icons.school_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage.round() == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon,
                            size: 120, color: theme.colorScheme.primary),
                        const SizedBox(height: 40),
                        Text(page.title,
                            style: theme.textTheme.headlineLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(page.description,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(height: 1.5),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  DotsIndicator(
                    dotsCount: _pages.length,
                    position: _currentPage,
                    decorator: DotsDecorator(
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLastPage
                            ? _completeOnboarding
                            : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(isLastPage ? "Get Started" : "Next"),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}