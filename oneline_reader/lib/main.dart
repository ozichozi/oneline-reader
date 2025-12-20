import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers.dart';
import 'ui/library/library_screen.dart';

void main() {
  runApp(const ProviderScope(child: OneLineReaderApp()));
}

class OneLineReaderApp extends ConsumerWidget {
  const OneLineReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final baseTextTheme = GoogleFonts.ebGaramondTextTheme();
    return MaterialApp(
      title: 'OneLine Reader',
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        textTheme: baseTextTheme,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: baseTextTheme.apply(bodyColor: Colors.white),
      ),
      home: const LibraryScreen(),
    );
  }
}
