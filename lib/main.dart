import'dart:io';import'package:flutter/services.dart';import'package:flutter/foundation.dart';import'package:flutter/material.dart';import'package:share_extend/share_extend.dart';import'package:path_provider/path_provider.dart';import'package:flutter_ffmpeg/flutter_ffmpeg.dart';import'package:permission_handler/permission_handler.dart';import'package:camera/camera.dart';import'package:firebase_ml_vision/firebase_ml_vision.dart';import'package:video_player/video_player.dart';import'package:chewie/chewie.dart';import'package:flutter_scroll_gallery/flutter_scroll_gallery.dart';
var F=false,T=true,X='FaceTimelapse',Dd,Pd,Z=0,L,Fc;
B(i,p)=>IconButton(icon:Icon(i),onPressed:p);
CPI()=>Center(child:CircularProgressIndicator());
main(){SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);runApp(A());}
class A extends StatelessWidget{build(c)=>MaterialApp(home:HP(),title:X,theme:ThemeData.dark());}
class FDP extends CustomPainter{
  FDP(this.S,this.O,this.C);var S,O,C;
  paint(c,s){
    if(S==null)return;
    var p=Paint()..color=C..style=PaintingStyle.stroke..strokeWidth=5,x=s.width/S.width,y=s.height/S.height;

    for(var o in O){
      for(var l in FaceLandmarkType.values){
        var m=o.getLandmark(l);
        if(m!=null)
          c.drawCircle(Offset((S.width-m.position.dx)*x,m.position.dy*y),10,p);
      }
      var q=S.height*y,r=Rect.fromLTRB(0,q*0.1,S.width*x,q*0.9);
      c.drawArc(r,1.57,o.headEulerAngleY/57.29,F,p);
      c.drawArc(r,4.71,o.headEulerAngleZ/57.29,F,p);
    }
  }
  shouldRepaint(o)=>o!=this;
}

class TP extends StatefulWidget{createState()=>TPS();}
class TPS extends State<TP>{
  var C,d=F,q=[],o=[],s;
  initState(){super.initState();iC();}
  iO()async{
    if(L==null)return;
    var v=FirebaseVisionImage.fromFilePath(L.path),f=Image.file(File.fromUri(L.uri));
    f.image.resolve(ImageConfiguration()).completer.addListener((i,b)async{
      o=await V(v);
      setState((){
        s=Size(i.image.width.toDouble(),i.image.height.toDouble());
      });
    });
  }

  var V=FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableLandmarks:T,mode:FaceDetectorMode.accurate)).processImage;

  iC()async{
    await iO();
    var a=await availableCameras();
    if(Z==a.length)Z=0;
    C=CameraController(a[Z],ResolutionPreset.medium);
    await C.initialize();
    C.startImageStream((CameraImage i)async{
      if(d)return;
      d=T;
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
        q=await V(FirebaseVisionImage.fromBytes(b.done().buffer.asUint8List(),v));
        if(mounted)setState((){});
      }finally{d=F;}
    });
  }
  build(c)=>Scaffold(
      floatingActionButton:FloatingActionButton(
        onPressed:()async{
          await C.stopImageStream();
          await Future.delayed(Duration(seconds:1));
          var p='$Pd/${Fc.toString().padLeft(5,'0')}.jpg';
          await C.takePicture(p);
          await FlutterFFmpeg().execute('-y -i $p -vf scale=1280:-2 $p');
          Navigator.of(c).pop();
        },backgroundColor:Colors.white,
        child:Icon(Icons.camera)
      ),
      appBar:AppBar(actions:[B(Icons.switch_camera,()async{Z++;await C.dispose();setState((){C=null;});iC();})]),
      body:Container(
          constraints:BoxConstraints.expand(),
          child:C?.value?.isInitialized??F?Stack(
                  fit:StackFit.expand,
                  children:[
                    CameraPreview(C),
                    CustomPaint(painter:FDP(s,o,Colors.red)),
                    CustomPaint(painter:FDP(C.value.previewSize.flipped,q,Colors.green))
                  ]
                ):CPI()));
}

class HP extends StatefulWidget{createState()=>HPS();}
class VP extends StatefulWidget{createState()=>VPS();}
class VPS extends State<VP>{
  var i=T,m='$Dd/v.mp4',v,w;
  initState(){super.initState();K();}
  dispose(){v?.dispose();w?.dispose();super.dispose();}
  K()async{
    var f=FlutterFFmpeg();
    await f.execute('-y -r 1 -i $Pd/%05d.jpg -c:v libx264 $m');
    var g=await f.getMediaInformation(m);
    var s=g['streams'][0];
    setState((){i=F;});
    v=VideoPlayerController.file(File(m));
    w=ChewieController(videoPlayerController:v,autoPlay:T,looping:T,aspectRatio:s['width']/s['height']);
  }
  build(c)=>Scaffold(body:i?CPI():Center(child:Chewie(controller:w)),appBar:AppBar(actions:i?[]:[B(Icons.share,(){ShareExtend.share(m,"video");})]));
}

class HPS extends State<HP>{
  var i=[];
  initState(){super.initState();iI();}
  iI()async{
    if((await PermissionHandler().requestPermissions([PermissionGroup.storage,PermissionGroup.camera,PermissionGroup.microphone])).values.where((p)=>p==PermissionStatus.granted).length!=3){
      await showDialog(context:context, builder:(b)=>AlertDialog(title:Text('App should have requested permissions')));
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return;
    }
    Dd=(await Directory('${(await getExternalStorageDirectory()).path}/$X').create()).path;
    var d=await Directory('$Dd/p').create();
    i=d.listSync().map((e)=>File(e.path)).toList();
    Pd=d.path;
    Fc=i.length;
    if(Fc>0)L=i.last;
    setState((){});
  }
  M(c,w)=>Navigator.of(c).push(MaterialPageRoute(builder:(_)=>w));
  build(c)=>Scaffold(
      appBar:AppBar(
        title:Text(X),
        actions:[
          B(Icons.movie_creation,()=>M(c,VP())),
          B(Icons.add_a_photo,()=>M(c,TP()).then((_)=>iI())),
        ]
      ),
      body:ScrollGallery(i.map((s)=>Image.file(s).image).toList().reversed.toList(),fit:BoxFit.cover,borderColor:Colors.white)
    );
}
