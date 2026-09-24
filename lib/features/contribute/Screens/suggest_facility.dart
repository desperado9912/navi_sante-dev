import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/native_photo_service.dart';
import '../widgets/map_location_picker.dart';
import '../widgets/work_days_sheet.dart';
import '../viewmodel/contribute_bloc.dart';
import '../../hospitals/data/facility_repository.dart';
import '../models/contribution_ticket.dart';
import '../widgets/postgis_utils.dart';

class SuggestFacilityScreen extends StatefulWidget {
  /// When set, the form opens pre-filled with this ticket's data, and any
  /// submission resubmits onto this SAME ticket instead of creating a new one.
  /// Used for the "Edit & resubmit" flow on a rejected ticket.
  ///
  final ContributionTicket? editingTicket;
  const SuggestFacilityScreen({super.key, this.editingTicket});

  @override
  State<SuggestFacilityScreen> createState() => _SuggestFacilityScreenState();
}

class _SuggestFacilityScreenState extends State<SuggestFacilityScreen> {
  final _formKey = GlobalKey<FormState>();
  final ContributionBackendService _backendService =
      ContributionBackendService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _coordinatesController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _servicesSearchController =
      TextEditingController();
  final TextEditingController _infraSearchController = TextEditingController();

  // Selections
  String? _selectedType;
  String? _selectedCity;
  String _selectedWorkDays = 'Mon-Fri (08:00 - 18:00)';
  String? _selectedPriceRange;
  LatLng _selectedCoordinates = const LatLng(
    3.868893,
    11.512699,
  ); // Yaoundé default
  bool _hasCustomCoordinates = false;

  // Fill arrays for placeholder data. Starts empty;
  // submission must only ever contain what the user actually picked.
  final Set<String> _selectedServices = {};
  final Set<String> _selectedInfrastructure = {};
  final List<String> _selectedPhotos = [];

  // City Options
  static const List<String> _types = ['Hospital', 'Pharmacy', 'Clinic'];
  static const List<String> _cities = [
    'Yaoundé',
    'Douala',
    'Bafoussam',
    'Bamenda',
    'Garoua',
    'Maroua',
    'Buea',
    'Kribi',
  ];

  // Price ranges
  static const List<String> _priceRanges = ['Low', 'Affordable', 'High'];

  // Used only until the real catalog finishes loading from db (cached
  // via FacilityRepository) or as an offline fallback if that fetch fails.
  static const List<String> _fallbackServices = [
    'Cardiology',
    'Oncology',
    'Malaria',
    'Gynecology',
    'Dental',
    'Maternity',
    'Surgery',
    'Infection',
    'Pediatrics',
    'Neurology',
    'Dermatology',
    'Ophthalmology',
    'Radiology',
    'Orthopedics',
    'Emergency',
    'Psychiatry',
    'General Medicine',
    'ENT',
    'Surgery',
    'Specialized Surgery',
    'Urology',
    'Endocrinology',
    'Physiotherapy',
  ];

  static const List<String> _fallbackInfrastructure = [
    'Laboratory',
    'Private ward',
    'Wheelchair Accessible',
    'ICU',
    'Parking',
    'CT Scanner',
    'Oxygen Supply',
    'Incubators',
    'In house pharmacy',
    'Morgue',
    'Restoration',
    'Ambulance Service',
    'Emergency Generator',
    'Blood Bank',
    'Ultrasound',
  ];

  List<String> _serviceSuggestions = [];
  List<String> _infraSuggestions = [];

  List<String> _allServices = _fallbackServices;
  List<String> _allInfrastructure = _fallbackInfrastructure;

  bool _isAttemptedSubmit = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _ratingController.addListener(_onFieldChanged);
    _coordinatesController.addListener(_onCoordinatesTextChanged);
    _servicesSearchController.addListener(_onServiceSearchChanged);
    _infraSearchController.addListener(_onInfraSearchChanged);

    final editing = widget.editingTicket;
    if (editing != null) _prefillFromTicket(editing);

