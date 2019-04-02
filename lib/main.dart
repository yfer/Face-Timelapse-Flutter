import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_extend/share_extend.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chewie/chewie.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

var name = 'FaceTimelapse';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: name,
      home: MyHomePage(),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.imageSize, this.faces);

  Size imageSize;
  List<Face> faces;

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    var sX = size.width / imageSize.width;
    var sY = size.height / imageSize.height;

    for (var face in faces) {
      for (var lm in FaceLandmarkType.values) {
        var mark = face.getLandmark(lm);
        if (mark != null)
          canvas.drawCircle(
              Offset((imageSize.width - mark.position.dx) * sX,
                  mark.position.dy * sY),
              10.0,
              paint);
      }

      var rect = face.boundingBox;
      canvas.drawRect(
        Rect.fromLTRB(
          (imageSize.width - rect.left) * sX,
          rect.top.toDouble() * sY,
          (imageSize.width - rect.right) * sX,
          rect.bottom.toDouble() * sY,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.faces != faces;
  }
}

typedef HandleDetection = Future<dynamic> Function(FirebaseVisionImage image);

class TakePhoto extends StatefulWidget {
  @override
  _TakePhotoState createState() => _TakePhotoState();
}

class _TakePhotoState extends State<TakePhoto> {
  CameraController _camera;
  bool _isDetecting = false;
  List<Face> _faces;
  CameraLensDirection _direction = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<CameraDescription> getCamera(CameraLensDirection dir) async {
    return await availableCameras().then(
      (List<CameraDescription> cameras) => cameras.firstWhere(
            (CameraDescription camera) => camera.lensDirection == dir,
          ),
    );
  }

  Uint8List concatenatePlanes(List<Plane> planes) {
    var allBytes = WriteBuffer();
    planes.forEach((Plane plane) => allBytes.putUint8List(plane.bytes));
    return allBytes.done().buffer.asUint8List();
  }

  FirebaseVisionImageMetadata buildMetaData(
    CameraImage image,
    ImageRotation rotation,
  ) {
    return FirebaseVisionImageMetadata(
      rawFormat: image.format.raw,
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      planeData: image.planes.map(
        (Plane plane) {
          return FirebaseVisionImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          );
        },
      ).toList(),
    );
  }

  Future<dynamic> detect(
    CameraImage image,
    HandleDetection handleDetection,
    ImageRotation rotation,
  ) async {
    return handleDetection(
      FirebaseVisionImage.fromBytes(
        concatenatePlanes(image.planes),
        buildMetaData(image, rotation),
      ),
    );
  }

  ImageRotation rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return ImageRotation.rotation0;
      case 90:
        return ImageRotation.rotation90;
      case 180:
        return ImageRotation.rotation180;
      default:
        assert(rotation == 270);
        return ImageRotation.rotation270;
    }
  }

  void _initializeCamera() async {
    var description = await getCamera(_direction);
    var rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );
    _camera = CameraController(description, ResolutionPreset.medium);
    await _camera.initialize();
    setState(() {});

    _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;
      var detector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(
          enableLandmarks: true, mode: FaceDetectorMode.accurate));
      detect(image, detector.processImage, rotation).then(
        (dynamic result) {
          setState(() {
            _faces = result;
          });

          _isDetecting = false;
        },
      ).catchError(
        (_) {
          _isDetecting = false;
        },
      );
    });
  }

  Widget _buildResults() {
    const noResultsText = const Text('No results!');

    if (_faces == null || _camera == null || !_camera.value.isInitialized) {
      return noResultsText;
    }
    var imageSize = _camera.value.previewSize.flipped;

    return CustomPaint(
      painter: FaceDetectorPainter(imageSize, _faces),
    );
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: _camera == null
          ? const Center(
              child: Text(
                'Initializing Camera...',
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_camera),
                _buildResults(),
              ],
            ),
    );
  }

  takePicture() async {
    var d = await getPhotoDir();
    //todo: getting id like this is not resilient to user actions in directory
    int i = d.listSync().length;
    if (_camera.value.isStreamingImages) await _camera.stopImageStream();
    if (_camera.value.isTakingPicture) {
      return null;
    }
    var path = '${d.path}/${i.toString().padLeft(3, '0')}.jpg';
    await _camera.takePicture(path);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: takePicture,
        child: Icon(Icons.add_a_photo),
      ),
      body: _buildImage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

Future<Directory> getDataDir() async {
  await PermissionHandler().requestPermissions([PermissionGroup.storage]);
  //todo: this is not available in ios, should research more
  var d = await getExternalStorageDirectory();
  return Directory('${d.path}/$name').create();
}

Future<Directory> getPhotoDir() async {
  var d = await getDataDir();
  return Directory('${d.path}/photos').create();
}

class _MyHomePageState extends State<MyHomePage> {
  VideoPlayerController videoPlayerController;
  ChewieController chewieController;
  List<File> images = [];

  @override
  void dispose() {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    videoPlayerController = null;
    chewieController = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    erase();
  }

  erase() async {
    (await getDataDir()).delete(recursive: true);
    await loadImages();
  }

  loadImages() async {
    var dir = await getPhotoDir();
    var list = dir.listSync().map((e) => File(e.path)).toList();
    setState(() {
      images = list;
    });
  }

  makeMovie() async {
    var d = await getDataDir();
    var p = await getPhotoDir();
    await FlutterFFmpeg().execute(
        '-y -r 1/5 -i ${p.path}/%03d.jpg -c:v libx264 -t 30 -pix_fmt yuv420p ${d.path}/v.mp4');
  }

  resetMovie() async {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    videoPlayerController = null;
    chewieController = null;
    setState(() {});
  }

  playMovie() async {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    videoPlayerController = null;
    chewieController = null;
    setState(() {});
    var d = await getDataDir();

    videoPlayerController = VideoPlayerController.file(File('${d.path}/v.mp4'));
    this.chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      aspectRatio: 3 / 2,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
              icon: Icon(Icons.add_a_photo),
              onPressed: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute(builder: (b) => TakePhoto()));
                loadImages();
              }),
          IconButton(icon: Icon(Icons.movie_creation), onPressed: makeMovie),
          IconButton(icon: Icon(Icons.play_arrow), onPressed: playMovie),
          IconButton(
              icon: Icon(Icons.share),
              onPressed: () async {
                var d = await getDataDir();
                ShareExtend.share('${d.path}/v.mp4', "video");
              })
        ],
      ),
      body: Center(
        child: chewieController == null
            ? GridView.count(
                crossAxisCount: 2,
                children: images
                    .map((s) => Image.file(
                          s,
                          filterQuality: FilterQuality.low,
                        ))
                    .toList(),
              )
            : Chewie(
                controller: chewieController,
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: resetMovie,
        child: Icon(Icons.add),
      ),
    );
  }
}
