import 'package:flutter/material.dart';

import '../brand.dart';

/// A soft light sweeping across [child] while content loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        final x = -1.5 + _controller.value * 3;
        return LinearGradient(
          begin: Alignment(x - 1, -0.3),
          end: Alignment(x + 1, 0.3),
          colors: const [
            Colors.transparent,
            Color(0x14FFFFFF),
            Colors.transparent,
          ],
        ).createShader(bounds);
      },
      child: child,
    ),
  );
}

/// A gray placeholder block with rounded corners.
class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Brand.surfaceHigher,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// The shape of a post card, shown before the first page arrives.
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Brand.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Brand.line),
    ),
    child: const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Bone(width: 44, height: 44, radius: 22),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(width: 120, height: 13),
                  SizedBox(height: 7),
                  Bone(width: 80, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Bone(height: 12),
          SizedBox(height: 8),
          Bone(height: 12),
          SizedBox(height: 8),
          Bone(width: 180, height: 12),
          SizedBox(height: 14),
          AspectRatio(aspectRatio: 16 / 10, child: Bone(radius: 16)),
        ],
      ),
    ),
  );
}
