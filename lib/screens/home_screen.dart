import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mahlete_semay_project/l10n/app_localizations.dart';
import 'package:mahlete_semay_project/managers/download_manager.dart';
import 'package:mahlete_semay_project/providers/setlist_provider.dart';
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
import 'tuner/guitar_tuner_screen.dart';
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

    if (!kIsWeb) _checkAndShowTutorial();
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    _fabController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _showCreateSetlistDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.createSetlist,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return _CreateSetlistDialog(
          onCreate: (name) {
            Provider.of<SetlistProvider>(context, listen: false).createSetlist(name);
            CustomSnackbar.show(context, l10n.setlistCreated);
          },
        );
      },
    );
  }

  Widget? _buildFloatingActionButton() {
    bool isSetlistScreen = _selectedIndex == HomePageTab.setlists.index;
    final l10n = AppLocalizations.of(context);

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
                pageBuilder: (c, a, s) => FadeTransition(opacity: a, child: const GuitarTunerScreen()),
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
              tooltip: l10n?.createSetlist ?? 'Create Setlist',
              child: const Icon(IconsaxPlusBold.add_circle),
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
      colorShadow: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
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
        identify: "Guitar Tuner FAB",
        keyTarget: settingsFabKey,
        radius: 56,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _buildTutorialContent(
              "Guitar Tuner",
              "Tap here anytime to access the professional interactive guitar tuner.",
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
            color: theme.cardColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(context.w(20)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2)],
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
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
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    if (!kIsWeb) HapticFeedback.lightImpact();
    setState(() {
      _selectedIndex = index;
      _indicatorController.reset();
      _indicatorController.forward();
    });
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _backgroundAnim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0A0A0A), const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                  : [theme.colorScheme.surface, theme.colorScheme.primary.withValues(alpha: 0.05)],
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
                      gradient: RadialGradient(colors: [theme.colorScheme.primary.withValues(alpha: 0.1), Colors.transparent]),
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
                      gradient: RadialGradient(colors: [theme.colorScheme.secondary.withValues(alpha: 0.08), Colors.transparent]),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final useRail = !context.isPhone;

    final labels = [
      l10n.lyrics,
      l10n.mashup,
      l10n.setlists,
      l10n.exercises,
      l10n.range,
      l10n.settings,
    ];

    final icons = <IconData>[
      IconsaxPlusBold.home_2,
      IconsaxPlusBold.music_library_2,
      IconsaxPlusBold.note_2,
      Icons.fitness_center_outlined,
      IconsaxPlusBold.microphone_2,
      IconsaxPlusLinear.setting_2,
    ];

    final selectedIcons = <IconData>[
      IconsaxPlusBold.home,
      IconsaxPlusBold.music_dashboard,
      IconsaxPlusBold.note,
      Icons.fitness_center,
      IconsaxPlusBold.microphone,
      IconsaxPlusBold.setting_2,
    ];

    Widget body = _buildBody(theme, isDark);

    // ── Desktop / Tablet: NavigationRail on the left ────────────────────────
    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.6),
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraint) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraint.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _onItemTapped,
                          backgroundColor: Colors.transparent,
                          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          labelType: NavigationRailLabelType.all,
                          leading: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/logo/logo.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          destinations: List.generate(labels.length, (i) {
                            return NavigationRailDestination(
                              icon: Icon(icons[i], size: 22),
                              selectedIcon: Icon(selectedIcons[i], size: 22, color: theme.colorScheme.primary),
                              label: Text(
                                labels[i],
                                style: TextStyle(fontSize: 11),
                              ),
                            );
                          }),
                          selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
                          unselectedIconTheme: IconThemeData(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          selectedLabelTextStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                          unselectedLabelTextStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      );
    }

    // ── Phone: floating bottom nav bar ───────────────────────────────────────
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
          CustomSnackbar.show(context, l10n.pressBackToExit);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: body,
        bottomNavigationBar: _ModernNavBar(
          selectedIndex: _selectedIndex,
          onTap: _onItemTapped,
          indicatorAnim: _indicatorAnim,
          lyricsTabKey: lyricsTabKey,
          exercisesTabKey: exercisesTabKey,
          mashupTabKey: mashupTabKey,
          labels: labels,
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
      _NavItemData(IconsaxPlusLinear.setting_2, IconsaxPlusBold.setting_2, labels[5]),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.w(16), 0, context.w(16), context.w(20)),
        child: Container(
          height: context.w(80),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(context.w(28)),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1), width: 1.5),
            boxShadow: [
              BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 0, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.8), blurRadius: 10, spreadRadius: -5, offset: const Offset(0, -5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.w(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2),
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
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(i);
                          },
                          borderRadius: BorderRadius.circular(context.w(20)),
                          splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                                            gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary.withValues(alpha: 0.7)]),
                                            borderRadius: BorderRadius.circular(context.w(16)),
                                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1),
                                          ),
                                        ),
                                      ),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: Icon(
                                        selected ? item.selectedIcon : item.icon,
                                        key: ValueKey('$i-$selected'),
                                        color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                                    color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)),
                      child: Icon(IconsaxPlusBold.music, color: Colors.white, size: context.w(28)),
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
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.createSetlist, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _controller,
                  decoration: InputDecoration(labelText: l10n.setlists, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) => value!.trim().isEmpty ? l10n.searchHint : null,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _submit, child: Text(l10n.createSetlist)),
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