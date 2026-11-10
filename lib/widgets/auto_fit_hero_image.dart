import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Hero picture that adjusts to the photo instead of chopping it.
///
/// The box height follows the photo's own shape (clamped so it never gets
/// silly), and the whole photo is always shown. Any space left over is filled
/// with a soft blurred copy of the same photo, so a tall shop front or a wide
/// panorama both look intentional. Added 10 Nov 2026 after partner photos were
/// losing their signage at the top.
class AutoFitHeroImage extends StatefulWidget {
  final String? url;
  final String fallbackAsset;
  final double minHeight;
  final double maxHeight;

  const AutoFitHeroImage({
    super.key,
    required this.url,
    required this.fallbackAsset,
    this.minHeight = 200,
    this.maxHeight = 340,
  });

  @override
  State<AutoFitHeroImage> createState() => _AutoFitHeroImageState();
}

class _AutoFitHeroImageState extends State<AutoFitHeroImage> {
  double? _aspect;
  bool _failed = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  ImageProvider get _provider => (widget.url != null && widget.url!.isNotEmpty)
      ? NetworkImage(widget.url!)
      : AssetImage(widget.fallbackAsset) as ImageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AutoFitHeroImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.fallbackAsset != widget.fallbackAsset) {
      _aspect = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _detach();
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted && w > 0 && h > 0) setState(() => _aspect = w / h);
    }, onError: (_, __) {
      if (mounted) setState(() => _failed = true);
    });
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  Widget _placeholder(double h) => Container(
        height: h,
        color: const Color(0xFF5C8FA8),
        child: Center(
          child: Icon(Icons.store_rounded, color: Colors.white.withValues(alpha: 0.3), size: 64),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.of(context).size.width;
      final h = _aspect == null
          ? 220.0
          : (w / _aspect!).clamp(widget.minHeight, widget.maxHeight).toDouble();
      if (_failed) return _placeholder(h);
      final img = _provider;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: h,
        width: double.infinity,
        child: ClipRect(
          child: Stack(fit: StackFit.expand, children: [
            // Soft backdrop so no empty bars show when the shape differs.
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image(image: img, fit: BoxFit.cover, gaplessPlayback: true),
            ),
            Container(color: Colors.black.withValues(alpha: 0.12)),
            // The whole photo, never cropped.
            Image(
              image: img,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _placeholder(h),
            ),
          ]),
        ),
      );
    });
  }
}
