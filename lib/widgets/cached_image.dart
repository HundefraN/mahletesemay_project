import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mahlete_semay_project/widgets/shimmer_loading.dart';

class CachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? height;
  final double? width;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultErrorWidget();
    }

    // Determine target memory cache dimensions to prevent huge memory spikes
    int? targetMemWidth = memCacheWidth;
    int? targetMemHeight = memCacheHeight;
    if (targetMemWidth == null && targetMemHeight == null) {
      if (width != null && width! > 0 && width!.isFinite) {
        targetMemWidth = (width! * 2.0).toInt().clamp(100, 1080);
      } else {
        targetMemWidth = 500;
      }
      if (height != null && height! > 0 && height!.isFinite) {
        targetMemHeight = (height! * 2.0).toInt().clamp(100, 1080);
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: width,
      fit: fit,
      memCacheWidth: targetMemWidth,
      memCacheHeight: targetMemHeight,
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) =>
          placeholder ??
          ShimmerLoading(
            child: Container(
              height: height,
              width: width,
              color: Colors.white,
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey.shade900.withOpacity(0.4),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white38,
          size: 32,
        ),
      ),
    );
  }
}