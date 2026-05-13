import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/folder.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/audio_handler.dart';

final musicServiceProvider = Provider((ref) => MusicService());

final audioHandlerProvider = Provider<OuroAudioHandler>((ref) {
  throw UnimplementedError(); // Initialized in main
});

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});

class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final List<Song> queue;

  PlayerState({this.currentSong, this.isPlaying = false, this.queue = const []});

  PlayerState copyWith({Song? currentSong, bool? isPlaying, List<Song>? queue}) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      queue: queue ?? this.queue,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref ref;

  PlayerNotifier(this.ref) : super(PlayerState());

  Future<void> playSong(Song song) async {
    final musicService = ref.read(musicServiceProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    final url = await musicService.getStreamUrl(song.youtubeId);
    if (url != null) {
      state = state.copyWith(currentSong: song, isPlaying: true);
      await audioHandler.playFromMediaId(song.id, {
        'url': url,
        'title': song.title,
        'artist': song.artist,
        'thumbnailUrl': song.thumbnailUrl,
      });
    }
  }

  Future<void> playFolderRecursive(Folder folder) async {
    final allSongs = folder.getAllSongsRecursively();
    if (allSongs.isNotEmpty) {
      allSongs.shuffle();
      state = state.copyWith(queue: allSongs);
      await playSong(allSongs.first);
    }
  }

  void togglePlay() {
    final audioHandler = ref.read(audioHandlerProvider);
    if (state.isPlaying) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
    state = state.copyWith(isPlaying: !state.isPlaying);
  }
}
