import 'dart:io';

import 'package:face_timelapse/make_video_page.dart';
import 'package:face_timelapse/photoshoot_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scroll_gallery/flutter_scroll_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class GalleryPage extends StatefulWidget {
  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<File> images = [];
  int imageCount() => images.length;
  File lastImage;
  Size size;
  String appFilesDirectory, photoFilesDirectory;

  @override
  void initState() {
    super.initState();
    initGalleryPage();
  }

  Future<bool> askRights() async {
    var requestResult = await PermissionHandler().requestPermissions([
      PermissionGroup.camera,
      PermissionGroup.microphone,
      PermissionGroup.storage
    ]);
    var grantedCount = requestResult.values
        .where((permission) => permission == PermissionStatus.granted)
        .length;
    var haveNecessaryPermissions = grantedCount == 3;
    if (haveNecessaryPermissions) {
      return true;
    }
    await showDialog(
        context: context,
        builder: (BuildContext context) =>
            AlertDialog(title: Text('Need rights!')));
    await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    return false;
  }

  initImageSize(File file) => Image.file(File.fromUri(file.uri))
      .image
      .resolve(ImageConfiguration())
      .completer
      .addListener((ImageInfo info, bool synchronousCall) => size =
          Size(info.image.width.toDouble(), info.image.height.toDouble()));

  void initGalleryPage() async {
    var rightsGiven = await askRights();
    if (!rightsGiven) {
      return;
    }
    appFilesDirectory = (await Directory(
                '${(await getExternalStorageDirectory()).path}/FaceTimelapse')
            .create())
        .path;
    var d = await Directory('$appFilesDirectory/photo').create();
    images = d.listSync().map((e) => File(e.path)).toList();
    photoFilesDirectory = d.path;
    if (imageCount() > 0) {
      lastImage = images.last;
      initImageSize(lastImage);
    }
    setState(() {});
  }

  void goToMakeVideoPage() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MakeVideoPage(
            imageCount(), size, appFilesDirectory, photoFilesDirectory)));
  }

  void goToPhotoshootPage() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PhotoshootPage(
            imageCount(), size, lastImage, photoFilesDirectory)));
    initGalleryPage();
  }

  bool haveImages() => imageCount() > 0;

  @override
  Widget build(BuildContext context) {
    List<IconButton> actions = [];
    if (haveImages()) {
      actions.add(
          IconButton(icon: Icon(Icons.movie), onPressed: goToMakeVideoPage));
    }
    actions.add(
        IconButton(icon: Icon(Icons.camera), onPressed: goToPhotoshootPage));
    var fab = haveImages()
        ? null
        : FloatingActionButton.extended(
            icon: Icon(Icons.camera),
            backgroundColor: Colors.white,
            onPressed: goToPhotoshootPage,
            label: Text('Selfie'));
    var body = ScrollGallery(
        images.map((s) => Image.file(s).image).toList().reversed.toList(),
        fit: BoxFit.cover);
    return Scaffold(
      appBar: AppBar(title: Text('FaceTimelapse'), actions: actions),
      body: body,
      floatingActionButton: fab,
    );
  }
}
