import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song_model.dart';
import '../../providers/song_provider.dart';

class MashupHelperScreen extends StatelessWidget {
  const MashupHelperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worship Mashup Helper'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChordSection(context, 'I Chord Songs (Tonic)', 1, theme.colorScheme.primary),
            _buildChordSection(context, 'IV Chord Songs (Subdominant)', 4, theme.colorScheme.secondary),
            _buildChordSection(context, 'V Chord Songs (Dominant)', 5, Colors.green),
            _buildChordSection(context, 'vi Chord Songs (Relative Minor)', 6, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildChordSection(BuildContext context, String title, int scaleDegree, Color color) {
    final songs = Provider.of<SongProvider>(context)
        .allSongs
        .where((s) => s.scaleDegree == scaleDegree)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: songs.isEmpty
                ? const Center(child: Text('No songs found for this category.'))
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return _buildSongCard(context, song, color);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(BuildContext context, Song song, Color color) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              color: color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artistName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}