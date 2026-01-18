import 'package:flutter/material.dart';

class AnimatedMetallicContainer extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final Color? baseColor; // Optional overrides
  final double shimmerIntensity;

  const AnimatedMetallicContainer({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.boxShadow,
    this.border,
    this.baseColor,
    this.shimmerIntensity = 1.0,
  });

  @override
  State<AnimatedMetallicContainer> createState() => _AnimatedMetallicContainerState();
}

class _AnimatedMetallicContainerState extends State<AnimatedMetallicContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Calculate dynamic values based on controller
        final double t = _controller.value;
        
        // Metallic colors shifting
        // We create a gradient that shifts its center and intensity
        return Container(
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.borderRadius,
            border: widget.border,
            boxShadow: widget.boxShadow,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (t * 0.2), -1.0 + (t * 0.5)), // Slight movement of start
              end: Alignment.bottomRight,
              colors: [
                (widget.baseColor ?? Colors.white).withOpacity(0.12 + (0.05 * t * widget.shimmerIntensity)),
                (widget.baseColor ?? Colors.white).withOpacity(0.05 + (0.03 * (1-t) * widget.shimmerIntensity)),
                (widget.baseColor ?? Colors.white).withOpacity(0.12),
              ],
              stops: [
                0.0,
                0.5 + (0.2 * t), // Move the midpoint
                1.0,
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
