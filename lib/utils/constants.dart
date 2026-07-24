import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/performance_tip_model.dart';

const String singlesArtistId = 'singles_artist';
const String singlesAlbumId = 'singles_album';

const String prefPermissionsCompleted = 'permissions_completed';
const String prefOnboardingCompleted = 'onboarding_completed';
const String prefGuidedTourCompletedV2 = 'guided_tour_completed_v2';
const String prefMashupTourCompletedV2 = 'mashup_helper_tour_completed_v2';
const String prefLastSyncTimestamp = 'lastSyncTimestamp';
const String prefFirstSyncCompleted = 'isFirstSyncCompleted';
const String prefDailyRemindersEnabled = 'dailyRemindersEnabled';
const String prefUserGender = 'userGender';
const String prefLastCompletionDate = 'lastCompletionDate';
const String prefIsDarkMode = 'isDarkMode';
const String prefLyricsFontSize = 'lyricsFontSize';
const String prefSongHistory = 'songHistory';
const String prefFavoriteSongIds = 'favoriteSongIds';
const String prefSubmissionHistory = 'submissionHistory';
const String prefSearchHistory = 'searchHistory';
const String prefServiceReminderDateTime = 'serviceReminderDateTime';

const String planMaleDaily = 'male_daily';
const String planFemaleDaily = 'female_daily';
const String planMaleWeekly = 'male_weekly';
const String planFemaleWeekly = 'female_weekly';
const String planMaleMonthly = 'male_monthly';
const String planFemaleMonthly = 'female_monthly';
const String planMaleQuarterly = 'male_quarterly';
const String planFemaleQuarterly = 'female_quarterly';
const String progressSuffix = '_progress';

const String tableArtists = 'artists';
const String tableAlbums = 'albums';
const String tableSongs = 'songs';
const String tableSetlists = 'setlists';
const String tableSetlistSongs = 'setlist_songs';

const String notificationPayloadVocalExercises = 'vocal_exercises';
const int dailyReminderNotificationId = 100;
const int continuationReminderId = 200;
const int serviceReminderNotificationIdBase = 300;

enum HomePageTab { lyrics, mashup, setlists, exercises, range, lessons }

final List<String> scaleMenuItems = [
  '1st (Major Scale)',
  '2nd (Dorian Mode)',
  '5th (Mixolydian Mode)',
  '6th (Natural minor)',
  'Tizita Minor',
  'Ambassel',
  'Anchi Hoy',
  'Bati',
  'Blues',
  'Other',
];

final Map<String, TextStyle> fontPresets = {
  'Montserrat': GoogleFonts.montserrat(),
  'Lora': GoogleFonts.lora(),
  'Playfair': GoogleFonts.playfairDisplay(),
  'Oswald': GoogleFonts.oswald(),
  'Roboto Slab': GoogleFonts.robotoSlab(),
};

