import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

// ─── ENTRY POINT ─────────────────────────────────────────────────
late AudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await Hive.initFlutter();
  Hive.registerAdapter(IdeaAdapter());
  await Hive.openBox<Idea>('ideas');
  _audioHandler = await AudioService.init(
    builder: () => SeekingAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.seeking.audio',
      androidNotificationChannelName: 'Seeking Music',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const SeekingApp());
}

// ─── COLORS ──────────────────────────────────────────────────────
class C {
  static const bg       = Color(0xFF080810);
  static const surface  = Color(0xFF0F0F1A);
  static const card     = Color(0xFF13131F);
  static const violet   = Color(0xFF7B5EA7);
  static const vLight   = Color(0xFF9D7DD1);
  static const vGlow    = Color(0xFF6B3FA0);
  static const pink     = Color(0xFFD05FA2);
  static const pinkL    = Color(0xFFE87FBF);
  static const cyan     = Color(0xFF3ECFCF);
  static const white    = Color(0xFFF0EEF8);
  static const whiteD   = Color(0xFFB8B4CC);
  static const grey     = Color(0xFF3A384A);
  static const greyL    = Color(0xFF5A5870);
}

// ─── HIVE MODEL ──────────────────────────────────────────────────
@HiveType(typeId: 0)
class Idea extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String title;
  @HiveField(2) late String description;
  @HiveField(3) late String category;
  @HiveField(4) late List<String> tags;
  @HiveField(5) late int mood; // 1-5
  @HiveField(6) late bool pinned;
  @HiveField(7) late DateTime createdAt;
}

