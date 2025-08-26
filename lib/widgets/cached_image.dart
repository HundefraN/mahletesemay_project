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

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultErrorWidget();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: width,
      fit: fit,
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
      color: Colors.grey.shade300,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
        size: 40,
      ),
    );
  }
}