import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:seeking/main.dart';
import 'package:seeking/db_helper.dart';
import 'dart:async';

// ─── Audio Handler ────────────────────────────────────────────────────────────

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _playlist;
  bool shuffle = false;
  bool repeat = false;

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.positionStream.listen((p) =>
        playbackState.add(playbackState.value.copyWith(updatePosition: p)));
    _player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        if (repeat) { await _player.seek(Duration.zero); await _player.play(); }
        else await stop();
      }
    });
    _player.currentIndexStream.listen((index) {
      if (index != null && _playlist != null && index < _playlist!.length) {
        final q = queue.value;
        if (index < q.length) mediaItem.add(q[index]);
      }
    });
    _setupAudioSession();
  }

  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  Future<void> setPlaylist(List<MediaItem> items, {int initialIndex = 0}) async {
    if (items.isEmpty) return;
    _playlist = ConcatenatingAudioSource(
      children: items.map((i) => AudioSource.file(i.id)).toList(),
    );
    await _player.setAudioSource(_playlist!, initialIndex: initialIndex, preload: false);
    queue.add(items);
    mediaItem.add(items[initialIndex]);
    await _player.play();
  }

  Future<void> playFile(MediaItem item, List<MediaItem> allItems) async {
    final index = allItems.indexWhere((i) => i.id == item.id);
    await setPlaylist(allItems, initialIndex: index < 0 ? 0 : index);
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    await _player.setShuffleModeEnabled(shuffle);
  }

  Future<void> toggleRepeat() async {
    repeat = !repeat;
    await _player.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
  }

  @override Future<void> play() => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> stop() async { await _player.stop(); await super.stop(); }
  @override Future<void> skipToNext() async { if (_player.hasNext) await _player.seekToNext(); }
  @override Future<void> skipToPrevious() async { if (_player.hasPrevious) await _player.seekToPrevious(); }
  @override Future<void> onTaskRemoved() async { await _player.dispose(); await super.onTaskRemoved(); }
}

