import'dart:io';import'package:flutter/services.dart';import'package:flutter/foundation.dart';import'package:flutter/material.dart';import'package:share_extend/share_extend.dart';import'package:path_provider/path_provider.dart';import'package:flutter_ffmpeg/flutter_ffmpeg.dart';import'package:permission_handler/permission_handler.dart';import'package:camera/camera.dart';import'package:firebase_ml_vision/firebase_ml_vision.dart';
var F=false;
main(){SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);runApp(A());}
class A extends StatelessWidget{build(c)=>MaterialApp(home:HP());}
class FDP extends CustomPainter{
  FDP(this.S,this.O,this.C);var S;var O;var C;
  paint(ca,sz){
    if(S==null)return;
    var p=Paint()..color=C..style=PaintingStyle.stroke..strokeWidth=5;

    var x=sz.width/S.width;
    var y=sz.height/S.height;

    for(var o in O){
      for(var l in FaceLandmarkType.values){
        var m=o.getLandmark(l);
        if(m!=null)
          ca.drawCircle(Offset((S.width-m.position.dx)*x,m.position.dy*y),10,p);
      }
      var q=S.height*y;
      var r=Rect.fromLTRB(0,q*0.1,S.width*x,q*0.9);
      ca.drawArc(r,1.57,o.headEulerAngleY/57.29,F,p);
      ca.drawArc(r,4.71,o.headEulerAngleZ/57.29,F,p);
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
    C=CameraController(a[N++],ResolutionPreset.medium);
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
          await FlutterFFmpeg().execute('-y -i $p -vf scale=1280:-1 $p');
          Navigator.of(c).pop();
        },
        child:Icon(Icons.camera)
      ),
      appBar:AppBar(actions:[IconButton(icon:Icon(Icons.switch_camera),onPressed:()async{await C.stopImageStream();await C.dispose();setState((){C=null;});iC();})]),
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

DD()async{return Directory('${(await getExternalStorageDirectory()).path}/FaceTimelapse').create();}
PD()async{return Directory('${(await DD()).path}/p').create();}

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
        actions:[
          IconButton(icon:Icon(Icons.movie_creation),
              onPressed:()async{
                await FlutterFFmpeg().execute('-y -r 1 -i ${(await PD()).path}/%05d.jpg -c:v libx264 -t 30 -pix_fmt yuv420p ${(await DD()).path}/v.mp4');
              }),
          IconButton(icon:Icon(Icons.play_arrow),
              onPressed:()async{var f='${(await DD()).path}/v.mp4';}),
          IconButton(icon:Icon(Icons.share),
              onPressed:()async{ShareExtend.share('${(await DD()).path}/v.mp4',"video");})
        ],
      ),
      body:Center(child:GridView.count(crossAxisCount:2,padding:EdgeInsets.all(10),children:I.map((s)=>Image.file(s)).toList())),
      floatingActionButton:FloatingActionButton(
        onPressed:()=>Navigator.of(c).push(MaterialPageRoute(builder:(b)=>TP())).then((_)=>iI()),
        child:Icon(Icons.add_a_photo)
      )
    );
  }
}
