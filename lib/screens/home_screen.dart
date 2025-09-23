import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/managers/download_manager.dart';
import 'package:mahlete_semay_project/providers/setlist_provider.dart';
import 'package:mahlete_semay_project/screens/lessons/lessons_screen.dart';
import 'package:mahlete_semay_project/screens/lyrics/setlists_screen.dart';
import 'package:mahlete_semay_project/utils/responsive_sizer.dart';
import 'package:mahlete_semay_project/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../utils/constants.dart';
import 'lyrics/artists_list_screen.dart';
import 'vocal_exercises/vocal_exercise_list_screen.dart';
import 'vocal_range/vocal_range_finder_screen.dart';
import 'mashup/mashup_helper_screen.dart';
import 'settings/settings_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatefulWidget {
  final HomePageTab initialTab;
  const HomeScreen({super.key, this.initialTab = HomePageTab.lyrics});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late int _selectedIndex;

  late TutorialCoachMark tutorialCoachMark;
  GlobalKey lyricsTabKey = GlobalKey();
  GlobalKey exercisesTabKey = GlobalKey();
  GlobalKey mashupTabKey = GlobalKey();
  GlobalKey settingsFabKey = GlobalKey();

  late AnimationController _indicatorController;
  late AnimationController _fabController;
  late AnimationController _backgroundController;
  late Animation<double> _indicatorAnim;
  late Animation<double> _fabAnim;
  late Animation<double> _backgroundAnim;

  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab.index;
    Provider.of<DownloadManager>(context, listen: false).initialize();

    _indicatorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _backgroundController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _indicatorAnim = CurvedAnimation(parent: _indicatorController, curve: Curves.easeOut);
    _fabAnim = CurvedAnimation(parent: _fabController, curve: Curves.bounceOut);
    _backgroundAnim = CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _indicatorController.forward();
      _fabController.forward();
      _backgroundController.forward();
    });

    _checkAndShowTutorial();
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    _fabController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _showCreateSetlistDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create Setlist',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return _CreateSetlistDialog(
          onCreate: (name) {
            Provider.of<SetlistProvider>(context, listen: false).createSetlist(name);
            CustomSnackbar.show(context, 'Setlist "$name" created!');
          },
        );
      },
    );
  }

  Widget? _buildFloatingActionButton() {
    bool isSetlistScreen = _selectedIndex == HomePageTab.setlists.index;

    return Stack(
      children: <Widget>[
        Positioned(
          bottom: 0,
          right: 0,
          child: _UltraModernFab(
            key: settingsFabKey,
            animation: _fabAnim,
            onOpen: () => Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 250),
                pageBuilder: (c, a, s) => FadeTransition(opacity: a, child: const SettingsScreen()),
              ),
            ),
          ),
        ),
        if (isSetlistScreen)
          Positioned(
            bottom: 80.0,
            right: 0,
            child: FloatingActionButton(
              onPressed: () => _showCreateSetlistDialog(context),
              tooltip: 'Create Setlist',
              child:  const Icon(IconsaxPlusBold.add_circle),
            ).animate().slide(begin: const Offset(0, 2)).fadeIn(),
          ),
      ],
    );
  }

  void _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenTour = prefs.getBool(prefGuidedTourCompletedV2) ?? false;
    if (!hasSeenTour && mounted) {
      _createTutorial();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTutorial();
      });
    }
  }

  void _showTutorial() {
    tutorialCoachMark.show(context: context);
  }

  void _createTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Theme.of(context).colorScheme.primary.withOpacity(0.85),
      textSkip: "SKIP",
      pulseEnable: true,
      opacityShadow: 0.95,
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
    await prefs.setBool(prefGuidedTourCompletedV2, true);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "Lyrics Tab",
        keyTarget: lyricsTabKey,
        radius: 48,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent(
              "Find Lyrics",
              "Tap here to browse, search, and discover lyrics for your favorite worship songs.",
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Exercises Tab",
        keyTarget: exercisesTabKey,
        radius: 48,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent(
              "Vocal Workouts",
              "Follow daily, weekly, and monthly plans to improve your voice.",
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Mashup Tab",
        keyTarget: mashupTabKey,
        radius: 48,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent(
              "Mashup Helper",
              "Find compatible scales and rhythms to create seamless sets.",
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Settings FAB",
        keyTarget: settingsFabKey,
        radius: 56,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent(
              "Settings & More",
              "Customize theme, manage reminders, and access the Moderator Portal.",
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTutorialContent(String title, String description) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.w(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(context.w(20)),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(context.w(20)),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      fontSize: context.sp(22)),
                ),
              ),
              SizedBox(height: context.w(12)),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.95),
                    height: 1.5,
                    letterSpacing: 0.2,
                    fontSize: context.sp(14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  static const List<Widget> _widgetOptions = <Widget>[
    ArtistsListScreen(),
    MashupHelperScreen(),
    SetlistsScreen(),
    VocalExerciseListScreen(),
    VocalRangeFinderScreen(),
    LessonsScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIndex = index;
      _indicatorController.reset();
      _indicatorController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final now = DateTime.now();
        final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
            _lastPressedAt == null ||
                now.difference(_lastPressedAt!) > const Duration(seconds: 2);

        if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
          _lastPressedAt = now;
          CustomSnackbar.show(context, 'Press back again to exit the app');
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: AnimatedBuilder(
          animation: _backgroundAnim,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                      : [theme.colorScheme.background, theme.colorScheme.primary.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Transform.scale(
                      scale: _backgroundAnim.value,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [theme.colorScheme.primary.withOpacity(0.1), Colors.transparent]),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150,
                    left: -150,
                    child: Transform.scale(
                      scale: _backgroundAnim.value * 0.8,
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [theme.colorScheme.secondary.withOpacity(0.08), Colors.transparent]),
                        ),
                      ),
                    ),
                  ),
                  PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, primary, secondary) =>
                        FadeThroughTransition(animation: primary, secondaryAnimation: secondary, child: child),
                    child: _widgetOptions.elementAt(_selectedIndex),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: _ModernNavBar(
          selectedIndex: _selectedIndex,
          onTap: _onItemTapped,
          indicatorAnim: _indicatorAnim,
          lyricsTabKey: lyricsTabKey,
          exercisesTabKey: exercisesTabKey,
          mashupTabKey: mashupTabKey,
          labels: [
            l10n.lyrics,
            l10n.mashup,
            "Setlists",
            l10n.exercises,
            l10n.range,
            l10n.lessons,
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }
}