class IdeaAdapter extends TypeAdapter<Idea> {
  @override final int typeId = 0;
  @override
  Idea read(BinaryReader r) {
    return Idea()
      ..id          = r.readString()
      ..title       = r.readString()
      ..description = r.readString()
      ..category    = r.readString()
      ..tags        = List<String>.from(r.readList())
      ..mood        = r.readInt()
      ..pinned      = r.readBool()
      ..createdAt   = DateTime.fromMillisecondsSinceEpoch(r.readInt());
  }
  @override
  void write(BinaryWriter w, Idea obj) {
    w.writeString(obj.id);
    w.writeString(obj.title);
    w.writeString(obj.description);
    w.writeString(obj.category);
    w.writeList(obj.tags);
    w.writeInt(obj.mood);
    w.writeBool(obj.pinned);
    w.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

// ─── AUDIO HANDLER ───────────────────────────────────────────────
class SeekingAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  SeekingAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        stop();
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle:      AudioProcessingState.idle,
        ProcessingState.loading:   AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready:     AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  Future<void> playUri(String uri, String title, {bool isLocal = false}) async {
    mediaItem.add(MediaItem(id: uri, title: title, album: 'Seeking'));
    if (isLocal) {
      await _player.setFilePath(uri);
    } else {
      await _player.setUrl(uri);
    }
    play();
  }

  @override Future<void> play()  => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> stop()  async { await _player.stop(); await super.stop(); }
  @override Future<void> seek(Duration pos) => _player.seek(pos);

  bool get isPlaying => _player.playing;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration? get duration => _player.duration;
}

SeekingAudioHandler get audio => _audioHandler as SeekingAudioHandler;

// ─── APP ROOT ────────────────────────────────────────────────────
class SeekingApp extends StatelessWidget {
  const SeekingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seeking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(
          primary: C.violet,
          secondary: C.pink,
          surface: C.surface,
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ─── MAIN SHELL ──────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(
        children: [
          IndexedStack(
            index: _idx,
            children: const [
              IdeasScreen(),
              BrowserScreen(),
              MusicScreen(),
            ],
          ),
          // mini player — always visible except on music screen
          if (_idx != 2)
            Positioned(
              bottom: 72,
              left: 16, right: 16,
              child: const MiniPlayer(),
            ),
        ],
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
        color: C.card,
        border: Border(top: BorderSide(color: C.grey.withOpacity(0.4), width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NI(icon: Icons.lightbulb_rounded,  label: 'Ideas',   active: current == 0, onTap: () => onTap(0)),
              _NI(icon: Icons.public_rounded,      label: 'Browser', active: current == 1, onTap: () => onTap(1)),
              _NI(icon: Icons.music_note_rounded,  label: 'Music',   active: current == 2, onTap: () => onTap(2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NI extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _NI({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? C.violet.withOpacity(0.15) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? C.vLight : C.greyL, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: active ? C.vLight : C.greyL,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SCREEN 1 — IDEAS VAULT
// ═══════════════════════════════════════════════════════════════════
class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});
  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  final _box = Hive.box<Idea>('ideas');
  String _search = '';
  String _filter = 'All';
  static const _cats = ['All', 'Business', 'Creative', 'Tech', 'Personal', 'Random'];

  List<Idea> get _filtered {
    var list = _box.values.toList();
    if (_filter != 'All') list = list.where((i) => i.category == _filter).toList();
    if (_search.isNotEmpty) {
      list = list.where((i) =>
        i.title.toLowerCase().contains(_search.toLowerCase()) ||
        i.description.toLowerCase().contains(_search.toLowerCase()) ||
        i.tags.any((t) => t.toLowerCase().contains(_search.toLowerCase()))
      ).toList();
    }
    list.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  void _deleteIdea(Idea idea) {
    idea.delete();
    setState(() {});
  }

  void _togglePin(Idea idea) {
    idea.pinned = !idea.pinned;
    idea.save();
    setState(() {});
  }

  void _inspireMe() {
    final list = _box.values.toList();
    if (list.isEmpty) return;
    final random = list[math.Random().nextInt(list.length)];
    showDialog(
      context: context,
      builder: (_) => _IdeaDialog(idea: random, readOnly: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ideas = _filtered;
    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Ideas Vault', style: TextStyle(color: C.white, fontSize: 28,
                    fontWeight: FontWeight.w800, letterSpacing: -1)),
                  const Spacer(),
                  _IconBtn(icon: Icons.auto_awesome_rounded, onTap: _inspireMe, tooltip: 'Inspire me'),
                ]),
                const SizedBox(height: 16),
                // search
                Container(
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.grey.withOpacity(0.4), width: 0.5),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: C.white),
                    decoration: const InputDecoration(
                      hintText: 'Search ideas…',
                      hintStyle: TextStyle(color: C.greyL),
                      prefixIcon: Icon(Icons.search_rounded, color: C.greyL, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // category filter
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _cats.map((c) => _FilterChip(
                      label: c,
                      active: _filter == c,
                      onTap: () => setState(() => _filter = c),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          if (ideas.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lightbulb_outline_rounded, color: C.greyL, size: 52),
                  const SizedBox(height: 12),
                  const Text('No ideas yet', style: TextStyle(color: C.greyL, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Tap + to capture your first idea', style: TextStyle(color: C.grey, fontSize: 13)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _IdeaCard(
                    idea: ideas[i],
                    onDelete: () => _deleteIdea(ideas[i]),
                    onPin: () => _togglePin(ideas[i]),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _IdeaDialog(idea: ideas[i]),
                    ).then((_) => setState(() {})),
                  ),
                  childCount: ideas.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _IdeaDialog(),
        ).then((_) => setState(() {})),
        backgroundColor: C.vGlow,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final Idea idea;
  final VoidCallback onDelete, onPin, onTap;
  const _IdeaCard({required this.idea, required this.onDelete, required this.onPin, required this.onTap});

  static const _moodEmoji = ['', '😴', '🤔', '💡', '🔥', '🚀'];
  static const _catColors = {
    'Business':  C.cyan,
    'Creative':  C.pink,
    'Tech':      C.vLight,
    'Personal':  C.pinkL,
    'Random':    C.greyL,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: idea.pinned ? C.violet.withOpacity(0.5) : C.grey.withOpacity(0.3),
            width: idea.pinned ? 1 : 0.5,
          ),
          boxShadow: idea.pinned
              ? [BoxShadow(color: C.violet.withOpacity(0.2), blurRadius: 12)]
              : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (idea.pinned) ...[
              const Icon(Icons.push_pin_rounded, color: C.vLight, size: 14),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(idea.title, style: const TextStyle(color: C.white,
                fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(_moodEmoji[idea.mood.clamp(1, 5)], style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            GestureDetector(onTap: onPin,
              child: Icon(idea.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: C.greyL, size: 18)),
            const SizedBox(width: 8),
            GestureDetector(onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded, color: C.greyL, size: 18)),
          ]),
          if (idea.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(idea.description, style: const TextStyle(color: C.whiteD, fontSize: 13, height: 1.5),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_catColors[idea.category] ?? C.greyL).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(idea.category, style: TextStyle(
                color: _catColors[idea.category] ?? C.greyL, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            ...idea.tags.take(2).map((t) => Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: C.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('#$t', style: const TextStyle(color: C.greyL, fontSize: 11)),
            )),
            const Spacer(),
            Text(_timeAgo(idea.createdAt), style: const TextStyle(color: C.grey, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── ADD/EDIT IDEA DIALOG ─────────────────────────────────────────
class _IdeaDialog extends StatefulWidget {
  final Idea? idea;
  final bool readOnly;
  const _IdeaDialog({this.idea, this.readOnly = false});
  @override
  State<_IdeaDialog> createState() => _IdeaDialogState();
}

class _IdeaDialogState extends State<_IdeaDialog> {
  late TextEditingController _title, _desc, _tags;
  late String _category;
  late int _mood;
  static const _cats = ['Business', 'Creative', 'Tech', 'Personal', 'Random'];

  @override
  void initState() {
    super.initState();
    _title    = TextEditingController(text: widget.idea?.title ?? '');
    _desc     = TextEditingController(text: widget.idea?.description ?? '');
    _tags     = TextEditingController(text: widget.idea?.tags.join(', ') ?? '');
    _category = widget.idea?.category ?? 'Creative';
    _mood     = widget.idea?.mood ?? 3;
  }

  @override
  void dispose() {
    _title.dispose(); _desc.dispose(); _tags.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final box  = Hive.box<Idea>('ideas');
    final tags = _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (widget.idea != null) {
      widget.idea!
        ..title       = _title.text.trim()
        ..description = _desc.text.trim()
        ..category    = _category
        ..tags        = tags
        ..mood        = _mood;
      widget.idea!.save();
    } else {
      final idea = Idea()
        ..id          = const Uuid().v4()
        ..title       = _title.text.trim()
        ..description = _desc.text.trim()
        ..category    = _category
        ..tags        = tags
        ..mood        = _mood
        ..pinned      = false
        ..createdAt   = DateTime.now();
      box.add(idea);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.readOnly ? 'Idea' : (widget.idea != null ? 'Edit Idea' : 'New Idea'),
            style: const TextStyle(color: C.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _Field(controller: _title, hint: 'Title', readOnly: widget.readOnly),
          const SizedBox(height: 12),
          _Field(controller: _desc, hint: 'Describe your idea…', maxLines: 4, readOnly: widget.readOnly),
          const SizedBox(height: 16),
          if (!widget.readOnly) ...[
            const Text('Category', style: TextStyle(color: C.whiteD, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _cats.map((c) => GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: _category == c
                        ? const LinearGradient(colors: [C.vGlow, C.vLight])
                        : null,
                    color: _category == c ? null : C.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _category == c ? Colors.transparent : C.grey.withOpacity(0.4)),
                  ),
                  child: Text(c, style: TextStyle(
                    color: _category == c ? Colors.white : C.whiteD, fontSize: 13,
                    fontWeight: _category == c ? FontWeight.w600 : FontWeight.w400)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Mood / Energy', style: TextStyle(color: C.whiteD, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final emojis = ['😴', '🤔', '💡', '🔥', '🚀'];
                final active = _mood == i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _mood = i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active ? C.violet.withOpacity(0.3) : C.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? C.vLight : C.grey.withOpacity(0.3)),
                    ),
                    child: Text(emojis[i], style: TextStyle(fontSize: active ? 22 : 18)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            _Field(controller: _tags, hint: 'Tags (comma separated)', readOnly: false),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: C.greyL)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GradBtn(label: widget.idea != null ? 'Update' : 'Save', onTap: _save),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: C.violet.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_category, style: const TextStyle(color: C.vLight, fontSize: 13)),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: C.vLight))),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SCREEN 2 — SECRET BROWSER
// ═══════════════════════════════════════════════════════════════════
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _wvc;
  final _urlCtrl = TextEditingController();
  String _currentUrl = '';
  bool _loading = false;
  double _progress = 0;

  void _navigate(String input) {
    String url = input.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url = 'https://search.brave.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    _wvc?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        // url bar
        Container(
          color: C.card,
          padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 10),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.grey.withOpacity(0.4), width: 0.5),
                ),
                child: Row(children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.lock_rounded, color: C.greyL, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(color: C.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search or enter URL',
                        hintStyle: TextStyle(color: C.greyL, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: _navigate,
                      textInputAction: TextInputAction.go,
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: C.vLight)),
                    )
                  else
                    GestureDetector(
                      onTap: () => _navigate(_urlCtrl.text),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.arrow_forward_rounded, color: C.vLight, size: 18),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.refresh_rounded, onTap: () => _wvc?.reload()),
          ]),
        ),
        // progress bar
        if (_loading)
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: C.surface,
            valueColor: const AlwaysStoppedAnimation(C.vLight),
            minHeight: 2,
          ),
        // webview
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('https://search.brave.com')),
            initialSettings: InAppWebViewSettings(
              incognito: true,
              clearCache: true,
              clearSessionCache: true,
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useHybridComposition: true,
            ),
            onWebViewCreated: (c) => _wvc = c,
            onLoadStart: (c, url) {
              setState(() {
                _loading = true;
                _urlCtrl.text = url?.toString() ?? '';
                _currentUrl = url?.toString() ?? '';
              });
            },
            onLoadStop: (c, url) {
              setState(() {
                _loading = false;
                _urlCtrl.text = url?.toString() ?? '';
                _currentUrl = url?.toString() ?? '';
              });
            },
            onProgressChanged: (c, p) => setState(() => _progress = p / 100),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SCREEN 3 — MUSIC PLAYER
// ═══════════════════════════════════════════════════════════════════
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final _urlCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _trackTitle;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'aac', 'wav', 'ogg', 'm4a'],
    );
    if (result == null || result.files.single.path == null) return;
    final path  = result.files.single.path!;
    final title = result.files.single.name;
    setState(() { _trackTitle = title; _error = null; });
    await audio.playUri(path, title, isLocal: true);
  }

  Future<void> _playUrl() async {
    final input = _urlCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      // YouTube / Piped detection
      if (input.contains('youtube.com') || input.contains('youtu.be') ||
          input.contains('piped.') || input.contains('invidious.')) {
        final yt  = YoutubeExplode();
        final vid = await yt.videos.get(input);
        final manifest = await yt.videos.streamsClient.getManifest(vid.id);
        final stream = manifest.audioOnly.withHighestBitrate();
        final url = stream.url.toString();
        yt.close();
        setState(() { _trackTitle = vid.title; });
        await audio.playUri(url, vid.title);
      } else {
        // Direct URL (any audio stream)
        final title = input.split('/').last.split('?').first;
        setState(() { _trackTitle = title; });
        await audio.playUri(input, title);
      }
    } catch (e) {
      setState(() { _error = 'Could not load: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<PlayerState>(
        stream: audio.playerStateStream,
        builder: (context, snap) {
          final playing = snap.data?.playing ?? false;
          final proc    = snap.data?.processingState ?? ProcessingState.idle;
          final idle    = proc == ProcessingState.idle || proc == ProcessingState.completed;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Music', style: TextStyle(color: C.white, fontSize: 28,
                      fontWeight: FontWeight.w800, letterSpacing: -1)),
                    const SizedBox(height: 6),
                    const Text('Plays in background across all screens',
                      style: TextStyle(color: C.greyL, fontSize: 13)),
                    const SizedBox(height: 32),

                    // ── now playing card ──
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [C.vGlow, C.violet, Color(0xFF1A0A2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: C.violet.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
                      ),
                      child: Column(children: [
                        // album art placeholder
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: idle
                              ? const Icon(Icons.music_note_rounded, color: Colors.white30, size: 64)
                              : _PulsingIcon(playing: playing),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _trackTitle ?? (idle ? 'Nothing playing' : 'Loading…'),
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        // seek bar
                        StreamBuilder<Duration>(
                          stream: audio.positionStream,
                          builder: (_, posSnap) {
                            final pos = posSnap.data ?? Duration.zero;
                            final dur = audio.duration ?? Duration.zero;
                            final frac = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                            return Column(children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white24,
                                ),
                                child: Slider(
                                  value: frac.clamp(0.0, 1.0),
                                  onChanged: dur.inMilliseconds > 0
                                      ? (v) => audio.seek(Duration(milliseconds: (v * dur.inMilliseconds).toInt()))
                                      : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(children: [
                                  Text(_fmt(pos), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                  const Spacer(),
                                  Text(_fmt(dur), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                ]),
                              ),
                            ]);
                          },
                        ),
                        const SizedBox(height: 8),
                        // controls
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          IconButton(
                            icon: const Icon(Icons.stop_rounded, color: Colors.white70),
                            onPressed: audio.stop,
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => playing ? audio.pause() : audio.play(),
                            child: Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 20)],
                              ),
                              child: Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: C.vGlow, size: 32,
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    ),

                    const SizedBox(height: 28),

                    // ── local file ──
                    _SectionLabel('From Device'),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: C.grey.withOpacity(0.4), width: 0.5),
                        ),
                        child: const Row(children: [
                          Icon(Icons.folder_open_rounded, color: C.vLight, size: 22),
                          SizedBox(width: 12),
                          Text('Pick mp3 / mp4 / audio file', style: TextStyle(color: C.white, fontSize: 15)),
                          Spacer(),
                          Icon(Icons.chevron_right_rounded, color: C.greyL),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── url / youtube ──
                    _SectionLabel('YouTube / Piped / Direct URL'),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: C.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.grey.withOpacity(0.4), width: 0.5),
                      ),
                      child: TextField(
                        controller: _urlCtrl,
                        style: const TextStyle(color: C.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Paste YouTube, Piped or audio URL…',
                          hintStyle: TextStyle(color: C.greyL, fontSize: 14),
                          prefixIcon: Icon(Icons.link_rounded, color: C.greyL, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onSubmitted: (_) => _playUrl(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GradBtn(
                      label: _loading ? 'Loading…' : 'Play',
                      onTap: _loading ? null : _playUrl,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── MINI PLAYER ─────────────────────────────────────────────────
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: _audioHandler.mediaItem,
      builder: (_, snap) {
        final item = snap.data;
        if (item == null) return const SizedBox.shrink();
        return StreamBuilder<PlayerState>(
          stream: (audio).playerStateStream,
          builder: (_, pSnap) {
            final playing = pSnap.data?.playing ?? false;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.violet.withOpacity(0.4), width: 0.8),
                boxShadow: [BoxShadow(color: C.vGlow.withOpacity(0.3), blurRadius: 20)],
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: C.vGlow.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: C.vLight, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.title, style: const TextStyle(color: C.white, fontSize: 13,
                    fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: C.vLight, size: 26),
                  onPressed: () => playing ? audio.pause() : audio.play(),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close_rounded, color: C.greyL, size: 18),
                  onPressed: audio.stop,
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ─── PULSING ICON ────────────────────────────────────────────────
class _PulsingIcon extends StatefulWidget {
  final bool playing;
  const _PulsingIcon({required this.playing});
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}
class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override
  void didUpdateWidget(_PulsingIcon old) {
    super.didUpdateWidget(old);
    widget.playing ? _c.repeat(reverse: true) : _c.stop();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.violet.withOpacity(0.3),
            boxShadow: [BoxShadow(color: C.violet.withOpacity(0.5), blurRadius: 30)],
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────
class _GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _GradBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [C.vGlow, C.vLight, C.pink]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: C.violet.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool readOnly;
  const _Field({required this.controller, required this.hint, this.maxLines = 1, required this.readOnly});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.grey.withOpacity(0.4), width: 0.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(color: C.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: C.greyL),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [C.vGlow, C.vLight]) : null,
          color: active ? null : C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.transparent : C.grey.withOpacity(0.4), width: 0.5),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : C.whiteD, fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final String? tooltip;
  const _IconBtn({required this.icon, required this.onTap, this.tooltip});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.grey.withOpacity(0.4), width: 0.5),
          ),
          child: Icon(icon, color: C.vLight, size: 20),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: C.whiteD, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3));
  }
}
