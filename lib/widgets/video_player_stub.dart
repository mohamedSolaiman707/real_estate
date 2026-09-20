import 'package:flutter/material.dart';

Widget buildWebIframe({
  required String viewType,
  required String embedUrl,
}) {
  return Container(
    color: Colors.black,
    child: const Center(
      child: Text(
        'مشغل ويب فقط',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}

void registerWebIframe(String viewType, String embedUrl) {
  // No-op for non-web platforms
}

Widget buildDesktopVideoPlayer({required String videoUrl, String? embedUrl}) {
  return Container(
    color: Colors.black,
    child: const Center(
      child: Text(
        'مشغل غير مدعوم على هذه المنصة',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}
