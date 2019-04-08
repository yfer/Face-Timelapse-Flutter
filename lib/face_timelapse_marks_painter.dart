import 'dart:ui' as ui;
import 'dart:math';

import 'package:camera/camera.dart';
//import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:firebase_face_contour/firebase_face_contour.dart';
import 'package:flutter/material.dart';

import 'utils.dart';

class FaceTimelapseMarksPainter extends CustomPainter {
  FaceTimelapseMarksPainter(
      this.oldImageSize,
      this.newImageSize,
      this.old_faces,
      this.new_faces,
      this.flipMarkersHorizontallyOld,
      this.flipMarkersHorizontallyNew)
      : assert(old_faces != null),
        assert(new_faces != null);

  static const double strokeWidth = 3.0;
  static const Color oldColor = Colors.red;
  static const Color newColor = Colors.green;

  final Size oldImageSize, newImageSize;
  final List<Face> old_faces, new_faces;
  final bool flipMarkersHorizontallyOld;
  final bool flipMarkersHorizontallyNew;

  Offset maybeFlipOld(Offset o) {
    return Offset(
        flipMarkersHorizontallyOld ? oldImageSize.width - o.dx : o.dx, o.dy);
  }

  Offset maybeFlipNew(Offset o) {
    return Offset(
        flipMarkersHorizontallyNew ? newImageSize.width - o.dx : o.dx, o.dy);
  }

  void _paintFaceMarkers(Canvas canvas, Size size, Face oldface, Face newface) {
    var scaleXOld = size.width / oldImageSize.width;
    var scaleYOld = size.height / oldImageSize.height;
    var scaleXNew = size.width / newImageSize.width;
    var scaleYNew = size.height / newImageSize.height;
    for (var contourType in FaceContourType.values) {
      var contourNew = newface.getContour(contourType);
      var contourOld = oldface.getContour(contourType);
      if (contourNew != null && contourOld != null) {
        for (int i = 0; i < contourNew.points.length; i++) {
          var oldpoint = maybeFlipOld(contourOld.points[i]).scale(scaleXOld, scaleYOld);
          var newpoint = maybeFlipNew(contourNew.points[i]).scale(scaleXNew, scaleYNew);
          var gradient =
              ui.Gradient.linear(oldpoint, newpoint, [oldColor, newColor]);
          var gradient_paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..shader = gradient;
          canvas.drawLine(oldpoint, newpoint, gradient_paint);
        }
      }
    }
    for (var landmarkType in FaceLandmarkType.values) {
      var oldlandmark = oldface.getLandmark(landmarkType);
      var newlandmark = newface.getLandmark(landmarkType);
      if (oldlandmark != null && newlandmark != null) {
        var oldpoint =
            maybeFlipOld(oldlandmark.position).scale(scaleXOld, scaleYOld);
        var newpoint =
            maybeFlipNew(newlandmark.position).scale(scaleXNew, scaleYNew);

        var gradient =
            ui.Gradient.linear(oldpoint, newpoint, [oldColor, newColor]);
        var gradient_paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..shader = gradient;

        canvas.drawLine(oldpoint, newpoint, gradient_paint);
      }
    }
  }

  void _paintFaceMarker(Canvas canvas, Size size, Face newface) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = newColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    var scaleX = size.width / newImageSize.width;
    var scaleY = size.height / newImageSize.height;
    for (var contourType in FaceContourType.values) {
      var contourNew = newface.getContour(contourType);
      var points = contourNew.points
          .map((p) => maybeFlipNew(p).scale(scaleX, scaleY))
          .toList();
      canvas.drawPoints(ui.PointMode.points, points, paint);
    }
    for (var landmarkType in FaceLandmarkType.values) {
      var landmark = newface.getLandmark(landmarkType);
      if (landmark != null) {
        canvas.drawCircle(
            maybeFlipNew(landmark.position).scale(scaleX, scaleY), 10, paint);
      }
    }
//    var markersBoxHeight = imageSize.height * scaleY;
//    var markersRect = Rect.fromLTRB(0, markersBoxHeight * 0.1,
//        imageSize.width * scaleX, markersBoxHeight * 0.9);
//    drawArc(double startAngle, x) => canvas.drawArc(markersRect, startAngle,
//        (flipMarkersHorizontally ? x : -x) / (180 / pi), false, paint);
//
//    drawArc(pi / 2, newface.headEulerAngleY);
//    drawArc(3 * pi / 2, newface.headEulerAngleZ);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (newImageSize != null && oldImageSize == null) {
      for (var face in new_faces) {
        _paintFaceMarker(canvas, size, face);
      }
    }
    if (newImageSize != null && oldImageSize != null) {
      var count = min(new_faces.length, old_faces.length);
      for (int i = 0; i < count; i++) {
        var newface = new_faces[i];
        var oldface = old_faces[i];
        _paintFaceMarkers(canvas, size, oldface, newface);
      }
    }
  }

  shouldRepaint(o) => o != this;
}
