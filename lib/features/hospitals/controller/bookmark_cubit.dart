import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/facility_repository.dart';
import '../data/facility_model.dart';

class BookmarkState {
  final Set<String> bookmarkedIds;
  final List<FacilityModel> savedFacilities;
  final bool isLoading;

  BookmarkState({
    this.bookmarkedIds = const {},
    this.savedFacilities = const [],
    this.isLoading = false,
  });
}

class BookmarkCubit extends Cubit<BookmarkState> {
  final FacilityRepository _repository;

  BookmarkCubit({required FacilityRepository repository})
    : _repository = repository,
      super(BookmarkState());

  Future<void> loadBookmarks() async {
    // Prevent redundant network calls if already loaded
    if (state.bookmarkedIds.isNotEmpty || state.savedFacilities.isNotEmpty) {
      return;
    }

    // Instant loading placeholder for widget build
    emit(
      BookmarkState(
        bookmarkedIds: state.bookmarkedIds,
        savedFacilities: state.savedFacilities,
        isLoading: true,
      ),
    );

    // Silently retry on failure using exponential backoff
    int retries = 0;
    while (retries < 3) {
      try {
        final bookmarks = await _repository.getUserBookmarks();
        final ids = bookmarks.map((b) => b.facilityId).toSet();
        emit(
          BookmarkState(
            bookmarkedIds: ids,
            savedFacilities: bookmarks,
            isLoading: false,
          ),
        );
        return;
      } catch (e) {
        retries++;
        await Future.delayed(Duration(seconds: retries * 3));
      }
    }

    // Failed silently, stop loading
    emit(
      BookmarkState(
        bookmarkedIds: state.bookmarkedIds,
        savedFacilities: state.savedFacilities,
        isLoading: false,
      ),
    );
  }

  // Manual bookmarks refresh from pull down on screen.
  Future<void> refreshBookmarks() async {
    emit(
      BookmarkState(
        bookmarkedIds: state.bookmarkedIds,
        savedFacilities: state.savedFacilities,
        isLoading: true,
      ),
    );

    try {
      final bookmarks = await _repository.getUserBookmarks();
      final ids = bookmarks.map((b) => b.facilityId).toSet();
      emit(
        BookmarkState(
          bookmarkedIds: ids,
          savedFacilities: bookmarks,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        BookmarkState(
          bookmarkedIds: state.bookmarkedIds,
          savedFacilities: state.savedFacilities,
          isLoading: false,
        ),
      );
    }
  }

  void clear() {
    emit(BookmarkState());
  }

  void toggleBookmark(String facilityId) async {
    final currentIds = Set<String>.from(state.bookmarkedIds);
    final currentFacilities = List<FacilityModel>.from(state.savedFacilities);

    final isCurrentlyBookmarked = currentIds.contains(facilityId);

    if (isCurrentlyBookmarked) {
      currentIds.remove(facilityId);
      currentFacilities.removeWhere((f) => f.facilityId == facilityId);
    } else {
      currentIds.add(facilityId);
      final model = _repository.getFacilitySync(facilityId);
      if (model != null) {
        currentFacilities.insert(0, model); // Add to top of list
      }
    }

    emit(
      BookmarkState(
        bookmarkedIds: currentIds,
        savedFacilities: currentFacilities,
        isLoading: state.isLoading,
      ),
    );

    // Attempt network sync
    try {
      if (isCurrentlyBookmarked) {
        await _repository.removeBookmark(facilityId);
      } else {
        await _repository.addBookmark(facilityId);
      }
    } catch (e) {
      // Revert on failure
      final revertedIds = Set<String>.from(state.bookmarkedIds);
      final revertedFacilities = List<FacilityModel>.from(
        state.savedFacilities,
      );

      if (isCurrentlyBookmarked) {
        revertedIds.add(facilityId);
        final model = _repository.getFacilitySync(facilityId);
        if (model != null) revertedFacilities.insert(0, model);
      } else {
        revertedIds.remove(facilityId);
        revertedFacilities.removeWhere((f) => f.facilityId == facilityId);
      }

      emit(
        BookmarkState(
          bookmarkedIds: revertedIds,
          savedFacilities: revertedFacilities,
          isLoading: state.isLoading,
        ),
      );
    }
  }
}
