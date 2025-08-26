import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/screens/lessons/lessons_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'lyrics/artists_list_screen.dart';
import 'vocal_exercises/vocal_exercise_list_screen.dart';
import 'vocal_range/vocal_range_finder_screen.dart';
import 'mashup/mashup_helper_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;

  late TutorialCoachMark tutorialCoachMark;
  GlobalKey lyricsTabKey = GlobalKey();
  GlobalKey exercisesTabKey = GlobalKey();
  GlobalKey mashupTabKey = GlobalKey();
  GlobalKey settingsFabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkAndShowTutorial();
  }

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenTour = prefs.getBool('guided_tour_completed') ?? false;
    if (!hasSeenTour && mounted) {
      _createTutorial();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTutorial();
        }
      });
    }
  }

  void _showTutorial() {
    tutorialCoachMark.show(context: context);
  }

  void _createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Theme.of(context).primaryColor.withOpacity(0.8),
      textSkip: "SKIP",
      onFinish: () {
        _completeTutorial();
        return true;
      },
      onSkip: () {
        _completeTutorial();
        return true;
      },
    );
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guided_tour_completed', true);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "Lyrics Tab",
        keyTarget: lyricsTabKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent("Find Lyrics",
                "Tap here to browse, search, and discover the lyrics for all your favorite worship songs."),
          ),
        ],
      ),
      TargetFocus(
        identify: "Exercises Tab",
        keyTarget: exercisesTabKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent("Vocal Workouts",
                "Follow guided daily, weekly, and monthly plans to train and improve your voice."),
          ),
        ],
      ),
      TargetFocus(
        identify: "Mashup Tab",
        keyTarget: mashupTabKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent("Mashup Helper",
                "Discover songs with compatible scales and rhythms to create seamless worship sets."),
          ),
        ],
      ),
      TargetFocus(
        identify: "Settings FAB",
        keyTarget: settingsFabKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent("Settings & More",
                "Customize your theme, manage reminders, and access the Moderator Portal here."),
          ),
        ],
      ),
    ];
  }

  Widget _buildTutorialContent(String title, String description) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20)),
        const SizedBox(height: 10),
        Text(description,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  static const List<Widget> _widgetOptions = <Widget>[
    ArtistsListScreen(),
    VocalExerciseListScreen(),
    VocalRangeFinderScreen(),
    MashupHelperScreen(),
    LessonsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: PageTransitionSwitcher(
        transitionBuilder: (child, primary, secondary) =>
            FadeThroughTransition(
                animation: primary, secondaryAnimation: secondary, child: child),
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.music_note, key: lyricsTabKey), label: l10n.lyrics),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center, key: exercisesTabKey),
              label: l10n.exercises),
          BottomNavigationBarItem(icon: const Icon(Icons.mic), label: l10n.range),
          BottomNavigationBarItem(
              icon: Icon(Icons.shuffle, key: mashupTabKey), label: l10n.mashup),
          BottomNavigationBarItem(icon: const Icon(Icons.school_outlined), label: l10n.lessons),
        ],
      ),
      floatingActionButton: OpenContainer(
        key: settingsFabKey,
        transitionType: ContainerTransitionType.fade,
        openBuilder: (ctx, _) => const SettingsScreen(),
        closedElevation: 6.0,
        closedShape: const CircleBorder(),
        closedColor: theme.colorScheme.secondary,
        closedBuilder: (ctx, open) => SizedBox(
            height: 56.0,
            width: 56.0,
            child: Center(
                child: Icon(Icons.settings, color: theme.colorScheme.onSecondary))),
      ),
    );
  }
}