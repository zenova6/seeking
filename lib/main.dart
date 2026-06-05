import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seeking/ideas.dart';
import 'package:seeking/music.dart';
import 'package:seeking/newidea.dart';
import 'package:seeking/db_helper.dart';
import 'package:seeking/audio_handler.dart';

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
  
  // Initialize AudioService FIRST before running app
  try {
    final handler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.seeking.audio',
        androidNotificationChannelName: 'Seeking Music',
        androidNotificationOngoing: true,
      ),
    );
    audioHandler = handler as MyAudioHandler;
  } catch (e) {
    debugPrint('AudioService init failed: $e');
    audioHandler = MyAudioHandler();
  }
  
  await DBHelper.db;

  // Request permissions on app start
  await [
    Permission.storage,
    Permission.audio,
    Permission.photos,
    Permission.videos,
  ].request();

  runApp(const SeekingApp());
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
        canvasColor: C.bg,
        colorScheme: const ColorScheme.dark(
          primary: C.accent,
          secondary: C.accentLight,
          surface: C.surface,
          error: Colors.redAccent,
          onPrimary: Colors.white,
          onSurface: C.textPrimary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: C.bg.withOpacity(0.95),
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 2,
          shadowColor: C.accent.withOpacity(0.3),
          titleTextStyle: const TextStyle(
            color: C.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          dividerColor: Colors.transparent,
          indicatorColor: C.accentLight,
          labelColor: C.accentLight,
          unselectedLabelColor: C.hint,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: TextStyle(fontSize: 14),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: C.accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: C.hint),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: C.card,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          selectedColor: C.accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        cardTheme: CardTheme(
          color: C.card,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(8),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: C.accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: C.surface,
          indicatorColor: C.accent.withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.resolveWith((states) => 
            states.contains(MaterialState.selected) 
              ? const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
              : const TextStyle(fontSize: 12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: C.accentLight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: C.hint,
          ),
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
      backgroundColor: C.bg,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: C.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            backgroundColor: Colors.transparent,
            indicatorColor: C.accent.withOpacity(0.2),
            elevation: 0,
            height: 70,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.lightbulb_outline, size: 24),
                selectedIcon: Icon(Icons.lightbulb, color: C.accentLight, size: 28),
                label: 'Ideas',
              ),
              NavigationDestination(
                icon: Icon(Icons.music_note_outlined, size: 24),
                selectedIcon: Icon(Icons.music_note, color: C.accentLight, size: 28),
                label: 'Music',
              ),
            ],
          ),
        ),
      ),
    );
  }
}