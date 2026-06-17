import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NfcScanAnimation extends StatefulWidget {
  final bool isScanning;
  const NfcScanAnimation({super.key, required this.isScanning});

  @override
  State<NfcScanAnimation> createState() => _NfcScanAnimationState();
}

class _NfcScanAnimationState extends State<NfcScanAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(NfcScanAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning) {
      _pulseController.repeat(reverse: true);
      _rotateController.repeat();
    } else {
      _pulseController.stop();
      _rotateController.stop();
      _pulseController.reset();
      _rotateController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isScanning) ...[
            _RippleRing(delay: 0, controller: _pulseController),
            _RippleRing(delay: 0.3, controller: _pulseController),
            _RippleRing(delay: 0.6, controller: _pulseController),
          ],
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: widget.isScanning ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary,
                    AppTheme.secondary,
                  ],
                ),
                boxShadow: widget.isScanning
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ]
                    : [],
              ),
              child: const Icon(
                Icons.nfc_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RippleRing extends StatefulWidget {
  final double delay;
  final AnimationController controller;
  const _RippleRing({required this.delay, required this.controller});

  @override
  State<_RippleRing> createState() => _RippleRingState();
}

class _RippleRingState extends State<_RippleRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scale = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: (widget.delay * 2000).toInt()), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primary.withOpacity(_opacity.value),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