// ─── Music Screen ─────────────────────────────────────────────────────────────

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  int _selectedTab = 0; // 0 = Library, 1 = Playlists
  List<SavedSong> _songs = [];
  List<Playlist> _playlists = [];
  bool _loadingSongs = true;
  bool _loadingPlaylists = true;
  bool _picking = false;
  String _search = '';
  Timer? _sleepTimer;
  int? _sleepMinutesLeft;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _loadPlaylists();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _loadingSongs = true);
    final songs = await DBHelper.getSongs();
    setState(() { _songs = songs; _loadingSongs = false; });
  }

  Future<void> _loadPlaylists() async {
    setState(() => _loadingPlaylists = true);
    final pls = await DBHelper.getPlaylists();
    setState(() { _playlists = pls; _loadingPlaylists = false; });
  }

  List<SavedSong> get _filtered => _search.isEmpty
      ? _songs
      : _songs.where((s) =>
          s.name.toLowerCase().contains(_search.toLowerCase())).toList();

  List<MediaItem> _toMediaItems(List<SavedSong> songs) => songs
      .map((s) => MediaItem(
            id: s.path,
            title: s.name,
            artist: s.isVideo ? 'Video' : 'Audio',
          ))
      .toList();

  Future<void> _pickFiles() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
      );
      if (result != null) {
        for (final f in result.files) {
          if (f.path == null) continue;
          if (await DBHelper.songExists(f.path!)) continue;
          final ext = f.name.split('.').last.toLowerCase();
          final isVideo = ['mp4', 'mkv', 'mov', 'avi', 'webm', '3gp'].contains(ext);
          await DBHelper.insertSong(SavedSong(
            id: '${DateTime.now().millisecondsSinceEpoch}_${f.name}',
            path: f.path!,
            name: f.name,
            isVideo: isVideo,
            addedAt: DateTime.now(),
          ));
        }
        await _loadSongs();
      }
    } finally {
      setState(() => _picking = false);
    }
  }

  Future<void> _deleteSong(SavedSong song) async {
    for (final pl in _playlists) {
      if (pl.songPaths.contains(song.path)) {
        pl.songPaths.remove(song.path);
        await DBHelper.updatePlaylist(pl);
      }
    }
    await DBHelper.deleteSong(song.id);
    _loadSongs();
    _loadPlaylists();
  }

  void _showAddToPlaylist(SavedSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add to Playlist',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.hint, fontSize: 12)),
              const Divider(height: 24),
              if (_playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No playlists yet. Create one in the Playlists tab.',
                      style: TextStyle(color: C.hint)),
                )
              else
                ..._playlists.map((pl) {
                  final alreadyIn = pl.songPaths.contains(song.path);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.queue_music, color: C.accentLight),
                    title: Text(pl.name),
                    subtitle: Text('${pl.songPaths.length} tracks',
                        style: const TextStyle(fontSize: 11, color: C.hint)),
                    trailing: alreadyIn
                        ? const Icon(Icons.check_circle, color: C.accentLight)
                        : const Icon(Icons.add_circle_outline, color: C.hint),
                    onTap: alreadyIn ? null : () async {
                      pl.songPaths.add(song.path);
                      await DBHelper.updatePlaylist(pl);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Added to ${pl.name}'),
                        backgroundColor: C.accent,
                        behavior: SnackBarBehavior.floating,
                      ));
                      _loadPlaylists();
                    },
                  );
                }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimer() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: const Row(children: [
          Icon(Icons.bedtime, color: C.accentLight),
          SizedBox(width: 8),
          Text('Sleep Timer'),
        ]),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ...[5, 10, 15, 30, 45, 60].map((m) => ActionChip(
              label: Text('$m min'),
              backgroundColor: C.surface,
              onPressed: () {
                Navigator.pop(context);
                _sleepTimer?.cancel();
                setState(() => _sleepMinutesLeft = m);
                _sleepTimer = Timer.periodic(const Duration(minutes: 1), (t) {
                  setState(() => _sleepMinutesLeft = (_sleepMinutesLeft ?? 1) - 1);
                  if (_sleepMinutesLeft! <= 0) {
                    t.cancel();
                    audioHandler.stop();
                    setState(() => _sleepMinutesLeft = null);
                  }
                });
              },
            )),
            ActionChip(
              label: const Text('Cancel Timer'),
              backgroundColor: Colors.red.withOpacity(0.2),
              onPressed: () {
                Navigator.pop(context);
                _sleepTimer?.cancel();
                setState(() => _sleepMinutesLeft = null);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: Colors.red,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Music'),
        actions: [
          if (_sleepMinutesLeft != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text('$_sleepMinutesLeft min',
                    style: const TextStyle(fontSize: 11)),
                avatar: const Icon(Icons.bedtime, size: 14),
                backgroundColor: C.accent.withOpacity(0.2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.bedtime_outlined),
            onPressed: _showSleepTimer,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── SegmentedButton tab switcher ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.library_music_outlined),
                  label: Text('Library'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.queue_music_outlined),
                  label: Text('Playlists'),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (s) => setState(() => _selectedTab = s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return C.accent;
                  return C.card;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return C.hint;
                }),
                iconColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return C.hint;
                }),
                side: WidgetStateProperty.all(BorderSide.none),
              ),
            ),
          ),

          // ── Tab content via IndexedStack ──
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildLibrary(),
                _buildPlaylists(),
              ],
            ),
          ),

          const _NowPlayingCard(),
        ],
      ),
    );
  }

  // ── Library ──────────────────────────────────────────────────────────────────

  Widget _buildLibrary() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search library...',
                    prefixIcon: const Icon(Icons.search, color: C.hint),
                    filled: true,
                    fillColor: C.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _picking ? null : _pickFiles,
                icon: Icon(_picking ? Icons.hourglass_empty : Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        if (_songs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${_filtered.length} track${_filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: C.hint, fontSize: 12)),
                const Spacer(),
                if (_filtered.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => audioHandler.setPlaylist(_toMediaItems(_filtered)),
                    icon: const Icon(Icons.shuffle, size: 16, color: C.accentLight),
                    label: const Text('Shuffle All',
                        style: TextStyle(fontSize: 12, color: C.accentLight)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loadingSongs
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.library_music_outlined,
                              size: 64, color: C.hint),
                          const SizedBox(height: 12),
                          Text(
                            _search.isNotEmpty
                                ? 'No results for "$_search"'
                                : 'Library is empty',
                            style: const TextStyle(color: C.hint),
                          ),
                          if (_search.isEmpty)
                            const Text('Tap Add to import audio or video',
                                style: TextStyle(color: C.hint, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final song = _filtered[i];
                        return StreamBuilder<MediaItem?>(
                          stream: audioHandler.mediaItem,
                          builder: (_, snap) {
                            final playing = snap.data?.id == song.path;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: playing
                                    ? C.accent.withOpacity(0.15)
                                    : C.card,
                                borderRadius: BorderRadius.circular(12),
                                border: playing
                                    ? Border.all(color: C.accent.withOpacity(0.4))
                                    : null,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: playing ? C.accent : C.surface,
                                  child: Icon(
                                    playing
                                        ? Icons.graphic_eq
                                        : song.isVideo
                                            ? Icons.videocam_outlined
                                            : Icons.music_note,
                                    color: playing ? Colors.white : C.accentLight,
                                    size: 20,
                                  ),
                                ),
                                title: Text(song.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: playing
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: playing ? C.accentLight : C.textPrimary,
                                      fontSize: 14,
                                    )),
                                subtitle: Text(
                                    song.isVideo ? 'Video' : 'Audio',
                                    style: const TextStyle(
                                        color: C.hint, fontSize: 11)),
                                onTap: () => audioHandler.playFile(
                                  MediaItem(id: song.path, title: song.name),
                                  _toMediaItems(_songs),
                                ),
                                trailing: PopupMenuButton<String>(
                                  color: C.card,
                                  icon: const Icon(Icons.more_vert,
                                      color: C.hint, size: 20),
                                  onSelected: (v) {
                                    if (v == 'playlist') _showAddToPlaylist(song);
                                    if (v == 'delete') _deleteSong(song);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'playlist',
                                      child: Row(children: [
                                        Icon(Icons.playlist_add,
                                            size: 18, color: C.accentLight),
                                        SizedBox(width: 8),
                                        Text('Add to Playlist'),
                                      ]),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete_outline,
                                            size: 18, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Remove',
                                            style: TextStyle(
                                                color: Colors.redAccent)),
                                      ]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Playlists ─────────────────────────────────────────────────────────────────

  Widget _buildPlaylists() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                  '${_playlists.length} playlist${_playlists.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: C.hint, fontSize: 12)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _createPlaylist(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingPlaylists
              ? const Center(child: CircularProgressIndicator())
              : _playlists.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_outlined,
                              size: 64, color: C.hint),
                          SizedBox(height: 12),
                          Text('No playlists yet',
                              style: TextStyle(color: C.hint)),
                          SizedBox(height: 4),
                          Text('Tap New to create one',
                              style: TextStyle(color: C.hint, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      itemCount: _playlists.length,
                      itemBuilder: (_, i) {
                        final pl = _playlists[i];
                        final plSongs = _songs
                            .where((s) => pl.songPaths.contains(s.path))
                            .toList();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: C.card,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: C.accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.queue_music,
                                  color: C.accentLight),
                            ),
                            title: Text(pl.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: C.textPrimary)),
                            subtitle: Text(
                                '${plSongs.length} track${plSongs.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: C.hint, fontSize: 12)),
                            onTap: plSongs.isEmpty
                                ? null
                                : () => audioHandler
                                    .setPlaylist(_toMediaItems(plSongs)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (plSongs.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.play_circle_outline,
                                        color: C.accentLight),
                                    onPressed: () => audioHandler
                                        .setPlaylist(_toMediaItems(plSongs)),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: C.hint, size: 20),
                                  onPressed: () =>
                                      _deletePlaylist(context, pl),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _createPlaylist(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await DBHelper.insertPlaylist(Playlist(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: ctrl.text.trim(),
                songPaths: [],
                createdAt: DateTime.now(),
              ));
              Navigator.pop(context);
              _loadPlaylists();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _deletePlaylist(BuildContext context, Playlist pl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Delete Playlist?'),
        content: Text('"${pl.name}" will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DBHelper.deletePlaylist(pl.id);
              _loadPlaylists();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Now Playing Card ─────────────────────────────────────────────────────────

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard();

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (_, mediaSnap) {
        final item = mediaSnap.data;
        if (item == null) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (_, stateSnap) {
            final playing = stateSnap.data?.playing ?? false;
            final position = stateSnap.data?.updatePosition ?? Duration.zero;
            final duration = item.duration ?? Duration.zero;
            final maxMs = duration.inMilliseconds.toDouble();

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: C.accent.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: C.hint,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: C.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            const Icon(Icons.music_note, color: C.accentLight),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: C.textPrimary)),
                            Text(item.artist ?? '',
                                style: const TextStyle(
                                    fontSize: 12, color: C.hint)),
                          ],
                        ),
                      ),
                      StatefulBuilder(
                        builder: (_, ss) => Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.shuffle,
                                  size: 20,
                                  color: audioHandler.shuffle
                                      ? C.accentLight
                                      : C.hint),
                              onPressed: () async {
                                await audioHandler.toggleShuffle();
                                ss(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.repeat,
                                  size: 20,
                                  color: audioHandler.repeat
                                      ? C.accentLight
                                      : C.hint),
                              onPressed: () async {
                                await audioHandler.toggleRepeat();
                                ss(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: maxMs > 0
                          ? position.inMilliseconds
                              .toDouble()
                              .clamp(0.0, maxMs)
                          : 0.0,
                      min: 0,
                      max: maxMs > 0 ? maxMs : 1,
                      onChanged: maxMs > 0
                          ? (v) => audioHandler
                              .seek(Duration(milliseconds: v.toInt()))
                          : null,
                      activeColor: C.accentLight,
                      inactiveColor: C.hint.withOpacity(0.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(position),
                            style:
                                const TextStyle(fontSize: 11, color: C.hint)),
                        Text(_fmt(duration),
                            style:
                                const TextStyle(fontSize: 11, color: C.hint)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, size: 32),
                          onPressed: audioHandler.skipToPrevious),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: C.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: C.accent.withOpacity(0.4),
                                blurRadius: 12)
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 32,
                              color: Colors.white),
                          onPressed: () =>
                              playing ? audioHandler.pause() : audioHandler.play(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 32),
                          onPressed: audioHandler.skipToNext),
                      IconButton(
                          icon: const Icon(Icons.stop_rounded),
                          onPressed: audioHandler.stop),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
