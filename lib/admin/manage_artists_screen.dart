import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/artist_model.dart';
import '../../providers/auth_proveider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_snackbar.dart';
import 'add_artists_screen.dart';
import 'edit_artists_screen.dart';
import 'widgets/admin_ui_kit.dart';

class ManageArtistsScreen extends StatefulWidget {
  const ManageArtistsScreen({super.key});

  @override
  State<ManageArtistsScreen> createState() => _ManageArtistsScreenState();
}

class _ManageArtistsScreenState extends State<ManageArtistsScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late Future<List<Artist>> _artistsFuture;
  List<Artist> _allArtists = [];
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedArtistIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _artistsFuture = _loadArtists();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Artist>> _loadArtists() async {
    _allArtists = await _firebaseService.getArtists();
    return _allArtists;
  }

  void _refreshData() {
    setState(() {
      _artistsFuture = _loadArtists();
    });
  }

  void _navigateToAddArtist() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddArtistScreen()),
    );
    if (result == true) {
      _refreshData();
    }
  }

  void _toggleSelection(String artistId) {
    AdminUiKit.hapticLight();
    setState(() {
      if (_selectedArtistIds.contains(artistId)) {
        _selectedArtistIds.remove(artistId);
      } else {
        _selectedArtistIds.add(artistId);
      }
      if (_selectedArtistIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _enterSelectionMode(String artistId) {
    AdminUiKit.hapticMedium();
    setState(() {
      _isSelectionMode = true;
      _selectedArtistIds.add(artistId);
    });
  }

  void _exitSelectionMode() {
    AdminUiKit.hapticLight();
    setState(() {
      _isSelectionMode = false;
      _selectedArtistIds.clear();
    });
  }

  Future<void> _deleteSelectedArtists() async {
    final count = _selectedArtistIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count Artist(s)?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to permanently delete $count artist(s)? This will affect associated albums and songs.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUiKit.roseRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final artistsToDelete = _allArtists
            .where((a) => _selectedArtistIds.contains(a.id))
            .map((a) => a.name)
            .join(', ');

        await _firebaseService.deleteArtists(_selectedArtistIds.toList());

        if (authProvider.currentUser != null) {
          _firebaseService.logActivity(
            moderatorId: authProvider.currentUser!.uid,
            moderatorName: authProvider.currentModerator?.fullName ?? 'Admin',
            action: 'DELETE_ARTISTS',
            details: 'Deleted $count artist(s): $artistsToDelete',
          );
        }

        if (mounted) {
          CustomSnackbar.show(context, 'Successfully deleted $count artist(s).');
          _exitSelectionMode();
          _refreshData();
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(context, 'Error during deletion: $e', isError: true);
        }
      }
    }
  }

  void _editArtist(Artist artist) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditArtistScreen(artist: artist)),
    );
    if (result == true) {
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070E1B) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'Manage Artists',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              AdminUiKit.hapticLight();
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13233D) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13.5),
              tabs: const [
                Tab(text: '🇪🇹 Ethiopian Artists'),
                Tab(text: '🌍 Worldwide Artists'),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Artist>>(
        future: _artistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminUiKit.goldAccent));
          }
          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load artists',
              description: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _refreshData,
            );
          }

          _allArtists = snapshot.data ?? [];
          final ethiopianArtists = _allArtists.where((a) => a.region == 'Ethiopian').toList();
          final worldwideArtists = _allArtists.where((a) => a.region == 'Worldwide').toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _isSelectionMode
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AdminUiKit.roseRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminUiKit.roseRed.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: _exitSelectionMode,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_selectedArtistIds.length} Selected',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white : AdminUiKit.roseRed,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _selectedArtistIds.isNotEmpty ? _deleteSelectedArtists : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AdminUiKit.roseRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                              label: const Text('Delete'),
                            ),
                          ],
                        ),
                      )
                    : AdminSearchBar(
                        controller: _searchController,
                        hintText: 'Search artists by name...',
                      ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildArtistList('Ethiopian', ethiopianArtists),
                    _buildArtistList('Worldwide', worldwideArtists),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          AdminUiKit.hapticMedium();
          _navigateToAddArtist();
        },
        backgroundColor: isDark ? AdminUiKit.goldAccent : AdminUiKit.primaryNavy,
        foregroundColor: isDark ? AdminUiKit.primaryNavy : Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
        label: Text(
          'Add Artist',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }

  Widget _buildArtistList(String category, List<Artist> artists) {
    final query = _searchController.text.toLowerCase().trim();
    final displayList = artists.where((artist) => artist.name.toLowerCase().contains(query)).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (displayList.isEmpty) {
      return AdminEmptyState(
        icon: Icons.person_off_rounded,
        title: 'No Artists Found',
        description: query.isNotEmpty
            ? 'No artist matching "$query".'
            : 'There are no $category artists added yet.',
        actionLabel: query.isEmpty ? 'Add Artist' : null,
        onAction: query.isEmpty ? _navigateToAddArtist : null,
      );
    }

    return RefreshIndicator(
      color: AdminUiKit.goldAccent,
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
        physics: const BouncingScrollPhysics(),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final artist = displayList[index];
          final isSelected = _selectedArtistIds.contains(artist.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AdminGlassCard(
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(artist.id);
                } else {
                  _editArtist(artist);
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode(artist.id);
                }
              },
              borderColor: isSelected ? AdminUiKit.goldAccent : null,
              customColor: isSelected
                  ? (isDark
                      ? AdminUiKit.goldAccent.withOpacity(0.15)
                      : AdminUiKit.primaryNavy.withOpacity(0.08))
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderRadius: 16,
              child: Row(
                children: [
                  // Circular Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AdminUiKit.goldAccent : AdminUiKit.goldAccent.withOpacity(0.3),
                        width: 1.8,
                      ),
                    ),
                    child: ClipOval(
                      child: artist.imageUrl.isNotEmpty
                          ? Image.network(
                              artist.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AdminUiKit.goldAccent.withOpacity(0.15),
                                child: const Icon(Icons.person_rounded, color: AdminUiKit.goldAccent),
                              ),
                            )
                          : Container(
                              color: AdminUiKit.goldAccent.withOpacity(0.15),
                              child: Center(
                                child: Text(
                                  artist.name.isNotEmpty ? artist.name[0].toUpperCase() : 'A',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: AdminUiKit.goldAccent,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AdminUiKit.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (artist.region == 'Ethiopian' ? AdminUiKit.emeraldGreen : AdminUiKit.royalBlue).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                artist.region,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: artist.region == 'Ethiopian' ? AdminUiKit.emeraldGreen : AdminUiKit.royalBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_isSelectionMode)
                    Checkbox(
                      value: isSelected,
                      activeColor: AdminUiKit.goldAccent,
                      checkColor: AdminUiKit.primaryNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      onChanged: (_) => _toggleSelection(artist.id),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: isDark ? AdminUiKit.goldHighlight : AdminUiKit.primaryNavy,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}