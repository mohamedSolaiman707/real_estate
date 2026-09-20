import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import '../constants/colors.dart';

Widget buildWebIframe({
  required String viewType,
  required String embedUrl,
}) {
  return const SizedBox.shrink();
}

void registerWebIframe(String viewType, String embedUrl) {
  // No-op on desktop
}

class LocalPlayerServer {
  static HttpServer? _server;
  static int? _port;

  static Future<int> ensureStarted() async {
    if (_server != null) return _port!;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _server!.listen((HttpRequest request) {
        final videoId = request.uri.queryParameters['v'] ?? '';
        final rawEmbed = request.uri.queryParameters['embed'] ?? '';

        String targetSrc = '';
        if (videoId.isNotEmpty) {
          targetSrc =
              'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&enablejsapi=0';
        } else if (rawEmbed.isNotEmpty) {
          targetSrc = Uri.decodeComponent(rawEmbed);
        }

        final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe 
    src="$targetSrc" 
    referrerpolicy="strict-origin-when-cross-origin"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
    allowfullscreen>
  </iframe>
</body>
</html>
''';

        request.response
          ..headers.contentType = ContentType.html
          ..headers.set('Access-Control-Allow-Origin', '*')
          ..headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
          ..write(html);
        request.response.close();
      });
      return _port!;
    } catch (e) {
      debugPrint('Error starting LocalPlayerServer: $e');
      rethrow;
    }
  }
}

Widget buildDesktopVideoPlayer({required String videoUrl, String? embedUrl}) {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return DesktopWebviewPlayer(videoUrl: videoUrl, embedUrl: embedUrl);
  }
  return Container(
    color: Colors.black,
    child: const Center(
      child: Text(
        'مشغل الديسكتاوب مدعوم على Windows فقط',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}

class DesktopWebviewPlayer extends StatefulWidget {
  final String videoUrl;
  final String? embedUrl;

  const DesktopWebviewPlayer({
    super.key,
    required this.videoUrl,
    this.embedUrl,
  });

  @override
  State<DesktopWebviewPlayer> createState() => _DesktopWebviewPlayerState();
}

class _DesktopWebviewPlayerState extends State<DesktopWebviewPlayer> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  @override
  void didUpdateWidget(covariant DesktopWebviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.videoUrl != widget.videoUrl ||
            oldWidget.embedUrl != widget.embedUrl) &&
        _isInitialized) {
      _loadTargetUrl();
    }
  }

  String? _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'^.*(?:youtu.be\/|v\/|e\/|u\/\w\/|embed\/|shorts\/|watch\?v=|&v=)([^#&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      if (id != null && id.length == 11) return id;
    }
    return null;
  }

  Future<void> _loadTargetUrl() async {
    final port = await LocalPlayerServer.ensureStarted();
    final ytId = _extractYouTubeId(widget.videoUrl);

    String localUrl;
    if (ytId != null) {
      localUrl = 'http://127.0.0.1:$port/?v=$ytId';
    } else {
      final targetEmbed = widget.embedUrl ?? widget.videoUrl;
      localUrl =
          'http://127.0.0.1:$port/?embed=${Uri.encodeComponent(targetEmbed)}';
    }

    await _controller.loadUrl(localUrl);
  }

  Future<void> _initWebview() async {
    try {
      await _controller.initialize();
      await _loadTargetUrl();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تهيئة مشغل الفيديو: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 36),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isInitialized = false;
                  });
                  _initWebview();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'جاري تحميل المعاينة المباشرة...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Webview(_controller);
  }
}
