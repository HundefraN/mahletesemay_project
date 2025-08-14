import '../models/vocal_exercise_model.dart';
import '../models/performance_tip_model.dart';

final List<VocalExercise> demoVocalExercises = [
  VocalExercise(id: 'd1', title: 'Day 1: Breathing Basics', duration: '10 min', category: 'Daily', description: 'Focus on diaphragmatic breathing. Inhale for 4 counts, hold for 4, exhale for 8. Repeat 10 times. This builds foundational breath support.'),
  VocalExercise(id: 'd2', title: 'Day 2: Lip Trills', duration: '5 min', category: 'Daily', description: 'Perform lip trills (like a motorboat sound) on a simple 5-note scale, moving up and down your range. This connects breath to phonation without strain.'),
  VocalExercise(id: 'd3', title: 'Day 3: Humming & Resonance', duration: '10 min', category: 'Daily', description: 'Hum on a comfortable pitch, focusing on the buzzing sensation in your lips, nose, and forehead. This helps find and place your resonance.'),
  VocalExercise(id: 'w1', title: 'Weekly Goal 1: Range Expansion', duration: '15 min', category: 'Weekly', description: 'Using a "gee" sound, sing major scales, moving one half-step higher each time. Do not push. The goal is gentle expansion.'),
  VocalExercise(id: 'w2', title: 'Weekly Goal 2: Agility', duration: '15 min', category: 'Weekly', description: 'Practice singing arpeggios (1-3-5-8-5-3-1) on an "ah" vowel. Start slowly and gradually increase speed to improve vocal flexibility.'),
  VocalExercise(id: 'm1', title: 'Monthly Focus: Dynamics', duration: '20 min', category: 'Monthly', description: 'Hold a single, comfortable note. Start as softly as possible (pianissimo), crescendo to loud (fortissimo), and then decrescendo back to soft. This builds incredible control.'),
];

final List<PerformanceTip> demoPerformanceTips = [
  PerformanceTip('t1', 'Connect with the Message', 'Before you sing a word, understand and feel the lyrics. Your primary role is to communicate a message. When you believe it, the audience will feel it.'),
  PerformanceTip('t2', 'Use the Stage', 'Don\'t be a statue. Move with purpose during instrumental breaks. Step forward during powerful moments and engage with different sections of the audience.'),
  PerformanceTip('t3', 'Engage, Don\'t Just Perform', 'Make eye contact. Smile. Invite the congregation to worship with you through your expressions. You are a leader, not just a singer.'),
  PerformanceTip('t4', 'Master Microphone Technique', 'Pull the mic away slightly on loud, high notes to avoid distortion. Bring it closer for softer, more intimate parts. This simple act dramatically improves the listening experience.'),
  PerformanceTip('t5', 'The Power of Stillness', 'Movement is good, but intentional stillness can be even more powerful. During a profound lyrical moment, standing still can draw all the attention to the message of the song.'),
  PerformanceTip('t6', 'Warm-Up is Non-Negotiable', 'A proper vocal and physical warm-up prevents injury, improves your sound, and calms your nerves. Never skip it.'),
];