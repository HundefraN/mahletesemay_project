import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en')
  ];

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @range.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get range;

  /// No description provided for @mashup.
  ///
  /// In en, this message translates to:
  /// **'Mashup'**
  String get mashup;

  /// No description provided for @lessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessons;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, lyrics...'**
  String get searchHint;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended For You'**
  String get recommendedForYou;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @ethiopianArtists.
  ///
  /// In en, this message translates to:
  /// **'Ethiopian Artists'**
  String get ethiopianArtists;

  /// No description provided for @worldwideArtists.
  ///
  /// In en, this message translates to:
  /// **'Worldwide Artists'**
  String get worldwideArtists;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @vocalTraining.
  ///
  /// In en, this message translates to:
  /// **'Vocal Training'**
  String get vocalTraining;

  /// No description provided for @structuredPlans.
  ///
  /// In en, this message translates to:
  /// **'Structured Plans'**
  String get structuredPlans;

  /// No description provided for @generalExercises.
  ///
  /// In en, this message translates to:
  /// **'General Exercises'**
  String get generalExercises;

  /// No description provided for @dailyWarmUp.
  ///
  /// In en, this message translates to:
  /// **'Daily Warm-up'**
  String get dailyWarmUp;

  /// No description provided for @dailyWarmUpDesc.
  ///
  /// In en, this message translates to:
  /// **'A quick daily routine to keep your voice healthy.'**
  String get dailyWarmUpDesc;

  /// No description provided for @weeklyWorkout.
  ///
  /// In en, this message translates to:
  /// **'Weekly Workout'**
  String get weeklyWorkout;

  /// No description provided for @weeklyWorkoutDesc.
  ///
  /// In en, this message translates to:
  /// **'A 7-day plan to build core vocal strength.'**
  String get weeklyWorkoutDesc;

  /// No description provided for @monthlyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Monthly Challenge'**
  String get monthlyChallenge;

  /// No description provided for @monthlyChallengeDesc.
  ///
  /// In en, this message translates to:
  /// **'A 30-day comprehensive vocal program.'**
  String get monthlyChallengeDesc;

  /// No description provided for @threeMonthTransformation.
  ///
  /// In en, this message translates to:
  /// **'3-Month Transformation'**
  String get threeMonthTransformation;

  /// No description provided for @threeMonthTransformationDesc.
  ///
  /// In en, this message translates to:
  /// **'A long-term plan for serious improvement.'**
  String get threeMonthTransformationDesc;

  /// No description provided for @vocalRangeFinder.
  ///
  /// In en, this message translates to:
  /// **'Vocal Range Finder'**
  String get vocalRangeFinder;

  /// No description provided for @worshipMashupHelper.
  ///
  /// In en, this message translates to:
  /// **'Worship Mashup Helper'**
  String get worshipMashupHelper;

  /// No description provided for @lessonsAndTutorials.
  ///
  /// In en, this message translates to:
  /// **'Lessons & Tutorials'**
  String get lessonsAndTutorials;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @dailyReminders.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminders'**
  String get dailyReminders;

  /// No description provided for @remindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Remind me to do my vocal workout at 10 AM.'**
  String get remindersDesc;

  /// No description provided for @suggestASong.
  ///
  /// In en, this message translates to:
  /// **'Suggest a Song'**
  String get suggestASong;

  /// No description provided for @moderatorPortal.
  ///
  /// In en, this message translates to:
  /// **'Moderator Portal'**
  String get moderatorPortal;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out of Moderator Portal'**
  String get signOut;

  /// No description provided for @sendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get sendTestNotification;

  /// No description provided for @findLowestNote.
  ///
  /// In en, this message translates to:
  /// **'Find Your Lowest Note'**
  String get findLowestNote;

  /// No description provided for @findLowestNoteDesc.
  ///
  /// In en, this message translates to:
  /// **'Press \'Start\' and sing the lowest note you can produce comfortably and steadily.'**
  String get findLowestNoteDesc;

  /// No description provided for @startFindingLowest.
  ///
  /// In en, this message translates to:
  /// **'Start Finding Lowest Note'**
  String get startFindingLowest;

  /// No description provided for @findHighestNote.
  ///
  /// In en, this message translates to:
  /// **'Find Your Highest Note'**
  String get findHighestNote;

  /// No description provided for @findHighestNoteDesc.
  ///
  /// In en, this message translates to:
  /// **'Now, press \'Start\' and sing your highest comfortable note without straining.'**
  String get findHighestNoteDesc;

  /// No description provided for @startFindingHighest.
  ///
  /// In en, this message translates to:
  /// **'Start Finding Highest Note'**
  String get startFindingHighest;

  /// No description provided for @yourResults.
  ///
  /// In en, this message translates to:
  /// **'Your Results'**
  String get yourResults;

  /// No description provided for @vocalRange.
  ///
  /// In en, this message translates to:
  /// **'Vocal Range'**
  String get vocalRange;

  /// No description provided for @probableVoiceType.
  ///
  /// In en, this message translates to:
  /// **'Probable Voice Type'**
  String get probableVoiceType;

  /// No description provided for @voiceTypeDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'(This is an estimate. A professional vocal coach can provide a more accurate classification.)'**
  String get voiceTypeDisclaimer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
