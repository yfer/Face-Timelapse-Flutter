import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_timelapse/face_marks_painter.dart';
import 'package:face_timelapse/utils.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

class PhotoshootPage extends StatefulWidget {
  final int imageCount;
  final Size size;
  final File lastImage;
  final String photoFilesDirectory;
  PhotoshootPage(this.imageCount, this.size, this.lastImage, this.photoFilesDirectory);

  @override
  _PhotoshootPageState createState() => _PhotoshootPageState();
}

Future<List<Face>> getFaces(FirebaseVisionImage image) =>
    FirebaseVision.instance
        .faceDetector(FaceDetectorOptions(
        enableLandmarks: true, mode: FaceDetectorMode.accurate))
        .processImage(image);

class _PhotoshootPageState extends State<PhotoshootPage> {
  CameraController cameraController;
  var selectedCameraIndex = 0;
  List<Face> newFaces = [], oldFaces = [];
  var isDetectionRunning = false;
  CameraLensDirection lensDirection;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  void initOldFaces() async {
    if (widget.lastImage != null) {
      var image = FirebaseVisionImage.fromFilePath(widget.lastImage.path);
      oldFaces = await getFaces(image);
      setState(() {});
    }
  }

  ImageRotation fromSensorOrientation(int sensorOrientation) {
    return ImageRotation.values[(sensorOrientation / 90).round()];
  }

  void initCamera() async {
    await initOldFaces();
    var cameraList = (await availableCameras()).reversed.toList();
    if (selectedCameraIndex == cameraList.length) selectedCameraIndex = 0;
    var selectedCamera = cameraList[selectedCameraIndex];
    lensDirection = selectedCamera.lensDirection;
    cameraController = CameraController(selectedCamera, ResolutionPreset.low);
    await cameraController.initialize();
    cameraController.startImageStream((CameraImage camImage) async {
      if (!isDetectionRunning) {
        isDetectionRunning = true;
        try {
          var buffer = WriteBuffer();
          camImage.planes.forEach((plane) => buffer.putUint8List(plane.bytes));
          var planeData = camImage.planes
              .map((plane) => FirebaseVisionImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height,
              width: plane.width))
              .toList();
          var size =
          Size(camImage.width.toDouble(), camImage.height.toDouble());
          var rotation =
          fromSensorOrientation(selectedCamera.sensorOrientation);
          var bytes = buffer.done().buffer.asUint8List();
          var imageMetadata = FirebaseVisionImageMetadata(
              rawFormat: camImage.format.raw,
              size: size,
              rotation: rotation,
              planeData: planeData);
          var image = FirebaseVisionImage.fromBytes(bytes, imageMetadata);
          newFaces = await getFaces(image);
          if (mounted) setState(() {});
        } finally {
          isDetectionRunning = false;
        }
      }
    });
  }

  void takePicture() async {
    await cameraController.stopImageStream();
    var imagename = widget.imageCount.toString().padLeft(5, '0');
    var filename = '${widget.photoFilesDirectory}/$imagename.jpg';
    await Future.delayed(Duration(seconds: 1));
    await cameraController.takePicture(filename);
    var hflip = isFrontCamera(lensDirection) ?'hflip,':'';
    await FlutterFFmpeg()
        .execute('-y -i $filename -vf ${hflip}scale=1280:-2 $filename');
    Navigator.of(context).pop();
  }

  void changeCamera() async {
    selectedCameraIndex++;
    await cameraController.dispose();
    setState(() {
      cameraController = null;
    });
    initCamera();
  }

  @override
  Widget build(BuildContext context) {
    List<IconButton> actions = [
      IconButton(icon: Icon(Icons.sync), onPressed: changeCamera)
    ];
    var fab = FloatingActionButton.extended(
        icon: Icon(Icons.camera),
        backgroundColor: Colors.white,
        onPressed: takePicture,
        label: Text('Selfie'));
    var body = Container(
        constraints: BoxConstraints.expand(),
        child: cameraController?.value?.isInitialized ?? false
            ? Stack(fit: StackFit.expand, children: [
          CameraPreview(cameraController),
          CustomPaint(
              painter: FaceMarksPainter(
                  widget.size, oldFaces, Colors.red, false)),
          CustomPaint(
              painter: FaceMarksPainter(
                  cameraController.value.previewSize.flipped,
                  newFaces,
                  Colors.green,
                  isFrontCamera(lensDirection)))
        ])
            : Center(
          child: CircularProgressIndicator(),
        ));
    return Scaffold(
        appBar: AppBar(title: Text('Selfie'), actions: actions),
        body: body,
        floatingActionButton: fab);
  }
}
