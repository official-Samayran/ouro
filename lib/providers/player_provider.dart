import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/folder.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/audio_handler.dart';

import 'package:rxdart/rxdart.dart';

final musicServiceProvider = Provider((ref) => MusicService());

final audioHandlerProvider = Provider<OuroAudioHandler>((ref) {
  throw UnimplementedError(); // Initialized in main
});

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

final positionDataProvider = StreamProvider<PositionData>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
    handler.positionStream,
    handler.bufferedPositionStream,
    handler.durationStream,
    (position, bufferedPosition, duration) =>
        PositionData(position, bufferedPosition, duration ?? Duration.zero),
  );
});

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});

enum LoopMode { none, one, all }

class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final List<Song> queue;
  final bool isShuffle;
  final LoopMode loopMode;
  final bool isPanelOpen;

  PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.queue = const [],
    this.isShuffle = false,
    this.loopMode = LoopMode.none,
    this.isPanelOpen = false,
  });

  PlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    List<Song>? queue,
    bool? isShuffle,
    LoopMode? loopMode,
    bool? isPanelOpen,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      queue: queue ?? this.queue,
      isShuffle: isShuffle ?? this.isShuffle,
      loopMode: loopMode ?? this.loopMode,
      isPanelOpen: isPanelOpen ?? this.isPanelOpen,
    );
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref ref;

  PlayerNotifier(this.ref) : super(PlayerState());

  Future<void> playSong(Song song) async {
    final musicService = ref.read(musicServiceProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    try {
      print('OURO: Starting playback for ${song.title}...');
      final url = await musicService.getStreamUrl(song.youtubeId);
      if (url != null) {
        state = state.copyWith(currentSong: song, isPlaying: true);
        print('OURO: Setting queue for ${song.title}...');
        await audioHandler.playFromMediaId(song.id, {
          'title': song.title,
          'artist': song.artist,
          'thumbnailUrl': song.thumbnailUrl,
          'duration': song.durationSeconds,
          'youtubeId': song.youtubeId,
        });
        print('OURO: Playback command sent successfully.');
      } else {
        print('OURO: Failed to get stream URL for ${song.title}');
      }
    } catch (e, stack) {
      print('OURO: Critical Error playing song ${song.title}: $e');
      print(stack);
    }
  }

  Future<void> playFolderRecursive(Folder folder, {Song? initialSong}) async {
    print('OURO: Preparing recursive playback for folder: ${folder.name}');
    final allSongs = folder.getAllSongsRecursively();
    if (allSongs.isEmpty) return;

    if (state.isShuffle) {
      allSongs.shuffle();
      if (initialSong != null) {
        allSongs.remove(initialSong);
        allSongs.insert(0, initialSong);
      }
    } else if (initialSong != null) {
      final index = allSongs.indexOf(initialSong);
      if (index != -1) {
        // Reorder to start from initialSong
        final start = allSongs.sublist(index);
        final end = allSongs.sublist(0, index);
        allSongs.clear();
        allSongs.addAll(start);
        allSongs.addAll(end);
      }
    }

    state = state.copyWith(queue: allSongs);
    
    final musicService = ref.read(musicServiceProvider);
    final audioHandler = ref.read(audioHandlerProvider);

    List<MediaItem> mediaItems = [];
    for (var song in allSongs) {
      mediaItems.add(MediaItem(
        id: song.id,
        album: song.artist,
        title: song.title,
        artUri: Uri.parse(song.thumbnailUrl),
        duration: Duration(seconds: song.durationSeconds),
        extras: {
          'youtubeId': song.youtubeId,
          'artist': song.artist,
          'title': song.title,
          'thumbnailUrl': song.thumbnailUrl,
        },
      ));
    }
    
    state = state.copyWith(currentSong: allSongs.first, isPlaying: true);
    await audioHandler.setQueue(mediaItems);
    audioHandler.play();
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
    if (state.isShuffle && state.queue.isNotEmpty) {
      final shuffledQueue = List<Song>.from(state.queue)..shuffle();
      // Keep current song at front if it's playing
      if (state.currentSong != null) {
        shuffledQueue.remove(state.currentSong);
        shuffledQueue.insert(0, state.currentSong!);
      }
      state = state.copyWith(queue: shuffledQueue);
    }
  }

  void toggleLoop() {
    final nextMode = LoopMode.values[(state.loopMode.index + 1) % LoopMode.values.length];
    state = state.copyWith(loopMode: nextMode);
  }

  void setPanelOpen(bool isOpen) {
    state = state.copyWith(isPanelOpen: isOpen);
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

  Future<void> next() async {
    if (state.queue.isEmpty || state.currentSong == null) return;
    final currentIndex = state.queue.indexOf(state.currentSong!);
    if (currentIndex < state.queue.length - 1) {
      await playSong(state.queue[currentIndex + 1]);
    } else if (state.loopMode == LoopMode.all) {
      await playSong(state.queue.first);
    }
  }

  Future<void> previous() async {
    if (state.queue.isEmpty || state.currentSong == null) return;
    final currentIndex = state.queue.indexOf(state.currentSong!);
    if (currentIndex > 0) {
      await playSong(state.queue[currentIndex - 1]);
    }
  }
}
