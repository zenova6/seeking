import 'package:flutter/material.dart';
import 'package:seeking/main.dart';
import 'package:seeking/db_helper.dart';
import 'package:audio_service/audio_service.dart';   // ✅ ADD THIS LINE

class PlaylistScreen extends StatelessWidget {
  final List<Playlist> playlists;
  final bool loading;
  final List<SavedSong> songs;
  final void Function() onCreatePlaylist;
  final void Function(Playlist) onDeletePlaylist;
  final List<MediaItem> Function(List<SavedSong>) toMediaItems;

  const PlaylistScreen({
    super.key,
    required this.playlists,
    required this.loading,
    required this.songs,
    required this.onCreatePlaylist,
    required this.onDeletePlaylist,
    required this.toMediaItems,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '${playlists.length} playlist${playlists.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: C.hint, fontSize: 12),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onCreatePlaylist,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : playlists.isEmpty
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
                                style: TextStyle(
                                    color: C.hint, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        itemCount: playlists.length,
                        itemBuilder: (_, i) {
                          final pl = playlists[i];
                          final plSongs = songs
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
                                width: 48,
                                height: 48,
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
                                    color: C.hint, fontSize: 12),
                              ),
                              onTap: plSongs.isEmpty
                                  ? null
                                  : () => audioHandler.setPlaylist(
                                      toMediaItems(plSongs)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (plSongs.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.play_circle_outline,
                                          color: C.accentLight),
                                      onPressed: () => audioHandler
                                          .setPlaylist(
                                              toMediaItems(plSongs)),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: C.hint, size: 20),
                                    onPressed: () =>
                                        onDeletePlaylist(pl),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}