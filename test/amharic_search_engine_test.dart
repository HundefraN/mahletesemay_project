import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/models/search_result_model.dart';
import 'package:mahlete_semay_project/models/song_model.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/services/search_service.dart';
import 'package:mahlete_semay_project/utils/amharic_transliterator.dart';

void main() {
  group('AmharicTransliterator Unit Tests', () {
    test('1. Homophone Normalization', () {
      // H homophones
      expect(AmharicTransliterator.normalizeAmharic('ሐመረ'), equals('ሀመረ'));
      expect(AmharicTransliterator.normalizeAmharic('ኀይል'), equals('ሀይል'));
      expect(AmharicTransliterator.normalizeAmharic('ዮሐንስ'), equals('ዮሀንስ'));

      // S homophones
      expect(AmharicTransliterator.normalizeAmharic('ሥላሴ'), equals('ስላሴ'));
      expect(AmharicTransliterator.normalizeAmharic('ሠላም'), equals('ሰላም'));

      // A/Glottal homophones
      expect(AmharicTransliterator.normalizeAmharic('ዓለም'), equals('ኣለም'));
      expect(AmharicTransliterator.normalizeAmharic('ዐይኑ'), equals('አይኑ'));

      // TS homophones
      expect(AmharicTransliterator.normalizeAmharic('ፀሎት'), equals('ጸሎት'));
      expect(AmharicTransliterator.normalizeAmharic('ፅዮን'), equals('ጽዮን'));
    });

    test('2. Script Detection', () {
      expect(AmharicTransliterator.containsAmharic('ሊሊ'), isTrue);
      expect(AmharicTransliterator.containsAmharic('Hanna'), isFalse);
      expect(AmharicTransliterator.containsAmharic('Lily - መዝሙር'), isTrue);

      expect(AmharicTransliterator.isEnglish('Lily'), isTrue);
      expect(AmharicTransliterator.isEnglish('ሀና'), isFalse);
    });

    test('3. Amharic Ge\'ez -> Latin Transliteration', () {
      expect(AmharicTransliterator.toLatin('ሊሊ'), equals('lili'));
      expect(AmharicTransliterator.toLatin('ሀና'), equals('hana'));
      expect(AmharicTransliterator.toLatin('በረከት'), equals('bereket'));
    });

    test('4. English -> Amharic Transliteration Variants', () {
      final liliVariants = AmharicTransliterator.toAmharicVariants('lili');
      expect(liliVariants.any((v) => v.contains('ሊሊ')), isTrue);

      final lilyVariants = AmharicTransliterator.toAmharicVariants('lily');
      expect(lilyVariants.any((v) => v.contains('ሊሊ')), isTrue);

      final hannaVariants = AmharicTransliterator.toAmharicVariants('hanna');
      expect(hannaVariants.any((v) => v.contains('ሀና') || v.contains('ሃና')), isTrue);

      final efremVariants = AmharicTransliterator.toAmharicVariants('efrem');
      expect(efremVariants.any((v) => v.contains('ኤፍሬም') || v.contains('እፍሬም') || v.contains('ፍሬም')), isTrue);
    });

    test('5. Search Keywords Array Generation', () {
      final keywords = AmharicTransliterator.generateSearchKeywords(
        title: 'እግዚአብሔር ይመስገን',
        englishTitle: 'Egziabher Yimesgen',
        subtitleOrArtist: 'ሊሊ ጥላሁን',
        lyricsOrDescription: 'ስሙ የተመሰገነ ይሁን ለዘላለም',
      );

      expect(keywords.isNotEmpty, isTrue);
      expect(keywords.contains('እግዚአብሔር ይመስገን'), isTrue);
      expect(keywords.contains('ሊሊ'), isTrue);
      expect(keywords.contains('lili'), isTrue);
    });
  });

  group('Unified Search Engine Multi-Script Tests', () {
    late SearchService searchService;
    late List<Song> mockSongs;
    late List<Artist> mockArtists;
    late List<Album> mockAlbums;
    late List<VocalExerciseDay> mockExercises;

    setUp(() {
      searchService = SearchService();

      mockArtists = [
        Artist(
          id: 'artist-1',
          name: 'ሊሊ ጥላሁን',
          englishName: 'Lily Tilahun',
          imageUrl: 'https://example.com/lily.jpg',
          region: 'Addis Ababa',
        ),
        Artist(
          id: 'artist-2',
          name: 'ሀና ተክሌ',
          englishName: 'Hanna Tekle',
          imageUrl: 'https://example.com/hanna.jpg',
          region: 'Hawassa',
        ),
        Artist(
          id: 'artist-3',
          name: 'ኤፍሬም ዓለሙ',
          englishName: 'Efrem Alemu',
          imageUrl: 'https://example.com/efrem.jpg',
          region: 'Addis Ababa',
        ),
      ];

      mockAlbums = [
        Album(
          id: 'album-1',
          title: 'አምላኬ ሆይ',
          englishTitle: 'Amlake Hoy',
          artistId: 'artist-1',
          artistName: 'ሊሊ ጥላሁን',
          coverImageUrl: 'https://example.com/album1.jpg',
        ),
        Album(
          id: 'album-2',
          title: 'ክብር ለአምላክ',
          englishTitle: 'Kibir Leamlak',
          artistId: 'artist-2',
          artistName: 'ሀና ተክሌ',
          coverImageUrl: 'https://example.com/album2.jpg',
        ),
      ];

      mockSongs = [
        Song(
          id: 'song-1',
          title: 'ቸርነትህ',
          englishTitle: 'Chernetih',
          artistName: 'ሊሊ ጥላሁን',
          artistId: 'artist-1',
          albumId: 'album-1',
          albumTitle: 'አምላኬ ሆይ',
          lyrics: 'ቸርነትህ ብዙ ነው ምህረትህ አያልቅም ከአንተ በቀር ሌላ አምላክ የለም',
          viewCount: 1500,
          createdAt: DateTime.now(),
        ),
        Song(
          id: 'song-2',
          title: 'ታማኝ ነህ',
          englishTitle: 'Tamagn Neh',
          artistName: 'ሀና ተክሌ',
          artistId: 'artist-2',
          albumId: 'album-2',
          albumTitle: 'ክብር ለአምላክ',
          lyrics: 'በዘመናት ሁሉ ታማኝ ነህ ጌታዬ አንተን አመሰግናለሁ',
          viewCount: 2200,
          createdAt: DateTime.now(),
        ),
        Song(
          id: 'song-3',
          title: 'እልልታ',
          englishTitle: 'Elilta',
          artistName: 'ኤፍሬም ዓለሙ',
          artistId: 'artist-3',
          albumId: 'album-3',
          albumTitle: 'እልልታ',
          lyrics: 'እልልታ ለእግዚአብሔር ድል አድራጊው ጌታ',
          viewCount: 3000,
          createdAt: DateTime.now(),
        ),
      ];

      mockExercises = [
        VocalExerciseDay(
          id: 'exercise-1',
          dayNumber: 1,
          title: 'የድምፅ ማሞቂያ (Warm-up)',
          englishTitle: 'Vocal Warm-up Exercise',
          description: 'የመተንፈስ እና የድምፅ መክፈቻ ልምምድ (Lip trills and breathing)',
        ),
      ];
    });

    test('1. Search in English finds Amharic Artist ("Lily" -> "ሊሊ ጥላሁን")', () {
      final results = searchService.searchLocal(
        query: 'Lily',
        songs: mockSongs,
        artists: mockArtists,
        albums: mockAlbums,
        exercises: mockExercises,
      );

      expect(results.isNotEmpty, isTrue);
      final topResult = results.first;
      expect(topResult.matchType == MatchType.artist || (topResult.item is Song && (topResult.item as Song).artistName.contains('ሊሊ')), isTrue);
    });

    test('2. Search in English finds Amharic Song ("Chernetih" -> "ቸርነትህ")', () {
      final results = searchService.searchLocal(
        query: 'Chernetih',
        songs: mockSongs,
        artists: mockArtists,
        albums: mockAlbums,
        exercises: mockExercises,
      );

      expect(results.isNotEmpty, isTrue);
      final song = results.first.item as Song;
      expect(song.title, equals('ቸርነትህ'));
    });

    test('3. Search in Amharic finds Amharic items ("ሀና" -> "ሀና ተክሌ")', () {
      final results = searchService.searchLocal(
        query: 'ሀና',
        songs: mockSongs,
        artists: mockArtists,
        albums: mockAlbums,
        exercises: mockExercises,
      );

      expect(results.isNotEmpty, isTrue);
      final artistResult = results.firstWhere((r) => r.item is Artist).item as Artist;
      expect(artistResult.name, equals('ሀና ተክሌ'));
    });

    test('4. Homophone spelling search ("ሐና" matches "ሀና ተክሌ")', () {
      final results = searchService.searchLocal(
        query: 'ሐና', // using ሐ instead of ሀ
        songs: mockSongs,
        artists: mockArtists,
        albums: mockAlbums,
        exercises: mockExercises,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.any((r) => r.item is Artist && (r.item as Artist).name == 'ሀና ተክሌ'), isTrue);
    });

    test('5. Lyric body search with context snippet ("ምህረትህ")', () {
      final results = searchService.searchLocal(
        query: 'ምህረትህ',
        songs: mockSongs,
        artists: mockArtists,
        albums: mockAlbums,
        exercises: mockExercises,
        category: SearchCategory.lyrics,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.matchType, equals(MatchType.lyric));
      expect(results.first.matchSnippet!.contains('ምህረትህ'), isTrue);
    });

    test('6. Vocal Exercise search ("Warm-up" / "ማሞቂያ")', () {
      final results = searchService.searchLocal(
        query: 'Warm-up',
        songs: mockSongs,
        artists: mockArtists,
        albums: mockAlbums,
        exercises: mockExercises,
        category: SearchCategory.exercises,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.matchType, equals(MatchType.exercise));
    });
  });
}
