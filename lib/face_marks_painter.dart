import 'dart:ui';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

import 'utils.dart';

class FaceMarksPainter extends CustomPainter {
  FaceMarksPainter(this.imageSize, this.faces, this.color, this.flipMarkersHorizontally);

  final Size imageSize;
  final List<Face> faces;
  final Color color;
  final bool flipMarkersHorizontally;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize != null) {
      var paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      var xScale = size.width / imageSize.width;
      var yScale = size.height / imageSize.height;
      for (var face in faces) {
        for (var landmarkType in FaceLandmarkType.values) {
          var landmark = face.getLandmark(landmarkType);

          if (landmark != null) {
            var u = landmark?.position?.dx;
            var xpos = flipMarkersHorizontally ? imageSize.width - u : u;
            var ypos = landmark.position.dy;
            canvas.drawCircle(Offset(xpos * xScale, ypos * yScale), 10, paint);
          }
        }
        var markersBoxHeight = imageSize.height * yScale;
        var markersRect = Rect.fromLTRB(0, markersBoxHeight * 0.1,
            imageSize.width * xScale, markersBoxHeight * 0.9);
        drawArc(double startAngle, x) => canvas.drawArc(markersRect, startAngle,
            (flipMarkersHorizontally ? x : -x) / (180 / pi), false, paint);

        drawArc(pi / 2, face.headEulerAngleY);
        drawArc(3 * pi / 2, face.headEulerAngleZ);
      }
    }
  }

  shouldRepaint(o) => o != this;
}
