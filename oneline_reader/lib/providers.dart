import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/book.dart';
import 'models/reading_state.dart';
import 'services/import/book_import_service.dart';
import 'services/preferences/user_preferences.dart';
import 'services/storage/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

final userPreferencesProvider = Provider<UserPreferences>((ref) {
  return UserPreferences();
});

final bookImportServiceProvider = Provider<BookImportService>((ref) {
  return BookImportService(
    libraryRepository: ref.read(libraryRepositoryProvider),
  );
});

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._prefs) : super(ThemeMode.system) {
    _load();
  }

  final UserPreferences _prefs;

  Future<void> _load() async {
    final stored = await _prefs.loadTheme();
    state = _mapToThemeMode(stored);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _prefs.saveTheme(_mapFromThemeMode(mode));
  }

  ThemeMode _mapToThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppThemeMode _mapFromThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  final prefs = ref.read(userPreferencesProvider);
  return ThemeController(prefs);
});

class FontScaleController extends StateNotifier<double> {
  FontScaleController(this._prefs) : super(1.0) {
    _load();
  }

  final UserPreferences _prefs;

  Future<void> _load() async {
    final stored = await _prefs.loadFontScale();
    state = stored;
  }

  Future<void> setScale(double scale) async {
    state = scale;
    await _prefs.saveFontScale(scale);
  }
}

final fontScaleProvider =
    StateNotifierProvider<FontScaleController, double>((ref) {
  final prefs = ref.read(userPreferencesProvider);
  return FontScaleController(prefs);
});

class BooksNotifier extends StateNotifier<AsyncValue<List<Book>>> {
  BooksNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  final LibraryRepository _repo;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final books = await _repo.loadBooks();
      state = AsyncValue.data(books);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final booksProvider =
    StateNotifierProvider<BooksNotifier, AsyncValue<List<Book>>>((ref) {
  return BooksNotifier(ref.read(libraryRepositoryProvider));
});

class ReadingStateNotifier
    extends StateNotifier<AsyncValue<Map<String, ReadingState>>> {
  ReadingStateNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final LibraryRepository _repo;

  Future<void> refresh() async => _load();

  Future<void> _load() async {
    try {
      final states = await _repo.loadStates();
      state = AsyncValue.data({for (final s in states) s.bookId: s});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  ReadingState? getFor(String bookId) {
    final data = state.valueOrNull;
    return data?[bookId];
  }

  Future<void> upsert(ReadingState updated) async {
    final data = Map<String, ReadingState>.from(state.valueOrNull ?? {});
    data[updated.bookId] = updated;
    state = AsyncValue.data(data);
    await _repo.upsertState(updated);
  }
}

final readingStatesProvider = StateNotifierProvider<ReadingStateNotifier,
    AsyncValue<Map<String, ReadingState>>>((ref) {
  return ReadingStateNotifier(ref.read(libraryRepositoryProvider));
});
