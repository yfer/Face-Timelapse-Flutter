import'dart:io';import'package:flutter/services.dart';import'package:flutter/foundation.dart';import'package:flutter/material.dart';import'package:share_extend/share_extend.dart';import'package:path_provider/path_provider.dart';import'package:flutter_ffmpeg/flutter_ffmpeg.dart';import'package:permission_handler/permission_handler.dart';import'package:camera/camera.dart';import'package:firebase_ml_vision/firebase_ml_vision.dart';import'package:video_player/video_player.dart';import'package:chewie/chewie.dart';import'package:flutter_scroll_gallery/flutter_scroll_gallery.dart';
var F=false,T=true,N,X='FaceTimelapse',D,P,Y=0,L,J=0,G=PermissionGroup.values,E=Colors.white,O='Selfie',R=Icons.camera;
B(i,p)=>IconButton(icon:Icon(i),onPressed:p);
U(p)=>FloatingActionButton.extended(icon:Icon(R),backgroundColor:E,onPressed:p,label:Text(O));
S(t,b,[List<Widget> a,u])=>Scaffold(appBar:AppBar(title:Text(t),actions:a),body:b,floatingActionButton:u);
Z(i)=>Size(i.width*1.0,i.height*1.0);
main(){SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);runApp(A());}
class A extends StatelessWidget{build(c)=>MaterialApp(home:HP(),title:X,theme:ThemeData.dark());}
class FP extends CustomPainter{
  FP(this.d,this.f,this.c,this.I);var d,f,c,I;
  paint(k,z){
    if(d!=N){
      var p=Paint()..color=c..style=PaintingStyle.stroke..strokeWidth=5,h=d.height,w=d.width,x=z.width/w,y=z.height/h;
      for(var i in f){
        for(var l in FaceLandmarkType.values){
          var m=i.getLandmark(l),u=m?.position?.dx;
          if(m!=N)
            k.drawCircle(Offset((I>0?u:w-u)*x,m.position.dy*y),10,p);
        }
        var q=h*y,r=Rect.fromLTRB(0,q*0.1,w*x,q*0.9);
        a(z,x)=>k.drawArc(r,z,(I>0?-x:x)/57,F,p);
        a(1.57,i.headEulerAngleY);
        a(4.71,i.headEulerAngleZ);
      }
    }
  }
  shouldRepaint(o)=>o!=this;
}

class TP extends StatefulWidget{createState()=>TPS();}
class TPS extends State<TP>{
  var c,d=F,q=[],o=[],s,l,V=FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableLandmarks:T,mode:FaceDetectorMode.accurate)).processImage;
  initState(){super.initState();iC();}
  iO()async{
    if(L!=N){
      var v=FirebaseVisionImage.fromFilePath(L.path),f=Image.file(File.fromUri(L.uri));
      f.image.resolve(ImageConfiguration()).completer.addListener((i,b)async{
        o=await V(v);
        setState((){
          s=Z(i.image);
        });
      });
    }
  }

  iC()async{
    await iO();
    var a=(await availableCameras()).reversed.toList();
    if(Y==a.length)Y=0;
    l=a[Y].lensDirection.index;
    c=CameraController(a[Y],ResolutionPreset.low);
    await c.initialize();
    c.startImageStream((CameraImage i)async{
      if(!d){
        d=T;
        try{
          var b=WriteBuffer();
          i.planes.forEach((p)=>b.putUint8List(p.bytes));
          q=await V(FirebaseVisionImage.fromBytes(b.done().buffer.asUint8List(),FirebaseVisionImageMetadata(
              rawFormat:i.format.raw,
              size:Z(i),
              rotation:ImageRotation.values[(a[Y].sensorOrientation/90).round()],
              planeData:i.planes
                  .map((p)=>FirebaseVisionImagePlaneMetadata(
                  bytesPerRow:p.bytesPerRow,
                  height:p.height,
                  width:p.width
              )).toList()
          )));
          if(mounted)setState((){});
        }finally{d=F;}
      }
    });
  }
  p(f)=>CustomPaint(painter:f);
  build(k)=>S(
      O,
      Container(
        constraints:BoxConstraints.expand(),
        child:c?.value?.isInitialized??F?Stack(
            fit:StackFit.expand,
            children:[
              CameraPreview(c),
              p(FP(s,o,Colors.red,1)),
              p(FP(c.value.previewSize.flipped,q,Colors.green,l))
            ]
        ):N),
      [B(Icons.sync,()async{Y++;await c.dispose();setState((){c=N;});iC();})],
      U(()async{
        await c.stopImageStream();
        var p='$P/${'$J'.padLeft(5,'0')}.jpg';
        await c.takePicture(p);
        await FlutterFFmpeg().execute('-y -i $p -vf ${l>0?'':'hflip,'}scale=1280:-2 $p');
        Navigator.of(k).pop();
      })
  );
}
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
    w=ChewieController(videoPlayerController:v,autoPlay:T,looping:T,aspectRatio:s['height']/s['width']);
    setState((){i=F;});
  }
  build(k)=>S(
    'Movie',
    Center(child:i?Text('${(p*10/J).round()}%'):Chewie(controller:w)),
    i?[]:[B(Icons.share,()=>ShareExtend.share(m,"video"))]
  );
}
class HP extends StatefulWidget{createState()=>HPS();}
class HPS extends State<HP>{
  var i=[];
  initState(){super.initState();iI();}
  iI()async{
    if((await PermissionHandler().requestPermissions([G[2],G[5],G[11]])).values.where((p)=>p.index==2).length!=3){
      await showDialog(context:context,builder:(b)=>AlertDialog(title:Text('Need rights!')));
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return;
    }
    D=(await Directory('${(await getExternalStorageDirectory()).path}/$X').create()).path;
    var d=await Directory('$D/p').create();
    i=d.listSync().map((e)=>File(e.path)).toList();
    P=d.path;
    J=i.length;
    if(J>0)L=i.last;
    setState((){});
  }
  n(k,w)=>Navigator.of(k).push(MaterialPageRoute(builder:(_)=>w));
  t(k)=>()=>n(k,TP()).then((_)=>iI());
  build(k)=>S(
    X,
    ScrollGallery(i.map((s)=>Image.file(s).image).toList().reversed.toList(),fit:BoxFit.cover,borderColor:E),
    J>0?[B(Icons.movie,()=>n(k,VP()))]:[]..add(B(R,t(k))),
    J>0?N:U(t(k))
  );
}
