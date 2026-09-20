import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

Widget buildWebIframe({
  required String viewType,
  required String embedUrl,
}) {
  return HtmlElementView(viewType: viewType);
}

void registerWebIframe(String viewType, String embedUrl) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
        ..src = embedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
      return iframe;
    },
  );
}

Widget buildDesktopVideoPlayer({required String videoUrl, String? embedUrl}) {
  return const SizedBox.shrink();
}
