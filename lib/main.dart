import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share/share.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chewie/chewie.dart';

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

  @override
  void dispose() {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    super.dispose();
  }

  var i = 0;
  void _incrementCounter() async {
//    Map<PermissionGroup, PermissionStatus> permissions = await PermissionHandler().requestPermissions([PermissionGroup.storage]);
    final Directory dir = await getApplicationDocumentsDirectory();
    var videoname = '${dir.path}/test.mp4';
//    var videotest = '${dir.path}/SampleVideo_360x240_1mb.mp4';

    var image = await ImagePicker.pickImage(source: ImageSource.camera);
//    Share.share('check out my website https://example.com');
//
//    HttpClient client = new HttpClient();
//    var req = await client.getUrl(Uri.parse("https://www.sample-videos.com/video123/mp4/240/big_buck_bunny_240p_1mb.mp4"));
//    var res = await req.done;
//    await res.pipe(new File(videoname).openWrite());

    var newImage = await image.copy('${dir.path}/image${i++}.jpg');

    var files = await dir.list().toList();

    final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
    var packageList = await _flutterFFmpeg.getExternalLibraries();
    packageList.forEach((value) => print("External library: $value"));
//
//    // -vframes 2  coutt of frames
    var res = await _flutterFFmpeg.execute(
        '-y -r 1 -i ${dir.path}/image%d.jpg -f lavfi -t 1 -i anullsrc -vcodec libx264 -shortest $videoname');
    var info1 = await _flutterFFmpeg.getMediaInformation(videoname);
//    var info2 = await _flutterFFmpeg.getMediaInformation(videotest);
    videoPlayerController = VideoPlayerController.file(File(videoname));
    this.chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      aspectRatio: 3 / 2,
      autoPlay: true,
      looping: true,
    );
////    _controller = VideoPlayerController.network('http://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_20mb.mp4');
//    await videoPlayerController.initialize();
//    await videoPlayerController.setLooping(true);
    setState(() {});
//    await videoPlayerController.play();
////    setState(() {
////      _image = newImage;
////    });
//    var d = 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: chewieController == null
            ? Text('No video selected.')
            : Chewie(
                controller: chewieController,
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        child: Icon(Icons.add),
      ),
    );
  }
}
