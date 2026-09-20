import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
// Conditional import: web implementation on web, desktop implementation on native
import 'video_player_stub.dart'
    if (dart.library.html) 'video_player_web.dart'
    if (dart.library.js_interop) 'video_player_web.dart'
    if (dart.library.io) 'video_player_desktop.dart';

class EmbeddedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String coverImageUrl;
  final double height;
  final bool autoPlayOnInit;

  const EmbeddedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.coverImageUrl,
    this.height = 240,
    this.autoPlayOnInit = false,
  });

  @override
  State<EmbeddedVideoPlayer> createState() => _EmbeddedVideoPlayerState();
}

class _EmbeddedVideoPlayerState extends State<EmbeddedVideoPlayer> {
  bool _isPlaying = false;
  late String _viewType;
  late String _embedUrl;
  String _platformName = 'فيديو المعاينة';
  IconData _platformIcon = Icons.play_circle_fill_rounded;
  Color _platformColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.autoPlayOnInit;
    _setupEmbedUrl();
  }

  @override
  void didUpdateWidget(covariant EmbeddedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _setupEmbedUrl();
    }
  }

  void _setupEmbedUrl() {
    final url = widget.videoUrl.trim();
    final ytId = _extractYouTubeId(url);
    final vimeoId = _extractVimeoId(url);
    final isFb = _isFacebookUrl(url);

    if (ytId != null) {
      _embedUrl = 'https://www.youtube-nocookie.com/embed/$ytId?autoplay=1';



      if (url.contains('/shorts/')) {
        _platformName = 'YouTube Shorts 🔴';
      } else {
        _platformName = 'YouTube 🔴';
      }
      _platformIcon = Icons.play_arrow_rounded;
      _platformColor = const Color(0xFFFF0000);
    } else if (vimeoId != null) {
      _embedUrl = 'https://player.vimeo.com/video/$vimeoId?autoplay=1';
      _platformName = 'Vimeo 🎬';
      _platformIcon = Icons.movie_rounded;
      _platformColor = const Color(0xFF1AB7EA);
    } else if (isFb) {
      _embedUrl =
          'https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(url)}&show_text=false&autoplay=true';
      _platformName = 'Facebook Reels 📱';
      _platformIcon = Icons.facebook_rounded;
      _platformColor = const Color(0xFF1877F2);
    } else {
      _embedUrl = url;
      _platformName = 'فيديو المعاينة 🎥';
      _platformIcon = Icons.video_library_rounded;
      _platformColor = AppColors.primary;
    }

    _viewType =
        'iframe-video-${url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      registerWebIframe(_viewType, _embedUrl);
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

  String? _extractVimeoId(String url) {
    final regExp = RegExp(
      r'vimeo\.com\/(?:channels\/(?:\w+\/)?|groups\/[^\/]*\/videos\/|album\/\d+\/video\/|video\/|)(\d+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  bool _isFacebookUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('facebook.com') || lower.contains('fb.watch');
  }

  void _launchExternal() async {
    final uri = Uri.parse(widget.videoUrl.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        final screenSize = MediaQuery.of(ctx).size;
        final dialogWidth = (screenSize.width * 0.88).clamp(340.0, 1100.0);
        final dialogHeight = screenSize.height * 0.78;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fullscreen Header
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _platformColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_platformIcon, color: _platformColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _platformName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'عرض مكبّر • جودة عالية',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded,
                            size: 18, color: AppColors.textSecondary),
                        tooltip: 'فتح في المتصفح',
                        onPressed: () { Navigator.of(ctx).pop(); _launchExternal(); },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.textSecondary),
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                // Fullscreen Video Area
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: SizedBox(
                    width: dialogWidth,
                    height: dialogHeight,
                    child: _buildPlayerWidget(isPlaying: true),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerWidget({required bool isPlaying}) {
    if (!isPlaying) return const SizedBox.shrink();
    if (kIsWeb) {
      return buildWebIframe(viewType: _viewType, embedUrl: _embedUrl);
    }
    return buildDesktopVideoPlayer(videoUrl: widget.videoUrl, embedUrl: _embedUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _platformColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_platformIcon, color: _platformColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _platformName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'جولة افتراضية مدمجة داخل السيستم',
                        style:
                            TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Expand / Fullscreen Button
                    Tooltip(
                      message: 'تكبير الفيديو',
                      child: InkWell(
                        onTap: () => _openFullscreen(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _platformColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _platformColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen_rounded,
                                  size: 18, color: _platformColor),
                              const SizedBox(width: 4),
                              Text(
                                'تكبير',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _platformColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded,
                          size: 18, color: AppColors.textSecondary),
                      tooltip: 'فتح الرابط في نافذة جديدة',
                      onPressed: _launchExternal,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Player Area
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: _isPlaying
                  ? _buildPlayerWidget(isPlaying: _isPlaying)


                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cover Image Background
                        Positioned.fill(
                          child: widget.coverImageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.coverImageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: const Color(0xFF0F172A)),
                                  errorWidget: (context, url, error) =>
                                      Container(color: const Color(0xFF0F172A)),
                                )
                              : Container(color: const Color(0xFF0F172A)),
                        ),
                        // Dark Overlay
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        // Play Button
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPlaying = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _platformColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          _platformColor.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 38,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'اضغط لمشاهدة المعاينة المباشرة ▶️',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
