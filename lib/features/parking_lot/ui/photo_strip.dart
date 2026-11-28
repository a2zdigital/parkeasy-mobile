import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/parking_lot/data/models/parking_photo.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The facility's photos in the owner's order, scrolled sideways. Shows
/// nothing when there are none.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({required this.photos, super.key});

  final List<ParkingPhoto> photos;

  static const double height = 180;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.colors;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, index) => Semantics(
          image: true,
          label: l10n.lotPhoto(index + 1, photos.length),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                photos[index].url,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, _, _) => ColoredBox(
                  color: colors.surfaceSubtle,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
