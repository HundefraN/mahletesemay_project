import 'package:flutter/material.dart';
import '../../models/album_model.dart';
import '../../services/firebase_service.dart';
import 'edit_album_screen.dart';

class ManageAlbumsScreen extends StatefulWidget {
  const ManageAlbumsScreen({super.key});

  @override
  State<ManageAlbumsScreen> createState() => _ManageAlbumsScreenState();
}

class _ManageAlbumsScreenState extends State<ManageAlbumsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Albums')),
      body: FutureBuilder<List<Album>>(
        future: _firebaseService.getAlbums(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No albums found.'));
          }

          final albums = snapshot.data!;
          return ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: album.coverImageUrl.isNotEmpty ? NetworkImage(album.coverImageUrl) : null,
                  child: album.coverImageUrl.isEmpty ? const Icon(Icons.album) : null,
                ),
                title: Text(album.title),
                subtitle: Text(album.artistName),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditAlbumScreen(album: album)),
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