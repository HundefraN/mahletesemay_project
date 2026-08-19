/// Amharic & English Multi-Script Transliterator and Search Normalizer
///
/// Provides robust bidirectional transliteration between Ge'ez (Fidel) script
/// and Latin / English phonetic representations, homophone normalization,
/// and search keyword array generation for Mahlete Semay.
class AmharicTransliterator {
  AmharicTransliterator._();

  // ---------------------------------------------------------------------------
  // 1. FIDEL (GE'EZ) CONSONANT-VOWEL MATRIX (Orders 1 through 7)
  // ---------------------------------------------------------------------------

  /// Mapping table of Ge'ez families: base Latin consonant + 7 orders (ä/e, u, i, a, e, ə, o)
  static const List<({String latin, List<String> fidel})> _fidelMatrix = [
    // H family
    (latin: 'h', fidel: ['ሀ', 'ሁ', 'ሂ', 'ሃ', 'ሄ', 'ህ', 'ሆ']),
    (latin: 'h', fidel: ['ሐ', 'ሑ', 'ሒ', 'ሓ', 'ሔ', 'ሕ', 'ሖ']),
    (latin: 'h', fidel: ['ኀ', 'ኁ', 'ኂ', 'ኃ', 'ኄ', 'ኅ', 'ኆ']),
    (latin: 'h', fidel: ['ኸ', 'ኹ', 'ኺ', 'ኻ', 'ኼ', 'ኽ', 'ኾ']),
    // L family
    (latin: 'l', fidel: ['ለ', 'ሉ', 'ሊ', 'ላ', 'ሌ', 'ል', 'ሎ']),
    // M family
    (latin: 'm', fidel: ['መ', 'ሙ', 'ሚ', 'ማ', 'ሜ', 'ም', 'ሞ']),
    // S family
    (latin: 's', fidel: ['ሰ', 'ሱ', 'ሲ', 'ሳ', 'ሴ', 'ስ', 'ሶ']),
    (latin: 's', fidel: ['ሠ', 'ሡ', 'ሢ', 'ሣ', 'ሤ', 'ሥ', 'ሦ']),
    // R family
    (latin: 'r', fidel: ['ረ', 'ሩ', 'ሪ', 'ራ', 'ሬ', 'ር', 'ሮ']),
    // SH family
    (latin: 'sh', fidel: ['ሸ', 'ሹ', 'ሺ', 'ሻ', 'ሼ', 'ሽ', 'ሾ']),
    // Q / K' family
    (latin: 'q', fidel: ['ቀ', 'ቁ', 'ቂ', 'ቃ', 'ቄ', 'ቅ', 'ቆ']),
    (latin: 'k', fidel: ['ቀ', 'ቁ', 'ቂ', 'ቃ', 'ቄ', 'ቅ', 'ቆ']),
    // B family
    (latin: 'b', fidel: ['በ', 'ቡ', 'ቢ', 'ባ', 'ቤ', 'ብ', 'ቦ']),
    // V family
    (latin: 'v', fidel: ['ቨ', 'ቩ', 'ቪ', 'ቫ', 'ቬ', 'ቭ', 'ቮ']),
    // T family
    (latin: 't', fidel: ['ተ', 'ቱ', 'ቲ', 'ታ', 'ቴ', 'ት', 'ቶ']),
    // CH family
    (latin: 'ch', fidel: ['ቸ', 'ቹ', 'ቺ', 'ቻ', 'ቼ', 'ች', 'ቾ']),
    // N family
    (latin: 'n', fidel: ['ነ', 'ኑ', 'ኒ', 'ና', 'ኔ', 'ን', 'ኖ']),
    // GN / NY family
    (latin: 'gn', fidel: ['ኘ', 'ኙ', 'ኚ', 'ኛ', 'ኜ', 'ኝ', 'ኞ']),
    (latin: 'ny', fidel: ['ኘ', 'ኙ', 'ኚ', 'ኛ', 'ኜ', 'ኝ', 'ኞ']),
    // Vowel / A family (Glottal stop)
    (latin: '', fidel: ['አ', 'ኡ', 'ኢ', 'ኣ', 'ኤ', 'እ', 'ኦ']),
    (latin: '', fidel: ['ዐ', 'ዑ', 'ዒ', 'ዓ', 'ዔ', 'ዕ', 'ዖ']),
    // K family
    (latin: 'k', fidel: ['ከ', 'ኩ', 'ኪ', 'ካ', 'ኬ', 'ክ', 'ኮ']),
    (latin: 'c', fidel: ['ከ', 'ኩ', 'ኪ', 'ካ', 'ኬ', 'ክ', 'ኮ']),
    // W family
    (latin: 'w', fidel: ['ወ', 'ዉ', 'ዊ', 'ዋ', 'ዌ', 'ው', 'ዎ']),
    // Z family
    (latin: 'z', fidel: ['ዘ', 'ዙ', 'ዚ', 'ዛ', 'ዜ', 'ዝ', 'ዞ']),
    // ZH / J family
    (latin: 'zh', fidel: ['ዠ', 'ዡ', 'ዢ', 'ዣ', 'ዤ', 'ዥ', 'ዦ']),
    // Y family
    (latin: 'y', fidel: ['የ', 'ዩ', 'ዪ', 'ያ', 'ዬ', 'ይ', 'ዮ']),
    // D family
    (latin: 'd', fidel: ['ደ', 'ዱ', 'ዲ', 'ዳ', 'ዴ', 'ድ', 'ዶ']),
    // J family
    (latin: 'j', fidel: ['ጀ', 'ጁ', 'ጂ', 'ጃ', 'ጄ', 'ጅ', 'ጆ']),
    // G family
    (latin: 'g', fidel: ['ገ', 'ጉ', 'ጊ', 'ጋ', 'ጌ', 'ግ', 'ጎ']),
    // T' / Tt family
    (latin: 't', fidel: ['ጠ', 'ጡ', 'ጢ', 'ጣ', 'ጤ', 'ጥ', 'ጦ']),
    // CH' / Cch family
    (latin: 'ch', fidel: ['ጨ', 'ጩ', 'ጪ', 'ጫ', 'ጬ', 'ጭ', 'ጮ']),
    // P' family
    (latin: 'p', fidel: ['ጰ', 'ጱ', 'ጲ', 'ጳ', 'ጴ', 'ጵ', 'ጶ']),
    // TS / TZ family
    (latin: 'ts', fidel: ['ጸ', 'ጹ', 'ጺ', 'ጻ', 'ጼ', 'ጽ', 'ጾ']),
    (latin: 'tz', fidel: ['ጸ', 'ጹ', 'ጺ', 'ጻ', 'ጼ', 'ጽ', 'ጾ']),
    (latin: 's', fidel: ['ጸ', 'ጹ', 'ጺ', 'ጻ', 'ጼ', 'ጽ', 'ጾ']),
    (latin: 'ts', fidel: ['ፀ', 'ፁ', 'ፂ', 'ፃ', 'ፄ', 'ፅ', 'ፆ']),
    (latin: 'tz', fidel: ['ፀ', 'ፁ', 'ፂ', 'ፃ', 'ፄ', 'ፅ', 'ፆ']),
    // F / PH family
    (latin: 'f', fidel: ['ፈ', 'ፉ', 'ፊ', 'ፋ', 'ፌ', 'ፍ', 'ፎ']),
    (latin: 'ph', fidel: ['ፈ', 'ፉ', 'ፊ', 'ፋ', 'ፌ', 'ፍ', 'ፎ']),
    // P family
    (latin: 'p', fidel: ['ፐ', 'ፑ', 'ፒ', 'ፓ', 'ፔ', 'ፕ', 'ፖ']),
  ];

