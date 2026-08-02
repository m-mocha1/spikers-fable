import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

/// The club crest. Constrain it on one axis only — pass [height] where the
/// space is a fixed band (an app bar), [width] where it is a fixed column — so
/// the mark always keeps its aspect ratio.
class AppLogo extends StatelessWidget {
  final double width;

  /// When given, drives the size instead of [width].
  final double? height;

  const AppLogo({super.key, this.width = 160, this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      width: height == null ? width : null,
      height: height,
    );
  }
}
