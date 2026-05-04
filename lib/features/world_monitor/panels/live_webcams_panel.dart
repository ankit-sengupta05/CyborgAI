// lib/panels/live_webcams_panel.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';
import '../wm_theme.dart';
import '../widgets/floating_panel.dart';
import '../services/dashboard_provider.dart';

class LiveWebcamsPanel extends StatefulWidget {
  const LiveWebcamsPanel({super.key});
  @override State<LiveWebcamsPanel> createState() => _LiveWebcamsPanelState();
}

class _LiveWebcamsPanelState extends State<LiveWebcamsPanel> {
  static const _cats = ['IRAN ATTACKS','ALL','MIDEAST','EUROPE','AMERICAS','ASIA','SPACE'];
  static const _cams = {
    'IRAN ATTACKS': [
      {'city':'TEHRAN','country':'IR','vid':'qkBFPMfHyJA','color':0xFF8B1A1A},
      {'city':'TEL AVIV','country':'IL','vid':'6y1JKS3A4s8','color':0xFF1A3A8B},
      {'city':'HAIFA','country':'IL','vid':'7XXHJ1CFDHE','color':0xFF1A4A7B},
      {'city':'MIDDLE EAST','country':'MID','vid':'F57BKKSQpME','color':0xFF5A3A1A},
      {'city':'BEIRUT','country':'LB','vid':'xMMCvHt0LCI','color':0xFF3A1A1A},
      {'city':'JERUSALEM','country':'IL','vid':'7XXHJ1CFDHE','color':0xFF2A4A2A},
    ],
    'ALL': [
      {'city':'JERUSALEM','country':'IL','vid':'7XXHJ1CFDHE','color':0xFF2A4A2A},
      {'city':'TEHRAN','country':'IR','vid':'qkBFPMfHyJA','color':0xFF8B1A1A},
      {'city':'KYIV','country':'UA','vid':'6y1JKS3A4s8','color':0xFF1A5A8B},
      {'city':'WASHINGTON DC','country':'US','vid':'sBdchIrpQ1Y','color':0xFF1A2A5A},
      {'city':'MOSCOW','country':'RU','vid':'mGnFABax00A','color':0xFF5A1A1A},
      {'city':'BEIJING','country':'CN','vid':'F57BKKSQpME','color':0xFF5A1A2A},
    ],
    'MIDEAST': [
      {'city':'JERUSALEM','country':'IL','vid':'7XXHJ1CFDHE','color':0xFF2A4A2A},
      {'city':'DUBAI','country':'AE','vid':'F57BKKSQpME','color':0xFF4A3A1A},
      {'city':'BEIRUT','country':'LB','vid':'xMMCvHt0LCI','color':0xFF3A1A1A},
      {'city':'CAIRO','country':'EG','vid':'h3MuIUNCCLI','color':0xFF5A4A1A},
    ],
    'EUROPE': [
      {'city':'LONDON','country':'GB','vid':'9Auq9mYxFEE','color':0xFF1A2A4A},
      {'city':'PARIS','country':'FR','vid':'8qoLBHqLMRQ','color':0xFF1A3A3A},
      {'city':'BERLIN','country':'DE','vid':'mGnFABax00A','color':0xFF2A2A2A},
      {'city':'KYIV','country':'UA','vid':'6y1JKS3A4s8','color':0xFF1A5A8B},
    ],
    'AMERICAS': [
      {'city':'NEW YORK','country':'US','vid':'sBdchIrpQ1Y','color':0xFF1A2A5A},
      {'city':'WASHINGTON DC','country':'US','vid':'F57BKKSQpME','color':0xFF1A1A4A},
      {'city':'SAO PAULO','country':'BR','vid':'dp8PhLsUcFE','color':0xFF1A4A2A},
      {'city':'MEXICO CITY','country':'MX','vid':'xMMCvHt0LCI','color':0xFF3A3A1A},
    ],
    'ASIA': [
      {'city':'TOKYO','country':'JP','vid':'qkBFPMfHyJA','color':0xFF3A1A3A},
      {'city':'SINGAPORE','country':'SG','vid':'8qoLBHqLMRQ','color':0xFF1A3A2A},
      {'city':'BEIJING','country':'CN','vid':'F57BKKSQpME','color':0xFF5A1A1A},
      {'city':'MUMBAI','country':'IN','vid':'mGnFABax00A','color':0xFF4A3A1A},
    ],
    'SPACE': [
      {'city':'ISS LIVE','country':'ISS','vid':'21X5lGlDOfg','color':0xFF0A1A3A},
      {'city':'EARTH VIEW','country':'NASA','vid':'86YLFOog4GM','color':0xFF0A2A4A},
      {'city':'STARLINK','country':'SX','vid':'9Auq9mYxFEE','color':0xFF0A0A2A},
      {'city':'LAUNCH PAD','country':'KSC','vid':'dp8PhLsUcFE','color':0xFF1A1A1A},
    ],
  };

  String _category = 'IRAN ATTACKS';
  int? _expandedIdx;
  WebviewController? _wvCtrl;
  bool _wvReady = false;

