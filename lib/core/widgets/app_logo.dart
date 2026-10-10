import 'package:app/core/config/app_identity.dart';
import 'package:app/core/config/brand_assets.dart';
import 'package:flutter/widgets.dart';

enum AppLogoVariant { mark, fullOnLight, fullOnDark }

/// The brand image. The wordmark is part of the image, so the name is
/// never drawn as text here; a screen reader hears the app's name.
class AppLogo extends StatelessWidget {
  const AppLogo({required this.variant, required this.height, super.key});

  final AppLogoVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    switch (variant) {
      AppLogoVariant.mark => BrandAssets.mark,
      AppLogoVariant.fullOnLight => BrandAssets.fullOnLight,
      AppLogoVariant.fullOnDark => BrandAssets.fullOnDark,
    },
    height: height,
    fit: BoxFit.contain,
    semanticLabel: appDisplayName,
  );
}
