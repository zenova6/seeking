import 'package:flutter/material.dart';
import 'package:seeking/main.dart';
import 'package:seeking/db_helper.dart';

class LibraryScreen extends StatelessWidget {
  final List<SavedSong> songs;
  final bool loading;
  final Future<void> Function() loadSongs;
  final List<Playlist> playlists;
  final Future<void> Function(SavedSong song, Playlist playlist) onAddToPlaylist;
  final Future<void> Function(SavedSong song) onDeleteSong;
  final List<MediaItem> Function(List<SavedSong>) toMediaItems;

  const LibraryScreen({
    super.key,
    required this.songs,
    required this.loading,
    required this.loadSongs,
    required this.playlists,
    required this.onAddToPlaylist,
    required this.onDeleteSong,
    required this.toMediaItems,
  });

  @override
  Widget build(BuildContext context) {
    // Local search state
    return _LibraryBody(
      songs: songs,
      loading: loading,
      playlists: playlists,
      onAddToPlaylist: onAddToPlaylist,
      onDeleteSong: onDeleteSong,
      toMediaItems: toMediaItems,
    );
  }
}

// Separate StatefulWidget for search
class _LibraryBody extends StatefulWidget {
  final List<SavedSong> songs;
  final bool loading;
  final List<Playlist> playlists;
  final Future<void> Function(SavedSong song, Playlist playlist) onAddToPlaylist;
  final Future<void> Function(SavedSong song) onDeleteSong;
  final List<MediaItem> Function(List<SavedSong>) toMediaItems;

  const _LibraryBody({
    required this.songs,
    required this.loading,
    required this.playlists,
    required this.onAddToPlaylist,
    required this.onDeleteSong,
    required this.toMediaItems,
  });

  @override
  State<_LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<_LibraryBody> {
  String _search = '';

  List<SavedSong> get _filtered => _search.isEmpty
      ? widget.songs
      : widget.songs
          .where((s) =>
              s.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  void _showAddToPlaylist(SavedSong song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add to Playlist',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.hint, fontSize: 12)),
              const Divider(height: 24),
              if (widget.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No playlists yet. Create one in the Playlists tab.',
                    style: TextStyle(color: C.hint),
                  ),
                )
              else
                ...widget.playlists.map((pl) {
                  final alreadyIn = pl.songPaths.contains(song.path);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.queue_music,
                        color: C.accentLight),
                    title: Text(pl.name),
                    subtitle: Text('${pl.songPaths.length} tracks',
                        style: const TextStyle(
                            fontSize: 11, color: C.hint)),
                    trailing: alreadyIn
                        ? const Icon(Icons.check_circle,
                            color: C.accentLight)
                        : const Icon(Icons.add_circle_outline,
                            color: C.hint),
                    onTap: alreadyIn
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await widget.onAddToPlaylist(song, pl);
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} track${_filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: C.hint, fontSize: 12),
                  ),
                  const Spacer(),
                  if (_filtered.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => audioHandler.setPlaylist(
                          widget.toMediaItems(_filtered)),
                      icon: const Icon(Icons.shuffle,
                          size: 16, color: C.accentLight),
                      label: const Text('Shuffle All',
                          style: TextStyle(
                              fontSize: 12, color: C.accentLight)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                ],
              ),
            ),
          Expanded(
            child: widget.loading
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
                              const Text(
                                'Tap Add to import audio or video',
                                style: TextStyle(
                                    color: C.hint, fontSize: 12),
                              ),
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
                              final playing =
                                  snap.data?.id == song.path;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: playing
                                      ? C.accent.withOpacity(0.15)
                                      : C.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: playing
                                      ? Border.all(
                                          color:
                                              C.accent.withOpacity(0.4))
                                      : null,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        playing ? C.accent : C.surface,
                                    child: Icon(
                                      playing
                                          ? Icons.graphic_eq
                                          : song.isVideo
                                              ? Icons.videocam_outlined
                                              : Icons.music_note,
                                      color: playing
                                          ? Colors.white
                                          : C.accentLight,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    song.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: playing
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: playing
                                          ? C.accentLight
                                          : C.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                      song.isVideo ? 'Video' : 'Audio',
                                      style: const TextStyle(
                                          color: C.hint, fontSize: 11)),
                                  onTap: () => audioHandler.playFile(
                                    MediaItem(
                                        id: song.path, title: song.name),
                                    widget.toMediaItems(widget.songs),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    color: C.card,
                                    icon: const Icon(Icons.more_vert,
                                        color: C.hint, size: 20),
                                    onSelected: (v) {
                                      if (v == 'playlist')
                                        _showAddToPlaylist(song);
                                      if (v == 'delete')
                                        widget.onDeleteSong(song);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'playlist',
                                        child: Row(children: [
                                          Icon(Icons.playlist_add,
                                              size: 18,
                                              color: C.accentLight),
                                          SizedBox(width: 8),
                                          Text('Add to Playlist'),
                                        ]),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [
                                          Icon(Icons.delete_outline,
                                              size: 18,
                                              color: Colors.redAccent),
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
      ),
    );
  }
}