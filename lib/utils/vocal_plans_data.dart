import '../models/vocal_plan_model.dart';

// MALE PLANS
final VocalPlan maleDailyPlan = VocalPlan(
  title: "Daily Foundation",
  duration: PlanDuration.daily,
  routines: [
    VocalExerciseRoutine(
      id: 'm_d_breath',
      title: 'Breathing Control',
      category: 'Breathing',
      steps: [
        VocalExerciseStep(title: 'Diaphragmatic Breaths', description: 'Inhale deeply for 4 counts, feeling your belly expand. Exhale for 8 counts on a "sss" sound. Repeat 10 times.', audioAsset: 'sounds/hiss.mp3', durationInSeconds: 120),
        VocalExerciseStep(title: 'Pulsed Breaths', description: 'Take a deep breath and exhale on short, sharp "ha" sounds. This strengthens your diaphragm. Do 3 sets of 15.', audioAsset: 'sounds/ha.mp3', durationInSeconds: 90),
      ],
    ),
    VocalExerciseRoutine(
      id: 'm_d_warmup',
      title: 'Vocal Warm-up',
      category: 'Warm-up',
      steps: [
        VocalExerciseStep(title: 'Lip Trills (Low Range)', description: 'Create a motorboat sound with your lips. Glide from a comfortable low note up a 5-note scale and back down. Keep it relaxed.', audioAsset: 'sounds/lip_trill_low.mp3', durationInSeconds: 180),
        VocalExerciseStep(title: 'Humming Sirens', description: 'Hum gently and slide your voice up and down your range like a siren. Focus on the buzzing sensation in your face.', audioAsset: 'sounds/hum_siren.mp3', durationInSeconds: 120),
      ],
    ),
  ],
);

// FEMALE PLANS (can have slightly different starting notes or focuses)
final VocalPlan femaleDailyPlan = VocalPlan(
  title: "Daily Foundation",
  duration: PlanDuration.daily,
  routines: [
    VocalExerciseRoutine(
      id: 'f_d_breath',
      title: 'Breathing Control',
      category: 'Breathing',
      steps: [
        VocalExerciseStep(title: 'Diaphragmatic Breaths', description: 'Inhale deeply for 4 counts, feeling your belly expand. Exhale for 8 counts on a "sss" sound. Repeat 10 times.', audioAsset: 'sounds/hiss.mp3', durationInSeconds: 120),
        VocalExerciseStep(title: 'Pulsed Breaths', description: 'Take a deep breath and exhale on short, sharp "ha" sounds. This strengthens your diaphragm. Do 3 sets of 15.', audioAsset: 'sounds/ha.mp3', durationInSeconds: 90),
      ],
    ),
    VocalExerciseRoutine(
      id: 'f_d_warmup',
      title: 'Vocal Warm-up',
      category: 'Warm-up',
      steps: [
        VocalExerciseStep(title: 'Lip Trills (Mid Range)', description: 'Create a motorboat sound with your lips. Glide from a comfortable mid note up a 5-note scale and back down. Keep it light and easy.', audioAsset: 'sounds/lip_trill_mid.mp3', durationInSeconds: 180),
        VocalExerciseStep(title: 'Resonant Humming', description: 'Hum a comfortable pitch on "ng" and focus on feeling the vibration behind your nose and in your forehead.', audioAsset: 'sounds/ng_hum.mp3', durationInSeconds: 120),
      ],
    ),
  ],
);

// Placeholder for other plans
final VocalPlan weeklyPlan = VocalPlan(title: "Weekly Goals", duration: PlanDuration.weekly, routines: []);
final VocalPlan monthlyPlan = VocalPlan(title: "Monthly Focus", duration: PlanDuration.monthly, routines: []);
final VocalPlan quarterlyPlan = VocalPlan(title: "3-Month Plan", duration: PlanDuration.quarterly, routines: []);