    _loadCatalog();
  }

  /// Pre-fills every field from a rejected ticket being reopened for
  /// editing, so the user only has to fix what the admin flagged rather
  /// than retype the whole submission.
  void _prefillFromTicket(ContributionTicket ticket) {
    _nameController.text = ticket.facilityName;
    _addressController.text = ticket.address ?? '';
    _phoneController.text = ticket.phone ?? '';
    _descriptionController.text = ticket.description ?? '';
    _ratingController.text = (ticket.rating ?? 4.5).toStringAsFixed(1);

    _selectedType = _types.contains(ticket.facilityType)
        ? ticket.facilityType
        : null;
    _selectedCity = _cities.contains(ticket.city) ? ticket.city : null;
    _selectedPriceRange = _priceRanges.contains(ticket.priceRange)
        ? ticket.priceRange
        : null;
    if (ticket.workDays != null && ticket.workDays!.isNotEmpty) {
      _selectedWorkDays = ticket.workDays!;
    }

    if (ticket.latitude != null && ticket.longitude != null) {
      _selectedCoordinates = LatLng(ticket.latitude!, ticket.longitude!);
      _hasCustomCoordinates = true;
      _coordinatesController.text = PostGisUtils.toHumanReadable(
        latitude: ticket.latitude!,
        longitude: ticket.longitude!,
      );
    }

    _selectedServices.addAll(ticket.services);
    _selectedInfrastructure.addAll(ticket.infrastructure);
    _selectedPhotos.addAll(ticket.photoUrls);
  }

  /// Loads the services/tags catalog through [FacilityRepository], which
  /// caches it locally (Hive) so repeated visits to this screen — and every
  /// keystroke while searching — never trigger a fresh database read.
  Future<void> _loadCatalog() async {
    try {
      final repository = context.read<FacilityRepository>();
      final results = await Future.wait([
        repository.getServicesCatalog(),
        repository.getTagsCatalog(),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].isNotEmpty) _allServices = results[0];
        if (results[1].isNotEmpty) _allInfrastructure = results[1];
      });
    } catch (e) {
      // Repository not available or network failed — the fallback list
      // already in place keeps the form fully usable.
      debugPrint('Catalog load failed, using fallback list: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _coordinatesController.dispose();
    _ratingController.dispose();
    _servicesSearchController.dispose();
    _infraSearchController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  /// Parses manual coordinates typed as (lat, lng) or (lng, lat) separated by comma.
  void _onCoordinatesTextChanged() {
    final raw = _coordinatesController.text.trim();
    if (raw.isEmpty) {
      if (_hasCustomCoordinates) {
        setState(() => _hasCustomCoordinates = false);
      }
      return;
    }

    final cleaned = raw.replaceAll(RegExp(r'[()\[\]]'), '').trim();
    final parts = cleaned.split(',');
    if (parts.length == 2) {
      final first = double.tryParse(parts[0].trim());
      final second = double.tryParse(parts[1].trim());
      if (first != null && second != null) {
        double lat;
        double lng;
        // Check coordinate ordering (supports lat, lng or lng, lat)
        if (first > 8 && first < 16 && second >= 1 && second <= 13) {
          // User typed (lng, lat) e.g. (11.51269, 3.86889)
          lng = first;
          lat = second;
        } else {
          lat = first;
          lng = second;
        }

        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          setState(() {
            _selectedCoordinates = LatLng(lat, lng);
            _hasCustomCoordinates = true;
          });
        }
      }
    }
  }

  void _onServiceSearchChanged() {
    final query = _servicesSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _serviceSuggestions = []);
    } else {
      setState(() {
        _serviceSuggestions = _allServices
            .where(
              (s) =>
                  s.toLowerCase().contains(query) &&
                  !_selectedServices.contains(s),
            )
            .take(4)
            .toList();
      });
    }
  }

  void _onInfraSearchChanged() {
    final query = _infraSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _infraSuggestions = []);
    } else {
      setState(() {
        _infraSuggestions = _allInfrastructure
            .where(
              (i) =>
                  i.toLowerCase().contains(query) &&
                  !_selectedInfrastructure.contains(i),
            )
            .take(4)
            .toList();
      });
    }
  }

  bool get _isRatingValid {
    final raw = _ratingController.text.trim();
    if (raw.isEmpty) return true; // optional unless entered
    final val = double.tryParse(raw);
    return val != null && val >= 1.0 && val <= 5.0;
  }

  bool get _isFormValid {
    return _nameController.text.trim().isNotEmpty &&
        _selectedType != null &&
        _selectedCity != null &&
        _addressController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty &&
        _selectedPriceRange != null &&
        _isRatingValid &&
        _selectedServices.length >= 3 &&
        _selectedInfrastructure.length >= 3;
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLocating = false);
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        final formatted =
            '${pos.latitude.toStringAsFixed(7)}, ${pos.longitude.toStringAsFixed(7)}';
        setState(() {
          _selectedCoordinates = LatLng(pos.latitude, pos.longitude);
          _hasCustomCoordinates = true;
          _isLocating = false;
        });
        _coordinatesController.text = formatted;
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openMapLocationPicker() async {
    final picked = await InteractiveMapPickerSheet.show(
      context,
      _selectedCoordinates,
    );
    if (picked != null && mounted) {
      final formatted =
          '${picked.latitude.toStringAsFixed(7)}, ${picked.longitude.toStringAsFixed(7)}';
      setState(() {
        _selectedCoordinates = picked;
        _hasCustomCoordinates = true;
      });
      _coordinatesController.text = formatted;
    }
  }

  Future<void> _openWorkDaysPicker() async {
    final picked = await WorkDaysPickerSheet.show(
      context,
      initialValue: _selectedWorkDays,
    );
    if (picked != null && mounted) {
      setState(() => _selectedWorkDays = picked);
    }
  }

  /// Opens the device's native system photo picker (iOS PHPicker / Android Photo Picker)
  /// with 3MB file size limit and magic bytes MIME validation.
  Future<void> _openNativePhotoPicker() async {
    final result = await NativePhotoService.pickVerifiedImages();

    if (result.hasErrors && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessages.first),
          backgroundColor: const Color(0xFFD93025),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (result.validFilePaths.isNotEmpty && mounted) {
      setState(() {
        _selectedPhotos.addAll(result.validFilePaths);
      });
    }
  }

  bool _isSubmitting = false;

  Future<void> _onSubmit() async {
    setState(() => _isAttemptedSubmit = true);
    if (!_isFormValid || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final double rating = double.tryParse(_ratingController.text.trim()) ?? 4.5;

    try {
      // Submits (or, if the user has a rejected ticket for the same facility,
      // resubmits onto that same ticket — see ContributionBackendService).
      await _backendService.submitFacilitySuggestion(
        ticketId: widget.editingTicket?.id,
        facilityName: _nameController.text.trim(),
        facilityType: _selectedType ?? 'Hospital',
        city: _selectedCity ?? 'Yaoundé',
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
        workDays: _selectedWorkDays,
        latitude: _selectedCoordinates.latitude,
        longitude: _selectedCoordinates.longitude,
        priceRange: _selectedPriceRange ?? 'Affordable',
        rating: rating,
        services: _selectedServices.toList(),
        infrastructure: _selectedInfrastructure.toList(),
        localPhotoPaths: _selectedPhotos,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit your suggestion: $e'),
          backgroundColor: const Color(0xFFD93025),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.editingTicket != null
                    ? 'Suggestion updated! Pending review.'
                    : 'Facility suggested! Your submission is now pending review.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2A7D8F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _isFormValid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.editingTicket != null ? 'Edit suggestion' : 'Suggest facility',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Scrollable Form Body
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                if (widget.editingTicket?.rejectionReason != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE8E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF9AB9F)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel_outlined, color: Color(0xFFD93025), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rejected — here\'s why',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD93025),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.editingTicket!.rejectionReason!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFD93025),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
 
                  // Top Notice Card (matches Image 1)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      'The details will be reviewed to make sure they align with our community requirements. If your suggestion is accepted it will be available publicly.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4B5563),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
 
                  // Section 1: Facility details
                  _buildSectionHeader(
                    title: 'Facility details',
                    hasInfoIcon: true,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please make sure to enter only accurate and verified information.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF5F6368)),
                  ),
                  const SizedBox(height: 14),
 
                  // Field 1: Facility name (required*)
                  _buildTextInput(
                    controller: _nameController,
                    hint: 'Facility name (required*)',
                    isRequired: true,
                    isError: _isAttemptedSubmit && _nameController.text.trim().isEmpty,
                  ),
                  const SizedBox(height: 12),
 
                  // Field 2: Row [Type (required*) ˅] [City (required*) ˅]
                  Row(
                    children: [
                      Expanded(
                        child: _buildPullDownField(
                          label: _selectedType ?? 'Type (required*)',
                          isSelected: _selectedType != null,
                          isError: _isAttemptedSubmit && _selectedType == null,
                          items: _types,
                          currentValue: _selectedType,
                          onSelected: (val) => setState(() => _selectedType = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildPullDownField(
                          label: _selectedCity ?? 'City (required*)',
                          isSelected: _selectedCity != null,
                          isError: _isAttemptedSubmit && _selectedCity == null,
                          items: _cities,
                          currentValue: _selectedCity,
                          onSelected: (val) => setState(() => _selectedCity = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
 
                  // Field 3: Address (required*)
                  _buildTextInput(
                    controller: _addressController,
                    hint: 'Address (required*)',
                    isRequired: true,
                    isError: _isAttemptedSubmit && _addressController.text.trim().isEmpty,
                  ),
                  const SizedBox(height: 12),
 
                  // Field 4: Phone (required*)
                  _buildTextInput(
                    controller: _phoneController,
                    hint: 'Phone (required*)',
                    keyboardType: TextInputType.phone,
                    isRequired: true,
                    isError: _isAttemptedSubmit && _phoneController.text.trim().isEmpty,
                  ),
                  const SizedBox(height: 12),
 
                  // Field 5: Description
                  _buildTextInput(
                    controller: _descriptionController,
                    hint: 'Description',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
 
                  // Field 6: Work days ˅
                  _buildTappableField(
                    label: _selectedWorkDays,
                    isSelected: true,
                    onTap: _openWorkDaysPicker,
                  ),
                  const SizedBox(height: 12),
 
                  // Field 7: Coordinates (required*) - Editable text field + GPS icon + Map preview
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _coordinatesController,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: 'Coordinates (e.g. 11.512698, 3.868893)',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF6B7280),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF2A7D8F),
                              width: 1.6,
                            ),
                          ),
                          suffixIcon: GestureDetector(
                            onTap: _fetchCurrentLocation,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: _isLocating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF2A7D8F),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.gps_fixed_rounded,
                                      size: 22,
                                      color: Color(0xFF1A1A1A),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
 
                      // Compact map preview with pin & [✎ Edit map location]
                      CompactMapLocationPreview(
                        selectedLocation: _selectedCoordinates,
                        onEditLocation: _openMapLocationPicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
 
                  // Field 8: Row [Price range * ˅] [Rating (max 5.0 restriction)]
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildPullDownField(
                          label: _selectedPriceRange != null
                              ? 'Price: $_selectedPriceRange'
                              : 'Price range *',
                          isSelected: _selectedPriceRange != null,
                          isError: _isAttemptedSubmit && _selectedPriceRange == null,
                          items: _priceRanges,
                          currentValue: _selectedPriceRange,
                          onSelected: (val) =>
                              setState(() => _selectedPriceRange = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _ratingController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                          decoration: InputDecoration(
                            hintText: 'Rating (max 5.0)',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: !_isRatingValid
                                  ? const Color(0xFFD93025)
                                  : const Color(0xFF6B7280),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            errorText: !_isRatingValid
                                ? 'Max rating is 5.0 (1.0 - 5.0)'
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: !_isRatingValid
                                    ? const Color(0xFFD93025)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: !_isRatingValid
                                    ? const Color(0xFFD93025)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: !_isRatingValid
                                    ? const Color(0xFFD93025)
                                    : const Color(0xFF2A7D8F),
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
 
                  // Section 2: Facility services
                  _buildSectionHeader(
                    title: 'Facility services',
                    hasInfoIcon: true,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select all Health services offered by this facility',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF5F6368)),
                  ),
                  const SizedBox(height: 12),
 
                  // Services Input field
                  _buildTextInput(
                    controller: _servicesSearchController,
                    hint: 'Health services (At least 3 required*)',
                    prefixIcon: CupertinoIcons.search,
                    isError: _isAttemptedSubmit && _selectedServices.length < 3,
                  ),
 
                  // Suggestion Dropdown popup
                  if (_serviceSuggestions.isNotEmpty)
                    _buildSuggestionsList(
                      suggestions: _serviceSuggestions,
                      onSelect: (item) {
                        setState(() {
                          _selectedServices.add(item);
                          _servicesSearchController.clear();
                          _serviceSuggestions = [];
                        });
                      },
                    ),
 
                  const SizedBox(height: 10),
 
                  // Selected Services Chips (teal background, minus icon in circle)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedServices.map((service) {
                      return _buildSelectedChip(
                        label: service,
                        onRemove: () => setState(() => _selectedServices.remove(service)),
                      );
                    }).toList(),
                  ),
                  if (_isAttemptedSubmit && _selectedServices.length < 3)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Please select at least 3 health services',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFD93025)),
                      ),
                    ),
                  const SizedBox(height: 24),
 
                  // Section 3: Infrastucture
                  _buildSectionHeader(
                    title: 'Infrastucture',
                    hasInfoIcon: false,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select available infrastructural equipment and services (e.g. parking, restoration, in house pharmacy, morgue, CT scanner, oxygen supply, Incubators ).',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF5F6368), height: 1.3),
                  ),
                  const SizedBox(height: 12),
 
                  // Infrastructure Input field
                  _buildTextInput(
                    controller: _infraSearchController,
                    hint: '(At least 3 required*)',
                    prefixIcon: CupertinoIcons.search,
                    isError: _isAttemptedSubmit && _selectedInfrastructure.length < 3,
                  ),
 
                  // Suggestion Dropdown popup
                  if (_infraSuggestions.isNotEmpty)
                    _buildSuggestionsList(
                      suggestions: _infraSuggestions,
                      onSelect: (item) {
                        setState(() {
                          _selectedInfrastructure.add(item);
                          _infraSearchController.clear();
                          _infraSuggestions = [];
                        });
                      },
                    ),
 
                  const SizedBox(height: 10),
 
                  // Selected Infrastructure Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedInfrastructure.map((infra) {
                      return _buildSelectedChip(
                        label: infra,
                        onRemove: () =>
                            setState(() => _selectedInfrastructure.remove(infra)),
                      );
                    }).toList(),
                  ),
                  if (_isAttemptedSubmit && _selectedInfrastructure.length < 3)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Please select at least 3 infrastructure equipment items',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFD93025)),
                      ),
                    ),
                  const SizedBox(height: 24),
 
                  // Section 4: Facility photos (Native OS Photo Picker Launcher)
                  _buildSectionHeader(
                    title: 'Facility photos',
                    hasInfoIcon: false,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add clear and helpful photos, like signboards, equipment, rooms, reception desk, building front (Max 3MB per photo).',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF5F6368), height: 1.3),
                  ),
                  const SizedBox(height: 12),
 
                  // "+ Add photos" button launching native photo picker,
                  // with a pressed-down state so the tap always feels acknowledged.
                  _AddPhotosButton(onTap: _openNativePhotoPicker),
                  const SizedBox(height: 12),
 
                  // Selected Photos thumbnails with (x) delete icon
                  if (_selectedPhotos.isNotEmpty)
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedPhotos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final photoPath = _selectedPhotos[i];
                          final isLocalFile = !photoPath.startsWith('http://') &&
                              !photoPath.startsWith('https://');
 
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isLocalFile
                                    ? Image.file(
                                        File(photoPath),
                                        width: 74,
                                        height: 74,
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: photoPath,
                                        width: 74,
                                        height: 74,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedPhotos.removeAt(i)),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.2),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
 
          // Fixed Bottom Bar (Notice + Cancel + Submit buttons)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9F8).withValues(alpha: 0.96),
                border: const Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Review Notice Line (matches Image 1: "Edits will be reviewed before beign accepted !")
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edits will be reviewed before beign accepted',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF5F6368),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.info_rounded,
                          size: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
 
                    // Cancel & Submit Buttons Row
                    Row(
                      children: [
                        // Cancel Button
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD0D5DD)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2A7D8F),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
 
                        // Submit Button
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isValid
                                    ? const Color(0xFF2A7D8F)
                                    : const Color(0xFFE5E7EB),
                                foregroundColor:
                                    isValid ? Colors.white : const Color(0xFF9CA3AF),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed:
                                  (isValid && !_isSubmitting) ? _onSubmit : null,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader({required String title, required bool hasInfoIcon}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        if (hasInfoIcon) ...[
          const SizedBox(width: 6),
          const Icon(
            Icons.info_rounded,
            size: 16,
            color: Color(0xFF1A1A1A),
          ),
        ],
      ],
    );
  }
 
  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? prefixIcon,
    bool isRequired = false,
    bool isError = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: isError ? const Color(0xFFD93025) : const Color(0xFF6B7280),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: const Color(0xFF6B7280))
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isError ? const Color(0xFFD93025) : const Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isError ? const Color(0xFFD93025) : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isError ? const Color(0xFFD93025) : const Color(0xFF2A7D8F),
            width: 1.6,
          ),
        ),
      ),
    );
  }
 
  /// Simple tappable field for pickers that open a custom sheet (not a
  /// plain list) — e.g. the work-days scheduler.
  Widget _buildTappableField({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isError = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError ? const Color(0xFFD93025) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isError
                      ? const Color(0xFFD93025)
                      : isSelected
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF6B7280),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.schedule_rounded,
              size: 17,
              color: Color(0xFF2A7D8F),
            ),
          ],
        ),
      ),
    );
  }
 
  /// Compact, field-anchored picker — renders right below the tapped field
  /// (like an iOS pull-down menu), never a full-screen bottom sheet.
  Widget _buildPullDownField({
    required String label,
    required bool isSelected,
    required List<String> items,
    required String? currentValue,
    required ValueChanged<String> onSelected,
    bool isError = false,
  }) {
    return Builder(
      builder: (fieldContext) {
        return GestureDetector(
          onTap: () => _showCompactPicker(
            fieldContext: fieldContext,
            items: items,
            currentValue: currentValue,
            onSelected: onSelected,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isError ? const Color(0xFFD93025) : const Color(0xFFE5E7EB),
                width: isSelected ? 1.3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isError
                          ? const Color(0xFFD93025)
                          : isSelected
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A7D8F).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.chevron_down,
                    size: 12,
                    color: Color(0xFF2A7D8F),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
 
  /// Shows a small, rounded popover anchored to [fieldContext]'s own field —
  /// it appears right at the field's level (like an iOS pull-down menu),
  /// not a bottom sheet that fills the screen.
  Future<void> _showCompactPicker({
    required BuildContext fieldContext,
    required List<String> items,
    required String? currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final renderBox = fieldContext.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final fieldTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final fieldSize = renderBox.size;
 
    final position = RelativeRect.fromLTRB(
      fieldTopLeft.dx,
      fieldTopLeft.dy + fieldSize.height + 6,
      overlay.size.width - (fieldTopLeft.dx + fieldSize.width),
      0,
    );
 
    final selected = await showMenu<String>(
      context: context,
      position: position,
      constraints: BoxConstraints(minWidth: fieldSize.width, maxWidth: fieldSize.width + 40),
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      items: items.map((item) {
        final isCurrent = item == currentValue;
        return PopupMenuItem<String>(
          value: item,
          height: 42,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? const Color(0xFF2A7D8F)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (isCurrent)
                const Icon(CupertinoIcons.check_mark, size: 16, color: Color(0xFF2A7D8F)),
            ],
          ),
        );
      }).toList(),
    );
 
    if (selected != null) onSelected(selected);
  }
 
  Widget _buildSuggestionsList({
    required List<String> suggestions,
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: suggestions.map((item) {
          return InkWell(
            onTap: () => onSelect(item),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF2F4F7))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, size: 16, color: Color(0xFF2A7D8F)),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
 
  Widget _buildSelectedChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A7D8F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFF7A9EA6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.remove,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 
/// "Add photos" trigger with a visible pressed state (filled background +
/// slight scale-down) so the user always gets feedback that the tap
/// registered before the native photo picker sheet opens.
class _AddPhotosButton extends StatefulWidget {
  final VoidCallback onTap;
 
  const _AddPhotosButton({required this.onTap});
 
  @override
  State<_AddPhotosButton> createState() => _AddPhotosButtonState();
}
 
class _AddPhotosButtonState extends State<_AddPhotosButton> {
  bool _isPressed = false;
 
  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isPressed ? const Color(0xFF2A7D8F) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A7D8F)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 18,
                color: _isPressed ? Colors.white : const Color(0xFF2A7D8F),
              ),
              const SizedBox(width: 8),
              Text(
                'Add photos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isPressed ? Colors.white : const Color(0xFF2A7D8F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}