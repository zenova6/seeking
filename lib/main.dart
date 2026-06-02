import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:seeking/ideas.dart';
import 'package:seeking/music.dart';
import 'package:seeking/newidea.dart';
import 'package:seeking/db_helper.dart';

class C {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF111118);
  static const card = Color(0xFF1C1C24);
  static const accent = Color(0xFF7B5EA7);
  static const accentLight = Color(0xFF9D7DD1);
  static const textPrimary = Color(0xFFF0EEF8);
  static const textSecondary = Color(0xFFB8B4CC);
  static const hint = Color(0xFF5A5870);
}

late MyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.db;
  runApp(const SeekingApp());
  try {
    final handler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.seeking.audio',
        androidNotificationChannelName: 'Seeking Music',
        androidNotificationOngoing: true,
      ),
    ).timeout(const Duration(seconds: 10));
    audioHandler = handler as MyAudioHandler;
  } catch (e) {
    debugPrint('AudioService init failed: $e');
    audioHandler = MyAudioHandler();
  }
}

class SeekingApp extends StatelessWidget {
  const SeekingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seeking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: C.bg,
        canvasColor: C.bg,          // ✅ fixes grey TabBarView background
        colorScheme: const ColorScheme.dark(
          primary: C.accent,
          surface: C.bg,            // ✅ ensures all surfaces use dark bg
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: C.bg,
          elevation: 0,
          centerTitle: false,
        ),
        tabBarTheme: const TabBarThemeData(
          dividerColor: Colors.transparent,
          indicatorColor: C.accentLight,
          labelColor: C.accentLight,
          unselectedLabelColor: C.hint,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: C.card,
          labelStyle: const TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const MainShell(),
      routes: {
        '/newIdea': (context) => const NewIdeaScreen(),
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final List<Widget> _screens = const [IdeasScreen(), MusicScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: C.surface,
        indicatorColor: C.accent.withOpacity(0.3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb, color: C.accentLight),
            label: 'Ideas',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note, color: C.accentLight),
            label: 'Music',
          ),
        ],
      ),
    );
  }
}