import 'package:flutter/material.dart';
import 'package:seeking/main.dart';
import 'package:seeking/db_helper.dart';
import 'library.dart';
import 'playlist.dart';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

// ─────────────────── Audio Handler ───────────────────
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
        if (repeat) {
          await _player.seek(Duration.zero);
          await _player.play();
        } else {
          await stop();
        }
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
    await _player.setAudioSource(_playlist!,
        initialIndex: initialIndex, preload: false);
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
    await _player.setLoopMode(repeat ? LoopMode.all : LoopMode.off);
  }

  @override Future<void> play() => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
  @override Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }
  @override Future<void> skipToPrevious() async {
    if (_player.hasPrevious) await _player.seekToPrevious();
  }
  @override Future<void> onTaskRemoved() async {
    await _player.dispose();
    await super.onTaskRemoved();
  }
}

// ─────────────────── Now Playing Card ───────────────────
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({super.key});

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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: C.accent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: C.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.music_note, color: C.accentLight),
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
                              icon: Icon(Icons.shuffle, size: 20,
                                  color: audioHandler.shuffle
                                      ? C.accentLight
                                      : C.hint),
                              onPressed: () async {
                                await audioHandler.toggleShuffle();
                                ss(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.repeat, size: 20,
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
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
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
                            style: const TextStyle(
                                fontSize: 11, color: C.hint)),
                        Text(_fmt(duration),
                            style: const TextStyle(
                                fontSize: 11, color: C.hint)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded,
                            size: 32),
                        onPressed: audioHandler.skipToPrevious,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: C.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: C.accent.withOpacity(0.4),
                              blurRadius: 12,
                            )
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                          onPressed: () => playing
                              ? audioHandler.pause()
                              : audioHandler.play(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 32),
                        onPressed: audioHandler.skipToNext,
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_rounded),
                        onPressed: audioHandler.stop,
                      ),
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

// ─────────────────── Main Music Screen ───────────────────
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  int _selectedTab = 0;
  List<SavedSong> _songs = [];
  List<Playlist> _playlists = [];
  bool _loadingSongs = true;
  bool _loadingPlaylists = true;
  bool _picking = false;
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
    setState(() {
      _songs = songs;
      _loadingSongs = false;
    });
  }

  Future<void> _loadPlaylists() async {
    setState(() => _loadingPlaylists = true);
    final pls = await DBHelper.getPlaylists();
    setState(() {
      _playlists = pls;
      _loadingPlaylists = false;
    });
  }

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
          final isVideo = [
            'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp'
          ].contains(ext);
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

  Future<void> _addSongToPlaylist(SavedSong song, Playlist pl) async {
    pl.songPaths.add(song.path);
    await DBHelper.updatePlaylist(pl);
    // ui will reload via callbacks
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
          spacing: 8,
          runSpacing: 8,
          children: [
            ...[5, 10, 15, 30, 45, 60].map((m) => ActionChip(
                  label: Text('$m min'),
                  backgroundColor: C.surface,
                  onPressed: () {
                    Navigator.pop(context);
                    _sleepTimer?.cancel();
                    setState(() => _sleepMinutesLeft = m);
                    _sleepTimer =
                        Timer.periodic(const Duration(minutes: 1), (t) {
                      setState(() =>
                          _sleepMinutesLeft = (_sleepMinutesLeft ?? 1) - 1);
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

  void _createPlaylist() {
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

  void _deletePlaylist(Playlist pl) {
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
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.bg,
      child: Column(
        children: [
          // Top header
          Container(
            color: C.bg,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                const Text(
                  'Music',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: C.textPrimary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _picking ? null : _pickFiles,
                  icon:
                      Icon(_picking ? Icons.hourglass_empty : Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
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
                  icon: const Icon(Icons.bedtime_outlined,
                      color: C.textPrimary),
                  onPressed: _showSleepTimer,
                ),
              ],
            ),
          ),
          // Segment control
          Container(
            color: C.bg,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.library_music_outlined),
                    label: Text('Library')),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.queue_music_outlined),
                    label: Text('Playlists')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (s) =>
                  setState(() => _selectedTab = s.first),
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return C.accent;
                  return C.card;
                }),
                foregroundColor:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return Colors.white;
                  return C.hint;
                }),
                iconColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return Colors.white;
                  return C.hint;
                }),
                side: WidgetStateProperty.all(BorderSide.none),
              ),
            ),
          ),
          // Tab content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                LibraryScreen(
                  songs: _songs,
                  loading: _loadingSongs,
                  loadSongs: _loadSongs,
                  playlists: _playlists,
                  onAddToPlaylist: (song, playlist) async {
                    await _addSongToPlaylist(song, playlist);
                    _loadPlaylists();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Added to ${playlist.name}'),
                        backgroundColor: C.accent,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                  onDeleteSong: _deleteSong,
                  toMediaItems: _toMediaItems,
                ),
                PlaylistScreen(
                  playlists: _playlists,
                  loading: _loadingPlaylists,
                  songs: _songs,
                  onCreatePlaylist: _createPlaylist,
                  onDeletePlaylist: _deletePlaylist,
                  toMediaItems: _toMediaItems,
                ),
              ],
            ),
          ),
          const NowPlayingCard(),
        ],
      ),
    );
  }
}