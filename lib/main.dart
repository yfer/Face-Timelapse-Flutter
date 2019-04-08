import 'package:face_timelapse/gallery_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(AppPage());
}

ThemeData getTheme() => ThemeData.dark();

class AppPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
      home: GalleryPage(), title: 'FaceTimelapse', theme: getTheme());
}