  List<Map<String,dynamic>> get _cams2 =>
      List<Map<String,dynamic>>.from(_cams[_category] ?? []);

  // Load YouTube watch page directly in WebView2
  String _ytUrl(String vid) => 'https://www.youtube.com/watch?v=$vid';

  Future<void> _loadExpanded(String vid) async {
    _wvCtrl?.dispose();
    _wvCtrl = WebviewController();
    _wvReady = false;
    try {
      await _wvCtrl!.initialize();
      await _wvCtrl!.setBackgroundColor(Colors.black);
      await _wvCtrl!.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _wvCtrl!.loadUrl(_ytUrl(vid));
      if (mounted) setState(() => _wvReady = true);
    } catch (_) {
      if (mounted) setState(() => _wvReady = false);
    }
  }

  void _expand(int idx) {
    setState(() { _expandedIdx = idx; _wvReady = false; });
    _loadExpanded(_cams2[idx]['vid'] as String);
  }

  void _collapse() {
    _wvCtrl?.dispose(); _wvCtrl = null;
    setState(() { _expandedIdx = null; _wvReady = false; });
  }

  void _switchCat(String cat) { _collapse(); setState(() => _category = cat); }

  Future<void> _openBrowser(String vid) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$vid');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override void dispose() { _wvCtrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GridPanel(
    title: 'LIVE WEBCAMS', isLive: true, count: 27, countColor: WMColors.accentGreen,
    onClose: () => context.read<DashboardProvider>().togglePanel(PanelId.liveWebcams),
    headerActions: [
      Container(padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(border: Border.all(color: WMColors.border), borderRadius: BorderRadius.circular(2)),
        child: const Icon(Icons.help_outline, color: WMColors.textMuted, size: 9)),
      const SizedBox(width: 6),
      const Icon(Icons.fullscreen, color: WMColors.textMuted, size: 13),
    ],
    child: Column(children: [
      _CatBar(cats: _cats, current: _category, onSelect: _switchCat),
      Expanded(child: _expandedIdx != null ? _buildExpanded() : _buildGrid()),
    ]),
  );

  Widget _buildGrid() {
    final cams = _cams2;
    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 3, mainAxisSpacing: 3),
      itemCount: cams.length,
      itemBuilder: (_, i) {
        final cam = cams[i];
        final color = Color(cam['color'] as int);
        return GestureDetector(
          onTap: () => _expand(i),
          onDoubleTap: () => _openBrowser(cam['vid'] as String),
          child: Stack(children: [
            _AnimCam(city: cam['city'] as String, color: color),
            Positioned(top:4,left:4,child:Container(
              padding: const EdgeInsets.symmetric(horizontal:5,vertical:2),
              color: Colors.black.withOpacity(0.72),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _Dot(), const SizedBox(width:4),
                Text(cam['city'] as String, style: const TextStyle(color:Colors.white,fontSize:7,fontWeight:FontWeight.bold)),
              ]))),
            Positioned(top:4,right:4,child:Container(padding:const EdgeInsets.all(2),color:Colors.black.withOpacity(0.6),
              child:const Icon(Icons.fullscreen,color:Colors.white,size:10))),
            Positioned(bottom:3,left:4,child:Text(cam['country'] as String,style:const TextStyle(color:WMColors.textSecond,fontSize:6))),
            Positioned(bottom:3,right:4,child:const Text('● LIVE',style:TextStyle(color:WMColors.accentRed,fontSize:6,fontWeight:FontWeight.bold))),
          ]),
        );
      },
    );
  }

  Widget _buildExpanded() {
    final cams = _cams2;
    final idx = _expandedIdx!.clamp(0, cams.length-1);
    final cam = cams[idx];
    final color = Color(cam['color'] as int);
    return Column(children: [
      Expanded(child: Stack(children: [
        _wvReady && _wvCtrl != null
          ? Webview(_wvCtrl!)
          : _AnimCam(city: cam['city'] as String, color: color),
        Positioned(top:8,left:8,child:Row(children:[
          _Dot(), const SizedBox(width:5),
          Text(cam['city'] as String,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold,shadows:[Shadow(color:Colors.black,blurRadius:4)])),
        ])),
        Positioned(top:8,right:48,child:GestureDetector(
          onTap: () => _openBrowser(cam['vid'] as String),
          child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),color:Colors.black.withOpacity(0.7),
            child:const Row(children:[Icon(Icons.open_in_new,color:Colors.white,size:12),SizedBox(width:4),
              Text('Open Live',style:TextStyle(color:Colors.white,fontSize:9))])))),
        Positioned(top:8,right:8,child:GestureDetector(onTap:_collapse,
          child:Container(padding:const EdgeInsets.all(5),color:Colors.black.withOpacity(0.7),
            child:const Icon(Icons.close,color:Colors.white,size:14)))),
      ])),
      SizedBox(height:56,child:ListView.builder(
        scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(3),itemCount:cams.length,
        itemBuilder:(_,i){
          final c=cams[i]; final sel=i==idx;
          return GestureDetector(onTap:()=>_expand(i),child:Container(width:84,margin:const EdgeInsets.only(right:3),
            decoration:BoxDecoration(border:Border.all(color:sel?WMColors.accentGreen:WMColors.border,width:sel?2:1)),
            child:Stack(children:[
              _AnimCam(city:c['city'] as String,color:Color(c['color'] as int)),
              Positioned(bottom:2,left:3,child:Text(c['city'] as String,
                style:const TextStyle(color:Colors.white,fontSize:6,fontWeight:FontWeight.bold,shadows:[Shadow(color:Colors.black,blurRadius:4)]))),
            ])));
        },
      )),
    ]);
  }
}

