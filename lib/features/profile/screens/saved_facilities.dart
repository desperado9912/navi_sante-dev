import 'package:flutter/material.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hospitals/controller/bookmark_cubit.dart';

class SavedFacilities extends StatefulWidget {
  const SavedFacilities({super.key});
  @override
  State<SavedFacilities> createState() => _SavedFacilitiesState();
}

class _SavedFacilitiesState extends State<SavedFacilities> {
  @override
  void initState() {
    super.initState();
    MemoryLeakTracker.logInit(this);
    // Trigger load if not loaded yet
    context.read<BookmarkCubit>().loadBookmarks();
  }
  
  @override
  void dispose() {
    MemoryLeakTracker.logDispose(this);
    super.dispose();
  }

  // UI Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: const PlatformAdaptiveAppBar(title: 'Saved Facilities'),
      body: BlocBuilder<BookmarkCubit, BookmarkState>(
        builder: (context, state) {
          if (state.isLoading && state.savedFacilities.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.savedFacilities.isEmpty) {
            return const Center(
              child: Text(
                'Saved facilities will appear here',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.savedFacilities.length,
            itemBuilder: (context, index) {
              final facility = state.savedFacilities[index];
              return ListTile(
                title: Text(facility.name),
                // TODO: SAVED FACILITIES TILES.
              );
            },
          );
        },
      ),
    );
  }
}
