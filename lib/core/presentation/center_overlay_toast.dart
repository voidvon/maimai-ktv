import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum CenterOverlayToastType { success, error, loading }

class CenterOverlayToastHandle {
  CenterOverlayToastHandle._(this._dismissCompleter);

  final Completer<Future<void> Function()> _dismissCompleter;
  bool _isDismissed = false;

  Future<void> dismiss() async {
    if (_isDismissed) {
      return;
    }
    _isDismissed = true;
    final Future<void> Function() dismiss = await _dismissCompleter.future;
    await dismiss();
  }
}

class CenterOverlayToast {
  const CenterOverlayToast._();

  static CenterOverlayToastHandle showSuccess(
    BuildContext context, {
    required String message,
  }) {
    return _show(
      context,
      message: message,
      type: CenterOverlayToastType.success,
      autoDismissDuration: const Duration(milliseconds: 1200),
    );
  }

  static CenterOverlayToastHandle showError(
    BuildContext context, {
    required String message,
  }) {
    return _show(
      context,
      message: message,
      type: CenterOverlayToastType.error,
      autoDismissDuration: const Duration(milliseconds: 1600),
    );
  }

  static CenterOverlayToastHandle showLoading(
    BuildContext context, {
    required String message,
  }) {
    return _show(
      context,
      message: message,
      type: CenterOverlayToastType.loading,
    );
  }

  static CenterOverlayToastHandle _show(
    BuildContext context, {
    required String message,
    required CenterOverlayToastType type,
    Duration? autoDismissDuration,
  }) {
    final OverlayState overlay = Overlay.of(context);
    final Completer<Future<void> Function()> dismissCompleter =
        Completer<Future<void> Function()>();
    late final OverlayEntry entry;
    bool isRemoved = false;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return _CenterOverlayToastView(
          message: message,
          type: type,
          autoDismissDuration: autoDismissDuration,
          onReadyToDismiss: (Future<void> Function() dismiss) {
            if (!dismissCompleter.isCompleted) {
              dismissCompleter.complete(dismiss);
            }
          },
          onDismissed: () {
            if (isRemoved) {
              return;
            }
            isRemoved = true;
            entry.remove();
          },
        );
      },
    );
    overlay.insert(entry);
    return CenterOverlayToastHandle._(dismissCompleter);
  }
}

class _CenterOverlayToastView extends StatefulWidget {
  const _CenterOverlayToastView({
    required this.message,
    required this.type,
    required this.onReadyToDismiss,
    required this.onDismissed,
    this.autoDismissDuration,
  });

  final String message;
  final CenterOverlayToastType type;
  final Duration? autoDismissDuration;
  final ValueChanged<Future<void> Function()> onReadyToDismiss;
  final VoidCallback onDismissed;

  @override
  State<_CenterOverlayToastView> createState() => _CenterOverlayToastViewState();
}

class _CenterOverlayToastViewState extends State<_CenterOverlayToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _dismissTimer;
  bool _isDismissing = false;
  bool _hasDismissed = false;

  @override
  void initState() {
    super.initState();
    widget.onReadyToDismiss(_dismiss);
    _play();
  }

  Future<void> _play() async {
    await _controller.forward();
    final Duration? autoDismissDuration = widget.autoDismissDuration;
    if (autoDismissDuration == null) {
      return;
    }
    _dismissTimer = Timer(autoDismissDuration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_hasDismissed || _isDismissing) {
      return;
    }
    _isDismissing = true;
    _dismissTimer?.cancel();
    if (mounted && _controller.status != AnimationStatus.dismissed) {
      await _controller.reverse();
    }
    _hasDismissed = true;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _CenterOverlayToastVisual visual = _resolveVisual(widget.type);
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x26FFFFFF)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    visual.buildIcon(),
                    const SizedBox(height: 10),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _CenterOverlayToastVisual _resolveVisual(CenterOverlayToastType type) {
    return switch (type) {
      CenterOverlayToastType.success => const _CenterOverlayToastVisual(
        icon: Icons.check_circle_rounded,
      ),
      CenterOverlayToastType.error => const _CenterOverlayToastVisual(
        icon: Icons.error_rounded,
      ),
      CenterOverlayToastType.loading => const _CenterOverlayToastVisual(
        isLoading: true,
      ),
    };
  }
}

class _CenterOverlayToastVisual {
  const _CenterOverlayToastVisual({
    this.icon,
    this.isLoading = false,
  });

  final IconData? icon;
  final bool isLoading;

  Widget buildIcon() {
    if (isLoading) {
      return const SizedBox(
        width: 38,
        height: 38,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return Icon(icon, color: Colors.white, size: 38);
  }
}
