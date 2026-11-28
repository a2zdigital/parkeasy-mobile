import 'package:app/core/config/app_identity.dart';
import 'package:app/core/motion/motion.dart';
import 'package:app/core/theme/app_dimensions.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/app_buttons.dart';
import 'package:app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// A point on the map, in degrees.
typedef MapPoint = ({double latitude, double longitude});

/// The OpenStreetMap tile layer, following the OSM tile usage policy
/// (operations.osmfoundation.org/policies/tiles): the standard tile URL,
/// an identifying User-Agent (the app ID), at most zoom 19, tiles cached on
/// the device (flutter_map's built-in cache honours the server's cache
/// headers), only what the owner looks at is loaded (no prefetching), and
/// the attribution always shown on the map ([OsmAttribution]).
///
/// Overridden in tests, which must not reach the tile servers.
final mapTileLayerProvider = Provider<Widget>(
  (ref) => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    // Identifies the app to OpenStreetMap in the User-Agent.
    userAgentPackageName: appApplicationId,
    maxZoom: 19,
  ),
);

/// Opens a full-screen map with a pin at [start]. The owner drags the pin
/// (or taps the map) to the exact spot and confirms. Returns the confirmed
/// point, or null when they back out.
Future<MapPoint?> pickLocationOnMap(
  BuildContext context, {
  required MapPoint start,
  required bool startIsKnown,
}) => Navigator.of(context).push(
  MaterialPageRoute<MapPoint>(
    builder: (_) =>
        LocationPickerScreen(start: start, startIsKnown: startIsKnown),
  ),
);

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    required this.start,
    required this.startIsKnown,
    super.key,
  });

  final MapPoint start;

  /// False when [start] is only a default area, not the facility: the map
  /// opens further out and says so.
  final bool startIsKnown;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  static const pinKey = ValueKey('location-pin');
  static const double _pinSize = 48;

  late LatLng _point = LatLng(widget.start.latitude, widget.start.longitude);
  bool _dragging = false;

  /// Counts taps that place the pin, so each placement drops in once.
  int _drops = 0;

  /// Whether the owner has placed the pin. A pin still on the default
  /// area (not the facility) cannot be confirmed: that would save the
  /// area's coordinates for an unrelated facility.
  late bool _placed = widget.startIsKnown;

  /// Moves the pin with the finger. Raw pointer events, so the map's own
  /// pan gesture cannot take the drag; the map holds still meanwhile.
  void _dragPin(BuildContext markerContext, PointerMoveEvent event) {
    final camera = MapCamera.of(markerContext);
    final moved = camera.latLngToScreenOffset(_point) + event.delta;
    setState(() {
      _point = camera.screenOffsetToLatLng(moved);
      _placed = true;
    });
  }

  void _setDragging(bool dragging) {
    if (_dragging != dragging) setState(() => _dragging = dragging);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final at =
        '${_point.latitude.toStringAsFixed(6)}, ${_point.longitude.toStringAsFixed(6)}';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapPickerTitle)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _point,
                initialZoom: widget.startIsKnown ? 17 : 12,
                minZoom: 3,
                maxZoom: 19,
                // North stays up; dragging the map is paused while the pin
                // itself is being dragged.
                interactionOptions: InteractionOptions(
                  flags: _dragging
                      ? InteractiveFlag.none
                      : InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, point) => setState(() {
                  _point = point;
                  _placed = true;
                  _drops++;
                }),
              ),
              children: [
                ref.watch(mapTileLayerProvider),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: _pinSize,
                      height: _pinSize,
                      // The pin's tip, not its middle, marks the spot.
                      alignment: Alignment.topCenter,
                      child: Builder(
                        builder: (markerContext) => Semantics(
                          label: l10n.mapPickerPin,
                          child: Listener(
                            key: pinKey,
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) => _setDragging(true),
                            onPointerMove: (event) =>
                                _dragPin(markerContext, event),
                            onPointerUp: (_) => _setDragging(false),
                            onPointerCancel: (_) => _setDragging(false),
                            child: _PinDrop(
                              key: ValueKey(_drops),
                              child: Icon(
                                Icons.location_pin,
                                size: _pinSize,
                                color: colors.danger.solid,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const OsmAttribution(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.startIsKnown
                        ? l10n.mapPickerHint
                        : l10n.mapPickerHintNoStart,
                    style: text.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  const Gap.xs(),
                  Text(l10n.mapPickerAt(at), style: text.body),
                  const Gap.md(),
                  PrimaryButton(
                    label: l10n.mapPickerConfirm,
                    onPressed: _placed
                        ? () => Navigator.of(context).pop((
                            latitude: _point.latitude,
                            longitude: _point.longitude,
                          ))
                        : null,
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

/// "© OpenStreetMap contributors", always visible on the map, as the
/// OpenStreetMap licence (ODbL) and tile policy require.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) => const SimpleAttributionWidget(
    source: Text('OpenStreetMap contributors'),
    alignment: Alignment.bottomLeft,
  );
}

/// The pin falls the last few pixels into place when it is put down, so the
/// eye follows where it went. Still with reduced motion.
class _PinDrop extends StatelessWidget {
  const _PinDrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, (1 - value) * -AppSpace.md),
        child: child,
      ),
    );
  }
}
