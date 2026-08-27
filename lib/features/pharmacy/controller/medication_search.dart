import 'pharmacy_model.dart';

// Bilingual (English/French) free-text search over the medication catalog.
//
// IMPORTANT: this class never touches the network. It operates entirely
// on a List<MedicationModel> handed to it by the caller (PharmacyBloc),
// which is always the already-loaded, in-memory catalog. Every search
// keystroke runs this synchronously — it is what makes search instant
// and offline-capable, and it is why it carries zero risk of duplicate
// network calls: there simply isn't a network call in this file.

/// Result of a single search: the ranked matches, plus which term (if
/// any) should be appended to the recent-searches chip row.
class MedicationSearchResult {
  final List<MedicationModel> matches;
  final String? chipTerm;
  const MedicationSearchResult({required this.matches, this.chipTerm});
}

/// Matching is a 2-step fallback:
///   1. Try the WHOLE normalized query against medication name, brand
///      names, and conditions. Covers direct searches ("paracetamol",
///      "pain relief", "paludisme").
///   2. If nothing matched, split into words (>=3 chars) and OR-match
///      each independently — a safety net for sentence-shaped queries
///      ("medicines that treat malaria": the surrounding words match
///      nothing, "malaria" alone still surfaces the right medications).
/// If neither step finds anything, the result is genuinely empty — the
/// screen shows a "no results" state. Nothing more is attempted.
class MedicationSearchEngine {
  const MedicationSearchEngine();

  static const int _minWordLength = 3;

  /// Common French symptom/condition words mapped to their canonical
  /// (English, as-stored) condition name.
  static const Map<String, String> _frenchToCanonicalCondition = {
    'paludisme': 'malaria',
    'palu': 'malaria',
    'fievre': 'fever',
    'tete': 'headache', // "mal de tête", "j'ai mal à la tête"
    'migraine': 'headache',
    'douleur': 'pain relief',
    'antidouleur': 'pain relief',
    'toux': 'cough',
    'diarrhee': 'diarrhea',
    'gorge': 'sore throat', // "mal de gorge"
    'infection': 'infection',
    'grippe': 'flu',
    'rhume': 'cold',
    'estomac': 'stomach',
    'ventre': 'stomach',
    'nausee': 'nausea',
    'vomissement': 'vomiting',
    'tension': 'hypertension',
    'hypertension': 'hypertension',
    'diabete': 'diabetes',
    'allergie': 'allergy',
  };

  /// Reverse mapping for when conditions in DB are stored in French.
  static const Map<String, String> _canonicalToFrenchCondition = {
    'malaria': 'paludisme',
    'fever': 'fievre',
    'headache': 'tete',
    'pain relief': 'douleur',
    'pain': 'douleur',
    'cough': 'toux',
    'diarrhea': 'diarrhee',
    'sore throat': 'gorge',
    'infection': 'infection',
    'flu': 'grippe',
    'cold': 'rhume',
    'stomach': 'estomac',
    'nausea': 'nausee',
    'hypertension': 'tension',
    'diabetes': 'diabete',
    'allergy': 'allergie',
  };

  MedicationSearchResult search(List<MedicationModel> pool, String rawQuery) {
    final String query = rawQuery.trim();
    if (query.isEmpty) return const MedicationSearchResult(matches: []);

    final String normalizedQuery = _normalize(query);

    // Step 1 — whole phrase.
    final List<MedicationModel> wholePhraseMatches = _matchAgainst(
      pool,
      [normalizedQuery],
    );
    if (wholePhraseMatches.isNotEmpty) {
      return MedicationSearchResult(
        matches: wholePhraseMatches,
        chipTerm: query.length >= _minWordLength ? _titleCase(query) : null,
      );
    }

    // Step 2 — word-level fallback.
    final List<String> words = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= _minWordLength)
        .toList();
    if (words.isEmpty) return const MedicationSearchResult(matches: []);

    final List<MedicationModel> wordMatches = _matchAgainst(pool, words);
    if (wordMatches.isEmpty) return const MedicationSearchResult(matches: []);

    return MedicationSearchResult(
      matches: wordMatches,
      chipTerm: _bestChipTerm(pool, words),
    );
  }

  List<MedicationModel> _matchAgainst(
    List<MedicationModel> pool,
    List<String> tokens,
  ) {
    return pool.where((m) => _matches(m, tokens)).toList();
  }

  bool _matches(MedicationModel medication, List<String> tokens) {
    final String name = _normalize(medication.name);
    final List<String> brands = medication.brandNames
        .map(_normalize)
        .toList();
    final List<String> conditions = medication.conditions
        .map(_normalize)
        .toList();
    final List<String> retailers = medication.retailers
        .map((r) => _normalize(r.name))
        .toList();
    final String description = medication.description != null
        ? _normalize(medication.description!)
        : '';

    for (final String token in tokens) {
      final String frToEn = _frenchToCanonicalCondition[token] ?? token;
      final String enToFr = _canonicalToFrenchCondition[token] ?? token;

      if (name.contains(token) || name.contains(frToEn)) return true;
      if (brands.any((b) => b.contains(token) || b.contains(frToEn))) return true;
      if (conditions.any(
        (c) => c.contains(token) || c.contains(frToEn) || c.contains(enToFr),
      )) {
        return true;
      }
      if (retailers.any((r) => r.contains(token) || r.contains(frToEn))) return true;
      if (description.isNotEmpty &&
          (description.contains(token) || description.contains(frToEn))) {
        return true;
      }
    }
    return false;
  }

  /// Picks which single word to surface as a recent-search chip when the
  /// query needed word-level fallback — prefers a word that matched a
  /// CONDITION (the "symptom search" use case) over one that only
  /// matched a medication/brand name.
  String? _bestChipTerm(List<MedicationModel> pool, List<String> words) {
    final Set<String> allConditions = pool
        .expand((m) => m.conditions.map(_normalize))
        .toSet();

    for (final String word in words) {
      final String translated = _frenchToCanonicalCondition[word] ?? word;
      if (allConditions.any((c) => c.contains(translated) || c.contains(word))) {
        // Surface the human-readable canonical term — a "paludisme"
        // search still saves a "Malaria" chip, not the raw French word.
        return _titleCase(translated);
      }
    }
    return words.isNotEmpty && words.first.length >= _minWordLength
        ? _titleCase(words.first)
        : null;
  }

  String _titleCase(String input) =>
      input.isEmpty ? input : input[0].toUpperCase() + input.substring(1);

  /// Lowercases and strips common French accents — same approach already
  /// used for the map screen's search bar.
  String _normalize(String input) {
    const Map<String, String> accentMap = {
      'à': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.toLowerCase().runes) {
      final String char = String.fromCharCode(rune);
      buffer.write(accentMap[char] ?? char);
    }
    return buffer.toString();
  }
}