import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';
import 'app_localizations_so.dart';
import 'app_localizations_ti.dart';

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
    Locale('en'),
    Locale('om'),
    Locale('so'),
    Locale('ti')
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

  /// No description provided for @setlists.
  ///
  /// In en, this message translates to:
  /// **'Setlists'**
  String get setlists;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

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

  /// No description provided for @myFavorites.
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get myFavorites;

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

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

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

  /// No description provided for @viewingHistory.
  ///
  /// In en, this message translates to:
  /// **'Viewing History'**
  String get viewingHistory;

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

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @amharic.
  ///
  /// In en, this message translates to:
  /// **'አማርኛ'**
  String get amharic;

  /// No description provided for @oromifa.
  ///
  /// In en, this message translates to:
  /// **'Afaan Oromoo'**
  String get oromifa;

  /// No description provided for @tigrinya.
  ///
  /// In en, this message translates to:
  /// **'ትግርኛ'**
  String get tigrinya;

  /// No description provided for @somali.
  ///
  /// In en, this message translates to:
  /// **'Af Soomaali'**
  String get somali;

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
  /// **'Send a test notification'**
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

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @pressBackToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit the app'**
  String get pressBackToExit;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// No description provided for @exitAppConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to close the application?'**
  String get exitAppConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share The App'**
  String get shareApp;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @practice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practice;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @dailyPracticeReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily practice reminder'**
  String get dailyPracticeReminder;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @unfinishedSessionNudge.
  ///
  /// In en, this message translates to:
  /// **'Unfinished session nudge'**
  String get unfinishedSessionNudge;

  /// No description provided for @unfinishedSessionDesc.
  ///
  /// In en, this message translates to:
  /// **'Remind me to come back if I leave a vocal plan halfway'**
  String get unfinishedSessionDesc;

  /// No description provided for @serviceReminders.
  ///
  /// In en, this message translates to:
  /// **'Service reminders'**
  String get serviceReminders;

  /// No description provided for @serviceRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Set reminders for rehearsals and worship services'**
  String get serviceRemindersDesc;

  /// No description provided for @blockedBySystem.
  ///
  /// In en, this message translates to:
  /// **'Blocked by system'**
  String get blockedBySystem;

  /// No description provided for @dailyReminderOff.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder off'**
  String get dailyReminderOff;

  /// No description provided for @dailyReminderAt.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder at {time}'**
  String dailyReminderAt(String time);

  /// No description provided for @newReminder.
  ///
  /// In en, this message translates to:
  /// **'New Reminder'**
  String get newReminder;

  /// No description provided for @editReminder.
  ///
  /// In en, this message translates to:
  /// **'Edit Reminder'**
  String get editReminder;

  /// No description provided for @noServiceReminders.
  ///
  /// In en, this message translates to:
  /// **'No Service Reminders Yet'**
  String get noServiceReminders;

  /// No description provided for @noServiceRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to schedule your upcoming rehearsals or choir services.'**
  String get noServiceRemindersDesc;

  /// No description provided for @serviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Service / Event Title'**
  String get serviceTitle;

  /// No description provided for @serviceDate.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get serviceDate;

  /// No description provided for @reminderNote.
  ///
  /// In en, this message translates to:
  /// **'Notes / Setlist Details'**
  String get reminderNote;

  /// No description provided for @allArtists.
  ///
  /// In en, this message translates to:
  /// **'All Artists'**
  String get allArtists;

  /// No description provided for @searchArtistsHint.
  ///
  /// In en, this message translates to:
  /// **'Search artists by name...'**
  String get searchArtistsHint;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'No Artists Found'**
  String get noArtistsFound;

  /// No description provided for @noSongsFound.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get noSongsFound;

  /// No description provided for @singlesAndStandalone.
  ///
  /// In en, this message translates to:
  /// **'Singles & Standalone'**
  String get singlesAndStandalone;

  /// No description provided for @autoScroll.
  ///
  /// In en, this message translates to:
  /// **'Auto-Scroll'**
  String get autoScroll;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @copyLyrics.
  ///
  /// In en, this message translates to:
  /// **'Copy Lyrics'**
  String get copyLyrics;

  /// No description provided for @shareLyrics.
  ///
  /// In en, this message translates to:
  /// **'Share Lyrics'**
  String get shareLyrics;

  /// No description provided for @shareCard.
  ///
  /// In en, this message translates to:
  /// **'Share Card'**
  String get shareCard;

  /// No description provided for @fullLyricsCopied.
  ///
  /// In en, this message translates to:
  /// **'Full clean lyrics copied to clipboard!'**
  String get fullLyricsCopied;

  /// No description provided for @structuredLyricsCopied.
  ///
  /// In en, this message translates to:
  /// **'Full structured lyrics copied to clipboard!'**
  String get structuredLyricsCopied;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard!'**
  String get copiedToClipboard;

  /// No description provided for @createSetlist.
  ///
  /// In en, this message translates to:
  /// **'Create Setlist'**
  String get createSetlist;

  /// No description provided for @mySetlists.
  ///
  /// In en, this message translates to:
  /// **'My Setlists'**
  String get mySetlists;

  /// No description provided for @noSetlistsYet.
  ///
  /// In en, this message translates to:
  /// **'No Setlists Yet'**
  String get noSetlistsYet;

  /// No description provided for @noSetlistsDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the \"+\" button below to create your first setlist and organize your worship songs.'**
  String get noSetlistsDesc;

  /// No description provided for @setlistCreated.
  ///
  /// In en, this message translates to:
  /// **'Setlist created successfully!'**
  String get setlistCreated;

  /// No description provided for @deleteSetlist.
  ///
  /// In en, this message translates to:
  /// **'Delete Setlist'**
  String get deleteSetlist;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteSetlistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this setlist? This cannot be undone.'**
  String get deleteSetlistConfirm;

  /// No description provided for @emptySetlist.
  ///
  /// In en, this message translates to:
  /// **'This setlist is empty. Add songs from the song detail page.'**
  String get emptySetlist;

  /// No description provided for @vocalCoaching.
  ///
  /// In en, this message translates to:
  /// **'VOCAL COACHING'**
  String get vocalCoaching;

  /// No description provided for @shapeYourVoice.
  ///
  /// In en, this message translates to:
  /// **'Shape Your Voice,'**
  String get shapeYourVoice;

  /// No description provided for @masterYourCraft.
  ///
  /// In en, this message translates to:
  /// **'Master Your Craft.'**
  String get masterYourCraft;

  /// No description provided for @pitchTrainer.
  ///
  /// In en, this message translates to:
  /// **'Pitch Trainer'**
  String get pitchTrainer;

  /// No description provided for @noGeneralExercises.
  ///
  /// In en, this message translates to:
  /// **'No general exercises available yet.'**
  String get noGeneralExercises;

  /// No description provided for @dayCompleted.
  ///
  /// In en, this message translates to:
  /// **'Day Completed!'**
  String get dayCompleted;

  /// No description provided for @completeDay.
  ///
  /// In en, this message translates to:
  /// **'Complete Day'**
  String get completeDay;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// No description provided for @genderSelectionDesc.
  ///
  /// In en, this message translates to:
  /// **'To personalize your vocal exercises, please select your vocal profile.'**
  String get genderSelectionDesc;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @targetNote.
  ///
  /// In en, this message translates to:
  /// **'Target Note'**
  String get targetNote;

  /// No description provided for @matchThePitch.
  ///
  /// In en, this message translates to:
  /// **'Match the Pitch'**
  String get matchThePitch;

  /// No description provided for @inTune.
  ///
  /// In en, this message translates to:
  /// **'In Tune!'**
  String get inTune;

  /// No description provided for @flat.
  ///
  /// In en, this message translates to:
  /// **'Flat (Too Low)'**
  String get flat;

  /// No description provided for @sharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp (Too High)'**
  String get sharp;

  /// No description provided for @playTone.
  ///
  /// In en, this message translates to:
  /// **'Play Tone'**
  String get playTone;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @guitarTuner.
  ///
  /// In en, this message translates to:
  /// **'Guitar Tuner'**
  String get guitarTuner;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @filterByScale.
  ///
  /// In en, this message translates to:
  /// **'Filter by Scale'**
  String get filterByScale;

  /// No description provided for @filterByRhythm.
  ///
  /// In en, this message translates to:
  /// **'Filter by Rhythm'**
  String get filterByRhythm;

  /// No description provided for @scales.
  ///
  /// In en, this message translates to:
  /// **'Scales'**
  String get scales;

  /// No description provided for @rhythms.
  ///
  /// In en, this message translates to:
  /// **'Rhythms'**
  String get rhythms;

  /// No description provided for @noMashupMatch.
  ///
  /// In en, this message translates to:
  /// **'No songs match the selected scale or rhythm.'**
  String get noMashupMatch;

  /// No description provided for @allLevels.
  ///
  /// In en, this message translates to:
  /// **'All Levels'**
  String get allLevels;

  /// No description provided for @noLessonsFound.
  ///
  /// In en, this message translates to:
  /// **'No lessons found.'**
  String get noLessonsFound;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Mahlete Semay'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Your complete vocal companion to grow as a Zemari, all in one place.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Find Any Mezmur'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Access a vast, searchable library of Mezmur lyrics, complete with artist and album details.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Train Your Voice'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Follow structured daily, weekly, and monthly vocal exercise plans to improve your skills.'**
  String get onboardingDesc3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In en, this message translates to:
  /// **'Master Your Service'**
  String get onboardingTitle4;

  /// No description provided for @onboardingDesc4.
  ///
  /// In en, this message translates to:
  /// **'Discover vocal lessons, scale guides, and performance tips to elevate your spiritual service.'**
  String get onboardingDesc4;

  /// No description provided for @underMaintenance.
  ///
  /// In en, this message translates to:
  /// **'We are under maintenance'**
  String get underMaintenance;

  /// No description provided for @maintenanceDesc.
  ///
  /// In en, this message translates to:
  /// **'The Mahlete Semay app is currently in repair mode. We are working hard to bring it back online shortly. Thank you for your patience!'**
  String get maintenanceDesc;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequired;

  /// No description provided for @updateRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'A newer version of Mahlete Semay is available. Please update to continue using the app.'**
  String get updateRequiredDesc;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @offlineNotice.
  ///
  /// In en, this message translates to:
  /// **'You are currently offline. Data may be limited.'**
  String get offlineNotice;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get submitForReview;

  /// No description provided for @submissionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your suggestion has been submitted for review.'**
  String get submissionSuccess;

  /// No description provided for @submissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed. Please try again.'**
  String get submissionFailed;

  /// No description provided for @mySubmissions.
  ///
  /// In en, this message translates to:
  /// **'My Submissions'**
  String get mySubmissions;

  /// No description provided for @noSubmissionsYet.
  ///
  /// In en, this message translates to:
  /// **'You have not submitted any songs yet.'**
  String get noSubmissionsYet;

  /// No description provided for @recallAndEdit.
  ///
  /// In en, this message translates to:
  /// **'Recall & Edit'**
  String get recallAndEdit;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @firstTimeHere.
  ///
  /// In en, this message translates to:
  /// **'First time here?'**
  String get firstTimeHere;

  /// No description provided for @claimAccount.
  ///
  /// In en, this message translates to:
  /// **'Claim Account'**
  String get claimAccount;

  /// No description provided for @pleaseSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue'**
  String get pleaseSignInToContinue;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @popularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get popularity;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @noFavoritesDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any song to add it to your favorites.'**
  String get noFavoritesDesc;

  /// No description provided for @noHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Your recently viewed songs will appear here.'**
  String get noHistoryDesc;

  /// No description provided for @switchToList.
  ///
  /// In en, this message translates to:
  /// **'Switch to list view'**
  String get switchToList;

  /// No description provided for @switchToGrid.
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get switchToGrid;

  /// No description provided for @albumSingular.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get albumSingular;

  /// No description provided for @albumsPlural.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albumsPlural;

  /// No description provided for @trackSingular.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get trackSingular;

  /// No description provided for @tracksPlural.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracksPlural;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @aboutExercise.
  ///
  /// In en, this message translates to:
  /// **'About Exercise'**
  String get aboutExercise;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get startOver;

  /// No description provided for @retestRange.
  ///
  /// In en, this message translates to:
  /// **'Retest Range'**
  String get retestRange;

  /// No description provided for @shareResults.
  ///
  /// In en, this message translates to:
  /// **'Share Results'**
  String get shareResults;

  /// No description provided for @trainYourVoicePitch.
  ///
  /// In en, this message translates to:
  /// **'Train Your Voice Pitch'**
  String get trainYourVoicePitch;

  /// No description provided for @practiceHittingNotes.
  ///
  /// In en, this message translates to:
  /// **'Practice hitting notes accurately with the Pitch Trainer'**
  String get practiceHittingNotes;

  /// No description provided for @famousSingers.
  ///
  /// In en, this message translates to:
  /// **'Famous Singers'**
  String get famousSingers;

  /// No description provided for @lockNote.
  ///
  /// In en, this message translates to:
  /// **'Lock Note'**
  String get lockNote;

  /// No description provided for @holdingSteady.
  ///
  /// In en, this message translates to:
  /// **'Hold note steady...'**
  String get holdingSteady;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @lowestNote.
  ///
  /// In en, this message translates to:
  /// **'Lowest Note'**
  String get lowestNote;

  /// No description provided for @highestNote.
  ///
  /// In en, this message translates to:
  /// **'Highest Note'**
  String get highestNote;

  /// No description provided for @step1FindLowest.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Find Your Lowest Note'**
  String get step1FindLowest;

  /// No description provided for @step1FindLowestDesc.
  ///
  /// In en, this message translates to:
  /// **'Hum or sing downwards to your lowest comfortable pitch and hold it steady.'**
  String get step1FindLowestDesc;

  /// No description provided for @step2FindHighest.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Find Your Highest Note'**
  String get step2FindHighest;

  /// No description provided for @step2FindHighestDesc.
  ///
  /// In en, this message translates to:
  /// **'Glide upwards to your highest comfortable note (chest or head voice) and hold it steady.'**
  String get step2FindHighestDesc;

  /// No description provided for @singNotePrompt.
  ///
  /// In en, this message translates to:
  /// **'Sing a note into the microphone first!'**
  String get singNotePrompt;

  /// No description provided for @singHighNotePrompt.
  ///
  /// In en, this message translates to:
  /// **'Sing a high note into the microphone first!'**
  String get singHighNotePrompt;

  /// No description provided for @uniqueRange.
  ///
  /// In en, this message translates to:
  /// **'Unique Range'**
  String get uniqueRange;

  /// No description provided for @micPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required.'**
  String get micPermissionRequired;

  /// No description provided for @pluckString.
  ///
  /// In en, this message translates to:
  /// **'PLUCK STRING'**
  String get pluckString;

  /// No description provided for @tooFlat.
  ///
  /// In en, this message translates to:
  /// **'TOO FLAT ▼'**
  String get tooFlat;

  /// No description provided for @tooSharp.
  ///
  /// In en, this message translates to:
  /// **'TOO SHARP ▲'**
  String get tooSharp;

  /// No description provided for @inTuneStatus.
  ///
  /// In en, this message translates to:
  /// **'IN TUNE ✓'**
  String get inTuneStatus;

  /// No description provided for @targetFrequency.
  ///
  /// In en, this message translates to:
  /// **'Target: {freq} Hz'**
  String targetFrequency(String freq);

  /// No description provided for @centsUnit.
  ///
  /// In en, this message translates to:
  /// **'CENTS'**
  String get centsUnit;

  /// No description provided for @strNumber.
  ///
  /// In en, this message translates to:
  /// **'Str {number}'**
  String strNumber(int number);

  /// No description provided for @musicalScaleKey.
  ///
  /// In en, this message translates to:
  /// **'Musical Scale (Key)'**
  String get musicalScaleKey;

  /// No description provided for @rhythmPattern.
  ///
  /// In en, this message translates to:
  /// **'Rhythm Pattern'**
  String get rhythmPattern;

  /// No description provided for @selectRhythmPattern.
  ///
  /// In en, this message translates to:
  /// **'Select a Rhythm Pattern'**
  String get selectRhythmPattern;

  /// No description provided for @selectRhythmPatternDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick a rhythm beat pattern above to display matching mashup songs.'**
  String get selectRhythmPatternDesc;

  /// No description provided for @noMatchingSongs.
  ///
  /// In en, this message translates to:
  /// **'No matching songs found'**
  String get noMatchingSongs;

  /// No description provided for @noMatchingSongsDesc.
  ///
  /// In en, this message translates to:
  /// **'Try searching with different song titles or lyric keywords'**
  String get noMatchingSongsDesc;

  /// No description provided for @syncFromServer.
  ///
  /// In en, this message translates to:
  /// **'Sync from Server'**
  String get syncFromServer;

  /// No description provided for @searchSongs.
  ///
  /// In en, this message translates to:
  /// **'Search Songs'**
  String get searchSongs;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @fetchFromServer.
  ///
  /// In en, this message translates to:
  /// **'Fetch from Server'**
  String get fetchFromServer;

  /// No description provided for @lockedLesson.
  ///
  /// In en, this message translates to:
  /// **'Locked Lesson'**
  String get lockedLesson;

  /// No description provided for @vocalRest.
  ///
  /// In en, this message translates to:
  /// **'Vocal Rest'**
  String get vocalRest;

  /// No description provided for @markAsDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as Done'**
  String get markAsDone;

  /// No description provided for @listenFirst.
  ///
  /// In en, this message translates to:
  /// **'Listen to Exercise First'**
  String get listenFirst;

  /// No description provided for @nextExercise.
  ///
  /// In en, this message translates to:
  /// **'Next Exercise'**
  String get nextExercise;

  /// No description provided for @planComplete.
  ///
  /// In en, this message translates to:
  /// **'Plan Complete!'**
  String get planComplete;

  /// No description provided for @completeDayToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Complete Day {day} to unlock this lesson.'**
  String completeDayToUnlock(int day);

  /// No description provided for @exercisesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Exercises coming soon for this plan.'**
  String get exercisesComingSoon;

  /// No description provided for @dayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {number}'**
  String dayNumber(int number);

  /// No description provided for @finishPlanReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish {title}'**
  String finishPlanReminderTitle(String title);

  /// No description provided for @finishPlanReminderBody.
  ///
  /// In en, this message translates to:
  /// **'You stopped just before Day {day}. Pick up where you left off and keep your streak going.'**
  String finishPlanReminderBody(int day);

  /// No description provided for @tutorialFilterScaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by Scale'**
  String get tutorialFilterScaleTitle;

  /// No description provided for @tutorialFilterScaleDesc.
  ///
  /// In en, this message translates to:
  /// **'First, press a scale like \'Tizita Minor\' to see all songs in that musical key.'**
  String get tutorialFilterScaleDesc;

  /// No description provided for @tutorialFilterRhythmTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by Rhythm'**
  String get tutorialFilterRhythmTitle;

  /// No description provided for @tutorialFilterRhythmDesc.
  ///
  /// In en, this message translates to:
  /// **'Then, press a rhythm like \'Waltz\' to find songs that match both the key and the beat.'**
  String get tutorialFilterRhythmDesc;

  /// No description provided for @tutorialSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Or, Search Directly'**
  String get tutorialSearchTitle;

  /// No description provided for @tutorialSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Alternatively, press the search icon to find any song by its title, artist, or lyrics.'**
  String get tutorialSearchDesc;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @contentManagement.
  ///
  /// In en, this message translates to:
  /// **'Content Management'**
  String get contentManagement;

  /// No description provided for @adminControlsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Admin Controls & Security'**
  String get adminControlsSecurity;

  /// No description provided for @addArtist.
  ///
  /// In en, this message translates to:
  /// **'Add Singer'**
  String get addArtist;

  /// No description provided for @addAlbum.
  ///
  /// In en, this message translates to:
  /// **'Add Album'**
  String get addAlbum;

  /// No description provided for @addSong.
  ///
  /// In en, this message translates to:
  /// **'Add Song'**
  String get addSong;

  /// No description provided for @manageSongs.
  ///
  /// In en, this message translates to:
  /// **'Manage Songs'**
  String get manageSongs;

  /// No description provided for @manageAlbums.
  ///
  /// In en, this message translates to:
  /// **'Manage Albums'**
  String get manageAlbums;

  /// No description provided for @manageArtists.
  ///
  /// In en, this message translates to:
  /// **'Manage Artists'**
  String get manageArtists;

  /// No description provided for @manageVocalPlans.
  ///
  /// In en, this message translates to:
  /// **'Manage Vocal Plans'**
  String get manageVocalPlans;

  /// No description provided for @manageModerators.
  ///
  /// In en, this message translates to:
  /// **'Manage Moderators'**
  String get manageModerators;

  /// No description provided for @createInvitationCode.
  ///
  /// In en, this message translates to:
  /// **'Create Invitation Code'**
  String get createInvitationCode;

  /// No description provided for @invitationCodesHistory.
  ///
  /// In en, this message translates to:
  /// **'Invitation Codes History'**
  String get invitationCodesHistory;

  /// No description provided for @auditActivityLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit Activity Logs'**
  String get auditActivityLogs;

  /// No description provided for @appAnalyticsInsights.
  ///
  /// In en, this message translates to:
  /// **'App Analytics & Insights'**
  String get appAnalyticsInsights;

  /// No description provided for @appRepairMode.
  ///
  /// In en, this message translates to:
  /// **'App Repair Mode'**
  String get appRepairMode;

  /// No description provided for @repairModeActive.
  ///
  /// In en, this message translates to:
  /// **'Active • App locked for maintenance'**
  String get repairModeActive;

  /// No description provided for @repairModeInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive • App is live & accessible'**
  String get repairModeInactive;

  /// No description provided for @generalVocalExercises.
  ///
  /// In en, this message translates to:
  /// **'General Vocal Exercises'**
  String get generalVocalExercises;

  /// No description provided for @reviewSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Review Suggestions'**
  String get reviewSuggestions;

  /// No description provided for @repairModeDialogTitleActive.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Repair Mode?'**
  String get repairModeDialogTitleActive;

  /// No description provided for @repairModeDialogTitleInactive.
  ///
  /// In en, this message translates to:
  /// **'Activate Repair Mode?'**
  String get repairModeDialogTitleInactive;

  /// No description provided for @repairModeDialogDescActive.
  ///
  /// In en, this message translates to:
  /// **'This will deactivate repair mode and unlock the app. All users will regain full access to all features immediately.'**
  String get repairModeDialogDescActive;

  /// No description provided for @repairModeDialogDescInactive.
  ///
  /// In en, this message translates to:
  /// **'This will activate repair mode and lock the app for everyone except Admins. Users will see a maintenance screen. Proceed with caution!'**
  String get repairModeDialogDescInactive;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @deletePrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete {item}?'**
  String deletePrompt(String item);

  /// No description provided for @deleteConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {item}?'**
  String deleteConfirmPrompt(String item);

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not Found'**
  String get notFound;

  /// No description provided for @possibleDuplicateDetected.
  ///
  /// In en, this message translates to:
  /// **'Possible Duplicate Detected'**
  String get possibleDuplicateDetected;

  /// No description provided for @duplicateDetectedDesc.
  ///
  /// In en, this message translates to:
  /// **'A song with a similar title or lyrics already exists in the library.'**
  String get duplicateDetectedDesc;

  /// No description provided for @viewExisting.
  ///
  /// In en, this message translates to:
  /// **'View Existing'**
  String get viewExisting;

  /// No description provided for @publishAnyway.
  ///
  /// In en, this message translates to:
  /// **'Publish Anyway'**
  String get publishAnyway;

  /// No description provided for @unsavedDraftFound.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Draft Found'**
  String get unsavedDraftFound;

  /// No description provided for @unsavedDraftDesc.
  ///
  /// In en, this message translates to:
  /// **'Would you like to restore your previous unsaved work?'**
  String get unsavedDraftDesc;

  /// No description provided for @restoreDraft.
  ///
  /// In en, this message translates to:
  /// **'Restore Draft'**
  String get restoreDraft;

  /// No description provided for @discardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard Draft'**
  String get discardDraft;

  /// No description provided for @accessRestricted.
  ///
  /// In en, this message translates to:
  /// **'Access Restricted'**
  String get accessRestricted;

  /// No description provided for @accessRestrictedDesc.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view or manage this section. Please contact your administrator.'**
  String get accessRestrictedDesc;

  /// No description provided for @createProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get createProfileSubtitle;

  /// No description provided for @uploadReleaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload release'**
  String get uploadReleaseSubtitle;

  /// No description provided for @lyricsScalesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics & scales'**
  String get lyricsScalesSubtitle;

  /// No description provided for @reviewSubmissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review submissions'**
  String get reviewSubmissionsSubtitle;

  /// No description provided for @batchEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit lyrics, scales, rhythms, and batch delete'**
  String get batchEditSubtitle;

  /// No description provided for @organizeAlbumsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize albums, covers, and track lists'**
  String get organizeAlbumsSubtitle;

  /// No description provided for @updateArtistBioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update artist photos, bio, and regions'**
  String get updateArtistBioSubtitle;

  /// No description provided for @vocalRoutinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily, weekly, monthly & quarterly routines'**
  String get vocalRoutinesSubtitle;

  /// No description provided for @independentDrillsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Independent workout audio drills'**
  String get independentDrillsSubtitle;

  /// No description provided for @deviceAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Device authorizations, role elevation, blocks'**
  String get deviceAuthSubtitle;

  /// No description provided for @generateCredentialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate secure single-use access credentials'**
  String get generateCredentialsSubtitle;

  /// No description provided for @trackInvitationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track claimed, active & pending invitations'**
  String get trackInvitationsSubtitle;

  /// No description provided for @actionTimelineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real-time moderator action timeline'**
  String get actionTimelineSubtitle;

  /// No description provided for @liveMetricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live traffic, view charts, and database metrics'**
  String get liveMetricsSubtitle;

  /// No description provided for @appAnalyticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'App Analytics'**
  String get appAnalyticsTooltip;

  /// No description provided for @dailyTrainingPlans.
  ///
  /// In en, this message translates to:
  /// **'Daily Training Plans'**
  String get dailyTrainingPlans;

  /// No description provided for @maleDailyPlan.
  ///
  /// In en, this message translates to:
  /// **'Male Daily Vocal Plan'**
  String get maleDailyPlan;

  /// No description provided for @maleDailyPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily routine drills for male vocal ranges'**
  String get maleDailyPlanSubtitle;

  /// No description provided for @femaleDailyPlan.
  ///
  /// In en, this message translates to:
  /// **'Female Daily Vocal Plan'**
  String get femaleDailyPlan;

  /// No description provided for @femaleDailyPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily routine drills for female vocal ranges'**
  String get femaleDailyPlanSubtitle;

  /// No description provided for @weeklyCurriculums.
  ///
  /// In en, this message translates to:
  /// **'Weekly 7-Day Curriculums'**
  String get weeklyCurriculums;

  /// No description provided for @maleWeeklyPlan.
  ///
  /// In en, this message translates to:
  /// **'Male Weekly Plan'**
  String get maleWeeklyPlan;

  /// No description provided for @femaleWeeklyPlan.
  ///
  /// In en, this message translates to:
  /// **'Female Weekly Plan'**
  String get femaleWeeklyPlan;

  /// No description provided for @weeklyPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Structured 7-day progressive workout'**
  String get weeklyPlanSubtitle;

  /// No description provided for @monthlyIntensives.
  ///
  /// In en, this message translates to:
  /// **'Monthly 30-Day Intensives'**
  String get monthlyIntensives;

  /// No description provided for @maleMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Male Monthly Plan'**
  String get maleMonthlyPlan;

  /// No description provided for @femaleMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Female Monthly Plan'**
  String get femaleMonthlyPlan;

  /// No description provided for @monthlyPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'30-day stamina and range expansion'**
  String get monthlyPlanSubtitle;

  /// No description provided for @quarterlyMasteries.
  ///
  /// In en, this message translates to:
  /// **'Quarterly (90-Day) Masteries'**
  String get quarterlyMasteries;

  /// No description provided for @maleQuarterlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Male Quarterly Plan'**
  String get maleQuarterlyPlan;

  /// No description provided for @femaleQuarterlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Female Quarterly Plan'**
  String get femaleQuarterlyPlan;

  /// No description provided for @quarterlyPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive 3-month vocal mastery'**
  String get quarterlyPlanSubtitle;

  /// No description provided for @exerciseInformation.
  ///
  /// In en, this message translates to:
  /// **'Exercise Information'**
  String get exerciseInformation;

  /// No description provided for @exerciseAudioGuide.
  ///
  /// In en, this message translates to:
  /// **'Exercise Audio Guide'**
  String get exerciseAudioGuide;

  /// No description provided for @uploadAudio.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadAudio;

  /// No description provided for @changeAudio.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeAudio;

  /// No description provided for @restDayBadge.
  ///
  /// In en, this message translates to:
  /// **'REST DAY'**
  String get restDayBadge;

  /// No description provided for @audioAttachedBadge.
  ///
  /// In en, this message translates to:
  /// **'AUDIO ATTACHED'**
  String get audioAttachedBadge;

  /// No description provided for @failedToLoadPlanDays.
  ///
  /// In en, this message translates to:
  /// **'Failed to load plan days'**
  String get failedToLoadPlanDays;

  /// No description provided for @noDaysAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No Days Added Yet'**
  String get noDaysAddedYet;

  /// No description provided for @cropCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Crop Cover Image'**
  String get cropCoverImage;

  /// No description provided for @cropArtistPhoto.
  ///
  /// In en, this message translates to:
  /// **'Crop Artist Photo'**
  String get cropArtistPhoto;

  /// No description provided for @albumArtistSection.
  ///
  /// In en, this message translates to:
  /// **'Album Artist'**
  String get albumArtistSection;

  /// No description provided for @selectArtistPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select Artist *'**
  String get selectArtistPrompt;

  /// No description provided for @albumDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Album Details'**
  String get albumDetailsSection;

  /// No description provided for @albumCoverOptional.
  ///
  /// In en, this message translates to:
  /// **'Album Cover Art (Optional)'**
  String get albumCoverOptional;

  /// No description provided for @albumCoverArt.
  ///
  /// In en, this message translates to:
  /// **'Album Cover Art'**
  String get albumCoverArt;

  /// No description provided for @changeCover.
  ///
  /// In en, this message translates to:
  /// **'Change Cover'**
  String get changeCover;

  /// No description provided for @artistInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Artist Information'**
  String get artistInfoSection;

  /// No description provided for @artistPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Artist Photo (Optional)'**
  String get artistPhotoOptional;

  /// No description provided for @artistPhoto.
  ///
  /// In en, this message translates to:
  /// **'Artist Photo'**
  String get artistPhoto;

  /// No description provided for @saveArtistChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Artist Changes'**
  String get saveArtistChanges;

  /// No description provided for @saveAlbumChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Album Changes'**
  String get saveAlbumChanges;

  /// No description provided for @revert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revert;

  /// No description provided for @songAssociationSection.
  ///
  /// In en, this message translates to:
  /// **'Song Association'**
  String get songAssociationSection;

  /// No description provided for @selectAlbumPrompt.
  ///
  /// In en, this message translates to:
  /// **'2. Select Album *'**
  String get selectAlbumPrompt;

  /// No description provided for @songDetailsMetadataSection.
  ///
  /// In en, this message translates to:
  /// **'Song Details & Metadata'**
  String get songDetailsMetadataSection;

  /// No description provided for @songDetailsLyricsSection.
  ///
  /// In en, this message translates to:
  /// **'Song Details & Lyrics'**
  String get songDetailsLyricsSection;

  /// No description provided for @updateSongChanges.
  ///
  /// In en, this message translates to:
  /// **'Update Song Changes'**
  String get updateSongChanges;

  /// No description provided for @keyPlatformMetrics.
  ///
  /// In en, this message translates to:
  /// **'Key Platform Metrics'**
  String get keyPlatformMetrics;

  /// No description provided for @totalSongs.
  ///
  /// In en, this message translates to:
  /// **'Total Songs'**
  String get totalSongs;

  /// No description provided for @totalArtists.
  ///
  /// In en, this message translates to:
  /// **'Total Artists'**
  String get totalArtists;

  /// No description provided for @totalAlbums.
  ///
  /// In en, this message translates to:
  /// **'Total Albums'**
  String get totalAlbums;

  /// No description provided for @totalSongViews.
  ///
  /// In en, this message translates to:
  /// **'Total Song Views'**
  String get totalSongViews;

  /// No description provided for @songsAdded7Days.
  ///
  /// In en, this message translates to:
  /// **'Songs Added (Last 7 Days)'**
  String get songsAdded7Days;

  /// No description provided for @artistDistributionBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Artist Distribution Breakdown'**
  String get artistDistributionBreakdown;

  /// No description provided for @top5ViewedSongs.
  ///
  /// In en, this message translates to:
  /// **'Top 5 Most Viewed Songs'**
  String get top5ViewedSongs;

  /// No description provided for @noSongViewsYet.
  ///
  /// In en, this message translates to:
  /// **'No Song Views Yet'**
  String get noSongViewsYet;

  /// No description provided for @topRecommendedArtists.
  ///
  /// In en, this message translates to:
  /// **'Top Recommended Artists'**
  String get topRecommendedArtists;

  /// No description provided for @allModeratorsDropdown.
  ///
  /// In en, this message translates to:
  /// **'All Moderators'**
  String get allModeratorsDropdown;

  /// No description provided for @noActivityLogged.
  ///
  /// In en, this message translates to:
  /// **'No Activity Logged'**
  String get noActivityLogged;

  /// No description provided for @searchActionsOrNames.
  ///
  /// In en, this message translates to:
  /// **'Search actions or names...'**
  String get searchActionsOrNames;

  /// No description provided for @noMatchingLogs.
  ///
  /// In en, this message translates to:
  /// **'No Matching Logs'**
  String get noMatchingLogs;

  /// No description provided for @historyButton.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyButton;

  /// No description provided for @invitationCodeReady.
  ///
  /// In en, this message translates to:
  /// **'Invitation Code Ready!'**
  String get invitationCodeReady;

  /// Localization for roleBadgePrefix
  ///
  /// In en, this message translates to:
  /// **'ROLE: {role}'**
  String roleBadgePrefix(String role);

  /// No description provided for @shareInvitation.
  ///
  /// In en, this message translates to:
  /// **'Share Invitation'**
  String get shareInvitation;

  /// No description provided for @inviteeDetails.
  ///
  /// In en, this message translates to:
  /// **'Invitee Details'**
  String get inviteeDetails;

  /// No description provided for @moderatorRoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Moderator (Content Editor)'**
  String get moderatorRoleDesc;

  /// No description provided for @adminRoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Administrator (Full Control)'**
  String get adminRoleDesc;

  /// No description provided for @generateInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Generate Invitation Code'**
  String get generateInviteCode;

  /// No description provided for @approveDevice.
  ///
  /// In en, this message translates to:
  /// **'Approve Device'**
  String get approveDevice;

  /// No description provided for @rejectAction.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectAction;

  /// No description provided for @permanentlyRemoveMod.
  ///
  /// In en, this message translates to:
  /// **'Permanently Remove Moderator Account'**
  String get permanentlyRemoveMod;

  /// No description provided for @searchByNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search by name or email...'**
  String get searchByNameOrEmail;

  /// No description provided for @noModeratorsFound.
  ///
  /// In en, this message translates to:
  /// **'No Moderators Found'**
  String get noModeratorsFound;

  /// No description provided for @underReviewFilter.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get underReviewFilter;

  /// No description provided for @blockedFilter.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blockedFilter;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @activeFilter.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeFilter;

  /// No description provided for @pendingTab.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingTab;

  /// No description provided for @approvedTab.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvedTab;

  /// No description provided for @rejectedTab.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejectedTab;

  /// No description provided for @noSuggestionsSubmitted.
  ///
  /// In en, this message translates to:
  /// **'No Suggestions Submitted'**
  String get noSuggestionsSubmitted;

  /// No description provided for @allClear.
  ///
  /// In en, this message translates to:
  /// **'All Clear'**
  String get allClear;

  /// No description provided for @searchYouTubeForAudioRef.
  ///
  /// In en, this message translates to:
  /// **'Search YouTube for Audio Reference'**
  String get searchYouTubeForAudioRef;

  /// No description provided for @selectArtistToSeeAlbums.
  ///
  /// In en, this message translates to:
  /// **'Select an artist to see their albums'**
  String get selectArtistToSeeAlbums;

  /// No description provided for @noArtistsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No artists in this category.'**
  String get noArtistsInCategory;

  /// Localization for noResultsFoundFor
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String noResultsFoundFor(String query);

  /// No description provided for @songNotFound.
  ///
  /// In en, this message translates to:
  /// **'Song Not Found'**
  String get songNotFound;

  /// No description provided for @pleaseRemove.
  ///
  /// In en, this message translates to:
  /// **'Please remove'**
  String get pleaseRemove;

  /// Localization for editDetailsFor
  ///
  /// In en, this message translates to:
  /// **'Edit Details for \"{title}\"'**
  String editDetailsFor(String title);

  /// No description provided for @customKeyField.
  ///
  /// In en, this message translates to:
  /// **'Custom Key (e.g., G#)'**
  String get customKeyField;

  /// No description provided for @performanceNotesField.
  ///
  /// In en, this message translates to:
  /// **'Performance Notes'**
  String get performanceNotesField;

  /// Localization for keyPrefix
  ///
  /// In en, this message translates to:
  /// **'Key: {key}'**
  String keyPrefix(String key);

  /// No description provided for @quoteInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter or edit lyrics quote here...'**
  String get quoteInputHint;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @applyLyricsText.
  ///
  /// In en, this message translates to:
  /// **'Apply Lyrics Text'**
  String get applyLyricsText;

  /// No description provided for @shareStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Studio'**
  String get shareStudioTitle;

  /// No description provided for @editText.
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get editText;

  /// No description provided for @shareStudioTitleOption.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get shareStudioTitleOption;

  /// No description provided for @shareStudioAppLogoOption.
  ///
  /// In en, this message translates to:
  /// **'App Logo'**
  String get shareStudioAppLogoOption;

  /// No description provided for @shareStudioArtistNameOption.
  ///
  /// In en, this message translates to:
  /// **'Artist Name'**
  String get shareStudioArtistNameOption;

  /// No description provided for @shareStudioWavesOption.
  ///
  /// In en, this message translates to:
  /// **'Waves / Ambient'**
  String get shareStudioWavesOption;

  /// No description provided for @selectLinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Lines'**
  String get selectLinesTitle;

  /// No description provided for @selectLinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick exact verses'**
  String get selectLinesSubtitle;

  /// No description provided for @copyQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy Quote'**
  String get copyQuoteTitle;

  /// No description provided for @copyQuoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'With artist credit'**
  String get copyQuoteSubtitle;

  /// No description provided for @cleanLyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean Lyrics'**
  String get cleanLyricsTitle;

  /// No description provided for @cleanLyricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Without tags'**
  String get cleanLyricsSubtitle;

  /// No description provided for @fullStructureTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Structure'**
  String get fullStructureTitle;

  /// No description provided for @fullStructureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verses & Chorus'**
  String get fullStructureSubtitle;

  /// No description provided for @alignLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get alignLeft;

  /// No description provided for @alignCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get alignCenter;

  /// No description provided for @setlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Setlist Name'**
  String get setlistNameHint;

  /// No description provided for @daysCountdown.
  ///
  /// In en, this message translates to:
  /// **'DAYS'**
  String get daysCountdown;

  /// No description provided for @hoursCountdown.
  ///
  /// In en, this message translates to:
  /// **'HRS'**
  String get hoursCountdown;

  /// No description provided for @minutesCountdown.
  ///
  /// In en, this message translates to:
  /// **'MIN'**
  String get minutesCountdown;

  /// No description provided for @secondsCountdown.
  ///
  /// In en, this message translates to:
  /// **'SEC'**
  String get secondsCountdown;

  /// No description provided for @setYourFirstReminder.
  ///
  /// In en, this message translates to:
  /// **'Set Your First Reminder'**
  String get setYourFirstReminder;

  /// No description provided for @cancelReminderPrompt.
  ///
  /// In en, this message translates to:
  /// **'Cancel Reminder'**
  String get cancelReminderPrompt;

  /// No description provided for @keepAction.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keepAction;

  /// No description provided for @confirmSchedule.
  ///
  /// In en, this message translates to:
  /// **'Confirm Schedule'**
  String get confirmSchedule;

  /// No description provided for @addAnyway.
  ///
  /// In en, this message translates to:
  /// **'Add Anyway'**
  String get addAnyway;

  /// No description provided for @serviceTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Title'**
  String get serviceTitleLabel;

  /// No description provided for @serviceTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Sunday Worship'**
  String get serviceTitleHint;

  /// No description provided for @dateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTimeLabel;

  /// No description provided for @reminderNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get reminderNotesLabel;

  /// No description provided for @reminderNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Song set, rehearsal notes, etc.'**
  String get reminderNotesHint;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @newSongsAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'New songs & content'**
  String get newSongsAlertTitle;

  /// No description provided for @notificationsBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked'**
  String get notificationsBlockedTitle;

  /// No description provided for @remindersLateTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders may arrive late'**
  String get remindersLateTitle;

  /// No description provided for @signOutAndReturn.
  ///
  /// In en, this message translates to:
  /// **'Sign Out & Return'**
  String get signOutAndReturn;

  /// No description provided for @filterAndSort.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get filterAndSort;

  /// No description provided for @lessonLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get lessonLevel;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get sortOldest;

  /// No description provided for @sortPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get sortPopular;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @analyzedRange.
  ///
  /// In en, this message translates to:
  /// **'Analyzed Range'**
  String get analyzedRange;

  /// No description provided for @lowNote.
  ///
  /// In en, this message translates to:
  /// **'Low Note'**
  String get lowNote;

  /// No description provided for @highNote.
  ///
  /// In en, this message translates to:
  /// **'High Note'**
  String get highNote;

  /// No description provided for @micPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone Permission Required'**
  String get micPermissionTitle;

  /// No description provided for @notifPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Required'**
  String get notifPermissionTitle;

  /// No description provided for @photosPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo Library Permission Required'**
  String get photosPermissionTitle;

  /// No description provided for @cameraPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Permission Required'**
  String get cameraPermissionTitle;

  /// No description provided for @audioAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Access Required'**
  String get audioAccessTitle;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @grantAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Grant & Continue'**
  String get grantAndContinue;

  /// No description provided for @searchDropdownHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchDropdownHint;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @selectItemFromList.
  ///
  /// In en, this message translates to:
  /// **'Select an item from the list'**
  String get selectItemFromList;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'A newer version of Mahlete Semay is available. Please update to continue using the app.'**
  String get updateRequiredMessage;

  /// No description provided for @updateNowButton.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNowButton;

  /// No description provided for @dayNumberCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Day Number in Curriculum *'**
  String get dayNumberCurriculum;

  /// No description provided for @dayNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Day number is required'**
  String get dayNumberRequired;

  /// No description provided for @exerciseTitleField.
  ///
  /// In en, this message translates to:
  /// **'Exercise Title *'**
  String get exerciseTitleField;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @descriptionInstructionsField.
  ///
  /// In en, this message translates to:
  /// **'Description & Instructions *'**
  String get descriptionInstructionsField;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;

  /// No description provided for @restDayPrompt.
  ///
  /// In en, this message translates to:
  /// **'Is this a Rest & Recovery Day?'**
  String get restDayPrompt;

  /// No description provided for @restDayDescription.
  ///
  /// In en, this message translates to:
  /// **'Rest days do not require audio drills.'**
  String get restDayDescription;

  /// No description provided for @audioDrillAttached.
  ///
  /// In en, this message translates to:
  /// **'Audio drill attached'**
  String get audioDrillAttached;

  /// No description provided for @noAudioFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No audio file selected'**
  String get noAudioFileSelected;

  /// No description provided for @readyForPlayback.
  ///
  /// In en, this message translates to:
  /// **'Ready for playback'**
  String get readyForPlayback;

  /// No description provided for @uploadAudioDrillPrompt.
  ///
  /// In en, this message translates to:
  /// **'Upload MP3, WAV, or AAC audio drill'**
  String get uploadAudioDrillPrompt;

  /// No description provided for @editVocalDrill.
  ///
  /// In en, this message translates to:
  /// **'Edit Vocal Drill'**
  String get editVocalDrill;

  /// No description provided for @addVocalDrill.
  ///
  /// In en, this message translates to:
  /// **'Add Vocal Drill'**
  String get addVocalDrill;

  /// No description provided for @publishVocalDrill.
  ///
  /// In en, this message translates to:
  /// **'Publish Vocal Drill'**
  String get publishVocalDrill;

  /// No description provided for @saveDrillChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Drill Changes'**
  String get saveDrillChanges;

  /// No description provided for @addFirstDay.
  ///
  /// In en, this message translates to:
  /// **'Add First Day'**
  String get addFirstDay;

  /// No description provided for @startBuildingCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Start building this vocal curriculum by adding Day 1.'**
  String get startBuildingCurriculum;

  /// No description provided for @deleteDay.
  ///
  /// In en, this message translates to:
  /// **'Delete Day'**
  String get deleteDay;

  /// No description provided for @scheduledRest.
  ///
  /// In en, this message translates to:
  /// **'Scheduled vocal rest & recovery'**
  String get scheduledRest;

  /// No description provided for @noInvitationsFound.
  ///
  /// In en, this message translates to:
  /// **'No Invitations Found'**
  String get noInvitationsFound;

  /// No description provided for @noExercisesFound.
  ///
  /// In en, this message translates to:
  /// **'No General Exercises'**
  String get noExercisesFound;

  /// No description provided for @failedToLoadExercises.
  ///
  /// In en, this message translates to:
  /// **'Failed to load exercises'**
  String get failedToLoadExercises;

  /// No description provided for @checkingForDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Checking for duplicates...'**
  String get checkingForDuplicates;

  /// No description provided for @saveAndPublishAlbum.
  ///
  /// In en, this message translates to:
  /// **'Save & Publish Album'**
  String get saveAndPublishAlbum;

  /// Localization for centsOffset
  ///
  /// In en, this message translates to:
  /// **'{offset} cents'**
  String centsOffset(String offset);

  /// No description provided for @filterByAction.
  ///
  /// In en, this message translates to:
  /// **'Action Type'**
  String get filterByAction;

  /// No description provided for @moderatorRole.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderatorRole;

  /// No description provided for @activityEventDetails.
  ///
  /// In en, this message translates to:
  /// **'Activity Event Details'**
  String get activityEventDetails;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @noActivityLoggedDesc.
  ///
  /// In en, this message translates to:
  /// **'No admin or moderator activities have been recorded yet.'**
  String get noActivityLoggedDesc;

  /// No description provided for @noMatchingLogsDesc.
  ///
  /// In en, this message translates to:
  /// **'No activity matches your active search and filter filters.'**
  String get noMatchingLogsDesc;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @failedToLoadAlbums.
  ///
  /// In en, this message translates to:
  /// **'Failed to load albums'**
  String get failedToLoadAlbums;

  /// No description provided for @deleteSelectedAlbumsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} Album(s)?'**
  String deleteSelectedAlbumsTitle(Object count);

  /// No description provided for @deleteSelectedArtistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} Artist(s)?'**
  String deleteSelectedArtistsTitle(Object count);

  /// No description provided for @failedToLoadArtists.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artists'**
  String get failedToLoadArtists;

  /// No description provided for @deleteExercisePrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete Exercise?'**
  String get deleteExercisePrompt;

  /// No description provided for @deleteExerciseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String deleteExerciseConfirm(Object title);

  /// No description provided for @deleteInvitePrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete Invitation?'**
  String get deleteInvitePrompt;

  /// No description provided for @deleteInviteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the invitation code for \"{email}\"?'**
  String deleteInviteConfirm(Object email);

  /// No description provided for @removeModPrompt.
  ///
  /// In en, this message translates to:
  /// **'Remove Moderator?'**
  String get removeModPrompt;

  /// No description provided for @removeModConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to completely remove \"{name}\" from the team?'**
  String removeModConfirm(Object name);

  /// No description provided for @failedToLoadSongs.
  ///
  /// In en, this message translates to:
  /// **'Failed to load songs'**
  String get failedToLoadSongs;

  /// No description provided for @deleteSuggestionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete Suggestion?'**
  String get deleteSuggestionPrompt;

  /// No description provided for @deleteSuggestionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this submission?'**
  String get deleteSuggestionConfirm;

  /// No description provided for @deleteAlbumPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete Album?'**
  String get deleteAlbumPrompt;

  /// No description provided for @deleteAlbumConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? This cannot be undone.'**
  String deleteAlbumConfirm(Object title);

  /// No description provided for @deleteArtistPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete Artist?'**
  String get deleteArtistPrompt;

  /// No description provided for @deleteArtistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This will impact attached albums and songs.'**
  String deleteArtistConfirm(Object name);

  /// No description provided for @deleteSongPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete Song?'**
  String get deleteSongPrompt;

  /// No description provided for @deleteSongConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? This cannot be undone.'**
  String deleteSongConfirm(Object title);

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @searchAlbumsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by album title or artist...'**
  String get searchAlbumsHint;

  /// No description provided for @noAlbumsFound.
  ///
  /// In en, this message translates to:
  /// **'No Albums Found'**
  String get noAlbumsFound;

  /// No description provided for @searchSongsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title, artist, or lyrics...'**
  String get searchSongsHint;

  /// No description provided for @discoverAmazingMusic.
  ///
  /// In en, this message translates to:
  /// **'Discover your favorite music'**
  String get discoverAmazingMusic;

  /// No description provided for @filterSearch.
  ///
  /// In en, this message translates to:
  /// **'Filter Search'**
  String get filterSearch;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get views;

  /// No description provided for @plays.
  ///
  /// In en, this message translates to:
  /// **'plays'**
  String get plays;

  /// No description provided for @shareAndCopyHub.
  ///
  /// In en, this message translates to:
  /// **'Share & Copy Hub'**
  String get shareAndCopyHub;

  /// No description provided for @quoteCardStudio.
  ///
  /// In en, this message translates to:
  /// **'Quote Card Studio'**
  String get quoteCardStudio;

  /// No description provided for @selectLines.
  ///
  /// In en, this message translates to:
  /// **'Select Lines'**
  String get selectLines;

  /// No description provided for @copyQuote.
  ///
  /// In en, this message translates to:
  /// **'Copy Quote'**
  String get copyQuote;

  /// No description provided for @cleanLyrics.
  ///
  /// In en, this message translates to:
  /// **'Clean Lyrics'**
  String get cleanLyrics;

  /// No description provided for @fullStructure.
  ///
  /// In en, this message translates to:
  /// **'Full Structure'**
  String get fullStructure;

  /// No description provided for @shareFullText.
  ///
  /// In en, this message translates to:
  /// **'Share Full Text via Apps...'**
  String get shareFullText;

  /// No description provided for @lyricsTypographyStyle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Typography & Style'**
  String get lyricsTypographyStyle;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get fontFamily;

  /// No description provided for @lyricsSize.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Size'**
  String get lyricsSize;

  /// No description provided for @alignment.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get alignment;

  /// No description provided for @spacing.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get spacing;

  /// No description provided for @addToSetlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Setlist'**
  String get addToSetlist;

  /// No description provided for @typographyAndSize.
  ///
  /// In en, this message translates to:
  /// **'Typography & Size'**
  String get typographyAndSize;

  /// No description provided for @shareCardButton.
  ///
  /// In en, this message translates to:
  /// **'Share Card'**
  String get shareCardButton;

  /// No description provided for @copyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyButton;

  /// No description provided for @shareTextButton.
  ///
  /// In en, this message translates to:
  /// **'Share Text'**
  String get shareTextButton;

  /// No description provided for @errorPickingAudio.
  ///
  /// In en, this message translates to:
  /// **'Error picking audio file'**
  String get errorPickingAudio;

  /// No description provided for @audioUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio upload failed. Please try again.'**
  String get audioUploadFailed;

  /// No description provided for @audioRequired.
  ///
  /// In en, this message translates to:
  /// **'An audio file is required for this vocal exercise.'**
  String get audioRequired;

  /// No description provided for @exerciseUpdated.
  ///
  /// In en, this message translates to:
  /// **'Exercise updated successfully!'**
  String get exerciseUpdated;

  /// No description provided for @exerciseAdded.
  ///
  /// In en, this message translates to:
  /// **'Exercise added successfully!'**
  String get exerciseAdded;

  /// No description provided for @failedToSaveExercise.
  ///
  /// In en, this message translates to:
  /// **'Failed to save exercise'**
  String get failedToSaveExercise;

  /// No description provided for @uploadingAudio.
  ///
  /// In en, this message translates to:
  /// **'Uploading audio file'**
  String get uploadingAudio;

  /// No description provided for @dayDeleted.
  ///
  /// In en, this message translates to:
  /// **'Day deleted successfully.'**
  String get dayDeleted;

  /// No description provided for @failedToDeleteDay.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete day'**
  String get failedToDeleteDay;

  /// No description provided for @addDay.
  ///
  /// In en, this message translates to:
  /// **'Add Day'**
  String get addDay;

  /// No description provided for @noSetlistsCreatedYet.
  ///
  /// In en, this message translates to:
  /// **'No setlists created yet.'**
  String get noSetlistsCreatedYet;

  /// No description provided for @createNewSetlist.
  ///
  /// In en, this message translates to:
  /// **'Create New Setlist'**
  String get createNewSetlist;

  /// No description provided for @newSetlist.
  ///
  /// In en, this message translates to:
  /// **'New Setlist'**
  String get newSetlist;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterName;

  /// No description provided for @setlistCreatedAndSongAdded.
  ///
  /// In en, this message translates to:
  /// **'Setlist created and song added!'**
  String get setlistCreatedAndSongAdded;

  /// No description provided for @addedSongToSetlist.
  ///
  /// In en, this message translates to:
  /// **'Added \"{songTitle}\" to \"{setlistName}\"'**
  String addedSongToSetlist(String songTitle, String setlistName);

  /// No description provided for @createdAgo.
  ///
  /// In en, this message translates to:
  /// **'Created {timeAgo}'**
  String createdAgo(String timeAgo);

  /// No description provided for @lastActive.
  ///
  /// In en, this message translates to:
  /// **'Last Active'**
  String get lastActive;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @currentDevice.
  ///
  /// In en, this message translates to:
  /// **'Current Device'**
  String get currentDevice;

  /// No description provided for @noneBound.
  ///
  /// In en, this message translates to:
  /// **'None bound'**
  String get noneBound;

  /// No description provided for @demoteToModerator.
  ///
  /// In en, this message translates to:
  /// **'Demote to Moderator'**
  String get demoteToModerator;

  /// No description provided for @promoteToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Promote to Admin'**
  String get promoteToAdmin;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get chooseLanguageTitle;

  /// No description provided for @chooseLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language to continue to the app.'**
  String get chooseLanguageSubtitle;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @languageSelectionNote.
  ///
  /// In en, this message translates to:
  /// **'You can always change your language anytime in Settings.'**
  String get languageSelectionNote;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @amharicLanguage.
  ///
  /// In en, this message translates to:
  /// **'አማርኛ'**
  String get amharicLanguage;

  /// No description provided for @oromoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Afaan Oromoo'**
  String get oromoLanguage;

  /// No description provided for @tigrinyaLanguage.
  ///
  /// In en, this message translates to:
  /// **'ትግርኛ'**
  String get tigrinyaLanguage;

  /// No description provided for @somaliLanguage.
  ///
  /// In en, this message translates to:
  /// **'Af Soomaali'**
  String get somaliLanguage;

  /// No description provided for @englishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spiritual Hymns & Vocal Training'**
  String get englishSubtitle;

  /// No description provided for @amharicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'የመንፈሳዊ ዝማሬዎች እና የድምፅ ስልጠና'**
  String get amharicSubtitle;

  /// No description provided for @oromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Faarfannaa fi Leenjii Sagalee'**
  String get oromoSubtitle;

  /// No description provided for @tigrinyaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'መንፈሳዊ ዝማሬን ስልጠና ድምጽን'**
  String get tigrinyaSubtitle;

  /// No description provided for @somaliSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Heesaha Ruuxiga iyo Tababarka Codka'**
  String get somaliSubtitle;

  /// No description provided for @appPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'App Permissions'**
  String get appPermissionsTitle;

  /// No description provided for @permissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable these permissions for the best spiritual & vocal training experience.'**
  String get permissionsSubtitle;

  /// No description provided for @micPermissionDesc.
  ///
  /// In en, this message translates to:
  /// **'Required for real-time vocal pitch detection, range finder, and chord-matching training modules.'**
  String get micPermissionDesc;

  /// No description provided for @notifPermissionDesc.
  ///
  /// In en, this message translates to:
  /// **'Get timely reminders for your daily vocal workouts and service alerts on schedule.'**
  String get notifPermissionDesc;

  /// No description provided for @configureLater.
  ///
  /// In en, this message translates to:
  /// **'Configure Later in Settings'**
  String get configureLater;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get permissionGranted;

  /// No description provided for @privacyAssurance.
  ///
  /// In en, this message translates to:
  /// **'🔒 Your privacy is protected. Audio is processed on-device only and never uploaded.'**
  String get privacyAssurance;

  /// No description provided for @enableMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Enable Microphone'**
  String get enableMicrophone;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @allowAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow Access'**
  String get allowAccess;

  /// No description provided for @allPermissionsGranted.
  ///
  /// In en, this message translates to:
  /// **'All permissions granted!'**
  String get allPermissionsGranted;

  /// No description provided for @onDeviceProcessingOnly.
  ///
  /// In en, this message translates to:
  /// **'100% On-Device Processing'**
  String get onDeviceProcessingOnly;
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
      <String>['am', 'en', 'om', 'so', 'ti'].contains(locale.languageCode);

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
    case 'om':
      return AppLocalizationsOm();
    case 'so':
      return AppLocalizationsSo();
    case 'ti':
      return AppLocalizationsTi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
