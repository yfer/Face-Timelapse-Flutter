import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
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

void main() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(MyApp());
}

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
  FaceDetectorPainter(this.iS, this.fs);

  Size iS;
  List<Face> fs;

  @override
  void paint(Canvas canvas, Size size) {
    var p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    var sX = size.width / iS.width;
    var sY = size.height / iS.height;

    for (var face in fs) {
      for (var lm in FaceLandmarkType.values) {
        var mark = face.getLandmark(lm);
        if (mark != null)
          canvas.drawCircle(
              Offset((iS.width - mark.position.dx) * sX,
                  mark.position.dy * sY),
              10.0,
              p);
      }

      var r = face.boundingBox;
      canvas.drawRect(
        Rect.fromLTRB(
          (iS.width - r.left) * sX,
          r.top.toDouble() * sY,
          (iS.width - r.right) * sX,
          r.bottom.toDouble() * sY,
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter old) => old != this;
}

typedef HandleDetection = Future<dynamic> Function(FirebaseVisionImage image);

class TakePhoto extends StatefulWidget {
  @override
  _TakePhotoState createState() => _TakePhotoState();
}

class _TakePhotoState extends State<TakePhoto> {
  CameraController cam;
  var det = false;
  List<Face> _faces;

  @override
  void initState() {
    super.initState();
    initCam();
  }

  Uint8List concatenatePlanes(List<Plane> planes) {
    var wb = WriteBuffer();
    planes.forEach((Plane plane) => wb.putUint8List(plane.bytes));
    return wb.done().buffer.asUint8List();
  }

  FirebaseVisionImageMetadata buildMetaData(
    CameraImage i,
    ImageRotation r,
  ) {
    return FirebaseVisionImageMetadata(
      rawFormat: i.format.raw,
      size: Size(i.width.toDouble(), i.height.toDouble()),
      rotation: r,
      planeData: i.planes
          .map((Plane plane) => FirebaseVisionImagePlaneMetadata(
                bytesPerRow: plane.bytesPerRow,
                height: plane.height,
                width: plane.width,
              ))
          .toList(),
    );
  }

  Future<dynamic> detect(
    CameraImage i,
    HandleDetection hd,
    ImageRotation r,
  ) async {
    return hd(
      FirebaseVisionImage.fromBytes(
        concatenatePlanes(i.planes),
        buildMetaData(i, r),
      ),
    );
  }

  void initCam() async {
    var d = (await availableCameras())
        .firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    cam = CameraController(d, ResolutionPreset.medium);
    await cam.initialize();
    setState(() {});

    cam.startImageStream((CameraImage image) {
      if (det) return;

      det = true;
      var detector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(
          enableLandmarks: true, mode: FaceDetectorMode.accurate));
      detect(image, detector.processImage, ImageRotation.rotation270).then(
        (dynamic result) {
          setState(() {
            _faces = result;
          });

          det = false;
        },
      ).catchError(
        (_) {
          det = false;
        },
      );
    });
  }

  Widget res() {
    const noResultsText = const Text('No results!');

    if (_faces == null || cam == null || !cam.value.isInitialized) {
      return noResultsText;
    }
    var imageSize = cam.value.previewSize.flipped;

    return CustomPaint(
      painter: FaceDetectorPainter(imageSize, _faces),
    );
  }

  takePicture() async {
    var d = await getPhotoDir();
    int i = d.listSync().length;
    if (cam.value.isStreamingImages) await cam.stopImageStream();
    if (cam.value.isTakingPicture) {
      return null;
    }
    var path = '${d.path}/${i.toString().padLeft(3, '0')}.jpg';
    await cam.takePicture(path);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: takePicture,
          child: Icon(Icons.add_a_photo),
        ),
        body: Container(
          constraints: const BoxConstraints.expand(),
          child: cam == null
              ? const Center(
                  child: Text(
                    'Initializing Camera...',
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(cam),
                    res(),
                  ],
                ),
        ));
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

Future<Directory> getDataDir() async {
  await PermissionHandler().requestPermissions([PermissionGroup.storage]);
  var d = await getExternalStorageDirectory();
  return Directory('${d.path}/$name').create();
}

Future<Directory> getPhotoDir() async {
  var d = await getDataDir();
  return Directory('${d.path}/photos').create();
}

class _MyHomePageState extends State<MyHomePage> {
  VideoPlayerController vPC;
  ChewieController cC;
  List<File> images = [];

  @override
  void dispose() {
    vPC?.dispose();
    cC?.dispose();
    vPC = null;
    cC = null;
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
    vPC?.dispose();
    cC?.dispose();
    vPC = null;
    cC = null;
    setState(() {});
  }

  playMovie() async {
    vPC?.dispose();
    cC?.dispose();
    vPC = null;
    cC = null;
    setState(() {});
    var d = await getDataDir();

    vPC = VideoPlayerController.file(File('${d.path}/v.mp4'));
    this.cC = ChewieController(
      videoPlayerController: vPC,
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
        child: cC == null
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
                controller: cC,
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: resetMovie,
        child: Icon(Icons.add),
      ),
    );
  }
}
