import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import '../../services/firebase_service.dart';
import 'edit_songs_screen.dart';

class ManageSongsScreen extends StatefulWidget {
  const ManageSongsScreen({super.key});

  @override
  State<ManageSongsScreen> createState() => _ManageSongsScreenState();
}

class _ManageSongsScreenState extends State<ManageSongsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Songs')),
      body: FutureBuilder<List<Song>>(
        future: _firebaseService.getSongs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No songs found.'));
          }

          final songs = snapshot.data!;
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song.title),
                subtitle: Text('${song.artistName} - ${song.albumTitle}'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditSongScreen(song: song)),
                  );
                  setState(() {});
                },
              );
            },
          );
        },
      ),
    );
  }
}