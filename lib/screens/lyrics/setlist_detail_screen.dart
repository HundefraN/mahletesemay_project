import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mahlete_semay_project/models/setlist_model.dart';
import 'package:mahlete_semay_project/models/song_model.dart';
import 'package:mahlete_semay_project/providers/setlist_provider.dart';
import 'package:mahlete_semay_project/providers/song_provider.dart';
import 'package:mahlete_semay_project/screens/lyrics/song_detail_screen.dart';
import 'package:provider/provider.dart';

class SetlistDetailScreen extends StatelessWidget {
  final Setlist setlist;

  const SetlistDetailScreen({super.key, required this.setlist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setlistProvider = Provider.of<SetlistProvider>(context);
    final songsInSetlist = setlistProvider.getSongsForSetlist(setlist.id!);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(setlist.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              centerTitle: false,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Setlist',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Setlist?'),
                      content: Text('Are you sure you want to delete "${setlist.name}"? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await setlistProvider.deleteSetlist(setlist.id!);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          if (songsInSetlist.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('This setlist is empty.\nAdd songs from the song detail page.', textAlign: TextAlign.center),
              ),
            )
          else
            SliverReorderableList(
              itemCount: songsInSetlist.length,
              itemBuilder: (context, index) {
                final setlistSong = songsInSetlist[index];
                return _SetlistSongCard(
                  key: ValueKey(setlistSong.id),
                  setlistSong: setlistSong,
                  index: index,
                  setlistCreationDate: setlist.createdAt,
                );
              },
              onReorder: (oldIndex, newIndex) {
                setlistProvider.updateSongOrder(setlist.id!, oldIndex, newIndex);
              },
            ),
        ],
      ),
    );
  }
}

class _SetlistSongCard extends StatelessWidget {
  final SetlistSong setlistSong;
  final int index;
  final DateTime setlistCreationDate;

  const _SetlistSongCard({
    required super.key,
    required this.setlistSong,
    required this.index,
    required this.setlistCreationDate,
  });

  void _editSongDetails(BuildContext context, Song song) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Details',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogCtx, anim1, anim2) => _EditSetlistSongDialog(
        songTitle: song.title,
        initialKey: setlistSong.customKey,
        initialNotes: setlistSong.notes,
        onSave: (newKey, newNotes) {
          final updatedSong = SetlistSong(
            id: setlistSong.id,
            setlistId: setlistSong.setlistId,
            songId: setlistSong.songId,
            orderIndex: setlistSong.orderIndex,
            customKey: newKey,
            notes: newNotes,
          );
          Provider.of<SetlistProvider>(context, listen: false).updateSongDetails(updatedSong);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    final setlistProvider = Provider.of<SetlistProvider>(context, listen: false);
    final theme = Theme.of(context);

    final song = songProvider.allSongs.firstWhere(
          (s) => s.id == setlistSong.songId,
      orElse: () => Song(id: 'deleted', title: 'Song Not Found', artistName: 'Please remove', artistId: '', albumId: '', albumTitle: '', lyrics: '', viewCount: 0, createdAt: setlistCreationDate.toUtc()),
    );
    final bool isDeleted = song.id == 'deleted';

    return Slidable(
      key: ValueKey(setlistSong.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => setlistProvider.removeSongFromSetlist(setlistSong.setlistId, setlistSong.id!),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Remove',
            borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          title: Text(song.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDeleted ? Colors.red : null)),
          subtitle: Text(setlistSong.customKey != null && setlistSong.customKey!.isNotEmpty ? 'Key: ${setlistSong.customKey}' : song.artistName),
          trailing: isDeleted ? null : IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () => _editSongDetails(context, song),
          ),
          onTap: isDeleted ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SongDetailScreen(song: song))),
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
  }
}

class _EditSetlistSongDialog extends StatefulWidget {
  final String songTitle;
  final String? initialKey;
  final String? initialNotes;
  final Function(String, String) onSave;

  const _EditSetlistSongDialog({
    required this.songTitle,
    this.initialKey,
    this.initialNotes,
    required this.onSave,
  });

  @override
  State<_EditSetlistSongDialog> createState() => _EditSetlistSongDialogState();
}

class _EditSetlistSongDialogState extends State<_EditSetlistSongDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.initialKey);
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Details for "${widget.songTitle}"', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(controller: _keyController, decoration: InputDecoration(labelText: 'Custom Key (e.g., G#)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: _notesController, decoration: InputDecoration(labelText: 'Performance Notes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), maxLines: 3),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      widget.onSave(_keyController.text.trim(), _notesController.text.trim());
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}