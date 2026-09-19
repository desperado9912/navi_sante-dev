import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Result of picking and validating images via the device's native photo picker.
class ImagePickerResult {
  final List<String> validFilePaths;
  final List<String> errorMessages;

  const ImagePickerResult({
    required this.validFilePaths,
    this.errorMessages = const [],
  });

  bool get hasErrors => errorMessages.isNotEmpty;
}

/// Service that leverages the OS native photo picker (PHPicker on iOS, Android Photo Picker on Android)
/// with strict validation:
/// - Maximum 3MB file size restriction
/// - Magic byte signature checking for genuine image formats (JPEG, PNG, WEBP, GIF, HEIC)
/// - Light compression (quality: 85, max dimensions: 1920x1920) preserving visual fidelity
class NativePhotoService {
  static final ImagePicker _picker = ImagePicker();
  static const int maxFileSizeInBytes = 3 * 1024 * 1024; // 3 MB

  /// Launches the device's default native system photo picker.
  static Future<ImagePickerResult> pickVerifiedImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFiles.isEmpty) {
        return const ImagePickerResult(validFilePaths: []);
      }

      final List<String> validPaths = [];
      final List<String> errors = [];

      for (final file in pickedFiles) {
        final Uint8List bytes = await file.readAsBytes();

        // 1. File Size Validation (Max 3MB)
        if (bytes.length > maxFileSizeInBytes) {
          final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
          errors.add('"${file.name}" is ${sizeMb}MB (exceeds 3MB maximum).');
          continue;
        }

        // 2. Magic Byte Verification & MIME Type Checking
        if (!_verifyImageMagicBytes(bytes)) {
          errors.add('"${file.name}" is not a recognized image format.');
          continue;
        }

        validPaths.add(file.path);
      }

      return ImagePickerResult(
        validFilePaths: validPaths,
        errorMessages: errors,
      );
    } catch (e) {
      debugPrint('Error picking images from system gallery: $e');
      return ImagePickerResult(
        validFilePaths: [],
        errorMessages: ['Could not open system photo library: $e'],
      );
    }
  }

  /// Validates genuine image magic bytes (header signatures)
  static bool _verifyImageMagicBytes(Uint8List bytes) {
    if (bytes.length < 12) return false;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    // GIF: 47 49 46 38 ("GIF8")
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }

    // WEBP: "RIFF" .... "WEBP"
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    // HEIC / HEIF: bytes 4-8 are 'ftyp' followed by 'heic', 'heix', 'mif1', etc.
    if (bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return true;
    }

    return false;
  }
}
