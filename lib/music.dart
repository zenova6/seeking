import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:seeking/main.dart';
import 'package:seeking/db_helper.dart';
import 'package:seeking/library.dart';
import 'package:seeking/playlist.dart';
import 'package:audio_service/audio_service.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  List<SavedSong> _songs = [];
  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _requestPermissions();
  }

  // Request permissions on app start (Android 13+ specific)
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Try to get SDK version (if device_info_plus not available, request all)
      // Request all possible media permissions – Android will ignore irrelevant ones
      await [
        Permission.storage,
        Permission.audio,
        Permission.photos,
        Permission.videos,
        Permission.manageExternalStorage,
      ].request();
    } else {
      await Permission.storage.request();
    }
  }

  // Simplified permission check before picking files
  Future<bool> _hasMediaPermission() async {
    if (Platform.isAndroid) {
      // On Android 13+, check modern permissions
      final audioGranted = await Permission.audio.isGranted;
      final photosGranted = await Permission.photos.isGranted;
      final videosGranted = await Permission.videos.isGranted;
      // On older Android, check storage
      final storageGranted = await Permission.storage.isGranted;
      return audioGranted || photosGranted || videosGranted || storageGranted;
    }
    return await Permission.storage.isGranted;
  }

  Future<void> _ensurePermission() async {
    if (await _hasMediaPermission()) return;

    // Not granted, request again
    if (Platform.isAndroid) {
      await [
        Permission.audio,
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();
    } else {
      await Permission.storage.request();
    }

    // If still not granted, show message
    if (!await _hasMediaPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required to import files')),
        );
      }
      throw Exception('Permission denied');
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final songs = await DBHelper.getSongs();
    final playlists = await DBHelper.getPlaylists();
    setState(() {
      _songs = songs;
      _playlists = playlists;
      _loading = false;
    });
  }

  Future<void> _addSong() async {
    try {
      await _ensurePermission();

      // Option 1: FileType.audio (no custom extensions)
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
      );

      if (result == null || result.files.isEmpty) return;

      int addedCount = 0;
      for (final file in result.files) {
        final path = file.path!;
        final name = file.name;
        final isVideo = name.toLowerCase().endsWith('.mp4') ||
            name.toLowerCase().endsWith('.mov') ||
            name.toLowerCase().endsWith('.avi');

        // Check if already exists
        if (await DBHelper.songExists(path)) continue;

        final song = SavedSong(
          id: const Uuid().v4(),
          path: path,
          name: name.split('.').first,
          isVideo: isVideo,
          addedAt: DateTime.now(),
        );
        await DBHelper.insertSong(song);
        addedCount++;
      }

      if (addedCount > 0) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added $addedCount file(s)')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new files added (already in library)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createPlaylist() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('New Playlist'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: C.textPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: const TextStyle(color: C.hint),
            filled: true,
            fillColor: C.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final newPlaylist = Playlist(
        id: const Uuid().v4(),
        name: result,
        songPaths: [],
        createdAt: DateTime.now(),
      );
      await DBHelper.insertPlaylist(newPlaylist);
      _loadData();
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Delete Playlist?'),
        content: Text('"${playlist.name}" will be deleted. Songs remain in library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.deletePlaylist(playlist.id);
      _loadData();
    }
  }

  Future<void> _addToPlaylist(SavedSong song, Playlist playlist) async {
    if (playlist.songPaths.contains(song.path)) return;
    playlist.songPaths.add(song.path);
    await DBHelper.updatePlaylist(playlist);
    _loadData();
  }

  Future<void> _deleteSong(SavedSong song) async {
    // Remove from all playlists
    for (final pl in _playlists) {
      if (pl.songPaths.contains(song.path)) {
        pl.songPaths.remove(song.path);
        await DBHelper.updatePlaylist(pl);
      }
    }
    await DBHelper.deleteSong(song.id);
    _loadData();
  }

  List<MediaItem> _toMediaItems(List<SavedSong> songs) {
    return songs.map((song) => MediaItem(
      id: song.path,
      title: song.name,
      extras: {'isVideo': song.isVideo},
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(
          title: const Text('Music Library'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.library_music), text: 'Library'),
              Tab(icon: Icon(Icons.queue_music), text: 'Playlists'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addSong,
              tooltip: 'Import audio/video',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            LibraryScreen(
              songs: _songs,
              loading: false,
              loadSongs: _loadData,
              playlists: _playlists,
              onAddToPlaylist: _addToPlaylist,
              onDeleteSong: _deleteSong,
              toMediaItems: _toMediaItems,
            ),
            PlaylistScreen(
              playlists: _playlists,
              loading: false,
              songs: _songs,
              onCreatePlaylist: _createPlaylist,
              onDeletePlaylist: _deletePlaylist,
              toMediaItems: _toMediaItems,
            ),
          ],
        ),
      ),
    );
  }
}