import 'dart:typed_data';

/// Utility class to format and convert geographic coordinates
/// to and from standard PostGIS formats (EWKB hex and EWKT).
///
/// PostGIS SRID 4326 (WGS 84) point geometry format:
/// - Byte 0: 0x01 (Little Endian)
/// - Bytes 1-4: 0x20000001 (Point with SRID in Little Endian: 01 00 00 20)
/// - Bytes 5-8: 4326 (SRID in Little Endian: E6 10 00 00)
/// - Bytes 9-16: X (longitude) as 64-bit float in Little Endian
/// - Bytes 17-24: Y (latitude) as 64-bit float in Little Endian
///
/// Example:
/// Lat: 3.8688932107800404, Lng: 11.512698739088105
/// -> 0101000020E61000006F9C14E63DFE26401D041DAD6AE90E40
class PostGisUtils {
  static const int srid = 4326;

  /// Converts [latitude] and [longitude] to PostGIS EWKB Hex string.
  static String toEwkbHex({required double latitude, required double longitude}) {
    final byteData = ByteData(25);

    // Byte 0: Little Endian
    byteData.setUint8(0, 0x01);

    // Bytes 1-4: Point geometry type with SRID flag (0x20000001)
    byteData.setUint32(1, 0x20000001, Endian.little);

    // Bytes 5-8: SRID 4326
    byteData.setUint32(5, srid, Endian.little);

    // Bytes 9-16: Longitude (X)
    byteData.setFloat64(9, longitude, Endian.little);

    // Bytes 17-24: Latitude (Y)
    byteData.setFloat64(17, latitude, Endian.little);

    final buffer = StringBuffer();
    for (int i = 0; i < 25; i++) {
      buffer.write(byteData.getUint8(i).toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }

  /// Converts [latitude] and [longitude] to PostGIS EWKT string:
  /// e.g. "SRID=4326;POINT(11.5126987 3.8688932)"
  static String toEwkt({required double latitude, required double longitude}) {
    return 'SRID=$srid;POINT(${longitude.toStringAsFixed(7)} ${latitude.toStringAsFixed(7)})';
  }

  /// Formats human-readable coordinate string:
  /// e.g. "11.5126987, 3.8688932"
  static String toHumanReadable({required double latitude, required double longitude}) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Parses EWKB hex back to LatLng pair if valid.
  static ({double latitude, double longitude})? parseEwkbHex(String hex) {
    if (hex.length != 50) return null;
    try {
      final bytes = Uint8List(25);
      for (int i = 0; i < 25; i++) {
        bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      final byteData = ByteData.sublistView(bytes);
      final lng = byteData.getFloat64(9, Endian.little);
      final lat = byteData.getFloat64(17, Endian.little);
      return (latitude: lat, longitude: lng);
    } catch (_) {
      return null;
    }
  }
}
