import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/contribution_ticket.dart';
import '../widgets/facility_selector.dart';
import 'suggest_facility.dart';
import '../../hospitals/data/facility_model.dart';

/// Selects an existing facility, then reuses the complete suggestion form in
/// update mode with the facility's current values prefilled.
class UpdateFacilityScreen extends StatefulWidget {
  final ContributionTicket? editingTicket;

  const UpdateFacilityScreen({super.key, this.editingTicket});

  @override
  State<UpdateFacilityScreen> createState() => _UpdateFacilityScreenState();
}

class _UpdateFacilityScreenState extends State<UpdateFacilityScreen> {
  FacilityDetailModel? _facility;

  void _continueToForm() {
    final facility = _facility;
    if (facility == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a facility first.')),
      );
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SuggestFacilityScreen(
          initialFacility: facility,
          contributionType: ContributionType.updateFacility,
          editingTicket: widget.editingTicket,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Update facility',
          style: TextStyle(
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
              'Choose a facility to update',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FacilitySelector(
              initialFacilityId: widget.editingTicket?.targetFacilityId,
              onSelected: (facility) => setState(() => _facility = facility),
              onCleared: () => setState(() => _facility = null),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _continueToForm,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Continue to facility information'),
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
