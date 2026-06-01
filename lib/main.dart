import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SeekingApp());
}

// ─── THEME & COLORS ───────────────────────────────────────────────
class AppColors {
  static const background   = Color(0xFF080810);
  static const surface      = Color(0xFF0F0F1A);
  static const card         = Color(0xFF13131F);
  static const violet       = Color(0xFF7B5EA7);
  static const violetLight  = Color(0xFF9D7DD1);
  static const violetGlow   = Color(0xFF6B3FA0);
  static const pink         = Color(0xFFD05FA2);
  static const pinkLight    = Color(0xFFE87FBF);
  static const cyan         = Color(0xFF3ECFCF);
  static const white        = Color(0xFFF0EEF8);
  static const whiteD       = Color(0xFFB8B4CC);
  static const grey         = Color(0xFF3A384A);
  static const greyLight    = Color(0xFF5A5870);
}

// ─── APP ROOT ────────────────────────────────────────────────────
class SeekingApp extends StatelessWidget {
  const SeekingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seeking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.violet,
          secondary: AppColors.pink,
          surface: AppColors.surface,
        ),

      ),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SCREEN 1 — SPLASH / ONBOARDING
// ═══════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _orb1;
  late AnimationController _orb2;
  late AnimationController _fadeIn;
  late AnimationController _slide;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineFade;
  late Animation<Offset> _btnSlide;
  late Animation<double> _btnFade;

  int _page = 0;

  final _onboardPages = [
    _OnboardData(
      title: 'Discover\nYour World',
      sub: 'Beautiful things are waiting\nto be found by you.',
      icon: Icons.explore_rounded,
    ),
    _OnboardData(
      title: 'Connect\nDeep',
      sub: 'Every moment is a chance\nto find something real.',
      icon: Icons.favorite_rounded,
    ),
    _OnboardData(
      title: 'Begin\nSeeking',
      sub: 'The journey starts\nwith a single step.',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _orb1 = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _orb2 = AnimationController(
        vsync: this, duration: const Duration(seconds: 11))
      ..repeat(reverse: true);
    _fadeIn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _slide = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _logoFade  = CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeIn, curve: Curves.elasticOut));
    _taglineSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeIn, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _taglineFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _fadeIn, curve: const Interval(0.3, 1.0)));
    _btnSlide = Tween<Offset>(
            begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));
    _btnFade = CurvedAnimation(parent: _slide, curve: Curves.easeOut);

    _fadeIn.forward();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _slide.forward();
    });
  }

  @override
  void dispose() {
    _orb1.dispose(); _orb2.dispose();
    _fadeIn.dispose(); _slide.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _onboardPages.length - 1) {
      setState(() => _page++);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── animated orbs ──
          AnimatedBuilder(
            animation: _orb1,
            builder: (_, __) => Positioned(
              top: -80 + _orb1.value * 60,
              left: -60 + _orb1.value * 40,
              child: _Orb(size: 340, color: AppColors.violetGlow.withOpacity(0.45)),
            ),
          ),
          AnimatedBuilder(
            animation: _orb2,
            builder: (_, __) => Positioned(
              bottom: 40 + _orb2.value * 80,
              right: -80 + _orb2.value * 50,
              child: _Orb(size: 280, color: AppColors.pink.withOpacity(0.3)),
            ),
          ),
          // ── noise overlay ──
          const _NoiseOverlay(),
          // ── content ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  // logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.violetLight, AppColors.pink],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.violet.withOpacity(0.6),
                                  blurRadius: 20, spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white, size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'seeking',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 26,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 6,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 72),

                  // page content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08), end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _OnboardContent(
                      key: ValueKey(_page),
                      data: _onboardPages[_page],
                    ),
                  ),

                  const Spacer(),

                  // dots
                  FadeTransition(
                    opacity: _btnFade,
                    child: Row(
                      children: List.generate(3, (i) => _Dot(active: i == _page)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CTA button
                  SlideTransition(
                    position: _btnSlide,
                    child: FadeTransition(
                      opacity: _btnFade,
                      child: _GradientButton(
                        label: _page == 2 ? 'Start Seeking' : 'Continue',
                        onTap: _next,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardData {
  final String title, sub;
  final IconData icon;
  const _OnboardData({required this.title, required this.sub, required this.icon});
}

class _OnboardContent extends StatelessWidget {
  final _OnboardData data;
  const _OnboardContent({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.violetGlow.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.violet.withOpacity(0.3), width: 1),
          ),
          child: Icon(data.icon, color: AppColors.violetLight, size: 32),
        ),
        const SizedBox(height: 32),
        Text(
          data.title,
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: AppColors.white,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          data.sub,
          style: const TextStyle(
            fontSize: 17,
            color: AppColors.whiteD,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// MAIN SHELL — bottom nav
// ═══════════════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  final _screens = const [HomeScreen(), SearchScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(key: ValueKey(_idx), child: _screens[_idx]),
      ),
      bottomNavigationBar: _BottomNav(
        current: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.grey.withOpacity(0.4), width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.violetGlow.withOpacity(0.1),
            blurRadius: 20, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', active: current == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.explore_rounded, label: 'Explore', active: current == 1, onTap: () => onTap(1)),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', active: current == 2, onTap: () => onTap(2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: active ? AppColors.violet.withOpacity(0.15) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: active ? AppColors.violetLight : AppColors.greyLight,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(
                fontSize: 10,
                color: active ? AppColors.violetLight : AppColors.greyLight,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// SCREEN 2 — HOME / FEED
// ═══════════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final _featured = [
    _CardData('Neon Dreams', 'Photography', 'Alex Rivera', '2.4k', AppColors.violetGlow, AppColors.pink),
    _CardData('Midnight Jazz', 'Music', 'Sam Cole', '1.8k', AppColors.cyan, AppColors.violetLight),
    _CardData('Digital Horizons', 'Art', 'Mia Yuen', '3.1k', AppColors.pink, AppColors.violetGlow),
  ];

  static final _recent = [
    _TileData('Urban Light', 'Street Photography', '34 min ago', Icons.camera_alt_rounded),
    _TileData('Echoes', 'Ambient Music', '1h ago', Icons.music_note_rounded),
    _TileData('Fractures', 'Digital Art', '2h ago', Icons.brush_rounded),
    _TileData('Pulse', 'Motion Design', '3h ago', Icons.play_circle_rounded),
    _TileData('Void', 'Conceptual Art', '5h ago', Icons.auto_awesome_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── header ──
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Good Evening', style: TextStyle(color: AppColors.whiteD, fontSize: 13, letterSpacing: 0.5)),
                    SizedBox(height: 2),
                    Text('What are you seeking?',
                      style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  ],
                ),
                const Spacer(),
                _AvatarBadge(),
              ],
            ),
          ),
        ),

        // ── featured cards ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _SectionHeader('Featured', 'See all'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _featured.length,
                    itemBuilder: (_, i) => _FeaturedCard(data: _featured[i]),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── categories ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader('Categories', null),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: const [
                    _Chip('All', true),
                    _Chip('Photography', false),
                    _Chip('Music', false),
                    _Chip('Art', false),
                    _Chip('Design', false),
                    _Chip('Motion', false),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── recent ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Row(children: const [_SectionHeader('Recent', 'See all')]),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _RecentTile(data: _recent[i]),
            childCount: _recent.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _CardData {
  final String title, category, author, likes;
  final Color c1, c2;
  const _CardData(this.title, this.category, this.author, this.likes, this.c1, this.c2);
}

class _TileData {
  final String title, sub, time;
  final IconData icon;
  const _TileData(this.title, this.sub, this.time, this.icon);
}

class _FeaturedCard extends StatelessWidget {
  final _CardData data;
  const _FeaturedCard({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [data.c1.withOpacity(0.8), data.c2.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(color: data.c1.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image_rounded, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Text(data.category, style: const TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(data.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(data.author, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                const Icon(Icons.favorite_rounded, color: Colors.white70, size: 12),
                const SizedBox(width: 3),
                Text(data.likes, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final _TileData data;
  const _RecentTile({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey.withOpacity(0.4), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.violetGlow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: AppColors.violetLight, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 3),
                Text(data.sub, style: const TextStyle(color: AppColors.whiteD, fontSize: 12)),
              ],
            ),
          ),
          Text(data.time, style: const TextStyle(color: AppColors.greyLight, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  const _SectionHeader(this.title, this.action);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const Spacer(),
        if (action != null)
          Text(action!, style: const TextStyle(color: AppColors.violetLight, fontSize: 13)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  const _Chip(this.label, this.active);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [AppColors.violetGlow, AppColors.violetLight])
            : null,
        color: active ? null : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? Colors.transparent : AppColors.grey.withOpacity(0.5), width: 0.5),
        boxShadow: active
            ? [BoxShadow(color: AppColors.violet.withOpacity(0.4), blurRadius: 12)]
            : null,
      ),
      child: Text(label,
        style: TextStyle(
          color: active ? Colors.white : AppColors.whiteD,
          fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.violetLight, AppColors.pink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(0.5), blurRadius: 14)],
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
        ),
        Positioned(
          right: 1, top: 1,
          child: Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(
              color: AppColors.cyan, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.cyan, blurRadius: 6)],
            ),
          ),
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// SCREEN 3 — SEARCH / DISCOVER
// ═══════════════════════════════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  bool _focused = false;

  static final _trending = [
    '#neonart', '#darkwave', '#lofi', '#cyberpunk',
    '#deepspace', '#vaporwave', '#retrosynth', '#glitch',
  ];

  static final _grid = [
    _GridItem('Cosmic', AppColors.violetGlow, AppColors.pink, Icons.star_rounded),
    _GridItem('Waves', AppColors.cyan, AppColors.violetLight, Icons.water_rounded),
    _GridItem('Void', AppColors.background, AppColors.violet, Icons.circle_outlined),
    _GridItem('Pulse', AppColors.pink, AppColors.cyan, Icons.graphic_eq_rounded),
    _GridItem('Dusk', AppColors.violetGlow, AppColors.cyan, Icons.wb_twilight_rounded),
    _GridItem('Echo', AppColors.violetLight, AppColors.pink, Icons.surround_sound_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Explore', style: TextStyle(color: AppColors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 20),
                // search bar
                Focus(
                  onFocusChange: (v) => setState(() => _focused = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _focused ? AppColors.violetLight.withOpacity(0.7) : AppColors.grey.withOpacity(0.4),
                        width: _focused ? 1.5 : 0.5,
                      ),
                      boxShadow: _focused
                          ? [BoxShadow(color: AppColors.violet.withOpacity(0.25), blurRadius: 20)]
                          : [],
                    ),
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: AppColors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Search creators, tags, moods…',
                        hintStyle: TextStyle(color: AppColors.greyLight, fontSize: 15),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.greyLight),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // trending
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trending', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _trending.map((t) => _TrendingTag(t)).toList(),
                ),
              ],
            ),
          ),
        ),

        // discover grid
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
            child: const Text('Discover', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _DiscoverCard(item: _grid[i]),
              childCount: _grid.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _GridItem {
  final String label;
  final Color c1, c2;
  final IconData icon;
  const _GridItem(this.label, this.c1, this.c2, this.icon);
}

class _DiscoverCard extends StatelessWidget {
  final _GridItem item;
  const _DiscoverCard({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [item.c1.withOpacity(0.75), item.c2.withOpacity(0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
        boxShadow: [BoxShadow(color: item.c1.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, top: -10,
            child: Icon(item.icon, color: Colors.white.withOpacity(0.08), size: 90),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: Colors.white, size: 26),
                const Spacer(),
                Text(item.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${(math.Random().nextInt(900) + 100)} works',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingTag extends StatelessWidget {
  final String label;
  const _TrendingTag(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.violetGlow.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.violet.withOpacity(0.35), width: 0.8),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.violetLight, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// SCREEN 4 — PROFILE
// ═══════════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final _stats = [
    ('214', 'Works'),
    ('12.4k', 'Followers'),
    ('381', 'Following'),
  ];

  static final _works = [
    _WorkItem('Ether I', AppColors.violetGlow, AppColors.pink),
    _WorkItem('Ether II', AppColors.cyan, AppColors.violetLight),
    _WorkItem('Cascade', AppColors.pink, AppColors.violetGlow),
    _WorkItem('Still', AppColors.violetLight, AppColors.cyan),
    _WorkItem('Noir', const Color(0xFF1A1A2E), AppColors.violet),
    _WorkItem('Prism', AppColors.pinkLight, AppColors.violetGlow),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── header ──
        SliverToBoxAdapter(
          child: Stack(
            children: [
              // banner
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.violetGlow, AppColors.pink, AppColors.violetLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const _NoiseOverlay(),
              ),
              // blur overlay at bottom
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.background],
                    ),
                  ),
                ),
              ),
              // top bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 24, right: 24,
                child: Row(
                  children: [
                    const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
              // avatar
              Positioned(
                bottom: 0, left: 24,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.violetLight, AppColors.pinkLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppColors.background, width: 3),
                    boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(0.5), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
                ),
              ),
            ],
          ),
        ),

        // ── name & bio ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jordan Voss', style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        SizedBox(height: 2),
                        Text('@jordanvoss', style: TextStyle(color: AppColors.greyLight, fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    _GradientButton(label: 'Edit Profile', onTap: () {}, compact: true),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Visual storyteller. Seeking beauty in the unseen.\nDigital / Photography / Soundscapes.',
                  style: TextStyle(color: AppColors.whiteD, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 20),
                // stats
                Row(
                  children: _stats
                      .map((s) => Expanded(
                            child: Column(
                              children: [
                                Text(s.$1, style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(s.$2, style: const TextStyle(color: AppColors.greyLight, fontSize: 12, letterSpacing: 0.5)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                const Text('Works', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              ],
            ),
          ),
        ),

        // ── works grid ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _WorkTile(item: _works[i]),
              childCount: _works.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkItem {
  final String title;
  final Color c1, c2;
  const _WorkItem(this.title, this.c1, this.c2);
}

class _WorkTile extends StatelessWidget {
  final _WorkItem item;
  const _WorkTile({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [item.c1.withOpacity(0.8), item.c2.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(item.title,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;
  const _GradientButton({required this.label, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 9)
            : const EdgeInsets.symmetric(horizontal: 0, vertical: 18),
        width: compact ? null : double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.violetGlow, AppColors.violetLight, AppColors.pink],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withOpacity(0.5),
              blurRadius: 20, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13 : 17,
              fontWeight: FontWeight.w700,
              letterSpacing: compact ? 0.2 : 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 24 : 6,
      height: 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: active
            ? const LinearGradient(colors: [AppColors.violetLight, AppColors.pink])
            : null,
        color: active ? null : AppColors.grey,
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _NoiseOverlay extends StatelessWidget {
  const _NoiseOverlay();
  @override
  Widget build(BuildContext context) {
    // Subtle noise via custom painter
    return Positioned.fill(
      child: CustomPaint(painter: _NoisePainter()),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..strokeWidth = 1;
    for (int i = 0; i < 600; i++) {
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.025);
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}
