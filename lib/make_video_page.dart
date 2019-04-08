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

  String m;
  var isVideoCompiling = true, framesProcessedCount = 0;

  @override
  void initState() {
    super.initState();
    m = '${widget.appFilesDirectory}/v.mp4';
    compileVideo();
  }

  @override
  void dispose() {
    vPC?.dispose();
    cC?.dispose();
    super.dispose();
  }

  void compileVideo() async {
    var ffmpeg = FlutterFFmpeg();
    var regex = RegExp(r"frame=[ ]{3}(\d+)");
    ffmpeg.enableLogCallback((level, message) => setState(() {
          framesProcessedCount =
              int.tryParse(regex.firstMatch(message)?.group(1) ?? '') ??
                  framesProcessedCount;
        }));
    await ffmpeg.execute(
        '-y -i ${widget.photoFilesDirectory}/%05d.jpg -vf zoompan=d=2:fps=1,framerate=5:interp_start=0:interp_end=255:scene=100 $m');
    vPC = VideoPlayerController.file(File(m));
    cC = ChewieController(
        videoPlayerController: vPC,
        autoPlay: true,
        looping: true,
        aspectRatio: widget.size.width / widget.size.height);
    setState(() {
      isVideoCompiling = false;
    });
  }

  void share() async {
    await ShareExtend.share(m, "video");
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    List<IconButton> actions = [];
    if (!isVideoCompiling) {
      actions.add(IconButton(icon: Icon(Icons.share), onPressed: share));
    }
    var percentCompleted =
        (framesProcessedCount * 10 / widget.imageCount).round();
    var body = Center(
        child: isVideoCompiling
            ? Text('$percentCompleted%')
            : Chewie(controller: cC));
    return Scaffold(
        appBar: AppBar(title: Text('Movie'), actions: actions), body: body);
  }
}
