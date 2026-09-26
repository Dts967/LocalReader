import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/book.dart';
import 'models/book_chapters.dart';
import 'models/reader_settings.dart';
import 'pages/bookshelf_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(BookAdapter());
  Hive.registerAdapter(BookChaptersAdapter());
  Hive.registerAdapter(ReaderSettingsAdapter());

  await Hive.openBox<Book>('books');
  await Hive.openBox<BookChapters>('book_chapters');
  await Hive.openBox<ReaderSettings>('settings');

  final settingsBox = Hive.box<ReaderSettings>('settings');
  settingsBox.put('defaults', settingsBox.get('defaults') ?? ReaderSettings());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _theme(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 3,
        backgroundColor: scheme.surface,
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(fontSize: 15),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box<ReaderSettings>('settings');

    return ValueListenableBuilder(
      valueListenable: settingsBox.listenable(),
      builder: (context, Box<ReaderSettings> _, __) {
        final setting = settingsBox.get('defaults') ?? ReaderSettings();
        final seedIndex = setting.seedIndex.clamp(0, kSeedColors.length - 1).toInt();
        final seed = Color(kSeedColors[seedIndex]);

        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final useDynamic = setting.dynamicColor;
            final light = useDynamic && lightDynamic != null
                ? lightDynamic
                : ColorScheme.fromSeed(
                    seedColor: seed,
                    brightness: Brightness.light,
                  );
            final dark = useDynamic && darkDynamic != null
                ? darkDynamic
                : ColorScheme.fromSeed(
                    seedColor: seed,
                    brightness: Brightness.dark,
                  );

            return MaterialApp(
              title: '本地阅读',
              debugShowCheckedModeBanner: false,
              theme: _theme(light),
              darkTheme: _theme(dark),
              themeMode: setting.theme,
              home: ValueListenableBuilder(
                valueListenable: Hive.box<Book>('books').listenable(),
                builder: (context, box, _) => const BookShelfPage(),
              ),
            );
          },
        );
      },
    );
  }
}