class _ModernNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final Animation<double> indicatorAnim;
  final GlobalKey lyricsTabKey;
  final GlobalKey exercisesTabKey;
  final GlobalKey mashupTabKey;
  final List<String> labels;

  const _ModernNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.indicatorAnim,
    required this.lyricsTabKey,
    required this.exercisesTabKey,
    required this.mashupTabKey,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = <_NavItemData>[
      _NavItemData(IconsaxPlusBold.home_2, IconsaxPlusBold.home, labels[0], key: lyricsTabKey),
      _NavItemData(IconsaxPlusBold.music_library_2, IconsaxPlusBold.music_dashboard, labels[1], key: mashupTabKey),
      _NavItemData(IconsaxPlusBold.note_2, IconsaxPlusBold.note, labels[2]),
      _NavItemData(Icons.fitness_center_outlined, Icons.fitness_center, labels[3], key: exercisesTabKey),
      _NavItemData(IconsaxPlusBold.microphone_2, IconsaxPlusBold.microphone, labels[4]),
      _NavItemData(Icons.school_outlined, Icons.school, labels[5]),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.w(16), 0, context.w(16), context.w(20)),
        child: Container(
          height: context.w(80),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(context.w(28)),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1), width: 1.5),
            boxShadow: [
              BoxShadow(color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.1), blurRadius: 30, spreadRadius: 0, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.white.withOpacity(isDark ? 0.05 : 0.8), blurRadius: 10, spreadRadius: -5, offset: const Offset(0, -5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.w(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(context.w(28)),
                ),
                child: Row(
                  children: List.generate(items.length, (i) {
                    final selected = i == selectedIndex;
                    final item = items[i];

                    return Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onTap(i),
                          borderRadius: BorderRadius.circular(context.w(20)),
                          splashColor: theme.colorScheme.primary.withOpacity(0.1),
                          highlightColor: Colors.transparent,
                          child: Container(
                            key: item.key,
                            padding: EdgeInsets.symmetric(horizontal: context.w(4), vertical: context.w(12)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (selected)
                                      ScaleTransition(
                                        scale: indicatorAnim,
                                        child: Container(
                                          width: context.w(48),
                                          height: context.w(32),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary.withOpacity(0.7)]),
                                            borderRadius: BorderRadius.circular(context.w(16)),
                                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1),
                                          ),
                                        ),
                                      ),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: Icon(
                                        selected ? item.selectedIcon : item.icon,
                                        key: ValueKey('$i-$selected'),
                                        color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                        size: context.w(24),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: context.w(6)),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    fontSize: context.sp(10),
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    letterSpacing: 0.3,
                                  ),
                                  child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Key? key;
  const _NavItemData(this.icon, this.selectedIcon, this.label, {this.key});
}

class _UltraModernFab extends StatelessWidget {
  final VoidCallback onOpen;
  final Animation<double> animation;

  const _UltraModernFab({
    super.key,
    required this.onOpen,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: OpenContainer(
            transitionType: ContainerTransitionType.fade,
            transitionDuration: const Duration(milliseconds: 300),
            closedColor: Colors.transparent,
            closedElevation: 0,
            openColor: theme.colorScheme.surface,
            openElevation: 0,
            closedBuilder: (ctx, open) {
              return Container(
                width: context.w(64),
                height: context.w(64),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onOpen();
                    },
                    borderRadius: BorderRadius.circular(context.w(32)),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
                      child: Icon(IconsaxPlusBold.setting_2, color: Colors.white, size: context.w(28)),
                    ),
                  ),
                ),
              );
            },
            openBuilder: (ctx, _) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _CreateSetlistDialog extends StatefulWidget {
  final Function(String) onCreate;
  const _CreateSetlistDialog({required this.onCreate});

  @override
  State<_CreateSetlistDialog> createState() => _CreateSetlistDialogState();
}

class _CreateSetlistDialogState extends State<_CreateSetlistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onCreate(_controller.text.trim());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Create New Setlist', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _controller,
                  decoration: InputDecoration(labelText: 'Setlist Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) => value!.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _submit, child: const Text('Create')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}