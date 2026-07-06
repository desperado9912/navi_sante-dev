import 'package:flutter/cupertino.dart';
import 'package:navi_sante/core/utils/app_bottom_sheet.dart';

/// Bottom sheet that shows map attribution and data source information.
class MapInfoSheet extends StatelessWidget {
  const MapInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Map Information',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Map style card
            _InfoCard(
              children: [
                _InfoRow(
                  icon: CupertinoIcons.layers_alt,
                  label: 'Tile Provider',
                  value: 'Carto CDN',
                ),
              ],
            ),

            const SizedBox(height: 15),

            // OSM Attribution card
            _InfoCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '© OpenStreetMap and other contributors',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Map data is licensed under the Open Database License (ODbL).',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5F6368),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }
}

/// Rounded card container that wraps a column of info rows.
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

/// A single label / value row inside an [_InfoCard].
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A1A1A)),  
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5F6368),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
