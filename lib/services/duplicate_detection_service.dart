import 'firebase_service.dart';

/// Severity levels for duplicate detection results.
enum DuplicateSeverity {
  /// Exact match on all key fields — almost certainly a duplicate.
  exact,

  /// High confidence match — same name/title with closely related fields.
  likely,

  /// Informational — same title/name exists but under different artist/region.
  possible,
}

/// Result of a duplicate detection check.
class DuplicateCheckResult {
  final DuplicateSeverity severity;
  final String message;
  final List<Map<String, String>> matchedItems;

  const DuplicateCheckResult({
    required this.severity,
    required this.message,
    required this.matchedItems,
  });

  bool get hasDuplicates => matchedItems.isNotEmpty;
}

/// Service that intelligently checks for duplicate entries across songs,
/// albums, and artists using multi-field combination matching.
class DuplicateDetectionService {
  final FirebaseService _firebaseService;

  DuplicateDetectionService({FirebaseService? firebaseService})
      : _firebaseService = firebaseService ?? FirebaseService();

  // ---------------------------------------------------------------------------
  // SONG DUPLICATE DETECTION
  // ---------------------------------------------------------------------------

  /// Runs multiple duplicate checks for a song in priority order:
  /// 1. title + artistId  (exact duplicate)
  /// 2. title + albumId   (exact duplicate within album)
  /// 3. title only        (possible duplicate — different artist)
  Future<DuplicateCheckResult?> checkSongDuplicates({
    required String title,
    String? artistId,
    String? artistName,
    String? albumId,
    String? albumTitle,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return null;

    // Check 1: Same title + same artist (strongest signal)
    if (artistId != null && artistId.isNotEmpty) {
      final exactMatches = await _firebaseService.findSongDuplicates(
        title: trimmedTitle,
        artistId: artistId,
      );
      if (exactMatches.isNotEmpty) {
        return DuplicateCheckResult(
          severity: DuplicateSeverity.exact,
          message:
              'A song titled "$trimmedTitle" by ${artistName ?? "this artist"} already exists.',
          matchedItems: exactMatches
              .map((s) => {
                    'title': s.title,
                    'artist': s.artistName,
                    'album': s.albumTitle,
                    'id': s.id,
                  })
              .toList(),
        );
      }
    }

    // Check 2: Same title + same album (duplicate within album)
    if (albumId != null && albumId.isNotEmpty) {
      final albumMatches = await _firebaseService.findSongDuplicates(
        title: trimmedTitle,
        albumId: albumId,
      );
      if (albumMatches.isNotEmpty) {
        return DuplicateCheckResult(
          severity: DuplicateSeverity.exact,
          message:
              'A song titled "$trimmedTitle" already exists in the album "${albumTitle ?? "this album"}".',
          matchedItems: albumMatches
              .map((s) => {
                    'title': s.title,
                    'artist': s.artistName,
                    'album': s.albumTitle,
                    'id': s.id,
                  })
              .toList(),
        );
      }
    }

    // Check 3: Same title, any artist (informational)
    final titleOnlyMatches = await _firebaseService.findSongDuplicates(
      title: trimmedTitle,
    );
    if (titleOnlyMatches.isNotEmpty) {
      // Filter out matches already caught above
      final otherArtistMatches = titleOnlyMatches
          .where((s) => s.artistId != (artistId ?? ''))
          .toList();

      if (otherArtistMatches.isNotEmpty) {
        return DuplicateCheckResult(
          severity: DuplicateSeverity.possible,
          message:
              'A song titled "$trimmedTitle" exists by ${otherArtistMatches.length == 1 ? "another artist" : "${otherArtistMatches.length} other artists"}. This may be intentional if different artists have the same song title.',
          matchedItems: otherArtistMatches
              .map((s) => {
                    'title': s.title,
                    'artist': s.artistName,
                    'album': s.albumTitle,
                    'id': s.id,
                  })
              .toList(),
        );
      }

      // Same artist match found via case-insensitive title (caught here but not in check 1)
      if (artistId != null) {
        final sameArtistMatches =
            titleOnlyMatches.where((s) => s.artistId == artistId).toList();
        if (sameArtistMatches.isNotEmpty) {
          return DuplicateCheckResult(
            severity: DuplicateSeverity.exact,
            message:
                'A song titled "$trimmedTitle" by ${artistName ?? "this artist"} already exists.',
            matchedItems: sameArtistMatches
                .map((s) => {
                      'title': s.title,
                      'artist': s.artistName,
                      'album': s.albumTitle,
                      'id': s.id,
                    })
                .toList(),
          );
        }
      }
    }

    return null; // No duplicates found
  }

  // ---------------------------------------------------------------------------
  // ALBUM DUPLICATE DETECTION
  // ---------------------------------------------------------------------------

  /// Runs multiple duplicate checks for an album:
  /// 1. title + artistId  (exact duplicate)
  /// 2. title only        (possible duplicate — different artist)
  Future<DuplicateCheckResult?> checkAlbumDuplicates({
    required String title,
    String? artistId,
    String? artistName,
    int? volume,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return null;

    // Check 1: Same title + same artist
    if (artistId != null && artistId.isNotEmpty) {
      final exactMatches = await _firebaseService.findAlbumDuplicates(
        title: trimmedTitle,
        artistId: artistId,
      );
      if (exactMatches.isNotEmpty) {
        // Sub-check: if volumes differ, it's a volume conflict (likely), not exact
        if (volume != null) {
          final sameVolume =
              exactMatches.where((a) => a.volume == volume).toList();
          final diffVolume =
              exactMatches.where((a) => a.volume != volume).toList();

          if (sameVolume.isNotEmpty) {
            return DuplicateCheckResult(
              severity: DuplicateSeverity.exact,
              message:
                  'An album titled "$trimmedTitle" (Vol. $volume) by ${artistName ?? "this artist"} already exists.',
              matchedItems: sameVolume
                  .map((a) => {
                        'title': a.title,
                        'artist': a.artistName,
                        'volume': a.volume?.toString() ?? '-',
                        'id': a.id,
                      })
                  .toList(),
            );
          }

          if (diffVolume.isNotEmpty) {
            return DuplicateCheckResult(
              severity: DuplicateSeverity.likely,
              message:
                  'An album titled "$trimmedTitle" by ${artistName ?? "this artist"} exists with a different volume number. Make sure this is a new volume.',
              matchedItems: diffVolume
                  .map((a) => {
                        'title': a.title,
                        'artist': a.artistName,
                        'volume': a.volume?.toString() ?? '-',
                        'id': a.id,
                      })
                  .toList(),
            );
          }
        }

        return DuplicateCheckResult(
          severity: DuplicateSeverity.exact,
          message:
              'An album titled "$trimmedTitle" by ${artistName ?? "this artist"} already exists.',
          matchedItems: exactMatches
              .map((a) => {
                    'title': a.title,
                    'artist': a.artistName,
                    'volume': a.volume?.toString() ?? '-',
                    'id': a.id,
                  })
              .toList(),
        );
      }
    }

    // Check 2: Same title, any artist (informational)
    final titleOnlyMatches = await _firebaseService.findAlbumDuplicates(
      title: trimmedTitle,
    );
    if (titleOnlyMatches.isNotEmpty) {
      final otherArtistMatches = titleOnlyMatches
          .where((a) => a.artistId != (artistId ?? ''))
          .toList();

      if (otherArtistMatches.isNotEmpty) {
        return DuplicateCheckResult(
          severity: DuplicateSeverity.possible,
          message:
              'An album titled "$trimmedTitle" exists by ${otherArtistMatches.length == 1 ? "another artist" : "${otherArtistMatches.length} other artists"}.',
          matchedItems: otherArtistMatches
              .map((a) => {
                    'title': a.title,
                    'artist': a.artistName,
                    'volume': a.volume?.toString() ?? '-',
                    'id': a.id,
                  })
              .toList(),
        );
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // ARTIST DUPLICATE DETECTION
  // ---------------------------------------------------------------------------

  /// Runs multiple duplicate checks for an artist:
  /// 1. name + region    (exact duplicate)
  /// 2. name only        (likely duplicate — same person, different region?)
  Future<DuplicateCheckResult?> checkArtistDuplicates({
    required String name,
    required String region,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    // Check 1: Same name + same region (exact)
    final exactMatches = await _firebaseService.findArtistDuplicates(
      name: trimmedName,
      region: region,
    );
    if (exactMatches.isNotEmpty) {
      return DuplicateCheckResult(
        severity: DuplicateSeverity.exact,
        message:
            'An artist named "$trimmedName" ($region) already exists.',
        matchedItems: exactMatches
            .map((a) => {
                  'name': a.name,
                  'region': a.region,
                  'id': a.id,
                })
            .toList(),
      );
    }

    // Check 2: Same name, different region (likely — could be same person)
    final nameOnlyMatches = await _firebaseService.findArtistDuplicates(
      name: trimmedName,
    );
    if (nameOnlyMatches.isNotEmpty) {
      return DuplicateCheckResult(
        severity: DuplicateSeverity.likely,
        message:
            'An artist named "$trimmedName" already exists under a different region. Are you sure this is a different person?',
        matchedItems: nameOnlyMatches
            .map((a) => {
                  'name': a.name,
                  'region': a.region,
                  'id': a.id,
                })
            .toList(),
      );
    }

    return null;
  }
}
