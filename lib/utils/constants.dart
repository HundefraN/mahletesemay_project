
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/performance_tip_model.dart';

final List<String> scaleMenuItems = [
  '1st (Ionian)',
  '2nd (Dorian)',
  '5th (Mixolydian)',
  '6th (Aeolian)',
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
  const Color(0xff0D47A1), // App Primary
  const Color(0xff1a1a1a), // Deep Charcoal
  const Color(0xff606c38), // Olive
  const Color(0xff283618), // Dark Olive
  const Color(0xfffefae0), // Cream
  const Color(0xffdda15e), // Tan
  const Color(0xffbc6c25), // Brown
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