import'dart:io';import'package:flutter/services.dart';import'package:flutter/foundation.dart';import'package:flutter/material.dart';import'package:share_extend/share_extend.dart';import'package:path_provider/path_provider.dart';import'package:flutter_ffmpeg/flutter_ffmpeg.dart';import'package:permission_handler/permission_handler.dart';import'package:camera/camera.dart';import'package:firebase_ml_vision/firebase_ml_vision.dart';import'package:video_player/video_player.dart';import'package:chewie/chewie.dart';import'package:flutter_scroll_gallery/flutter_scroll_gallery.dart';
var F=false,T=true,X='FaceTimelapse',D,P,Z=0,L,H;
B(i,p)=>IconButton(icon:Icon(i),onPressed:p);
main(){SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);runApp(A());}
class A extends StatelessWidget{build(c)=>MaterialApp(home:HP(),title:X,theme:ThemeData.dark());}
class FP extends CustomPainter{
  FP(this.d,this.f,this.c);var d,f,c;
  paint(k,z){
    if(d==null)return;
    var p=Paint()..color=c..style=PaintingStyle.stroke..strokeWidth=5,x=z.width/d.width,y=z.height/d.height;

    for(var i in f){
      for(var l in FaceLandmarkType.values){
        var m=i.getLandmark(l);
        if(m!=null)
          k.drawCircle(Offset((d.width-m.position.dx)*x,m.position.dy*y),10,p);
      }
      var q=d.height*y,r=Rect.fromLTRB(0,q*0.1,d.width*x,q*0.9);
      k.drawArc(r,1.57,i.headEulerAngleY/57.29,F,p);
      k.drawArc(r,4.71,i.headEulerAngleZ/57.29,F,p);
    }
  }
  shouldRepaint(o)=>o!=this;
}

class TP extends StatefulWidget{createState()=>TPS();}
class TPS extends State<TP>{
  var c,d=F,q=[],o=[],s;
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
    c=CameraController(a[Z],ResolutionPreset.medium);
    await c.initialize();
    c.startImageStream((CameraImage i)async{
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
  build(k)=>Scaffold(
      floatingActionButton:FloatingActionButton(
        onPressed:()async{
          await c.stopImageStream();
          var p='$P/${H.toString().padLeft(5,'0')}.jpg';
          await c.takePicture(p);
          await FlutterFFmpeg().execute('-y -i $p -vf scale=1280:-2 $p');
          Navigator.of(k).pop();
        },backgroundColor:Colors.white,
        child:Icon(Icons.camera)
      ),
      appBar:AppBar(actions:[B(Icons.sync,()async{Z++;await c.dispose();setState((){c=null;});iC();})]),
      body:Container(
          constraints:BoxConstraints.expand(),
          child:c?.value?.isInitialized??F?Stack(
                  fit:StackFit.expand,
                  children:[
                    CameraPreview(c),
                    CustomPaint(painter:FP(s,o,Colors.red)),
                    CustomPaint(painter:FP(c.value.previewSize.flipped,q,Colors.green))
                  ]
                ):Center(child:CircularProgressIndicator())));
}

class HP extends StatefulWidget{createState()=>HPS();}
class VP extends StatefulWidget{createState()=>VPS();}
class VPS extends State<VP>{
  var i=T,m='$D/v.mp4',v,w,p=0;
  initState(){super.initState();K();}
  dispose(){v?.dispose();w?.dispose();super.dispose();}
  K()async{
    var f=FlutterFFmpeg(),e=RegExp(r"frame=[ ]{3}(\d+)");
    f.enableLogCallback((_,s)=>setState((){p=int.tryParse(e.firstMatch(s)?.group(1)??'')??p;}));
    await f.execute('-y -i $P/%05d.jpg -vf zoompan=d=2:fps=1,framerate=5:interp_start=0:interp_end=255:scene=100 $m');
    var s=(await f.getMediaInformation(m))['streams'][0];
    v=VideoPlayerController.file(File(m));
    w=ChewieController(videoPlayerController:v,autoPlay:T,looping:T,aspectRatio:s['width']/s['height']);
    setState((){i=F;});
  }
  build(k)=>Scaffold(body:Center(child:i?Text('${(p*10/H).round()}%'):Chewie(controller:w)),appBar:AppBar(actions:i?[]:[B(Icons.share,(){ShareExtend.share(m,"video");})]));
}

class HPS extends State<HP>{
  var i=[];
  initState(){super.initState();iI();}
  iI()async{
    if((await PermissionHandler().requestPermissions([PermissionGroup.storage,PermissionGroup.camera,PermissionGroup.microphone])).values.where((p)=>p==PermissionStatus.granted).length!=3){
      await showDialog(context:context, builder:(b)=>AlertDialog(title:Text('App want theese rights')));
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return;
    }
    D=(await Directory('${(await getExternalStorageDirectory()).path}/$X').create()).path;
    var d=await Directory('$D/p').create();
    i=d.listSync().map((e)=>File(e.path)).toList();
    P=d.path;
    H=i.length;
    if(H>0)L=i.last;
    setState((){});
  }
  M(k,w)=>Navigator.of(k).push(MaterialPageRoute(builder:(_)=>w));
  build(k)=>Scaffold(
      appBar:AppBar(
        title:Text(X),
        actions:[
          B(Icons.movie_creation,()=>M(k,VP())),
          B(Icons.add_a_photo,()=>M(k,TP()).then((_)=>iI()))
        ]
      ),
      body:ScrollGallery(i.map((s)=>Image.file(s).image).toList().reversed.toList(),fit:BoxFit.cover,borderColor:Colors.white)
    );
}
