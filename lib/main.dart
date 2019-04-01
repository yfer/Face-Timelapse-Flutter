import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_extend/share_extend.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<String> log = [];

  @override
  void dispose() {
    videoPlayerController?.dispose();
    chewieController?.dispose();
    videoPlayerController = null;
    chewieController = null;
    super.dispose();
  }

  Future<int> getNewId() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var key = 'num';
    int val = prefs.getInt(key);
    if(val == null){
      val = 0;
    }
    val++;
    await prefs.setInt(key, val);
    return val;
  }
  void addPhoto() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory();
      var image = await ImagePicker.pickImage(source: ImageSource.camera);
      int i = await getNewId();
      var newImage = await image.copy('${dir.path}/image${i}.jpg');
      setState(() {
        log.add('${dir.path}/image${i}.jpg');
      });
//      _scaffoldKey.currentState.showSnackBar(SnackBar(
//        content: Text('${dir.path}/image${i}.jpg'),
//      ));
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
      var videoname = '${dir.path}/test.mp4';

      final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
      _flutterFFmpeg.enableLogCallback((i,s){
        setState(() {
          log.add(s);
        });
      });
//      var packageList = await _flutterFFmpeg.getExternalLibraries();
//      packageList.forEach((value) => print("External library: $value"));
      var res = await _flutterFFmpeg.execute(
          '-y -r 1 -i ${dir.path}/image%d.jpg -f lavfi -t 1 -i anullsrc -vcodec libx264 -shortest $videoname');
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
    setState(() {

    });
  }
  void shareMovie() async {
      var permissions = await PermissionHandler().requestPermissions([PermissionGroup.storage]);
      final Directory dir = await getApplicationDocumentsDirectory();
      var temp = await getExternalStorageDirectory(); //todo: this is not available in ios
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
            onPressed: addPhoto
          ),
          IconButton(
            icon: Icon(Icons.movie_creation),
            onPressed: makeMovie
          ),
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: playMovie
          ),
          IconButton(
              icon: Icon(Icons.share),
              onPressed: shareMovie
          )
        ],
      ),
      body: Center(
        child: chewieController == null
            ? ListView(children: log.map((e)=>Text(e)).toList(),)
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