  /// Common labiovelar characters
  static const Map<String, String> _labiovelars = {
    'ቋ': 'kwa',
    'ቊ': 'kwi',
    'ቌ': 'kwe',
    'ቍ': 'kw',
    'ኋ': 'hwa',
    'ኊ': 'hwi',
    'ኳ': 'kwa',
    'ኲ': 'kwi',
    'ኬ': 'kwe',
    'ጓ': 'gwa',
    'ጒ': 'gwi',
    'ጧ': 'twa',
    'ቿ': 'chwa',
    'ኗ': 'nwa',
    'ኟ': 'nywa',
    'ዟ': 'zwa',
    'ዷ': 'dwa',
    'ጇ': 'jwa',
    'ጿ': 'tswa',
    'ፏ': 'fwa',
    'ፗ': 'pwa',
    'ሟ': 'mwa',
    'ሯ': 'rwa',
    'ሷ': 'swa',
    'ሿ': 'shwa',
    'ቧ': 'bwa',
    'ቷ': 'twa',
  };

  /// Vowel sound suffixes for the 7 orders
  static const List<String> _vowelEndings = ['e', 'u', 'i', 'a', 'ie', '', 'o'];

  /// Lookup map from Ge'ez character -> Primary Latin transliteration
  static final Map<String, String> _fidelToLatinMap = _buildFidelToLatinMap();

