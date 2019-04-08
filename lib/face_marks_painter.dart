import 'dart:ui';
import 'dart:math';

import 'package:camera/camera.dart';
//import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:firebase_face_contour/firebase_face_contour.dart';
import 'package:flutter/material.dart';

import 'utils.dart';

class FaceMarksPainter extends CustomPainter {
  FaceMarksPainter(this.imageSize, this.faces, this.color, this.flipMarkersHorizontally);

  final Size imageSize;
  final List<Face> faces;
  final Color color;
  final bool flipMarkersHorizontally;

  Offset maybeFlip(Offset o) {
    return Offset(flipMarkersHorizontally ? imageSize.width - o.dx : o.dx, o.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize != null) {
      var paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      var scaleX = size.width / imageSize.width;
      var scaleY = size.height / imageSize.height;
      for (var face in faces) {
        for (var contourType in FaceContourType.values) {
          var contour = face.getContour(contourType);
          var points = contour.points.map((p)=>maybeFlip(p).scale(scaleX, scaleY)).toList();
          canvas.drawPoints(PointMode.lines, points, paint);
        }
        for (var landmarkType in FaceLandmarkType.values) {
          var landmark = face.getLandmark(landmarkType);
          if (landmark != null) {
            canvas.drawCircle(maybeFlip(landmark.position).scale(scaleX, scaleY), 10, paint);
          }
        }
        var markersBoxHeight = imageSize.height * scaleY;
        var markersRect = Rect.fromLTRB(0, markersBoxHeight * 0.1,
            imageSize.width * scaleX, markersBoxHeight * 0.9);
        drawArc(double startAngle, x) => canvas.drawArc(markersRect, startAngle,
            (flipMarkersHorizontally ? x : -x) / (180 / pi), false, paint);

        drawArc(pi / 2, face.headEulerAngleY);
        drawArc(3 * pi / 2, face.headEulerAngleZ);
      }
    }
  }

  shouldRepaint(o) => o != this;
}
