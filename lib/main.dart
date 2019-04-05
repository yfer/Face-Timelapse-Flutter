import'dart:io';import'package:flutter/services.dart';import'package:flutter/foundation.dart';import'package:flutter/material.dart';import'package:share_extend/share_extend.dart';import'package:path_provider/path_provider.dart';import'package:flutter_ffmpeg/flutter_ffmpeg.dart';import'package:permission_handler/permission_handler.dart';import'package:camera/camera.dart';import'package:firebase_ml_vision/firebase_ml_vision.dart';import'package:video_player/video_player.dart';import'package:chewie/chewie.dart';import'package:flutter_scroll_gallery/flutter_scroll_gallery.dart';
var F=false;var X='FaceTimelapse';
main(){SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);runApp(A());}
class A extends StatelessWidget{build(c)=>MaterialApp(home:HP(),title:X,theme:ThemeData.dark());}
class FDP extends CustomPainter{
  FDP(this.S,this.O,this.C);var S;var O;var C;
  paint(c,s){
    if(S==null)return;
    var p=Paint()..color=C..style=PaintingStyle.stroke..strokeWidth=5;

    var x=s.width/S.width;
    var y=s.height/S.height;

    for(var o in O){
      for(var l in FaceLandmarkType.values){
        var m=o.getLandmark(l);
        if(m!=null)
          c.drawCircle(Offset((S.width-m.position.dx)*x,m.position.dy*y),10,p);
      }
      var q=S.height*y;
      var r=Rect.fromLTRB(0,q*0.1,S.width*x,q*0.9);
      c.drawArc(r,1.57,o.headEulerAngleY/57.29,F,p);
      c.drawArc(r,4.71,o.headEulerAngleZ/57.29,F,p);
    }
  }
  shouldRepaint(o)=>o!=this;
}

class TP extends StatefulWidget{createState()=>TPS();}
var N=0;
class TPS extends State<TP>{
  var C;var D=F;var Q=[],O=[];var S;
  initState(){super.initState();iC();}
  iO()async{
    var l=(await PD()).listSync();
    if(l.length==0)return;
    var v=FirebaseVisionImage.fromFilePath(l.last.path);
    var f=Image.file(File.fromUri(l.last.uri));
    f.image.resolve(ImageConfiguration()).completer.addListener((i,b)async{
      var o=await V(v);
      setState((){
        S=Size(i.image.width.toDouble(),i.image.height.toDouble());
        O=o;
      });
    });
  }

  var V=FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableLandmarks:true,mode:FaceDetectorMode.accurate)).processImage;

  iC()async{
    await iO();
    var a=await availableCameras();
    if(N==a.length)N=0;
    C=CameraController(a[N],ResolutionPreset.medium);
    await C.initialize();
    C.startImageStream((CameraImage i)async{
      if(D)return;
      D=true;
      try{
        var b=WriteBuffer();
        i.planes.forEach((p)=>b.putUint8List(p.bytes));
        var v=FirebaseVisionImageMetadata(
          rawFormat:i.format.raw,
          size:Size(i.width.toDouble(),i.height.toDouble()),
          rotation:ImageRotation.rotation270,
          planeData:i.planes
              .map((p)=>FirebaseVisionImagePlaneMetadata(
                    bytesPerRow:p.bytesPerRow,
                    height:p.height,
                    width:p.width
                  ))
              .toList()
        );
        var q=await V(FirebaseVisionImage.fromBytes(b.done().buffer.asUint8List(),v));
        if(mounted)setState((){Q=q;});
      }finally{D=F;}
    });
  }
  build(c)=>Scaffold(
      floatingActionButton:FloatingActionButton(
        onPressed:()async{
          var d=await PD();
          if(C.value.isStreamingImages)await C.stopImageStream();
          await Future.delayed(Duration(seconds:1));
          var p='${d.path}/${d.listSync().length.toString().padLeft(5,'0')}.jpg';
          await C.takePicture(p);
          await FlutterFFmpeg().execute('-y -i $p -vf scale=1280:-2 $p');
          Navigator.of(c).pop();
        },
        child:Icon(Icons.camera)
      ),
      appBar:AppBar(actions:[IconButton(icon:Icon(Icons.switch_camera),onPressed:()async{N++;await C.stopImageStream();await C.dispose();setState((){C=null;});iC();})]),
      body:Container(
          constraints:BoxConstraints.expand(),
          child:C?.value?.isInitialized??F?Stack(
                  fit:StackFit.expand,
                  children:[
                    CameraPreview(C),
                    CustomPaint(painter:FDP(S,O,Colors.red)),
                    CustomPaint(painter:FDP(C.value.previewSize.flipped,Q,Colors.green))
                  ]
                ):Center(child:CircularProgressIndicator())));
}

class HP extends StatefulWidget{createState()=>HPS();}

DD()async{return Directory('${(await getExternalStorageDirectory()).path}/$X').create();}
PD()async{return Directory('${(await DD()).path}/p').create();}
class VP extends StatefulWidget{createState()=>VPS();}
class VPS extends State<VP>{
  var I=true;var v;var vpc;var cc;
  initState(){super.initState();compile();}
  dispose(){vpc?.dispose();cc?.dispose();super.dispose();}
  compile()async{
    v='${(await DD()).path}/v.mp4';
    await FlutterFFmpeg().execute('-y -r 1 -i ${(await PD()).path}/%05d.jpg -c:v libx264 -pix_fmt yuv420p $v');
    setState((){I=F;});
    vpc=VideoPlayerController.file(File(v));
    cc=ChewieController(videoPlayerController:vpc,autoPlay:true,looping:true);
  }
  build(c)=>Scaffold(body:I?Center(child:CircularProgressIndicator()):Center(child:Chewie(controller:cc)),appBar:AppBar(),
      floatingActionButton:I?null:FloatingActionButton(child:Icon(Icons.share),onPressed:()async{ShareExtend.share(v,"video");}));

}
class HPS extends State<HP>{
  var I=[];
  initState(){super.initState();iI();}
  iI()async{
    await PermissionHandler().requestPermissions([PermissionGroup.storage,PermissionGroup.camera,PermissionGroup.microphone]);
    var i=(await PD()).listSync().map((e)=>File(e.path)).toList();
    setState((){I=i;});
  }
  build(c){
    return Scaffold(
      appBar:AppBar(
        title:Text(X),
        actions:[
          IconButton(icon:Icon(Icons.movie_creation),onPressed:()=>Navigator.of(c).push(MaterialPageRoute(builder:(b)=>VP())))
        ]
      ),
      body:ScrollGallery(I.map((s)=>Image.file(s).image).toList().reversed.toList(),fit:BoxFit.cover),
      floatingActionButton:FloatingActionButton(
        onPressed:()=>Navigator.of(c).push(MaterialPageRoute(builder:(b)=>TP())).then((_)=>iI()),
        child:Icon(Icons.add_a_photo)
      )
    );
  }
}