class _CatBar extends StatelessWidget {
  final List<String> cats; final String current; final Function(String) onSelect;
  const _CatBar({required this.cats,required this.current,required this.onSelect});
  @override
  Widget build(BuildContext ctx)=>Container(
    height:34,decoration:BoxDecoration(border:Border(bottom:BorderSide(color:WMColors.border))),
    child:SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:6,vertical:5),
      child:Row(children:[
        GestureDetector(onTap:()=>onSelect('IRAN ATTACKS'),child:Container(
          padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
          color:current=='IRAN ATTACKS'?WMColors.accentRed:WMColors.accentRed.withOpacity(0.25),
          child:const Text('IRAN ATTACKS',style:TextStyle(color:Colors.white,fontSize:8,fontWeight:FontWeight.bold)))),
        const SizedBox(width:4),
        ...cats.skip(1).map((c)=>Padding(padding:const EdgeInsets.only(right:4),
          child:GestureDetector(onTap:()=>onSelect(c),child:Container(
            padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
            decoration:BoxDecoration(
              color:current==c?WMColors.accentGreen.withOpacity(0.15):Colors.transparent,
              border:Border.all(color:current==c?WMColors.accentGreen:WMColors.borderLight),
              borderRadius:BorderRadius.circular(1)),
            child:Text(c,style:TextStyle(color:current==c?WMColors.accentGreen:WMColors.textSecond,fontSize:8,fontWeight:FontWeight.bold)))))),
        const SizedBox(width:8),
        const Icon(Icons.grid_view,color:WMColors.accentGreen,size:14),
      ])));
}

class _Dot extends StatefulWidget {
  @override State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState(){super.initState();_c=AnimationController(duration:const Duration(seconds:1),vsync:this)..repeat(reverse:true);}
  @override void dispose(){_c.dispose();super.dispose();}
  @override Widget build(BuildContext ctx)=>AnimatedBuilder(animation:_c,builder:(_,__)=>Container(
    width:5,height:5,decoration:BoxDecoration(color:WMColors.accentRed.withOpacity(0.4+0.6*_c.value),shape:BoxShape.circle)));
}

class _AnimCam extends StatefulWidget {
  final String city; final Color color;
  const _AnimCam({required this.city,required this.color});
  @override State<_AnimCam> createState() => _AnimCamState();
}
class _AnimCamState extends State<_AnimCam> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState(){super.initState();_c=AnimationController(duration:const Duration(seconds:4),vsync:this)..repeat();}
  @override void dispose(){_c.dispose();super.dispose();}
  @override Widget build(BuildContext ctx)=>AnimatedBuilder(animation:_c,
    builder:(_,__)=>CustomPaint(painter:_CP(color:widget.color,t:_c.value,city:widget.city),child:const SizedBox.expand()));
}

class _CP extends CustomPainter {
  final Color color;final double t;final String city;
  final Random _r;
  _CP({required this.color,required this.t,required this.city}):_r=Random(city.hashCode);
  @override
  void paint(Canvas canvas,Size size){
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height),Paint()..shader=LinearGradient(
      begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[color.withOpacity(0.35),Colors.black.withOpacity(0.9)]).createShader(Rect.fromLTWH(0,0,size.width,size.height)));
    final bp=Paint()..color=color.withOpacity(0.22);
    final wp=Paint()..color=color.withOpacity(0.5+0.25*sin(t*pi*2));
    final cnt=(size.width/10).floor();
    for(int i=0;i<cnt;i++){
      final seed=_r.nextInt(999);
      final x=i*(size.width/cnt);final w=7.0+seed%5;final h=15.0+seed%35;
      canvas.drawRect(Rect.fromLTWH(x+1,size.height-h-8,w,h),bp);
      for(double wy=size.height-h-4;wy<size.height-10;wy+=5)
        for(double wx=x+3;wx<x+w-1;wx+=4)
          if((seed+wy.toInt()+wx.toInt())%4!=0) canvas.drawRect(Rect.fromLTWH(wx,wy,2,2),wp);
    }
    final sp=Paint()..color=Colors.black.withOpacity(0.1)..strokeWidth=0.5;
    for(double y=0;y<size.height;y+=2.5) canvas.drawLine(Offset(0,y),Offset(size.width,y),sp);
    final sx=size.width*t;
    canvas.drawRect(Rect.fromLTWH(sx-30,0,60,size.height),Paint()..shader=LinearGradient(
      colors:[Colors.transparent,color.withOpacity(0.06),Colors.transparent]).createShader(Rect.fromLTWH(sx-30,0,60,size.height)));
  }
  @override bool shouldRepaint(_CP o)=>o.t!=t;
}
