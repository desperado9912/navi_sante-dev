import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../hospitals/controller/facility_bloc.dart';
import '../../hospitals/controller/facility_model.dart';
import '../../hospitals/data/facility_repository.dart';

// Home screen Floating search bar with user profile avatar.

// Search typing shows a compact dropdown of 4 matching facilities below the bar.
// Queries local cached facilities immediately with a debounced direct database query guard.
// Selecting one hands the facility via [onFacilitySelected]
// so the map screen can glide the camera and highlight the pin.
class HeaderSearch extends StatefulWidget {
  final void Function(FacilityModel facility) onFacilitySelected;
  final VoidCallback? onClear;

  const HeaderSearch({
    super.key,
    required this.onFacilitySelected,
    this.onClear,
  });

  @override
  State<HeaderSearch> createState() => HeaderSearchState();
}

class HeaderSearchState extends State<HeaderSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<FacilityModel> _suggestions = const [];

  // Dropdown options prevents single keystroke query
  static const int _minQueryLength = 2;
  static const int _minRemoteQueryLength = 3;
  static const int _maxSuggestions = 4;
  static const Duration _debounceDelay = Duration(milliseconds: 350);
  int _remoteSearchSeq = 0;

  @override
  void initState() {
    super.initState();
    // Dropdown visibility depends on focus, panning map hides it.
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _onQueryChanged(String raw) {
    setState(() {}); // clear button's visibility.

    _debounce?.cancel();
    final String query = raw.trim();

    if (query.length < _minQueryLength) {
      setState(() => _suggestions = const []);
      return;
    }

    // 1. Immediately match against local cached facilities (instant UI response)
    final List<FacilityModel> cachedFacilities = context
        .read<FacilityBloc>()
        .state
        .facilities;
    final List<FacilityModel> localMatches = _matchingSuggestions(
      cachedFacilities,
      query,
      limit: _maxSuggestions,
    );

    setState(() {
      _suggestions = localMatches;
    });

    // 2. Database direct query fallback / guard
    _debounce = Timer(_debounceDelay, () async {
      if (!mounted) return;

      try {
        final repo = context.read<FacilityRepository>();
        final remoteResults = await repo.searchFacilities(query: query);

        if (!mounted || _controller.text.trim() != query) return;

        // Merge remote results with local suggestions (deduplicate by facilityId)
        final Map<String, FacilityModel> mergedMap = {};
        for (final item in _suggestions) {
          mergedMap[item.facilityId] = item;
        }
        for (final item in remoteResults) {
          if (!mergedMap.containsKey(item.facilityId)) {
            mergedMap[item.facilityId] = item;
          }
          if (mergedMap.length >= _maxSuggestions) break;
        }

        setState(() {
          _suggestions = mergedMap.values.take(_maxSuggestions).toList();
        });
      } catch (_) {
        // Fallback gracefully to existing local matches
      }
    });
  }

  void clearSearch({bool notify = true}) {
    _debounce?.cancel();
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _suggestions = const []);
    if (notify) {
      widget.onClear?.call();
    }
  }

  void _handleSuggestionTap(FacilityModel facility) {
    _debounce?.cancel();
    _focusNode.unfocus();
    _controller.text = facility.name;
    setState(() => _suggestions = const []);
    widget.onFacilitySelected(facility);
  }

  @override
  Widget build(BuildContext context) {
    final String trimmedQuery = _controller.text.trim();
    final bool showDropdown =
        _focusNode.hasFocus && trimmedQuery.length >= _minQueryLength;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 8),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.search,
                          color: Color(0xFF5F6368),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: _onQueryChanged,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'Search hospitals, pharmacies, clinics',
                              hintStyle: TextStyle(
                                color: Color(0xFF5F6368),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        // Clear text button (x)
                        if (_controller.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.clear,
                              size: 18,
                              color: Color(0xFF5F6368),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: clearSearch,
                          ),

                        const SizedBox(width: 8),

                        // Build account Profile avatar
                        const _SearchBarAvatar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (showDropdown) ...[
              const SizedBox(height: 8),
              _SuggestionsBox(
                suggestions: _suggestions,
                query: trimmedQuery,
                onSelect: _handleSuggestionTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Light weight client-side filter over the already-loaded `facilities`
// list, not a backend query, since NaviSante loads all facilities up
// front.

/// Lowercases and strips common French accents so a query like "yaounde"
/// matches a name like "Yaoundé" — most facility names here are French.
String _normalizeForSearch(String input) {
  const Map<String, String> accentMap = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final StringBuffer buffer = StringBuffer();
  for (final int rune in input.toLowerCase().runes) {
    final String char = String.fromCharCode(rune);
    buffer.write(accentMap[char] ?? char);
  }
  return buffer.toString();
}

String _facilityTypeLabel(FacilityType type) => switch (type) {
  FacilityType.hospital => 'Hospital',
  FacilityType.clinic => 'Clinic',
  FacilityType.pharmacy => 'Pharmacy',
};

/// Ranks [facilities] against [query] for the dropdown: name-starts-with
/// matches first (most likely what the user is typing toward), then
/// name/type "contains" matches, each alphabetical, capped at [limit].
List<FacilityModel> _matchingSuggestions(
  List<FacilityModel> facilities,
  String query, {
  required int limit,
}) {
  final String needle = _normalizeForSearch(query);
  if (needle.isEmpty) return const [];

  final List<FacilityModel> startsWith = [];
  final List<FacilityModel> contains = [];

  for (final FacilityModel facility in facilities) {
    final String name = _normalizeForSearch(facility.name);
    if (name.startsWith(needle)) {
      startsWith.add(facility);
    } else if (name.contains(needle) ||
        _normalizeForSearch(
          _facilityTypeLabel(facility.type),
        ).contains(needle)) {
      contains.add(facility);
    }
  }

  startsWith.sort((a, b) => a.name.compareTo(b.name));
  contains.sort((a, b) => a.name.compareTo(b.name));

  return [...startsWith, ...contains].take(limit).toList();
}

// SUGGESTIONS DROPDOWN BOX
//
// Compact list (max 4 rows) shown below the search bar.
class _SuggestionsBox extends StatelessWidget {
  final List<FacilityModel> suggestions;
  final String query;
  final void Function(FacilityModel facility) onSelect;

  const _SuggestionsBox({
    required this.suggestions,
    required this.query,
    required this.onSelect,
  });

  IconData _iconFor(FacilityType type) => switch (type) {
    FacilityType.hospital => Icons.local_hospital_rounded,
    FacilityType.clinic => Icons.medical_services_rounded,
    FacilityType.pharmacy => Icons.local_pharmacy_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: suggestions.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'No Results for "$query"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < suggestions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A7D8F).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconFor(suggestions[i].type),
                        size: 17,
                        color: const Color(0xFF2A7D8F),
                      ),
                    ),
                    title: Text(
                      suggestions[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _facilityTypeLabel(suggestions[i].type),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    onTap: () => onSelect(suggestions[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

// Profile avatar / initilas init class
class _SearchBarAvatar extends StatelessWidget {
  const _SearchBarAvatar();

  String _initials(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';
    final name = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        // Read the current session on every auth event (name change, refresh, etc.)
        final user = Supabase.instance.client.auth.currentUser;
        final customName =
            (user?.userMetadata?['custom_display_name'] as String?) ?? '';
        final fullName = (user?.userMetadata?['full_name'] as String?) ?? '';
        final resolvedName = customName.isNotEmpty ? customName : fullName;
        final email = user?.email ?? '';

        // Use name if available, otherwise fall back to email for initials.
        final source = resolvedName.isNotEmpty ? resolvedName : email;
        final initials = _initials(source);
        final bool hasInitials = initials.isNotEmpty;

        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2A7D8F).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: hasInitials
              ? Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A7D8F),
                      height: 1,
                    ),
                  ),
                )
              // Fallback: no session yet or anonymous user
              : const Icon(
                  CupertinoIcons.profile_circled,
                  color: Color(0xFF5F6368),
                  size: 39,
                ),
        );
      },
    );
  }
}
