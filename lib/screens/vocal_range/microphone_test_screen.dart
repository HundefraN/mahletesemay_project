// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:record/record.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class MicrophoneTestScreen extends StatefulWidget {
//   const MicrophoneTestScreen({super.key});
//
//   @override
//   State<MicrophoneTestScreen> createState() => _MicrophoneTestScreenState();
// }
//
// class _MicrophoneTestScreenState extends State<MicrophoneTestScreen> {
//   final AudioRecorder _audioRecorder = AudioRecorder();
//   StreamSubscription? _audioStreamSubscription;
//   bool _isListening = false;
//   int _bytesReceived = 0;
//   bool _isReceivingData = false;
//
//   @override
//   void dispose() {
//     _audioStreamSubscription?.cancel();
//     _audioRecorder.dispose();
//     super.dispose();
//   }
//
//   Future<void> _toggleListening() async {
//     if (_isListening) {
//       await _stop();
//     } else {
//       await _start();
//     }
//   }
//
//   Future<void> _start() async {
//     final status = await Permission.microphone.request();
//     if (!status.isGranted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Microphone permission denied.')),
//       );
//       return;
//     }
//
//     setState(() {
//       _isListening = true;
//       _bytesReceived = 0;
//     });
//
//     try {
//       final stream = await _audioRecorder.startStream(const RecordConfig(
//         encoder: AudioEncoder.pcm16bits,
//         sampleRate: 44100,
//         numChannels: 1,
//       ));
//
//       _audioStreamSubscription = stream.listen((data) {
//         if (mounted) {
//           setState(() {
//             _bytesReceived += data.length;
//             // This is our visual feedback toggle
//             _isReceivingData = !_isReceivingData;
//           });
//         }
//       });
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error starting stream: $e')),
//         );
//         _stop();
//       }
//     }
//   }
//
//   Future<void> _stop() async {
//     await _audioStreamSubscription?.cancel();
//     _audioStreamSubscription = null;
//     if (await _audioRecorder.isRecording()) {
//       await _audioRecorder.stop();
//     }
//     if (mounted) {
//       setState(() => _isListening = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Microphone Test'),
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 _isListening ? 'LISTENING' : 'IDLE',
//                 style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                   color: _isListening ? Colors.green : Colors.grey,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 40),
//               AnimatedContainer(
//                 duration: const Duration(milliseconds: 100),
//                 width: 100,
//                 height: 100,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: _isReceivingData ? Colors.blueAccent : Colors.lightBlue,
//                 ),
//                 child: const Icon(Icons.graphic_eq, color: Colors.white, size: 50),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 'Bytes received: $_bytesReceived',
//                 style: Theme.of(context).textTheme.titleLarge,
//               ),
//               const SizedBox(height: 40),
//               ElevatedButton(
//                 onPressed: _toggleListening,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
//                   backgroundColor: _isListening ? Colors.red : Colors.blue,
//                 ),
//                 child: Text(_isListening ? 'Stop Listening' : 'Start Listening', style: const TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }