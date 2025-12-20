import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/book.dart';
import '../../models/reading_state.dart';
import '../../providers.dart';
import '../reader/reader_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String? _openTileId;

  void _setOpenTile(String? id) {
    setState(() {
      _openTileId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _setOpenTile(null),
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
                  final isOpen = _openTileId == book.id;
                  return _BookTile(
                    book: book,
                    progress: progress,
                    onOpen: () => _openBook(context, ref, book),
                    onDelete: () => _deleteBook(context, ref, book),
                    isOpen: isOpen,
                    onSlideChanged: (open) =>
                        _setOpenTile(open ? book.id : null),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
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

  Future<void> _deleteBook(
      BuildContext context, WidgetRef ref, Book book) async {
    final repo = ref.read(libraryRepositoryProvider);
    await repo.deleteBook(book.id);
    await ref.read(booksProvider.notifier).refresh();
    await ref.read(readingStatesProvider.notifier).refresh();
    _setOpenTile(null);
  }

  double _progressPercent(Book book, ReadingState? state) {
    if (state == null || book.totalUnits == 0) return 0;
    final current = state.currentUnitIndex;
    final total = book.totalUnits;
    return ((current + 1) / total * 100).clamp(0, 100);
  }
}

class _BookTile extends StatefulWidget {
  const _BookTile({
    required this.book,
    required this.progress,
    required this.onOpen,
    required this.onDelete,
    required this.isOpen,
    required this.onSlideChanged,
  });

  final Book book;
  final double progress;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool isOpen;
  final ValueChanged<bool> onSlideChanged;

  @override
  State<_BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<_BookTile> {
  static const double _actionWidth = 96;
  double _dragX = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(-_actionWidth, _actionWidth);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final shouldOpen = (_dragX < -_actionWidth / 2) || widget.isOpen;
    widget.onSlideChanged(shouldOpen);
    setState(() {
      _dragX = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final offset = widget.isOpen ? -_actionWidth : 0.0;
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Theme.of(context)
                  .colorScheme
                  .error
                  .withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            left: offset + _dragX,
            right: -(offset + _dragX),
            top: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                onTap: () {
                  if (widget.isOpen) {
                    widget.onSlideChanged(false);
                  } else {
                    widget.onOpen();
                  }
                },
                child: ListTile(
                  title: Text(widget.book.title),
                  subtitle: Text(widget.book.author),
                  trailing: Text('${widget.progress.toStringAsFixed(0)}%'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
