import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MapMarkerUtil {
  /// Draws a custom delivery van badge to a [Uint8List] PNG for Mapbox PointAnnotations.
  static Future<Uint8List> getCarMarkerBytes({int size = 150}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double width = size.toDouble();
    final double height = size.toDouble();
    final center = Offset(width / 2, height / 2);

    // 1. Draw Map Pin Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, height - 10),
        width: 60,
        height: 20,
      ),
      0,
      3.14 * 2,
      true,
      shadowPaint,
    );

    // 2. Draw Main Map Pin / Circle
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color =
          const Color(0xFFFCA311) // Edita primary orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(
      Offset(center.dx, center.dy - 10),
      width * 0.4,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy - 10),
      width * 0.4,
      strokePaint,
    );

    // 3. Draw Delivery Icon / Car using path inside the circle
    final iconPaint = Paint()
      ..color = const Color(0xFFFCA311)
      ..style = PaintingStyle.fill;

    // A simple van/truck path
    final path = Path();
    final double iconCenterX = center.dx;
    final double iconCenterY = center.dy - 10;

    // Truck body
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(iconCenterX - 10, iconCenterY + 5),
          width: 40,
          height: 25,
        ),
        const Radius.circular(4),
      ),
    );
    // Truck cabin
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(iconCenterX + 20, iconCenterY + 10),
          width: 20,
          height: 15,
        ),
        const Radius.circular(4),
      ),
    );

    canvas.drawPath(path, iconPaint);

    // Wheels
    final wheelPaint = Paint()..color = Colors.black87;
    canvas.drawCircle(
      Offset(iconCenterX - 10, iconCenterY + 20),
      6,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(iconCenterX + 18, iconCenterY + 20),
      6,
      wheelPaint,
    );

    // Render to PNG bytes
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return bytes!.buffer.asUint8List();
  }

  /// Draws a square marker with an inner dot (Uber Origin style).
  static Future<Uint8List> getOriginMarkerBytes({int size = 60}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double width = size.toDouble();
    final double height = size.toDouble();
    final center = Offset(width / 2, height / 2);

    final bgPaint = Paint()..color = Colors.black;
    final dotPaint = Paint()..color = Colors.white;

    canvas.drawRect(
      Rect.fromCenter(center: center, width: width, height: height),
      bgPaint,
    );
    canvas.drawCircle(center, width * 0.15, dotPaint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return bytes!.buffer.asUint8List();
  }

  static Future<Uint8List> getDestinationMarkerBytes({int size = 60}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double width = size.toDouble();
    final double height = size.toDouble();
    final center = Offset(width / 2, height / 2);

    final bgPaint = Paint()..color = const Color(0xFFFCA311); // Orange
    final dotPaint = Paint()..color = Colors.white;

    canvas.drawCircle(center, width * 0.45, bgPaint);
    canvas.drawCircle(center, width * 0.2, dotPaint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return bytes!.buffer.asUint8List();
  }
}