final List<Gradient> gradientPresets = [
  const LinearGradient(colors: [Color(0xff434343), Color(0xff000000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  const LinearGradient(colors: [Color(0xff0f2027), Color(0xff203a43), Color(0xff2c5364)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  const LinearGradient(colors: [Color(0xff373B44), Color(0xff4286f4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  const LinearGradient(colors: [Color(0xff4b6cb7), Color(0xff182848)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  const LinearGradient(colors: [Color(0xffc31432), Color(0xff240b36)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  const LinearGradient(colors: [Color(0xff159957), Color(0xff155799)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  const LinearGradient(colors: [Color(0xfff2709c), Color(0xffff9472)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  const LinearGradient(colors: [Color(0xff8A2387), Color(0xffE94057), Color(0xffF27121)], begin: Alignment.topLeft, end: Alignment.bottomRight),
];

final List<Color> solidColorPresets = [
  const Color(0xff0D47A1),
  const Color(0xff1a1a1a),
  const Color(0xff606c38),
  const Color(0xff283618),
  const Color(0xfffefae0),
  const Color(0xffdda15e),
  const Color(0xffbc6c25),
];

final List<String> rhythmMenuItems = [
  'Waltz',
  'Reggae',
  'Wello',
  'Chickchika',
  'Disco',
  'Ballad',
  'Swing',
  '6/8',
  'Other',
];

final List<PerformanceTip> demoPerformanceTips = [
  PerformanceTip('t1', 'Connect with the Message', 'Before you sing a word, understand and feel the lyrics. Your primary role is to communicate a message. When you believe it, the audience will feel it.'),
  PerformanceTip('t2', 'Use the Stage', 'Don\'t be a statue. Move with purpose during instrumental breaks. Step forward during powerful moments and engage with different sections of the audience.'),
  PerformanceTip('t3', 'Engage, Don\'t Just Perform', 'Make eye contact. Smile. Invite the congregation to worship with you through your expressions. You are a leader, not just a singer.'),
  PerformanceTip('t4', 'Master Microphone Technique', 'Pull the mic away slightly on loud, high notes to avoid distortion. Bring it closer for softer, more intimate parts. This simple act dramatically improves the listening experience.'),
  PerformanceTip('t5', 'The Power of Stillness', 'Movement is good, but intentional stillness can be even more powerful. During a profound lyrical moment, standing still can draw all the attention to the message of the song.'),
  PerformanceTip('t6', 'Warm-Up is Non-Negotiable', 'A proper vocal and physical warm-up prevents injury, improves your sound, and calms your nerves. Never skip it.'),
];

class VoiceTypeRange {
  final String name;
  final double lowPitch;
  final double highPitch;
  final String lowNote;
  final String highNote;
  final String description;
  final List<String> famousExamples;
  final String category;

  const VoiceTypeRange({
    required this.name,
    required this.lowPitch,
    required this.highPitch,
    required this.lowNote,
    required this.highNote,
    required this.description,
    required this.famousExamples,
    required this.category,
  });
}

const List<VoiceTypeRange> voiceTypeRanges = [
  VoiceTypeRange(
    name: 'Soprano',
    lowPitch: 261.6,
    highPitch: 1046.5,
    lowNote: 'C4',
    highNote: 'C6',
    description: 'High female singing voice, bright and resonant in high tessitura.',
    famousExamples: ['Whitney Houston', 'Mariah Carey', 'Celine Dion'],
    category: 'Female / High',
  ),
  VoiceTypeRange(
    name: 'Mezzo-Soprano',
    lowPitch: 220.0,
    highPitch: 880.0,
    lowNote: 'A3',
    highNote: 'A5',
    description: 'Middle female voice with a warm, rich tone and versatile range.',
    famousExamples: ['Beyoncé', 'Adele', 'Lady Gaga'],
    category: 'Female / Mid',
  ),
  VoiceTypeRange(
    name: 'Contralto',
    lowPitch: 174.6,
    highPitch: 698.5,
    lowNote: 'F3',
    highNote: 'F5',
    description: 'Lowest female singing voice, deep, soulful and rich.',
    famousExamples: ['Amy Winehouse', 'Cher', 'Tracy Chapman'],
    category: 'Female / Low',
  ),
  VoiceTypeRange(
    name: 'Tenor',
    lowPitch: 130.8,
    highPitch: 523.2,
    lowNote: 'C3',
    highNote: 'C5',
    description: 'Highest natural male singing voice, bright and flexible.',
    famousExamples: ['Luciano Pavarotti', 'Freddie Mercury', 'Bruno Mars'],
    category: 'Male / High',
  ),
  VoiceTypeRange(
    name: 'Baritone',
    lowPitch: 110.0,
    highPitch: 440.0,
    lowNote: 'A2',
    highNote: 'A4',
    description: 'Most common male voice type, balanced between power and warmth.',
    famousExamples: ['Elvis Presley', 'Frank Sinatra', 'John Legend'],
    category: 'Male / Mid',
  ),
  VoiceTypeRange(
    name: 'Bass',
    lowPitch: 82.4,
    highPitch: 329.6,
    lowNote: 'E2',
    highNote: 'E4',
    description: 'Lowest male singing voice, deep, resonant and rich in low harmonics.',
    famousExamples: ['Johnny Cash', 'Barry White', 'Josh Turner'],
    category: 'Male / Low',
  ),
];