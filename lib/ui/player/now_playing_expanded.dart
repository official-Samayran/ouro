import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/player_provider.dart';
import '../theme.dart';

class NowPlayingExpanded extends ConsumerWidget {
  const NowPlayingExpanded({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Glassmorphic background reflecting album art
          Positioned.fill(
            child: Image.network(
              song.thumbnailUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                color: Colors.black.withOpacity(0.8),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                        onPressed: () => ref.read(playerProvider.notifier).setPanelOpen(false),
                      ),
                      const Text(
                        'SINGULARITY',
                        style: TextStyle(
                          letterSpacing: 4,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Pulsing Ouro Ring & Art
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Ring
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.2, 1.2),
                            duration: 2.seconds,
                            curve: Curves.easeInOut,
                          )
                          .fadeOut(duration: 2.seconds),
                      
                      // Static Ring
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                      ),

                      // Album Art
                      ClipRRect(
                        borderRadius: BorderRadius.circular(130),
                        child: Image.network(
                          song.thumbnailUrl,
                          width: 240,
                          height: 240,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Song Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Custom Thin Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: 0.3, // Mock value
                      onChanged: (v) {},
                    ),
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: playerState.isShuffle ? Colors.white : Colors.white24,
                        ),
                        onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
                      ).animate(target: playerState.isShuffle ? 1 : 0).shimmer(),
                      
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 36),
                        onPressed: () => ref.read(playerProvider.notifier).previous(),
                      ),
                      
                      // Play/Pause with Circle
                      GestureDetector(
                        onTap: () => ref.read(playerProvider.notifier).togglePlay(),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.black,
                            size: 40,
                          ),
                        ),
                      ).animate(target: playerState.isPlaying ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                      
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 36),
                        onPressed: () => ref.read(playerProvider.notifier).next(),
                      ),
                      
                      IconButton(
                        icon: Icon(
                          playerState.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                          color: playerState.loopMode != LoopMode.none ? Colors.white : Colors.white24,
                        ),
                        onPressed: () => ref.read(playerProvider.notifier).toggleLoop(),
                      ),
                    ],
                  ),
                ),

                // Bottom Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.share_outlined, color: Colors.white70),
                      IconButton(
                        icon: const Icon(Icons.queue_music, color: Colors.white70),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
