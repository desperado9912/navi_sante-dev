import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi_sante/features/home/map/map_service.dart';

class CompactMapLocationPreview extends StatelessWidget {
  final LatLng selectedLocation;
  final VoidCallback onEditLocation;

  const CompactMapLocationPreview({
    super.key,
    required this.selectedLocation,
    required this.onEditLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: true,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: selectedLocation,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.cartoLightUrl,
                  fallbackUrl: MapConfig.fallbackUrl,
                  subdomains: MapConfig.subdomains,
                  userAgentPackageName: MapConfig.userAgentPackageName,
                  tileProvider: NetworkTileProvider(
                    headers: Map.of(MapConfig.tileHeaders),
                  ),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFD93025),
                        size: 38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Map data copyright watermark
          Positioned(
            right: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Map data ©2026',
                style: TextStyle(fontSize: 9, color: Color(0xFF5F6368)),
              ),
            ),
          ),

          // Edit map location floating pill button (matches Image 3)
          Positioned(
            left: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: onEditLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_location_alt_outlined,
                      size: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Edit map location',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
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
}

/// Full interactive modal sheet / screen to select location by moving map marker
class InteractiveMapPickerSheet extends StatefulWidget {
  final LatLng initialLocation;

  const InteractiveMapPickerSheet({
    super.key,
    required this.initialLocation,
  });

  static Future<LatLng?> show(BuildContext context, LatLng initial) {
    return showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InteractiveMapPickerSheet(initialLocation: initial),
    );
  }

  @override
  State<InteractiveMapPickerSheet> createState() =>
      _InteractiveMapPickerSheetState();
}

class _InteractiveMapPickerSheetState extends State<InteractiveMapPickerSheet> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialLocation;
  }

  Future<void> _locateUser() async {
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
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final newLoc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentCenter = newLoc;
          _isLocating = false;
        });
        _mapController.move(newLoc, 16.0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Drag handle & Top Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Set map location',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Text(
                      '${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2A7D8F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Interactive Map Area
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 16.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _currentCenter = camera.center;
                        });
                      }
                    },
                    onTap: (tapPosition, point) {
                      setState(() {
                        _currentCenter = point;
                      });
                      _mapController.move(point, _mapController.camera.zoom);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapConfig.cartoLightUrl,
                      fallbackUrl: MapConfig.fallbackUrl,
                      subdomains: MapConfig.subdomains,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                      tileProvider: NetworkTileProvider(
                        headers: Map.of(MapConfig.tileHeaders),
                      ),
                    ),
                  ],
                ),

                // Center Pin Marker
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 38.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Move map to place pin',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFD93025),
                          size: 42,
                        ),
                      ],
                    ),
                  ),
                ),

                // Target GPS button
                Positioned(
                  right: 16,
                  bottom: 20,
                  child: FloatingActionButton.small(
                    heroTag: 'map_picker_gps_btn',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2A7D8F),
                    elevation: 3,
                    onPressed: _locateUser,
                    child: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2A7D8F),
                            ),
                          )
                        : const Icon(Icons.my_location, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Confirmation Bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A7D8F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, _currentCenter),
                  child: const Text(
                    'Confirm Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
