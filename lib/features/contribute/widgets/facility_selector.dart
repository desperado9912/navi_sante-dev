import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../hospitals/data/facility_model.dart';
import '../../hospitals/data/facility_repository.dart';

/// Small shared search-and-select step for contribution workflows.
class FacilitySelector extends StatefulWidget {
  final String? initialFacilityId;
  final ValueChanged<FacilityDetailModel> onSelected;
  final VoidCallback? onCleared;

  const FacilitySelector({
    super.key,
    this.initialFacilityId,
    required this.onSelected,
    this.onCleared,
  });

  @override
  State<FacilitySelector> createState() => _FacilitySelectorState();
}

class _FacilitySelectorState extends State<FacilitySelector> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<FacilityModel> _results = const [];
  FacilityDetailModel? _selected;
  bool _isSearching = false;
  bool _isLoadingSelected = false;
  String? _error;

  FacilityRepository get _repository => context.read<FacilityRepository>();

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialFacilityId;
    if (initialId != null && initialId.isNotEmpty) {
      _loadInitialFacility(initialId);
    }
  }

  Future<void> _loadInitialFacility(String facilityId) async {
    setState(() => _isLoadingSelected = true);
    try {
      final detail = await _repository.getFacilityDetail(facilityId);
      if (!mounted) return;
      if (detail == null) {
        setState(() => _error = 'The selected facility could not be found.');
      } else {
        setState(() => _selected = detail);
        widget.onSelected(detail);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this facility.');
    } finally {
      if (mounted) setState(() => _isLoadingSelected = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _isSearching = false;
        _error = null;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    // Try instant cache hit first — avoids network round-trip when the
    // facility is already in the local Hive store.
    final cached = _repository.searchCachedFacilities(query);
    if (cached.isNotEmpty) {
      setState(() {
        _results = cached;
        _isSearching = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await _repository.searchFacilities(query: query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not search facilities.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _select(FacilityModel facility) async {
    setState(() {
      _isLoadingSelected = true;
      _error = null;
    });
    try {
      final detail = await _repository.getFacilityDetail(facility.facilityId);
      if (!mounted) return;
      if (detail == null) {
        setState(() => _error = 'Could not load this facility.');
        return;
      }
      setState(() {
        _selected = detail;
        _results = const [];
        _searchController.clear();
      });
      widget.onSelected(detail);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this facility.');
    } finally {
      if (mounted) setState(() => _isLoadingSelected = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search by facility name',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFD93025), fontSize: 12),
          ),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final facility = _results[index];
                return ListTile(
                  onTap: () => _select(facility),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2A7D8F).withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.local_hospital_outlined,
                      color: Color(0xFF2A7D8F),
                    ),
                  ),
                  title: Text(
                    facility.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    facility.address ?? facility.type.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                );
              },
            ),
          ),
        ],
        if (_isLoadingSelected) ...[
          const SizedBox(height: 18),
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF2A7D8F)),
          ),
        ],
        if (_selected != null && !_isLoadingSelected) ...[
          const SizedBox(height: 18),
          _SelectedFacilityCard(
            facility: _selected!,
            onChange: () {
              setState(() => _selected = null);
              widget.onCleared?.call();
            },
          ),
        ],
      ],
    );
  }
}

class _SelectedFacilityCard extends StatelessWidget {
  final FacilityDetailModel facility;
  final VoidCallback onChange;

  const _SelectedFacilityCard({required this.facility, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB7E1CD)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: facility.primaryImageUrl == null
                  ? const ColoredBox(
                      color: Color(0xFFE6F4EA),
                      child: Icon(
                        Icons.local_hospital_outlined,
                        color: Color(0xFF2A7D8F),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: facility.primaryImageUrl!,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  facility.address ?? facility.city ?? 'Facility selected',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: onChange,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}
