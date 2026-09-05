import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'network_image_safe.dart';

/// Photo gallery for a destination: swipeable like any normal carousel,
/// PLUS auto-advances every few seconds while left alone. Any touch
/// (drag, tap-and-hold) pauses it instantly; it only resumes after a
/// few seconds of no interaction - so it never fights a manual swipe,
/// and never yanks a photo away while someone's actually looking at it.
class DestinationGallery extends StatefulWidget {
  final List<String> photoUrls; // already resolved to absolute-ish paths
  final Widget Function(BuildContext) placeholderBuilder;
  final double height;

  const DestinationGallery({
    super.key,
    required this.photoUrls,
    required this.placeholderBuilder,
    this.height = 260,
  });

  @override
  State<DestinationGallery> createState() => _DestinationGalleryState();
}

class _DestinationGalleryState extends State<DestinationGallery> {
  late final PageController _controller;
  Timer? _autoplayTimer;
  Timer? _resumeTimer;
  int _page = 0;
  bool _paused = false;

  static const _autoplayInterval = Duration(seconds: 4);
  static const _resumeAfterTouch = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoplay();
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoplay() {
    _autoplayTimer?.cancel();
    if (widget.photoUrls.length < 2) return; // nothing to advance to
    _autoplayTimer = Timer.periodic(_autoplayInterval, (_) {
      if (_paused || !mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.photoUrls.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  /// Called on any touch - pauses autoplay immediately, and schedules it
  /// to resume a few seconds after the touch ends (each new touch resets
  /// that timer, so actively browsing never gets interrupted).
  void _onUserInteraction() {
    _paused = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeAfterTouch, () {
      if (mounted) _paused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoUrls;
    if (photos.isEmpty) {
      return SizedBox(height: widget.height, child: widget.placeholderBuilder(context));
    }

    return SizedBox(
      height: widget.height,
      child: Listener(
        // Raw pointer events (not GestureDetector) so this fires on the
        // very first touch of a drag, not just after a full gesture is
        // recognized - the pause needs to be instant, not delayed.
        onPointerDown: (_) => _onUserInteraction(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => NetworkImageSafe(
                url: ApiConstants.resolveImageUrl(photos[i]),
                fit: BoxFit.cover,
                placeholder: widget.placeholderBuilder,
              ),
            ),
            if (photos.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(photos.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