  static Map<String, String> _buildFidelToLatinMap() {
    final map = <String, String>{};
    for (final entry in _fidelMatrix) {
      final base = entry.latin;
      for (int i = 0; i < entry.fidel.length && i < 7; i++) {
        final char = entry.fidel[i];
        if (!map.containsKey(char)) {
          if (base.isEmpty) {
            // Vowel family: አ->a, ኡ->u, ኢ->i, ኣ->aa, ኤ->e, እ->e, ኦ->o
            const glottalVowels = ['a', 'u', 'i', 'aa', 'e', 'e', 'o'];
            map[char] = glottalVowels[i];
          } else if (base == 'h') {
            // H family: ሀ->ha, ሁ->hu, ሂ->hi, ሃ->ha, ሄ->he, ህ->h, ሆ->ho
            const hVowels = ['a', 'u', 'i', 'a', 'e', '', 'o'];
            map[char] = '$base${hVowels[i]}';
          } else {
            final vowel = _vowelEndings[i];
            map[char] = '$base$vowel';
          }
        }
      }
    }
    _labiovelars.forEach((key, value) {
      map[key] = value;
    });
    return map;
  }

  // ---------------------------------------------------------------------------
  // 2. HOMOPHONE NORMALIZATION (ሀ/ሐ/ኀ, ሰ/ሠ, አ/ዐ, ጸ/ፀ)
  // ---------------------------------------------------------------------------

