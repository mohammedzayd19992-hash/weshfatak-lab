import 'package:flutter/material.dart';

import '../brand.dart';
import '../models.dart';
import 'skeleton.dart';

/// A network image that fades in, shows a shimmer while loading and a note on error.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.label});

  final String url;
  final BoxFit fit;
  final String? label;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    fit: fit,
    semanticLabel: label,
    width: double.infinity,
    height: double.infinity,
    frameBuilder: (context, child, frame, synchronous) => AnimatedOpacity(
      opacity: synchronous || frame != null ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: child,
    ),
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const Shimmer(child: ColoredBox(color: Brand.surfaceHigher)),
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Brand.surfaceHigh,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: Brand.muted),
      ),
    ),
  );
}

/// The images of a post: one image at its own shape, or a grid of up to four.
/// Tapping an image opens the full screen viewer.
class MediaGallery extends StatelessWidget {
  const MediaGallery({super.key, required this.media, required this.heroTag});

  final List<NewsMedia> media;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox.square(dimension: 3);
    Widget tile(int index) => _MediaTile(
      media: media,
      index: index,
      heroTag: heroTag,
      more: index == 3 ? media.length - 4 : 0,
    );

    final Widget content;
    final double ratio;
    switch (media.length) {
      case 1:
        ratio = (media.first.aspectRatio ?? 16 / 10).clamp(0.62, 2.0);
        content = tile(0);
      case 2:
        ratio = 16 / 10;
        content = Row(
          children: [
            Expanded(child: tile(0)),
            gap,
            Expanded(child: tile(1)),
          ],
        );
      case 3:
        ratio = 16 / 10;
        content = Row(
          children: [
            Expanded(child: tile(0)),
            gap,
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tile(1)),
                  gap,
                  Expanded(child: tile(2)),
                ],
              ),
            ),
          ],
        );
      default:
        ratio = 16 / 10;
        content = Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(0)),
                  gap,
                  Expanded(child: tile(1)),
                ],
              ),
            ),
            gap,
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(2)),
                  gap,
                  Expanded(child: tile(3)),
                ],
              ),
            ),
          ],
        );
    }
    return AspectRatio(
      aspectRatio: ratio,
      child: Container(
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        decoration: BoxDecoration(
          color: Brand.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.media,
    required this.index,
    required this.heroTag,
    this.more = 0,
  });

  final List<NewsMedia> media;
  final int index;
  final String heroTag;
  final int more; // images not shown in the grid, as "+2" on the last tile

  @override
  Widget build(BuildContext context) {
    final item = media[index];
    return Semantics(
      button: true,
      label: item.alt ?? 'Image ${index + 1} of ${media.length}',
      child: GestureDetector(
        onTap: () => openMediaViewer(context, media, index, heroTag),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: '$heroTag-$index',
              child: NetImage(item.url, label: item.alt),
            ),
            if (more > 0)
              ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$more',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> openMediaViewer(
  BuildContext context,
  List<NewsMedia> media,
  int index,
  String heroTag,
) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) =>
        MediaViewer(media: media, initialIndex: index, heroTag: heroTag),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);

/// Full screen images: swipe between them, pinch or double tap to zoom.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.media,
    required this.initialIndex,
    required this.heroTag,
  });

  final List<NewsMedia> media;
  final int initialIndex;
  final String heroTag;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed =
      false; // while zoomed in, dragging moves the image instead of the page

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.media.length;
    final alt = widget.media[_index].alt;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: count,
            onPageChanged: (index) => setState(() {
              _index = index;
              _zoomed = false;
            }),
            itemBuilder: (_, index) => _ZoomableImage(
              media: widget.media[index],
              heroTag: '${widget.heroTag}-$index',
              onZoomChanged: (zoomed) {
                if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (count > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / $count',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (alt != null && alt.isNotEmpty)
                          Text(
                            alt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Brand.inkSoft,
                              height: 1.4,
                            ),
                          ),
                        if (count > 1) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < count; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: i == _index ? 18 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: i == _index
                                        ? Colors.white
                                        : Colors.white38,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One full screen image: pinch to zoom, double tap to zoom in on a spot or back out.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.media,
    required this.heroTag,
    required this.onZoomChanged,
  });

  final NewsMedia media;
  final String heroTag;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<Matrix4>? _zoom;
  Offset _tapPosition = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _animation.addListener(() {
      if (_zoom != null) _transform.value = _zoom!.value;
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  void _toggleZoom() {
    const scale = 2.5;
    final target = _zoomed
        ? Matrix4.identity()
        : (Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
            -_tapPosition.dx * (scale - 1),
            -_tapPosition.dy * (scale - 1),
            0,
          ));
    _zoom = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _tapPosition = details.localPosition,
    onDoubleTap: _toggleZoom,
    child: InteractiveViewer(
      transformationController: _transform,
      maxScale: 5,
      panEnabled: _zoomed,
      child: SizedBox.expand(
        child: Center(
          child: Hero(
            tag: widget.heroTag,
            child: Image.network(
              widget.media.url,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: BoxFit.contain,
              semanticLabel: widget.media.alt,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox.square(
                      dimension: 32,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_not_supported_outlined,
                color: Brand.muted,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
