import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../models/reading_state.dart';
import '../../providers.dart';
import '../reader/reader_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final statesAsync = ref.watch(readingStatesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () {
              final themeMode = ref.read(themeControllerProvider);
              final next = themeMode == ThemeMode.light
                  ? ThemeMode.dark
                  : themeMode == ThemeMode.dark
                      ? ThemeMode.system
                      : ThemeMode.light;
              ref.read(themeControllerProvider.notifier).setTheme(next);
            },
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(booksProvider.notifier).refresh();
          await ref.read(readingStatesProvider.notifier).refresh();
        },
        child: booksAsync.when(
          data: (books) {
            if (books.isEmpty) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 64),
                children: const [
                  Center(
                    child: Text(
                      "No books yet.\nTap '+' to add one.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            final states = statesAsync.valueOrNull ?? {};
            return ListView.separated(
              itemCount: books.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final book = books[index];
                final state = states[book.id];
                final progress = _progressPercent(book, state);
                return ListTile(
                  title: Text(book.title),
                  subtitle: Text(book.author),
                  trailing: Text('${progress.toStringAsFixed(0)}%'),
                  onTap: () => _openBook(context, ref, book),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _importBook(context, ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
    );
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Importing book...')),
      );
      await ref.read(bookImportServiceProvider).importFromDevice();
      await ref.read(booksProvider.notifier).refresh();
      await ref.read(readingStatesProvider.notifier).refresh();
      messenger.showSnackBar(
        const SnackBar(content: Text('Book added')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to import: $e')),
      );
    }
  }

  void _openBook(BuildContext context, WidgetRef ref, Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book),
      ),
    );
  }

  double _progressPercent(Book book, ReadingState? state) {
    if (state == null || book.totalUnits == 0) return 0;
    final current = state.currentUnitIndex;
    final total = book.totalUnits;
    return ((current + 1) / total * 100).clamp(0, 100);
  }
}