  /// Normalizes Amharic homophones so identical sounds match regardless of spelling
  static String normalizeAmharic(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      switch (char) {
        // H homophones (ሐ, ኀ, ኸ -> ሀ)
        case 'ሐ':
        case 'ኀ':
        case 'ኸ':
          buffer.write('ሀ');
          break;
        case 'ሑ':
        case 'ኁ':
        case 'ኹ':
          buffer.write('ሁ');
          break;
        case 'ሒ':
        case 'ኂ':
        case 'ኺ':
          buffer.write('ሂ');
          break;
        case 'ሓ':
        case 'ኃ':
        case 'ኻ':
          buffer.write('ሃ');
          break;
        case 'ሔ':
        case 'ኄ':
        case 'ኼ':
          buffer.write('ሄ');
          break;
        case 'ሕ':
        case 'ኅ':
        case 'ኽ':
          buffer.write('ህ');
          break;
        case 'ሖ':
        case 'ኆ':
        case 'ኾ':
          buffer.write('ሆ');
          break;

        // S homophones (ሠ -> ሰ)
        case 'ሠ':
          buffer.write('ሰ');
          break;
        case 'ሡ':
          buffer.write('ሱ');
          break;
        case 'ሢ':
          buffer.write('ሲ');
          break;
        case 'ሣ':
          buffer.write('ሳ');
          break;
        case 'ሤ':
          buffer.write('ሴ');
          break;
        case 'ሥ':
          buffer.write('ስ');
          break;
        case 'ሦ':
          buffer.write('ሶ');
          break;

        // Glottal/A homophones (ዐ -> አ)
        case 'ዐ':
          buffer.write('አ');
          break;
        case 'ዑ':
          buffer.write('ኡ');
          break;
        case 'ዒ':
          buffer.write('ኢ');
          break;
        case 'ዓ':
          buffer.write('ኣ');
          break;
        case 'ዔ':
          buffer.write('ኤ');
          break;
        case 'ዕ':
          buffer.write('እ');
          break;
        case 'ዖ':
          buffer.write('ኦ');
          break;

        // TS homophones (ፀ -> ጸ)
        case 'ፀ':
          buffer.write('ጸ');
          break;
        case 'ፁ':
          buffer.write('ጹ');
          break;
        case 'ፂ':
          buffer.write('ጺ');
          break;
        case 'ፃ':
          buffer.write('ጻ');
          break;
        case 'ፄ':
          buffer.write('ጼ');
          break;
        case 'ፅ':
          buffer.write('ጽ');
          break;
        case 'ፆ':
          buffer.write('ጾ');
          break;

        default:
          buffer.write(char);
      }
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // 3. SCRIPT DETECTION
  // ---------------------------------------------------------------------------

  /// Checks if a string contains any Ethiopic (Ge'ez) characters
  static bool containsAmharic(String text) {
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      // Ethiopic Unicode Block: 0x1200 - 0x137F, Extended: 0x1380 - 0x139F, 0x2D80 - 0x2DDF
      if ((codeUnit >= 0x1200 && codeUnit <= 0x137F) ||
          (codeUnit >= 0x1380 && codeUnit <= 0x139F) ||
          (codeUnit >= 0x2D80 && codeUnit <= 0x2DDF)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a string is primarily Latin / English
  static bool isEnglish(String text) {
    if (text.isEmpty) return false;
    return !containsAmharic(text);
  }

  // ---------------------------------------------------------------------------
  // 4. FIDEL -> LATIN (AMHARIC TO ENGLISH) TRANSLITERATION
  // ---------------------------------------------------------------------------

  /// Transliterates Amharic Ge'ez text to phonetic Latin/English script
  static String toLatin(String amharicText) {
    if (amharicText.isEmpty) return '';
    final buffer = StringBuffer();

    for (int i = 0; i < amharicText.length; i++) {
      final char = amharicText[i];
      if (_fidelToLatinMap.containsKey(char)) {
        buffer.write(_fidelToLatinMap[char]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString().toLowerCase().trim();
  }

  // ---------------------------------------------------------------------------
  // 5. LATIN -> FIDEL (ENGLISH TO AMHARIC) TRANSLITERATION
  // ---------------------------------------------------------------------------

  /// Converts English/Latin phonetic spelling (e.g. "lili", "lily", "hanna", "efrem")
  /// into possible Amharic Fidel representations.
  static List<String> toAmharicVariants(String latinText) {
    final clean = latinText.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final variants = <String>{};

    // 1. Direct phonetic parsing
    final direct = _parseLatinToFidel(clean);
    if (direct.isNotEmpty) variants.add(direct);

    // 2. Common English phoneme replacements & generate permutations
    final phoneticTransforms = _generatePhoneticSpellingVariants(clean);
    for (final alt in phoneticTransforms) {
      final parsed = _parseLatinToFidel(alt);
      if (parsed.isNotEmpty) variants.add(parsed);
    }

    // 3. Initial vowel variants (e -> ኤ, እ, አ)
    if (clean.startsWith('e')) {
      final sub = clean.substring(1);
      final eVariant = 'ኤ${_parseLatinToFidel(sub)}';
      final iVariant = 'እ${_parseLatinToFidel(sub)}';
      final aVariant = 'አ${_parseLatinToFidel(sub)}';
      variants.add(eVariant);
      variants.add(iVariant);
      variants.add(aVariant);

      for (final alt in phoneticTransforms) {
        if (alt.startsWith('e') || alt.startsWith('a') || alt.startsWith('i')) {
          final altSub = alt.substring(1);
          variants.add('ኤ${_parseLatinToFidel(altSub)}');
          variants.add('እ${_parseLatinToFidel(altSub)}');
        }
      }
    }

    return variants.toList();
  }

  /// Generates spelling variations for common English vocalizations of Amharic words
  static Set<String> _generatePhoneticSpellingVariants(String input) {
    final results = <String>{input};

    // Rule: 'y' at word end or before consonants often acts like 'i' or 'ee' (Lily -> Lili)
    if (input.endsWith('y')) {
      results.add('${input.substring(0, input.length - 1)}i');
      results.add('${input.substring(0, input.length - 1)}ee');
    }
    if (input.contains('ee')) {
      results.add(input.replaceAll('ee', 'i'));
    }
    if (input.contains('oo')) {
      results.add(input.replaceAll('oo', 'u'));
    }
    if (input.contains('ou')) {
      results.add(input.replaceAll('ou', 'u'));
    }
    if (input.contains('ph')) {
      results.add(input.replaceAll('ph', 'f'));
    }
    if (input.contains('c') && !input.contains('ch')) {
      results.add(input.replaceAll('c', 'k'));
    }
    if (input.contains('kh')) {
      results.add(input.replaceAll('kh', 'h'));
    }
    if (input.contains('nn')) {
      results.add(input.replaceAll('nn', 'n'));
    }
    if (input.contains('ll')) {
      results.add(input.replaceAll('ll', 'l'));
    }
    if (input.contains('mm')) {
      results.add(input.replaceAll('mm', 'm'));
    }
    if (input.contains('tt')) {
      results.add(input.replaceAll('tt', 't'));
    }
    if (input.contains('rr')) {
      results.add(input.replaceAll('rr', 'r'));
    }
    if (input.contains('bb')) {
      results.add(input.replaceAll('bb', 'b'));
    }
    if (input.contains('ss')) {
      results.add(input.replaceAll('ss', 's'));
    }
    if (input.contains('e') && !input.contains('ee')) {
      results.add(input.replaceAll('e', 'a'));
      results.add(input.replaceAll('e', 'ie'));
      results.add(input.replaceAll('e', 'ee'));
    }

    return results;
  }

  static String _parseLatinToFidel(String text) {
    final buffer = StringBuffer();
    int i = 0;

    while (i < text.length) {
      // Check 2-letter consonants: ch, sh, gn, ny, zh, ts, tz, ph, kw, gw, hw
      String? matchedConsonant;
      int consonantLen = 0;

      if (i + 1 < text.length) {
        final pair = text.substring(i, i + 2);
        if (['ch', 'sh', 'gn', 'ny', 'zh', 'ts', 'tz', 'ph', 'kw', 'gw', 'hw'].contains(pair)) {
          matchedConsonant = pair;
          consonantLen = 2;
        }
      }

      if (matchedConsonant == null) {
        final single = text[i];
        if (RegExp(r'[a-z]').hasMatch(single)) {
          matchedConsonant = single;
          consonantLen = 1;
        } else {
          buffer.write(single);
          i++;
          continue;
        }
      }

      final afterConsonant = i + consonantLen;
      int orderIndex = 0; // Default order 1 (e / ä)
      int vowelLen = 0;

      // Check for vowel sequences
      if (afterConsonant < text.length) {
        if (afterConsonant + 1 < text.length) {
          final twoVowels = text.substring(afterConsonant, afterConsonant + 2);
          if (twoVowels == 'ee' || twoVowels == 'ie') {
            orderIndex = 4; // 5th order (é)
            vowelLen = 2;
          } else if (twoVowels == 'oo' || twoVowels == 'ou') {
            orderIndex = 1; // 2nd order (u)
            vowelLen = 2;
          } else if (twoVowels == 'aa') {
            orderIndex = 3; // 4th order (a)
            vowelLen = 2;
          }
        }

        if (vowelLen == 0) {
          final singleVowel = text[afterConsonant];
          switch (singleVowel) {
            case 'e':
              orderIndex = 0; // 1st order
              vowelLen = 1;
              break;
            case 'u':
              orderIndex = 1; // 2nd order
              vowelLen = 1;
              break;
            case 'i':
            case 'y':
              orderIndex = 2; // 3rd order
              vowelLen = 1;
              break;
            case 'a':
              orderIndex = 3; // 4th order
              vowelLen = 1;
              break;
            case 'o':
              orderIndex = 6; // 7th order
              vowelLen = 1;
              break;
            default:
              // Followed by another consonant -> use 6th order (ə / silent consonant)
              orderIndex = 5;
              vowelLen = 0;
              break;
          }
        }
      } else {
        // End of word consonant -> 6th order
        orderIndex = 5;
        vowelLen = 0;
      }

      // Find matching Fidel in matrix
      final fidelChar = _findFidelCharacter(matchedConsonant, orderIndex);
      if (fidelChar != null) {
        buffer.write(fidelChar);
      } else {
        // If it's pure vowel without consonant
        if (['a', 'e', 'i', 'o', 'u', 'y'].contains(matchedConsonant)) {
          final glottal = _findFidelCharacter('', orderIndex);
          if (glottal != null) buffer.write(glottal);
        }
      }

      i += consonantLen + vowelLen;
    }

    return buffer.toString();
  }

  static String? _findFidelCharacter(String latin, int orderIndex) {
    if (orderIndex < 0 || orderIndex > 6) orderIndex = 0;

    for (final entry in _fidelMatrix) {
      if (entry.latin == latin) {
        if (orderIndex < entry.fidel.length) {
          return entry.fidel[orderIndex];
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 6. SEARCH KEYWORDS ARRAY GENERATION (FOR DATABASE & INDEXING)
  // ---------------------------------------------------------------------------

  /// Generates a comprehensive, deduplicated array of search keyword tokens
  /// given text in Amharic, English, or mixed.
  static List<String> generateSearchKeywords({
    required String title,
    String? englishTitle,
    String? subtitleOrArtist,
    String? lyricsOrDescription,
    List<String>? extraTags,
  }) {
    final Set<String> keywords = <String>{};

    void addText(String? text) {
      if (text == null || text.trim().isEmpty) return;

      final raw = text.trim().toLowerCase();
      // Add raw lowercase
      keywords.add(raw);

      // Tokenize by whitespace and punctuation
      final tokens = raw
          .split(RegExp(r'[\s\p{P}\p{S}]+', unicode: true))
          .where((t) => t.isNotEmpty && t.length >= 2);

      for (final token in tokens) {
        keywords.add(token);

        if (containsAmharic(token)) {
          // Add normalized Amharic
          final normalized = normalizeAmharic(token);
          keywords.add(normalized);

          // Add English/Latin transliteration
          final latin = toLatin(token);
          if (latin.isNotEmpty) {
            keywords.add(latin);
            // Also add simplified phonetic variations of latin
            final alts = _generatePhoneticSpellingVariants(latin);
            keywords.addAll(alts);
          }
        } else {
          // Latin token: generate Amharic Fidel variants
          final amharicVariants = toAmharicVariants(token);
          for (final variant in amharicVariants) {
            keywords.add(variant);
            keywords.add(normalizeAmharic(variant));
          }
        }
      }
    }

    addText(title);
    addText(englishTitle);
    addText(subtitleOrArtist);

    // Add first 300 characters of lyrics or description for keyword tokens
    if (lyricsOrDescription != null && lyricsOrDescription.isNotEmpty) {
      final sample = lyricsOrDescription.length > 400
          ? lyricsOrDescription.substring(0, 400)
          : lyricsOrDescription;
      addText(sample);
    }

    if (extraTags != null) {
      for (final tag in extraTags) {
        addText(tag);
      }
    }

    return keywords.where((k) => k.isNotEmpty && k.length >= 2).toList();
  }

  // ---------------------------------------------------------------------------
  // 7. CROSS-SCRIPT MATCH EVALUATION & SCORING
  // ---------------------------------------------------------------------------

  /// Evaluates if [target] matches [query] across Amharic & English
  /// Returns a match score from 0.0 (no match) to 100.0 (perfect match)
  static double calculateMatchScore({
    required String query,
    required String target,
    String? targetEnglish,
    List<String>? targetKeywords,
  }) {
    if (query.trim().isEmpty || target.trim().isEmpty) return 0.0;

    final q = query.trim().toLowerCase();
    final t = target.trim().toLowerCase();
    final tEng = targetEnglish?.trim().toLowerCase() ?? '';

    // 1. Direct exact match
    if (t == q || tEng == q) return 100.0;

    // 2. Direct prefix / contains match
    if (t.startsWith(q) || tEng.startsWith(q)) return 90.0;
    if (t.contains(q) || tEng.contains(q)) return 75.0;

    // 3. Amharic Homophone Normalized Match
    final qNorm = normalizeAmharic(q);
    final tNorm = normalizeAmharic(t);
    if (tNorm == qNorm) return 95.0;
    if (tNorm.startsWith(qNorm)) return 85.0;
    if (tNorm.contains(qNorm)) return 70.0;

    // 4. Cross-Script Transliteration Match
    if (isEnglish(q)) {
      // Query is English -> check against transliterated Amharic variants
      final qAmharicVariants = toAmharicVariants(q);
      for (final variant in qAmharicVariants) {
        final variantNorm = normalizeAmharic(variant);
        if (tNorm == variantNorm || t == variant) return 85.0;
        if (tNorm.startsWith(variantNorm) || t.startsWith(variant)) return 75.0;
        if (tNorm.contains(variantNorm) || t.contains(variant)) return 60.0;
      }

      // Also compare against Latin transliteration of target
      final tLatin = toLatin(t);
      if (tLatin == q) return 80.0;
      if (tLatin.startsWith(q)) return 70.0;
      if (tLatin.contains(q)) return 55.0;
    } else {
      // Query is Amharic -> check against target in Latin
      final qLatin = toLatin(q);
      if (tEng.isNotEmpty) {
        if (tEng == qLatin) return 80.0;
        if (tEng.startsWith(qLatin)) return 70.0;
        if (tEng.contains(qLatin)) return 55.0;
      }
    }

    // 5. Search Keywords Array Match
    if (targetKeywords != null && targetKeywords.isNotEmpty) {
      for (final kw in targetKeywords) {
        final kwLower = kw.toLowerCase();
        if (kwLower == q || kwLower == qNorm) return 65.0;
        if (kwLower.startsWith(q) || kwLower.startsWith(qNorm)) return 50.0;
      }
    }

    return 0.0;
  }
}
