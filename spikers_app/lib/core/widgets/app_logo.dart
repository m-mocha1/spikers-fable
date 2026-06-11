import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

class AppLogo extends StatelessWidget {
  final double width;
  const AppLogo({super.key, this.width = 160});

  @override
  Widget build(BuildContext context) {
    return Image.asset(AppAssets.logo, width: width);
  }
}
