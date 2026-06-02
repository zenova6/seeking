import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  List<MediaItem> _queue = [];
  int _currentIndex = -1;

  MyAudioHandler() {
    _setupPlayer();
    _listenToPositionChanges();
  }

  Future<void> _setupPlayer() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });
  }

  void _listenToPositionChanges() {
    _player.positionStream.listen((position) {
      if (_currentIndex >= 0 && _queue.isNotEmpty) {
        playbackState.add(playbackState.value.copyWith(
          position: position,
          updatePosition: position,
        ));
      }
    });
    _player.playerStateStream.listen((state) {
      _broadcastState();
    });
  }

  void _broadcastState() {
    final playing = _player.playing;
    final processingState = _player.processingState;
    final position = _player.position;
    final duration = _queue.isNotEmpty && _currentIndex >= 0
        ? _queue[_currentIndex].duration ?? Duration.zero
        : Duration.zero;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seekTo,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState == ProcessingState.ready
          ? AudioProcessingState.ready
          : processingState == ProcessingState.loading
              ? AudioProcessingState.loading
              : AudioProcessingState.idle,
      playing: playing,
      updatePosition: position,
      position: position,
      bufferedPosition: Duration.zero,
      speed: _player.speed,
      queueIndex: _currentIndex,
      repeatMode: AudioServiceRepeatMode.none,
      shuffleMode: AudioServiceShuffleMode.none,
    ));
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _currentIndex = -1;
    mediaItem.add(null);
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex + 1 < _queue.length) {
      await _playAtIndex(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex - 1 >= 0) {
      await _playAtIndex(_currentIndex - 1);
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    final item = _queue[index];
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.uri(Uri.file(item.id)));
    await _player.play();
    _broadcastState();
  }

  // Custom method to play a single file
  Future<void> playFile(MediaItem item, List<MediaItem> queue) async {
    _queue = List.from(queue);
    final index = _queue.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      await _playAtIndex(index);
    } else {
      // If item not in queue, add it and play
      _queue.add(item);
      await _playAtIndex(_queue.length - 1);
    }
  }

  // Custom method to set entire playlist
  Future<void> setPlaylist(List<MediaItem> newQueue) async {
    if (newQueue.isEmpty) return;
    _queue = List.from(newQueue);
    await _playAtIndex(0);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queue.add(mediaItem);
    if (_queue.length == 1) await _playAtIndex(0);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    _queue.removeWhere((item) => item.id == mediaItem.id);
    if (_queue.isEmpty) {
      await stop();
    } else if (_currentIndex >= _queue.length) {
      await _playAtIndex(_queue.length - 1);
    } else {
      _broadcastState();
    }
  }

  @override
  Future<void> onDestroy() async {
    await _player.dispose();
    super.onDestroy();
  }
}