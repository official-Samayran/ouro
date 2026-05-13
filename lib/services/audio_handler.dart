import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class OuroAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  OuroAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).listen((state) {
      playbackState.add(state);
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final url = extras?['url'] as String?;
    if (url != null) {
      final mediaItem = MediaItem(
        id: mediaId,
        album: extras?['artist'] ?? 'Unknown',
        title: extras?['title'] ?? 'Unknown',
        artUri: Uri.parse(extras?['thumbnailUrl'] ?? ''),
      );
      this.mediaItem.add(mediaItem);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      play();
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
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
