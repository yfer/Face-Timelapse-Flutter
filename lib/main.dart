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

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Timelapse',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Face Timelapse'),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.imageSize, this.faces);

  final Size imageSize;
  final List<Face> faces;

  Rect _scaleRect({
    @required Rect rect,
    @required Size imageSize,
    @required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;
    return Rect.fromLTRB(
      (imageSize.width - rect.left) * scaleX,
      rect.top.toDouble() * scaleY,
      (imageSize.width - rect.right) * scaleX,
      rect.bottom.toDouble() * scaleY,
    );
  }

  Offset _scaleOffset({
    @required Offset offset,
    @required Size imageSize,
    @required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    return Offset((imageSize.width - offset.dx) * scaleX,
        offset.dy * scaleY); //offset.scale(scaleX, scaleY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (Face face in faces) {
      for (var lm in FaceLandmarkType.values) {
        var mark = face.getLandmark(lm);
        if (mark != null)
          canvas.drawCircle(
              _scaleOffset(
                  offset: mark.position,
                  imageSize: imageSize,
                  widgetSize: size),
              10.0,
              paint);
      }

      canvas.drawRect(
        _scaleRect(
          rect: face.boundingBox,
          imageSize: imageSize,
          widgetSize: size,
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
  dynamic _scanResults;
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
    final WriteBuffer allBytes = WriteBuffer();
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
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );
    _camera = CameraController(description, ResolutionPreset.medium);
    await _camera.initialize();
    setState(() {});

    final FirebaseVision mlVision = FirebaseVision.instance;
    _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;
      var detector = mlVision.faceDetector(FaceDetectorOptions(
          enableLandmarks: true, mode: FaceDetectorMode.accurate));
      detect(image, detector.processImage, rotation).then(
        (dynamic result) {
          setState(() {
            _scanResults = result;
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
    const Text noResultsText = const Text('No results!');

    if (_scanResults == null ||
        _camera == null ||
        !_camera.value.isInitialized) {
      return noResultsText;
    }

    CustomPainter painter;

    final Size imageSize = Size(
      _camera.value.previewSize.height,
      _camera.value.previewSize.width,
    );

    if (_scanResults is! List<Face>) return noResultsText;
    painter = FaceDetectorPainter(imageSize, _scanResults);

    return CustomPaint(
      painter: painter,
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
              children: <Widget>[
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
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

Future<Directory> getDataDir() async {
  await PermissionHandler().requestPermissions([PermissionGroup.storage]);
  //todo: this is not available in ios, should research more
  var d = await getExternalStorageDirectory();
  var ret = await Directory('${d.path}/FaceTimelapse').create();
  var list = ret.listSync();
  return ret;
}

Future<Directory> getPhotoDir() async {
  var d = await getDataDir();
  var ret = await Directory('${d.path}/photos').create();
  var list = ret.listSync();
  return ret;
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
    loadImages();
  }

  void loadImages() async {
//    (await getDataDir()).delete(recursive: true);

    var dir = await getPhotoDir();
    var list = dir.listSync().map((e) => File(e.path)).toList();
    setState(() {
      images = list;
    });
  }

  void makeMovie() async {
    var d = await getDataDir();
    var p = await getPhotoDir();
    var ff = new FlutterFFmpeg();
    await ff.execute(
        '-y -r 1 -i ${p.path}/%03d.jpg -f lavfi -t 1 -i anullsrc -vcodec libx264 -shortest ${d.path}/v.mp4');
//      var info = await ff.getMediaInformation('${d.path}/v.mp4');
  }

  void resetMovie() async {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    videoPlayerController = null;
    chewieController = null;
    setState(() {});
  }

  void playMovie() async {
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
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.add_a_photo),
              onPressed: (){
                Navigator.of(context).push(MaterialPageRoute(builder: (b) => TakePhoto()));
              }),
          IconButton(icon: Icon(Icons.movie_creation), onPressed: makeMovie),
          IconButton(icon: Icon(Icons.play_arrow), onPressed: playMovie),
          IconButton(icon: Icon(Icons.share), onPressed: () async{
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
