import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CustomBarcodeOverlay extends StatefulWidget {
  final MobileScannerController controller;
  final BoxFit boxFit;

  const CustomBarcodeOverlay({
    super.key,
    required this.controller,
    this.boxFit = BoxFit.cover,
  });

  @override
  State<CustomBarcodeOverlay> createState() => _CustomBarcodeOverlayState();
}

class _CustomBarcodeOverlayState extends State<CustomBarcodeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextPainter _textPainter = TextPainter(
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );

  DeviceOrientation? _lastOrientation;
  int _orientationResetKey = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true); // Pulsing effect

    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CustomBarcodeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastOrientation = null;
    }
  }

  void _onControllerChanged() {
    final orientation = widget.controller.value.deviceOrientation;
    if (_lastOrientation != null && _lastOrientation != orientation) {
      setState(() {
        _orientationResetKey++;
      });
    }
    _lastOrientation = orientation;
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.controller.removeListener(_onControllerChanged);
    _textPainter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        if (!value.isInitialized || !value.isRunning || value.error != null) {
          return const SizedBox();
        }

        return StreamBuilder<BarcodeCapture>(
          key: ValueKey(_orientationResetKey),
          stream: widget.controller.barcodes,
          builder: (context, snapshot) {
            final barcodeCapture = snapshot.data;

            if (barcodeCapture == null ||
                barcodeCapture.size.isEmpty ||
                barcodeCapture.barcodes.isEmpty) {
              return const SizedBox();
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                for (final Barcode barcode in barcodeCapture.barcodes)
                  if (barcode.corners.isNotEmpty)
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _CustomBarcodePainter(
                            barcodeCorners: barcode.corners,
                            barcodeFormat: barcode.format.name,
                            boxFit: widget.boxFit,
                            cameraPreviewSize: barcodeCapture.size,
                            textPainter: _textPainter,
                            deviceOrientation: value.deviceOrientation,
                            animationValue: _animationController.value,
                          ),
                        );
                      },
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CustomBarcodePainter extends CustomPainter {
  final List<Offset> barcodeCorners;
  final String barcodeFormat;
  final BoxFit boxFit;
  final Size cameraPreviewSize;
  final TextPainter textPainter;
  final DeviceOrientation deviceOrientation;
  final double animationValue;

  const _CustomBarcodePainter({
    required this.barcodeCorners,
    required this.barcodeFormat,
    required this.boxFit,
    required this.cameraPreviewSize,
    required this.textPainter,
    required this.deviceOrientation,
    required this.animationValue,
  });

  ({double widthRatio, double heightRatio}) _calculateBoxFitRatio(
    BoxFit boxFit,
    Size cameraPreviewSize,
    Size size,
  ) {
    double widthRatio = size.width / cameraPreviewSize.width;
    double heightRatio = size.height / cameraPreviewSize.height;

    switch (boxFit) {
      case BoxFit.fill:
        break;
      case BoxFit.contain:
        widthRatio = math.min(widthRatio, heightRatio);
        heightRatio = widthRatio;
      case BoxFit.cover:
        widthRatio = math.max(widthRatio, heightRatio);
        heightRatio = widthRatio;
      case BoxFit.fitWidth:
        heightRatio = widthRatio;
      case BoxFit.fitHeight:
        widthRatio = heightRatio;
      case BoxFit.scaleDown:
      case BoxFit.none:
        widthRatio = 1.0;
        heightRatio = 1.0;
    }

    return (widthRatio: widthRatio, heightRatio: heightRatio);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (barcodeCorners.length < 4 || cameraPreviewSize.isEmpty) {
      return;
    }

    final isLandscape = deviceOrientation == DeviceOrientation.landscapeLeft ||
        deviceOrientation == DeviceOrientation.landscapeRight;

    final adjustedCameraPreviewSize = isLandscape
        ? Size(cameraPreviewSize.height, cameraPreviewSize.width)
        : cameraPreviewSize;

    final ratios = _calculateBoxFitRatio(
      boxFit,
      adjustedCameraPreviewSize,
      size,
    );

    final horizontalPadding =
        (adjustedCameraPreviewSize.width * ratios.widthRatio - size.width) / 2;
    final verticalPadding =
        (adjustedCameraPreviewSize.height * ratios.heightRatio - size.height) /
        2;

    final adjustedOffset = <Offset>[
      for (final offset in barcodeCorners)
        Offset(
          offset.dx * ratios.widthRatio - horizontalPadding,
          offset.dy * ratios.heightRatio - verticalPadding,
        ),
    ];

    if (adjustedOffset.length < 4) return;

    // Calculate bounding box center and rotation
    final centerX = (adjustedOffset[0].dx + adjustedOffset[2].dx) / 2;
    final centerY = (adjustedOffset[0].dy + adjustedOffset[2].dy) / 2;
    final center = Offset(centerX, centerY);

    final angle = math.atan2(
      adjustedOffset[1].dy - adjustedOffset[0].dy,
      adjustedOffset[1].dx - adjustedOffset[0].dx,
    );

    // Bounding Box Dimensions
    // Length is distance between top-left (0) and top-right (1)
    final width = (adjustedOffset[1] - adjustedOffset[0]).distance;
    final height = (adjustedOffset[3] - adjustedOffset[0]).distance;

    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    // Rotate canvas to match the barcode's angle
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);

    // Glowing/Pulsing Paint
    final boundingBoxPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.3 * animationValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0 + (5.0 * animationValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Draw Glow
    canvas.drawRRect(roundedRect, glowPaint);
    // Draw Border
    canvas.drawRRect(roundedRect, boundingBoxPaint);

    // Draw Corner Markers (L-shaped)
    final markerPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    const double markerLength = 20.0;

    void drawLCorner(Offset corner, double dx1, double dy1, double dx2, double dy2) {
      final path = Path()
        ..moveTo(corner.dx + dx1, corner.dy + dy1)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(corner.dx + dx2, corner.dy + dy2);
      canvas.drawPath(path, markerPaint);
    }

    // Top-Left corner
    drawLCorner(
      rect.topLeft,
      markerLength, 0,
      0, markerLength,
    );
    // Top-Right corner
    drawLCorner(
      rect.topRight,
      -markerLength, 0,
      0, markerLength,
    );
    // Bottom-Left corner
    drawLCorner(
      rect.bottomLeft,
      markerLength, 0,
      0, -markerLength,
    );
    // Bottom-Right corner
    drawLCorner(
      rect.bottomRight,
      -markerLength, 0,
      0, -markerLength,
    );

    // Draw text label below the box
    final textSpan = TextSpan(
      text: barcodeFormat.toUpperCase(),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    textPainter.text = textSpan;
    textPainter.layout(maxWidth: rect.width);

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    // Position text below the rect
    final textPositionOffset = Offset(
      center.dx - textWidth / 2,
      rect.bottom + 8,
    );

    // Draw background for text
    final textBgRect = Rect.fromCenter(
      center: Offset(center.dx, rect.bottom + 8 + textHeight / 2),
      width: textWidth + 12,
      height: textHeight + 8,
    );

    final textBgPaint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawRRect(
        RRect.fromRectAndRadius(textBgRect, const Radius.circular(6)),
        textBgPaint);

    textPainter.paint(
      canvas,
      textPositionOffset,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CustomBarcodePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.barcodeCorners != barcodeCorners ||
        oldDelegate.barcodeFormat != barcodeFormat ||
        oldDelegate.boxFit != boxFit ||
        oldDelegate.cameraPreviewSize != cameraPreviewSize ||
        oldDelegate.deviceOrientation != deviceOrientation;
  }
}
