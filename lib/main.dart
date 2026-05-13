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
import 'ui/player/now_playing_expanded.dart';
import 'models/folder.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:app_links/app_links.dart';
import 'services/wormhole_service.dart';

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
  final PanelController _panelController = PanelController();
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) async {
      print('OURO: Incoming Deep Link: $uri');
      final folder = WormholeService.parseLink(uri.toString());
      if (folder != null) {
        await StorageService.importFolder(folder, 'root');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported Orbit: ${folder.name}')),
          );
          setState(() {}); // Refresh view
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    
    return Scaffold(
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: playerState.currentSong != null ? 70 : 0,
        maxHeight: MediaQuery.of(context).size.height,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.black,
        boxShadow: const [], // OLED Black doesn't need shadows
        onPanelOpened: () => ref.read(playerProvider.notifier).setPanelOpen(true),
        onPanelClosed: () => ref.read(playerProvider.notifier).setPanelOpen(false),
        panel: const NowPlayingExpanded(),
        collapsed: playerState.currentSong != null 
            ? _buildMiniPlayer(playerState) 
            : const SizedBox.shrink(),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const Center(child: Text('Home Feed (Explore)')),
            const SearchScreen(),
            _buildLibraryView(),
          ],
        ),
      ),
      bottomNavigationBar: playerState.isPanelOpen ? null : BottomNavigationBar(
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

  Widget _buildMiniPlayer(PlayerState state) {
    return GestureDetector(
      onTap: () => _panelController.open(),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                state.currentSong!.thumbnailUrl,
                width: 44,
                height: 44,
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
                    state.currentSong!.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    state.currentSong!.artist,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => ref.read(playerProvider.notifier).togglePlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryView() {
    final rootFolder = StorageService.foldersBox.get('root');
    if (rootFolder == null) return const Center(child: Text('Loading Library...'));
    
    return FolderView(folder: rootFolder, path: [rootFolder]);
  }
}
