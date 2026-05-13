import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'youtube_audio_source.dart';
import 'audio_cache_service.dart';

class OuroAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  ConcatenatingAudioSource? _currentPlaylist;

  OuroAudioHandler() {
    _player.processingStateStream.listen((state) {
      print('OURO [Player]: Processing State: $state');
    });

    _player.playbackEventStream.map(_transformEvent).listen((state) {
      playbackState.add(state);
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  bool get isPlaying => _player.playing;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  Future<void> setQueue(List<MediaItem> items, {int initialIndex = 0}) async {
    print('OURO [Handler]: Setting queue with ${items.length} items');
    queue.add(items);
    
    final List<AudioSource> sources = [];
    for (var item in items) {
      final youtubeId = item.extras?['youtubeId'] as String?;
      if (youtubeId != null) {
        final cachedPath = await AudioCacheService.getCachedFile(youtubeId);
        if (cachedPath != null) {
          sources.add(AudioSource.file(cachedPath, tag: item));
        } else {
          sources.add(YoutubeAudioSource(youtubeId, tag: item));
        }
      } else {
        final url = item.extras?['url'] as String?;
        sources.add(AudioSource.uri(Uri.parse(url ?? ''), tag: item));
      }
    }

    try {
      if (sources.length == 1) {
        print('OURO [Handler]: Single song mode.');
        _currentPlaylist = null; // Clean up old playlist reference
        await _player.setAudioSource(sources.first);
      } else {
        print('OURO [Handler]: Playlist mode.');
        _currentPlaylist = ConcatenatingAudioSource(children: sources);
        await _player.setAudioSource(_currentPlaylist!, initialIndex: initialIndex);
      }
      print('OURO [Handler]: Source set successfully.');
    } catch (e) {
      print('OURO [Handler]: Error setting audio source: $e');
    }
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final mediaItem = MediaItem(
      id: mediaId,
      album: extras?['artist'] ?? 'Unknown',
      title: extras?['title'] ?? 'Unknown',
      artUri: Uri.parse(extras?['thumbnailUrl'] ?? ''),
      duration: extras?['duration'] != null ? Duration(seconds: extras!['duration']) : null,
      extras: extras,
    );
    
    await setQueue([mediaItem]);
    play();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
