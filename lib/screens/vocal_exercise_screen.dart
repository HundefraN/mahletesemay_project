// import 'package:flutter/material.dart';
// // import '../models/exercise_model.dart';
// // import '../widgets/exercise_card.dart';
//
// class VocalExerciseScreen extends StatefulWidget {
//   @override
//   _VocalExerciseScreenState createState() => _VocalExerciseScreenState();
// }
//
// class _VocalExerciseScreenState extends State<VocalExerciseScreen>
//     with TickerProviderStateMixin {
//   late TabController _tabController;
//   List<Exercise> _exercises = [];
//   Map<String, int> _progress = {};
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 4, vsync: this);
//     _loadExercises();
//   }
//
//   void _loadExercises() {
//     _exercises = [
//       Exercise(
//         id: '1',
//         title: 'Breathing Foundation',
//         description: 'Learn proper diaphragmatic breathing technique',
//         duration: '10 minutes',
//         difficulty: 'Beginner',
//         category: 'Daily',
//         day: 1,
//         instructions: [
//           'Lie down comfortably on your back',
//           'Place one hand on chest, one on stomach',
//           'Breathe in slowly through nose for 4 counts',
//           'Hold breath for 4 counts',
//           'Exhale through mouth for 6 counts',
//           'Repeat 10 times'
//         ],
//         benefits: ['Improves breath control', 'Strengthens diaphragm', 'Reduces tension'],
//       ),
//       Exercise(
//         id: '2',
//         title: 'Lip Trills',
//         description: 'Warm up vocal cords with gentle vibrations',
//         duration: '5 minutes',
//         difficulty: 'Beginner',
//         category: 'Daily',
//         day: 1,
//         instructions: [
//           'Relax your lips',
//           'Blow air through slightly closed lips',
//           'Create a "brrr" sound like a horse',
//           'Start low and slide up in pitch',
//           'Then slide back down',
//           'Repeat 5 times'
//         ],
//         benefits: ['Warms up vocal cords', 'Improves airflow', 'Gentle vocal exercise'],
//       ),
//       Exercise(
//         id: '3',
//         title: 'Vocal Scales',
//         description: 'Practice major scales to improve pitch accuracy',
//         duration: '15 minutes',
//         difficulty: 'Intermediate',
//         category: 'Weekly',
//         day: 2,
//         instructions: [
//           'Start on comfortable note (C4 for most)',
//           'Sing "Do-Re-Mi-Fa-Sol-La-Ti-Do"',
//           'Use proper posture and breath support',
//           'Go up one semitone and repeat',
//           'Continue until comfortable range limit',
//           'Come back down slowly'
//         ],
//         benefits: ['Improves pitch accuracy', 'Expands vocal range', 'Builds muscle memory'],
//       ),
//     ];
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Vocal Exercises'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: [
//             Tab(text: 'Daily'),
//             Tab(text: 'Weekly'),
//             Tab(text: 'Monthly'),
//             Tab(text: 'Progress'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _buildExerciseList('Daily'),
//           _buildExerciseList('Weekly'),
//           _buildExerciseList('Monthly'),
//           _buildProgressView(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildExerciseList(String category) {
//     final filteredExercises = _exercises.where((e) => e.category == category).toList();
//
//     return ListView.builder(
//       padding: EdgeInsets.all(16),
//       itemCount: filteredExercises.length,
//       itemBuilder: (context, index) {
//         final exercise = filteredExercises[index];
//         return ExerciseCard(
//           exercise: exercise,
//           onTap: () => _showExerciseDetails(exercise),
//           onComplete: () => _markComplete(exercise),
//           isCompleted: _progress[exercise.id] != null,
//         );
//       },
//     );
//   }
//
//   Widget _buildProgressView() {
//     return Padding(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Your Progress',
//             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 20),
//           _buildProgressCard('Daily Exercises', _getCompletionRate('Daily'), Colors.blue),
//           SizedBox(height: 16),
//           _buildProgressCard('Weekly Exercises', _getCompletionRate('Weekly'), Colors.green),
//           SizedBox(height: 16),
//           _buildProgressCard('Monthly Exercises', _getCompletionRate('Monthly'), Colors.orange),
//           SizedBox(height: 20),
//           Text(
//             'Recent Achievements',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 12),
//           _buildAchievementItem('Completed 7-day streak!', Icons.local_fire_department),
//           _buildAchievementItem('Mastered breathing exercises', Icons.air),
//           _buildAchievementItem('Improved vocal range', Icons.trending_up),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildProgressCard(String title, double progress, Color color) {
//     return Card(
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             LinearProgressIndicator(
//               value: progress,
//               backgroundColor: color.withOpacity(0.2),
//               valueColor: AlwaysStoppedAnimation<Color>(color),
//             ),
//             SizedBox(height: 8),
//             Text(
//               '${(progress * 100).round()}% Complete',
//               style: TextStyle(color: Colors.grey[600]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAchievementItem(String title, IconData icon) {
//     return ListTile(
//       leading: CircleAvatar(
//         backgroundColor: Color(0xFF6B46C1),
//         child: Icon(icon, color: Colors.white),
//       ),
//       title: Text(title),
//       trailing: Icon(Icons.check_circle, color: Colors.green),
//     );
//   }
//
//   double _getCompletionRate(String category) {
//     final categoryExercises = _exercises.where((e) => e.category == category);
//     if (categoryExercises.isEmpty) return 0.0;
//
//     final completedCount = categoryExercises.where((e) => _progress[e.id] != null).length;
//     return completedCount / categoryExercises.length;
//   }
//
//   void _markComplete(Exercise exercise) {
//     setState(() {
//       _progress[exercise.id] = DateTime.now().millisecondsSinceEpoch;
//     });
//   }
//
//   void _showExerciseDetails(Exercise exercise) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => DraggableScrollableSheet(
//         initialChildSize: 0.8,
//         maxChildSize: 0.95,
//         minChildSize: 0.6,
//         builder: (context, scrollController) {
//           return Container(
//             decoration: BoxDecoration(
//               color: Theme.of(context).scaffoldBackgroundColor,
//               borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//             ),
//             child: Column(
//               children: [
//                 Container(
//                   margin: EdgeInsets.symmetric(vertical: 8),
//                   width: 40,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[300],
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     controller: scrollController,
//                     padding: EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           exercise.title,
//                           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                         ),
//                         SizedBox(height: 8),
//                         Text(
//                           exercise.description,
//                           style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//                         ),
//                         SizedBox(height: 16),
//                         Row(
//                           children: [
//                             _buildInfoChip('${exercise.duration}', Icons.timer),
//                             SizedBox(width: 8),
//                             _buildInfoChip(exercise.difficulty, Icons.signal_cellular_alt),
//                           ],
//                         ),
//                         SizedBox(height: 20),
//                         Text(
//                           'Instructions:',
//                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                         ),
//                         SizedBox(height: 12),
//                         ...exercise.instructions.asMap().entries.map((entry) {
//                           return Padding(
//                             padding: EdgeInsets.only(bottom: 8),
//                             child: Row(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Container(
//                                   width: 24,
//                                   height: 24,
//                                   decoration: BoxDecoration(
//                                     color: Color(0xFF6B46C1),
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       '${entry.key + 1}',
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 SizedBox(width: 12),
//                                 Expanded(
//                                   child: Text(
//                                     entry.value,
//                                     style: TextStyle(fontSize: 14),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           );
//                         }).toList(),
//                         SizedBox(height: 20),
//                         Text(
//                           'Benefits:',
//                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                         ),
//                         SizedBox(height: 12),
//                         ...exercise.benefits.map((benefit) {
//                           return Padding(
//                             padding: EdgeInsets.only(bottom: 4),
//                             child: Row(
//                               children: [
//                                 Icon(Icons.check_circle, color: Colors.green, size: 16),
//                                 SizedBox(width: 8),
//                                 Expanded(child: Text(benefit)),
//                               ],
//                             ),
//                           );
//                         }).toList(),
//                         SizedBox(height: 24),
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             onPressed: () {
//                               Navigator.pop(context);
//                               _markComplete(exercise);
//                             },
//                             child: Text('Mark as Complete'),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildInfoChip(String text, IconData icon) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: Color(0xFF6B46C1).withOpacity(0.1),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 16, color: Color(0xFF6B46C1)),
//           SizedBox(width: 4),
//           Text(
//             text,
//             style: TextStyle(
//               color: Color(0xFF6B46C1),
//               fontWeight: FontWeight.w500,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
// }