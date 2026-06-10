import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight shimmer placeholders for AI-content loading states
/// (Ideas enrichment, Recap insight generation) — no external `shimmer` package.
///
/// Wrap one or more [MrSkeletonBox]es (or any opaque, base-coloured shapes) in
/// an [MrShimmer] to animate a moving highlight across them.
class MrShimmer extends StatefulWidget {
  const MrShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<MrShimmer> createState() => _MrShimmerState();
}

class _MrShimmerState extends State<MrShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = MrSkeletonBox.baseColor;
    final highlight = AppColors.mix(AppColors.surface, base, 0.85);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, highlight, base],
            stops: [
              (t - 0.3).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.3).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single rounded placeholder bar painted in the skeleton base colour.
class MrSkeletonBox extends StatelessWidget {
  const MrSkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 7,
  });

  static const Color baseColor = AppColors.border;

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A stack of shimmering text lines; the last line is shortened to read as
/// running prose. Used as the body placeholder while AI text is generated.
class MrSkeletonLines extends StatelessWidget {
  const MrSkeletonLines({
    super.key,
    this.lines = 3,
    this.lineHeight = 11,
    this.gap = 8,
    this.lastLineFraction = 0.55,
  });

  final int lines;
  final double lineHeight;
  final double gap;
  final double lastLineFraction;

  @override
  Widget build(BuildContext context) {
    return MrShimmer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines; i++) ...[
                if (i > 0) SizedBox(height: gap),
                MrSkeletonBox(
                  width: i == lines - 1 ? maxW * lastLineFraction : maxW,
                  height: lineHeight,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
