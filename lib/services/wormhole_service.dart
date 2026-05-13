import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/folder.dart';

class WormholeService {
  static const String _scheme = 'ouro';
  static const String _host = 'wormhole';

  static String generateLink(Folder folder) {
    final jsonStr = jsonEncode(folder.toJson());
    final bytes = utf8.encode(jsonStr);
    final compressed = gzip.encode(bytes);
    final base64 = base64UrlEncode(compressed);
    
    return '$_scheme://$_host?data=$base64';
  }

  static Future<void> shareFolder(Folder folder) async {
    final link = generateLink(folder);
    await Share.share(
      'Open this Wormhole to import the orbit "${folder.name}" into OURO:\n\n$link',
      subject: 'OURO Wormhole: ${folder.name}',
    );
  }

  static Folder? parseLink(String link) {
    try {
      final uri = Uri.parse(link);
      if (uri.scheme != _scheme || uri.host != _host) return null;
      
      final data = uri.queryParameters['data'];
      if (data == null) return null;
      
      final compressed = base64Url.decode(data);
      final bytes = gzip.decode(compressed);
      final jsonStr = utf8.decode(bytes);
      final jsonMap = jsonDecode(jsonStr);
      
      return Folder.fromJson(jsonMap);
    } catch (e) {
      print('Error parsing wormhole: $e');
      return null;
    }
  }
}
