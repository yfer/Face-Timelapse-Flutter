import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:share_extend/share_extend.dart';
import 'package:video_player/video_player.dart';

class MakeVideoPage extends StatefulWidget {
  final int imageCount;
  final Size size;
  final String appFilesDirectory, photoFilesDirectory;
  MakeVideoPage(this.imageCount, this.size, this.appFilesDirectory,
      this.photoFilesDirectory);

  @override
  _MakeVideoPageState createState() => _MakeVideoPageState();
}

class _MakeVideoPageState extends State<MakeVideoPage> {
  VideoPlayerController vPC;
  ChewieController cC;
  StreamSubscription subscription;

  String videoFilename;
  var isVideoCompiling = true, framesProcessedCount = 0;

  @override
  void initState() {
    super.initState();
    videoFilename = '${widget.appFilesDirectory}/video.mp4';
    compileVideo();
  }

  @override
  void dispose() {
    vPC?.dispose();
    cC?.dispose();
    super.dispose();
  }

  Stream<int> launchCompileVideoProcess() {
    var sc = StreamController<int>();
    FlutterFFmpeg ffmpeg;
    sc.onListen = () async {
      try {
        ffmpeg = FlutterFFmpeg();
        var regex = RegExp(r"frame=[ ]{3}(\d+)");
        int parseCurrentFrame(String message) =>
            int.tryParse(regex.firstMatch(message)?.group(1) ?? '');

        ffmpeg.enableLogCallback((level, message) {
          var frame = parseCurrentFrame(message);
          if (frame != null) {
            sc.add(frame);
          }
        });
        var imageFilenameTemplate = '${widget.photoFilesDirectory}/%05d.jpg';
        var zoompanFilter =
            '-vf zoompan=d=2:fps=1,framerate=5:interp_start=0:interp_end=255:scene=100';
        await ffmpeg.execute(
            '-y -i $imageFilenameTemplate $zoompanFilter $videoFilename');
      } catch (ex) {
        sc.addError(ex);
      } finally {
        sc.close();
      }
    };
    sc.onCancel = () async {
      try {
        await ffmpeg.cancel();
      } catch (ex) {
        sc.addError(ex);
      }
    };

    return sc.stream;
  }

  void compileVideo() {
    newData(int progress) {
      setState(() {
        framesProcessedCount = progress;
      });
    }

    onDone() {
      vPC = VideoPlayerController.file(File(videoFilename));
      cC = ChewieController(
          videoPlayerController: vPC,
          autoPlay: true,
          looping: true,
          aspectRatio: widget.size.width / widget.size.height);
      setState(() {
        isVideoCompiling = false;
      });
    }

    subscription = launchCompileVideoProcess().listen(newData, onDone: onDone);
  }

  void share() async {
    await ShareExtend.share(videoFilename, "video");
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    List<IconButton> actions = [];
    if (!isVideoCompiling) {
      actions.add(IconButton(icon: Icon(Icons.share), onPressed: share));
    }
    var ratio = framesProcessedCount / widget.imageCount;
    var percentCompleted = (ratio / 100).toStringAsFixed(2);
    var body = Center(
        child: isVideoCompiling
            ? Text('$percentCompleted%')
            : Chewie(controller: cC));
    return Scaffold(
        appBar: AppBar(title: Text('Movie'), actions: actions), body: body);
  }
}
