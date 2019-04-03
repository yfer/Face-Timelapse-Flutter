import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_extend/share_extend.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';

main() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  build(c) => MaterialApp(
        home: MyHomePage(),
      );
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.iS, this.fs, this.c);

  Size iS;
  List<Face> fs;
  Color c;

  @override
  paint(ca, sz) {
    var p = Paint()
      ..color = c;

    var sX = sz.width / iS.width;
    var sY = sz.height / iS.height;

    for (var f in fs) {
      for (var lm in FaceLandmarkType.values) {
        var m = f.getLandmark(lm);
        if (m != null)
          ca.drawCircle(
              Offset((iS.width - m.position.dx) * sX, m.position.dy * sY),
              10.0,
              p);
      }
    }
  }

  @override
  shouldRepaint(o) => o != this;
}

class TakePhoto extends StatefulWidget {
  @override
  createState() => _TakePhotoState();
}

class _TakePhotoState extends State<TakePhoto> {
  CameraController cam;
  var det = false;
  List<Face> _f, _of;
  Size _old;

  @override
  initState() {
    super.initState();
    initCam();
  }

  loadOld() async {
    var dd = await getPhotoDir();
    var list = dd.listSync();
    if (list.length == 0) return;
    var p = list.last.path;
    var u = list.last.uri;
    FirebaseVisionImage im = FirebaseVisionImage.fromFilePath(p);
    var i = Image.file(File.fromUri(u));
    i.image
        .resolve(ImageConfiguration())
        .completer
        .addListener((ii, b) async {
      var f = await detect(im);
      setState(() {
        _old = Size(ii.image.width.toDouble(), ii.image.height.toDouble());
        _of = f;
      });
    });
  }

  var detect = FirebaseVision.instance
      .faceDetector(FaceDetectorOptions(
          enableLandmarks: true, mode: FaceDetectorMode.accurate))
      .processImage;

  initCam() async {
    await loadOld();
    var d = (await availableCameras())
        .firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    cam = CameraController(d, ResolutionPreset.medium);
    await cam.initialize();
    setState(() {});

    cam.startImageStream((i) async {
      if (det) return;

      det = true;
      try {
        var b = WriteBuffer();
        i.planes.forEach((p) => b.putUint8List(p.bytes));

        var md = FirebaseVisionImageMetadata(
          rawFormat: i.format.raw,
          size: Size(i.width.toDouble(), i.height.toDouble()),
          rotation: ImageRotation.rotation270,
          planeData: i.planes
              .map((p) => FirebaseVisionImagePlaneMetadata(
                    bytesPerRow: p.bytesPerRow,
                    height: p.height,
                    width: p.width,
                  ))
              .toList(),
        );

        var f = await detect(FirebaseVisionImage.fromBytes(
          b.done().buffer.asUint8List(),
          md,
        ));
        setState(() {
          _f = f;
        });
      } finally {
        det = false;
      }
    });
  }
  res(f) {
    var nr = Text('No results!');
    if (f == null || cam == null || !cam.value.isInitialized) {
      return nr;
    }
    return CustomPaint(
      painter:
          FaceDetectorPainter(cam.value.previewSize.flipped, f, Colors.red),
    );
  }

  res2(f) {
    var nr = Text('No results!');
    if (f == null || cam == null || !cam.value.isInitialized) {
      return nr;
    }
    return CustomPaint(
      painter: FaceDetectorPainter(_old, f, Colors.green),
    );
  }

  takePicture() async {
    var d = await getPhotoDir();
    var i = d.listSync().length;
    if (cam.value.isStreamingImages) await cam.stopImageStream();
    await Future.delayed(Duration(seconds: 1));
    var path = '${d.path}/${i.toString().padLeft(3, '0')}.jpg';
    await cam.takePicture(path);
    Navigator.of(context).pop();
  }

  @override
  build(BuildContext context) => Scaffold(
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
                  res(_f),
                  res2(_of),
                ],
              ),
      ));
}

class MyHomePage extends StatefulWidget {
  @override
  createState() => _MyHomePageState();
}

Future<Directory> getDataDir() async {
  await PermissionHandler().requestPermissions([PermissionGroup.storage]);
  var d = await getExternalStorageDirectory();
  return Directory('${d.path}/FaceTimelapse').create();
}

Future<Directory> getPhotoDir() async {
  var d = await getDataDir();
  return Directory('${d.path}/photos').create();
}

class _MyHomePageState extends State<MyHomePage> {
  List<File> images = [];

  @override
  initState() {
    super.initState();
    loadImages();
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
        '-y -r 1 -i ${p.path}/%03d.jpg -c:v libx264 -t 30 -pix_fmt yuv420p ${d.path}/v.mp4');
  }

  @override
  build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: Icon(Icons.movie_creation), onPressed: makeMovie),
          IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () async {
                var d = await getDataDir();
                var file = '${d.path}/v.mp4';
              }),
          IconButton(
              icon: Icon(Icons.share),
              onPressed: () async {
                var d = await getDataDir();
                ShareExtend.share('${d.path}/v.mp4', "video");
              })
        ],
      ),
      body: Center(
          child: GridView.count(
        crossAxisCount: 2,
        children: images.map((s) => Image.file(s)).toList(),
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (b) => TakePhoto()));
          loadImages();
        },
        child: Icon(Icons.add_a_photo),
      ),
    );
  }
}
