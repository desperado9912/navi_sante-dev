import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:navi_sante/core/utils/app_bottom_sheet.dart';

// Bottom sheet in settings tiles for users to select preffered navigation app
class NavigationAppBottomSheet extends StatelessWidget {
  final String currentCode;

  const NavigationAppBottomSheet({
    super.key,
    required this.currentCode,
  });

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Preferred Navigation App',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose which app NaviSanté uses for directions and live navigation.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5F6368),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // TODO: ADD ORIGINAL PLATFORM LOGOS TO ASSETS FOLDER.

            // Google Maps
            _NavAppOption(
              label: 'Google Maps',
              code: 'google',
              assetPath: 'assets/google_maps_logo.svg',
              isSelected: currentCode == 'google',
              onTap: () => Navigator.pop(context, 'google'),
            ),
            const SizedBox(height: 12),

            // Apple Maps
            _NavAppOption(
              label: 'Apple Maps',
              code: 'apple',
              assetPath: 'assets/apple_maps_logo.png',
              isSelected: currentCode == 'apple',
              onTap: () => Navigator.pop(context, 'apple'),
            ),
            const SizedBox(height: 12),

            // Waze
            _NavAppOption(
              label: 'Waze',
              code: 'waze',
              assetPath: 'assets/waze_logo.svg',
              isSelected: currentCode == 'waze',
              onTap: () => Navigator.pop(context, 'waze'),
            ),
            
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }
}

class _NavAppOption extends StatelessWidget {
  final String label;
  final String code;
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavAppOption({
    required this.label,
    required this.code,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF2A7D8F).withValues(alpha: 0.1) 
              : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2A7D8F) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Platform logo from SVG or PNG asset
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: assetPath.endsWith('.svg')
              // Support svg
                  ? SvgPicture.asset(
                      assetPath,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => Icon(
                        Icons.map_rounded,
                        size: 24,
                        color: isSelected 
                            ? const Color(0xFF2A7D8F) 
                            : const Color(0xFF1A1A1A),
                      ),
                    )
                    // Support PNG
                  : Image.asset(
                      assetPath,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,

                      // fallback icon if logo is not found or displayed
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.map_rounded,
                        size: 24,
                        color: isSelected 
                            ? const Color(0xFF2A7D8F) 
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2A7D8F) : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2A7D8F),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
