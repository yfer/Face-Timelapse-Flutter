import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_extend/share_extend.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

void main() => runApp(MyApp());

Future<int> getNewId() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  var key = 'num';
  int val = prefs.getInt(key);
  if (val == null) {
    val = 0;
  }
  val++;
  await prefs.setInt(key, val);
  return val;
}
setNewId() async {

}

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

    return Offset((imageSize.width - offset.dx) * scaleX, offset.dy * scaleY);//offset.scale(scaleX, scaleY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (Face face in faces) {
//      face.getLandmark(Face)
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
//  Detector _currentDetector = Detector.barcode;

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
    _camera = CameraController(description, ResolutionPreset.medium
//      defaultTargetPlatform == TargetPlatform.iOS
//          ? ResolutionPreset.low
//          : ResolutionPreset.medium,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Directory dir = await getApplicationDocumentsDirectory();
          int i = await getNewId();
          if(_camera.value.isStreamingImages)
            await _camera.stopImageStream();
          if (_camera.value.isTakingPicture) {
            // A capture is already pending, do nothing.
            return null;
          }
          var path = '${dir.path}/image${i.toString().padLeft(3, '0')}.jpg';
          await _camera.takePicture(path);
        },
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

class _MyHomePageState extends State<MyHomePage> {
  File _image;
  VideoPlayerController videoPlayerController;
  ChewieController chewieController;
  List<String> log = [];

  @override
  void dispose() {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    videoPlayerController = null;
    chewieController = null;
    super.dispose();
  }

  void addPhoto(BuildContext context) async {
    try {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (b) => TakePhoto()));
//      final Directory dir = await getApplicationDocumentsDirectory();
//      var image = await ImagePicker.pickImage(source: ImageSource.camera);
//      int i = await getNewId();
//      var newImage = await image.copy('${dir.path}/image${i}.jpg');
//      setState(() {
//        log.add('${dir.path}/image${i}.jpg');
//      });
////      _scaffoldKey.currentState.showSnackBar(SnackBar(
////        content: Text('${dir.path}/image${i}.jpg'),
////      ));
    } on Exception catch (ex) {
      setState(() {
        log.add(ex.toString());
      });
//      _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(ex.toString())));
    }
  }

  void makeMovie() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      var list = await dir.list().toList();
      var videoname = '${dir.path}/test.mp4';

      final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
      _flutterFFmpeg.enableLogCallback((i, s) {
        setState(() {
          log.add(s);
        });
      });
//      var packageList = await _flutterFFmpeg.getExternalLibraries();
//      packageList.forEach((value) => print("External library: $value"));
      var res = await _flutterFFmpeg.execute(
          '-y -r 1 -i ${dir.path}/image%03d.jpg -f lavfi -t 1 -i anullsrc -vcodec libx264 -shortest $videoname');
      var info = await _flutterFFmpeg.getMediaInformation(videoname);
      setState(() {
        log.add(info.toString());
      });
    } on Exception catch (ex) {
      setState(() {
        log.add(ex.toString());
      });
//      _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(ex.toString())));
    }
  }

  void resetMovie() async {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    videoPlayerController = null;
    chewieController = null;
    setState(() {});
  }

  void shareMovie() async {
    var permissions =
        await PermissionHandler().requestPermissions([PermissionGroup.storage]);
    final Directory dir = await getApplicationDocumentsDirectory();
    var temp =
        await getExternalStorageDirectory(); //todo: this is not available in ios
    var file = File.fromUri(Uri.file('${dir.path}/test.mp4'));
    await file.copy('${temp.path}/test.mp4');
    var videoname = '${temp.path}/test.mp4';
    ShareExtend.share(videoname, "video");
  }

  void playMovie() async {
    try {
      videoPlayerController?.dispose();
      chewieController?.dispose();
      videoPlayerController = null;
      chewieController = null;
      setState(() {});
      final Directory dir = await getApplicationDocumentsDirectory();
      var videoname = '${dir.path}/test.mp4';

      videoPlayerController = VideoPlayerController.file(File(videoname));
      this.chewieController = ChewieController(
        videoPlayerController: videoPlayerController,
        aspectRatio: 3 / 2,
        autoPlay: false,
        looping: false,
      );
      setState(() {});
    } on Exception catch (ex) {
      setState(() {
        log.add(ex.toString());
      });
//      _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(ex.toString())));
    }
  }

//  void _incrementCounter() async {
////    Map<PermissionGroup, PermissionStatus> permissions = await PermissionHandler().requestPermissions([PermissionGroup.storage]);
//    final Directory dir = await getApplicationDocumentsDirectory();
//    var videoname = '${dir.path}/test.mp4';
////    var videotest = '${dir.path}/SampleVideo_360x240_1mb.mp4';
//
//    var image = await ImagePicker.pickImage(source: ImageSource.camera);
////    Share.share('check out my website https://example.com');
////
////    HttpClient client = new HttpClient();
////    var req = await client.getUrl(Uri.parse("https://www.sample-videos.com/video123/mp4/240/big_buck_bunny_240p_1mb.mp4"));
////    var res = await req.done;
////    await res.pipe(new File(videoname).openWrite());
//
//    var newImage = await image.copy('${dir.path}/image${i++}.jpg');
//
//    var files = await dir.list().toList();
//
//    final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
//    var packageList = await _flutterFFmpeg.getExternalLibraries();
//    packageList.forEach((value) => print("External library: $value"));
////
////    // -vframes 2  coutt of frames
//    var res = await _flutterFFmpeg.execute(
//        '-y -r 1 -i ${dir.path}/image%d.jpg -f lavfi -t 1 -i anullsrc -vcodec libx264 -shortest $videoname');
//    var info1 = await _flutterFFmpeg.getMediaInformation(videoname);
////    var info2 = await _flutterFFmpeg.getMediaInformation(videotest);
//    videoPlayerController = VideoPlayerController.file(File(videoname));
//    this.chewieController = ChewieController(
//      videoPlayerController: videoPlayerController,
//      aspectRatio: 3 / 2,
//      autoPlay: true,
//      looping: true,
//    );
//////    _controller = VideoPlayerController.network('http://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_20mb.mp4');
////    await videoPlayerController.initialize();
////    await videoPlayerController.setLooping(true);
//    setState(() {});
////    await videoPlayerController.play();
//////    setState(() {
//////      _image = newImage;
//////    });
////    var d = 1;
//  }

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.add_a_photo),
              onPressed: () => addPhoto(context)),
          IconButton(icon: Icon(Icons.movie_creation), onPressed: makeMovie),
          IconButton(icon: Icon(Icons.play_arrow), onPressed: playMovie),
          IconButton(icon: Icon(Icons.share), onPressed: shareMovie)
        ],
      ),
      body: Center(
        child: chewieController == null
            ? ListView(
                children: log.map((e) => Text(e)).toList(),
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
