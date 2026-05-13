import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'services/storage_service.dart';
import 'services/audio_handler.dart';
import 'providers/player_provider.dart';
import 'ui/theme.dart';
import 'ui/screens/search_screen.dart';
import 'ui/widgets/folder_view.dart';
import 'ui/player/now_playing.dart';
import 'models/folder.dart';

AudioHandler? _audioHandler;

// Top-level builder for AudioService
AudioHandler _buildAudioHandler() => OuroAudioHandler();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('OURO: Initializing Audio Service...');
  _audioHandler = await AudioService.init(
    builder: _buildAudioHandler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ouro.music.playback',
      androidNotificationChannelName: 'Ouro Music Playback',
      androidNotificationOngoing: true,
    ),
  );
  print('OURO: Audio Service initialized.');

  runApp(
    ProviderScope(
      overrides: [
        if (_audioHandler != null)
          audioHandlerProvider.overrideWithValue(_audioHandler! as OuroAudioHandler),
      ],
      child: const OuroApp(),
    ),
  );
}

class OuroApp extends StatelessWidget {
  const OuroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OURO',
      theme: OuroTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: StorageService.init(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const MainScreen();
          }
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'OURO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              const Center(child: Text('Home Feed (Explore)')),
              const SearchScreen(),
              _buildLibraryView(),
            ],
          ),
          
          // Floating Player Bar
          if (playerState.currentSong != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const FractionallySizedBox(
                      heightFactor: 0.95,
                      child: NowPlayingSheet(),
                    ),
                  );
                },
                child: Hero(
                  tag: 'player',
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF212121),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            playerState.currentSong!.thumbnailUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playerState.currentSong!.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                playerState.currentSong!.artist,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () => ref.read(playerProvider.notifier).togglePlay(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music_outlined), label: 'Library'),
        ],
      ),
    );
  }

  Widget _buildLibraryView() {
    final rootFolder = StorageService.foldersBox.get('root');
    if (rootFolder == null) return const Center(child: Text('Loading Library...'));
    
    return FolderView(folder: rootFolder, path: [rootFolder]);
  }
}
