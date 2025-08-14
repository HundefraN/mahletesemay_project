import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/screens/tips/%20performance_tips_screen.dart';
import '../vocal_range_finder.dart';
import 'lyrics/artists_list_screen.dart';
import 'vocal_exercises/vocal_exercise_list_screen.dart';
import 'vocal_range/vocal_range_finder_screen.dart';
import 'mashup/mashup_helper_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    ArtistsListScreen(),
    VocalExerciseListScreen(),
    VocalRangeFinder(),
    MashupHelperScreen(),
    PerformanceTipsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: PageTransitionSwitcher(
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Lyrics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Exercises',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Range',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shuffle),
            label: 'Mashup',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Tips',
          ),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      floatingActionButton: OpenContainer(
        transitionType: ContainerTransitionType.fade,
        openBuilder: (BuildContext context, VoidCallback _) {
          return const SettingsScreen();
        },
        closedElevation: 6.0,
        closedShape: const CircleBorder(),
        closedColor: theme.colorScheme.secondary,
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return SizedBox(
            height: 56.0,
            width: 56.0,
            child: Center(
              child: Icon(
                Icons.settings,
                color: theme.colorScheme.onSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}