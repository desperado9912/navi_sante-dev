import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/contribution_ticket.dart';
import '../viewmodel/contribute_bloc.dart';
import '../widgets/facility_selector.dart';
import '../widgets/native_photo_service.dart';
import '../../hospitals/data/facility_model.dart';

class AddPhotoScreen extends StatefulWidget {
  final ContributionTicket? editingTicket;

  const AddPhotoScreen({super.key, this.editingTicket});

  @override
  State<AddPhotoScreen> createState() => _AddPhotoScreenState();
}

class _AddPhotoScreenState extends State<AddPhotoScreen> {
  static const int _maxPhotos = 5;

  final ContributionBackendService _backendService =
      ContributionBackendService();
  final List<String> _selectedPhotos = [];
  FacilityDetailModel? _facility;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final ticket = widget.editingTicket;
    if (ticket != null) _selectedPhotos.addAll(ticket.photoUrls);
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _selectedPhotos.length;
    if (remaining <= 0) {
      _showMessage('You can add up to $_maxPhotos photos.');
      return;
    }

    final result = await NativePhotoService.pickVerifiedImages();
    if (!mounted) return;
    if (result.hasErrors) _showMessage(result.errorMessages.first);
    if (result.validFilePaths.isEmpty) return;

    setState(() {
      _selectedPhotos.addAll(result.validFilePaths.take(remaining));
    });
  }

  Future<void> _submit() async {
    final facility = _facility;
    if (facility == null) {
      _showMessage('Select a facility first.');
      return;
    }
    if (_selectedPhotos.isEmpty) {
      _showMessage('Select at least one photo.');
      return;
    }
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await _backendService.submitPhotoContribution(
        ticketId: widget.editingTicket?.id,
        facility: facility,
        localPhotoPaths: _selectedPhotos,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showMessage('Could not submit photos: $e', error: true);
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photos submitted and pending review.'),
        backgroundColor: Color(0xFF2A7D8F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFD93025) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editingTicket = widget.editingTicket;

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
          editingTicket == null ? 'Add photo' : 'Edit photo contribution',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              'Choose a facility',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FacilitySelector(
              initialFacilityId: editingTicket?.targetFacilityId,
              onSelected: (facility) => setState(() => _facility = facility),
              onCleared: () => setState(() => _facility = null),
            ),
            const SizedBox(height: 28),
            const Text(
              'Choose photos',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select clear photos of the facility from your gallery (1–5 photos). Each photo must be under 3 MB.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF5F6368),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickPhotos,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _selectedPhotos.isEmpty
                    ? 'Choose from gallery (up to $_maxPhotos)'
                    : '${_selectedPhotos.length} selected (max $_maxPhotos)',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2A7D8F),
                side: const BorderSide(color: Color(0xFF2A7D8F)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_selectedPhotos.isNotEmpty) ...[
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedPhotos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final path = _selectedPhotos[index];
                  final isRemote = path.startsWith('http://') ||
                      path.startsWith('https://');
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: isRemote
                              ? CachedNetworkImage(imageUrl: path, fit: BoxFit.cover)
                              : Image.file(File(path), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: -7,
                        right: -7,
                        child: IconButton(
                          onPressed: () => setState(() => _selectedPhotos.removeAt(index)),
                          icon: const Icon(Icons.cancel, color: Color(0xFFD93025)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit photos'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2A7D8F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
