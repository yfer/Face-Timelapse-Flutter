import 'package:camera/camera.dart';

bool isFrontCamera(CameraLensDirection lensDirection) =>
    lensDirection == CameraLensDirection.front;
