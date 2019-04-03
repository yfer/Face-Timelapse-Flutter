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
  runApp(A());
}

class A extends StatelessWidget {
  @override
  build(c) => MaterialApp(
        home: HP(),
      );
}

class FDP extends CustomPainter {
  FDP(this.S, this.F, this.C);

  var S;
  var F;
  var C;

  @override
  paint(ca, sz) {
    var p = Paint()..color = C;

    var x = sz.width / S.width;
    var y = sz.height / S.height;

    for (var f in F) {
      for (var l in FaceLandmarkType.values) {
        var m = f.getLandmark(l);
        if (m != null)
          ca.drawCircle(
              Offset((S.width - m.position.dx) * x, m.position.dy * y),
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
  var C;
  var D = false;
  var F = [], O = [];
  var S;

  @override
  initState() {
    super.initState();
    initCam();
  }

  loadOld() async {
    var l = (await PD()).listSync();
    if (l.length == 0) return;
    var v = FirebaseVisionImage.fromFilePath(l.last.path);
    var f = Image.file(File.fromUri(l.last.uri));
    f.image.resolve(ImageConfiguration()).completer.addListener((i, b) async {
      var d = await detect(v);
      setState(() {
        S = Size(i.image.width.toDouble(), i.image.height.toDouble());
        O = d;
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
    C = CameraController(d, ResolutionPreset.medium);
    await C.initialize();
    setState(() {});

    C.startImageStream((i) async {
      if (D) return;

      D = true;
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
          F = f;
        });
      } finally {
        D = false;
      }
    });
  }

  @override
  build(c) => Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var d = await PD();
          var i = d.listSync().length;
          if (C.value.isStreamingImages) await C.stopImageStream();
          await Future.delayed(Duration(seconds: 1));
          var path = '${d.path}/${i.toString().padLeft(3, '0')}.jpg';
          await C.takePicture(path);
          Navigator.of(c).pop();
        },
        child: Icon(Icons.add_a_photo),
      ),
      body: Container(
          constraints: BoxConstraints.expand(),
          child: C?.value?.isInitialized
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(C),
                    CustomPaint(
                      painter: FDP(
                          C.value.previewSize.flipped, F, Colors.red),
                    ),
                    CustomPaint(
                      painter: FDP(S, O, Colors.red),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    'Initializing Camera...',
                  ),
                )));
}

class HP extends StatefulWidget {
  @override
  createState() => _HPState();
}

DD() async {
  await PermissionHandler().requestPermissions([PermissionGroup.storage]);
  return Directory(
          '${(await getExternalStorageDirectory()).path}/FaceTimelapse')
      .create();
}

PD() async {
  return Directory('${(await DD()).path}/photos').create();
}

class _HPState extends State<HP> {
  var I = [];

  @override
  initState() {
    super.initState();
    loadImages();
  }

  loadImages() async {
    var i =
        (await PD()).listSync().map((e) => File(e.path)).toList();
    setState(() {
      I = i;
    });
  }

  makeMovie() async {
    await FlutterFFmpeg().execute(
        '-y -r 1 -i ${(await PD()).path}/%03d.jpg -c:v libx264 -t 30 -pix_fmt yuv420p ${(await DD()).path}/v.mp4');
  }

  @override
  build(c) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(icon: Icon(Icons.movie_creation), onPressed: makeMovie),
          IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () async {
                var file = '${(await DD()).path}/v.mp4';
              }),
          IconButton(
              icon: Icon(Icons.share),
              onPressed: () async {
                ShareExtend.share(
                    '${(await DD()).path}/v.mp4', "video");
              })
        ],
      ),
      body: Center(
          child: GridView.count(
        crossAxisCount: 2,
        children: I.map((s) => Image.file(s)).toList(),
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(c)
              .push(MaterialPageRoute(builder: (b) => TakePhoto()));
          loadImages();
        },
        child: Icon(Icons.add_a_photo),
      ),
    );
  }
}
