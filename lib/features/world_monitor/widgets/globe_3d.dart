// lib/widgets/globe_3d.dart
// Canvas-painted 3D rotating globe with country dots and arcs
import 'dart:math';
import 'package:flutter/material.dart';
import '../wm_theme.dart';

class Globe3D extends StatefulWidget {
  final MapVariant variant;
  const Globe3D({super.key, required this.variant});
  @override State<Globe3D> createState() => _Globe3DState();
}

class _Globe3DState extends State<Globe3D> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _rotY = 0.2; // auto-rotate angle
  double _rotX = -0.2;
  Offset? _dragStart;
  double _dragStartRotY = 0;
  double _dragStartRotX = 0;

  // Known locations [lat_rad, lng_rad, label, color_int, size]
  static final _hotspots = [
    [0.56, 0.91, 'TEHRAN', 0xFFcc2222, 8.0],       // Iran 32°N 51°E
    [0.54, 0.60, 'KYIV', 0xFFcc2222, 7.0],          // Ukraine 31°N 30°E
    [0.26, 0.53, 'CAIRO', 0xFFff8800, 5.0],         // Egypt
    [0.15, 0.67, 'KHARTOUM', 0xFFcc2222, 6.0],      // Sudan
    [-0.07, 0.40, 'NAIROBI', 0xFFffcc00, 4.0],      // Kenya
    [0.55, 2.32, 'BEIJING', 0xFFff8800, 5.0],        // China
    [0.63, 2.43, 'PYONGYANG', 0xFFcc2222, 5.0],     // N Korea
    [0.37, -1.30, 'NEW YORK', 0xFF4488ff, 5.0],      // US
    [0.89, -1.34, 'LONDON', 0xFF4488ff, 5.0],        // UK
    [0.56, 2.23, 'SHANGHAI', 0xFFff8800, 4.0],       // China East
    [0.35, 1.36, 'MUMBAI', 0xFFffcc00, 4.0],         // India
    [0.02, 1.81, 'SINGAPORE', 0xFF00ff88, 4.0],      // Singapore
    [0.62, 2.43, 'SEOUL', 0xFF4488ff, 4.0],          // Korea
    [0.63, 2.43, 'TOKYO', 0xFF4488ff, 5.0],          // Japan
    [-0.40, -0.81, 'SAO PAULO', 0xFF00ff88, 4.0],   // Brazil
    [0.10, -1.22, 'BOGOTA', 0xFFffcc00, 4.0],       // Colombia
    [0.55, 0.48, 'WARSAW', 0xFF4488ff, 3.0],        // Poland
    [0.66, 0.23, 'OSLO', 0xFF4488ff, 3.0],          // Norway
    [0.22, 0.78, 'RIYADH', 0xFFff8800, 5.0],        // Saudi Arabia
    [0.30, 0.77, "SANA'A", 0xFFcc2222, 5.0],        // Yemen
    [0.37, 0.74, 'BAGHDAD', 0xFFcc2222, 5.0],       // Iraq
    [0.55, 0.87, 'KABUL', 0xFFcc2222, 5.0],         // Afghanistan
  ].map((h) => _Hotspot(
    latR: (h[0] as num).toDouble(),
    lngR: (h[1] as num).toDouble(),
    label: h[2] as String,
    color: Color(h[3] as int),
    size: (h[4] as num).toDouble(),
  )).toList();

  // Arc paths [lat1, lng1, lat2, lng2, color]
  static final _arcs = [
    [0.56, 0.91, 0.54, 0.60, WMColors.highAlert],   // Iran → Ukraine
    [0.56, 0.91, 0.30, 0.60, WMColors.accentOrange], // Iran → Israel
    [0.37, -1.30, 0.89, -0.00, WMColors.accentBlue], // NY → London
    [0.89, -0.00, 0.55, 2.32, WMColors.techCyan],    // London → Beijing
    [0.37, -1.30, 0.35, 1.36, WMColors.financeGreen],// NY → Mumbai
    [0.55, 2.32, 0.02, 1.81, WMColors.techCyan],     // Beijing → Singapore
    [-0.40, -0.81, 0.89, -0.00, WMColors.accentGreen], // Sao Paulo → London
    [0.63, 2.43, 0.37, -1.30, WMColors.accentPurple], // Tokyo → NY
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 60), vsync: this)..repeat();
    _ctrl.addListener(() => setState(() => _rotY = _ctrl.value * 2 * pi));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        _dragStart = d.globalPosition;
        _dragStartRotY = _rotY;
        _dragStartRotX = _rotX;
        _ctrl.stop();
      },
      onPanUpdate: (d) {
        if (_dragStart == null) return;
        final dx = d.globalPosition.dx - _dragStart!.dx;
        final dy = d.globalPosition.dy - _dragStart!.dy;
        setState(() {
          _rotY = _dragStartRotY + dx * 0.005;
          _rotX = (_dragStartRotX + dy * 0.005).clamp(-1.0, 1.0);
        });
      },
      onPanEnd: (_) {
        _dragStart = null;
        _ctrl.repeat(); // resume auto-rotate
      },
      child: CustomPaint(
        painter: _GlobePainter(
          rotY: _rotY, rotX: _rotX,
          hotspots: _hotspots,
          arcs: _arcs,
          animT: _ctrl.value,
          variant: widget.variant,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Hotspot {
  final double latR, lngR, size;
  final String label;
  final Color color;
  const _Hotspot({required this.latR, required this.lngR, required this.label, required this.color, required this.size});
}

class _GlobePainter extends CustomPainter {
  final double rotY, rotX, animT;
  final List<_Hotspot> hotspots;
  final List<List<dynamic>> arcs;
  final MapVariant variant;

  _GlobePainter({required this.rotY, required this.rotX, required this.hotspots,
    required this.arcs, required this.animT, required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = min(size.width, size.height) * 0.46;

    // ── Globe sphere ────────────────────────────────────────────────────────
    // Background glow
    canvas.drawCircle(Offset(cx, cy), r + 8,
      Paint()..color = _accentColor.withOpacity(0.06)
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Ocean
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFF0d1f3c),
        const Color(0xFF070f1e),
      ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Atmosphere rim glow
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()..style = PaintingStyle.stroke
             ..strokeWidth = 3
             ..color = _accentColor.withOpacity(0.25)
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // ── Lat/lng grid ────────────────────────────────────────────────────────
    _drawGrid(canvas, cx, cy, r);

    // ── Continent silhouettes (simplified painted shapes) ───────────────────
    _drawContinents(canvas, cx, cy, r);

    // ── Animated arcs ───────────────────────────────────────────────────────
    for (int i = 0; i < arcs.length; i++) {
      _drawArc(canvas, cx, cy, r, arcs[i], i);
    }

    // ── Hotspot dots ────────────────────────────────────────────────────────
    for (final h in hotspots) {
      _drawHotspot(canvas, cx, cy, r, h);
    }

    // ── Beta badge ──────────────────────────────────────────────────────────
    final tp = TextPainter(
      text: TextSpan(text: 'BETA', style: TextStyle(
        color: _accentColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx - 50, cy - r - 24));
  }

  Color get _accentColor => switch (variant) {
    MapVariant.tech     => WMColors.techCyan,
    MapVariant.finance  => WMColors.financeGreen,
    MapVariant.commodity=> WMColors.commodityOrange,
    MapVariant.energy   => WMColors.energyPurple,
    MapVariant.goodNews => WMColors.goodNewsGreen,
    _                   => WMColors.accentGreen,
  };

  void _drawGrid(Canvas canvas, double cx, double cy, double r) {
    final p = Paint()..color = _accentColor.withOpacity(0.08)..strokeWidth = 0.6..style = PaintingStyle.stroke;
    // Latitude lines
    for (int lat = -75; lat <= 75; lat += 30) {
      final latR = lat * pi / 180;
      final pts = <Offset>[];
      for (int lng = -180; lng <= 180; lng += 3) {
        final pt = _project(latR, lng * pi / 180, cx, cy, r);
        if (pt != null) pts.add(pt);
      }
      if (pts.length > 2) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final pt in pts.skip(1)) path.lineTo(pt.dx, pt.dy);
        canvas.drawPath(path, p);
      }
    }
    // Longitude lines
    for (int lng = -180; lng < 180; lng += 30) {
      final lngR = lng * pi / 180;
      final pts = <Offset>[];
      for (int lat = -90; lat <= 90; lat += 3) {
        final pt = _project(lat * pi / 180, lngR, cx, cy, r);
        if (pt != null) pts.add(pt);
      }
      if (pts.length > 2) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final pt in pts.skip(1)) path.lineTo(pt.dx, pt.dy);
        canvas.drawPath(path, p);
      }
    }
  }

  void _drawContinents(Canvas canvas, double cx, double cy, double r) {
    final landColor = _accentColor.withOpacity(0.12);
    final landBorder = _accentColor.withOpacity(0.25);
    // Draw major continents as filled latitude-longitude polygons
    _fillContinent(canvas, cx, cy, r, _europeAsia, landColor, landBorder);
    _fillContinent(canvas, cx, cy, r, _africa, landColor, landBorder);
    _fillContinent(canvas, cx, cy, r, _northAmerica, landColor, landBorder);
    _fillContinent(canvas, cx, cy, r, _southAmerica, landColor, landBorder);
    _fillContinent(canvas, cx, cy, r, _australia, landColor, landBorder);
    // Conflict zones in red
    _fillContinent(canvas, cx, cy, r, _conflictMiddleEast,
      WMColors.highAlert.withOpacity(0.22), WMColors.highAlert.withOpacity(0.5));
    _fillContinent(canvas, cx, cy, r, _conflictUkraine,
      WMColors.highAlert.withOpacity(0.28), WMColors.highAlert.withOpacity(0.6));
    _fillContinent(canvas, cx, cy, r, _conflictSudan,
      WMColors.accentOrange.withOpacity(0.22), WMColors.accentOrange.withOpacity(0.5));
  }

  void _fillContinent(Canvas canvas, double cx, double cy, double r,
      List<List<double>> coords, Color fill, Color border) {
    final pts = coords.map((c) => _project(c[1] * pi/180, c[0] * pi/180, cx, cy, r))
        .whereType<Offset>().toList();
    if (pts.length < 3) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) path.lineTo(p.dx, p.dy);
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 0.8);
  }

  void _drawArc(Canvas canvas, double cx, double cy, double r, List<dynamic> arc, int idx) {
    final lat1 = arc[0] as double; final lng1 = arc[1] as double;
    final lat2 = arc[2] as double; final lng2 = arc[3] as double;
    final color = arc[4] as Color;

    // Animated segment traveling along the arc
    final offset = (animT + idx * 0.12) % 1.0;
    final segLen = 0.4;

    final path = Path();
    final fadePath = Path();
    bool fadeMoved = false, segMoved = false;

    for (int i = 0; i <= 60; i++) {
      final t = i / 60;
      // Great circle interpolation with parabolic height
      final lat = lat1 + (lat2 - lat1) * t;
      final lng = lng1 + (lng2 - lng1) * t;
      final heightBoost = sin(t * pi) * 0.08; // arc above surface

      final nx = cos(lat + heightBoost) * sin(lng);
      final ny = sin(lat + heightBoost);
      final nz = cos(lat + heightBoost) * cos(lng);

      // Apply rotation
      final rx = _applyRotX(nx, ny, nz);
      final ry = _applyRotY(nx, ny, nz);
      final rz = _applyRotZ(nx, ny, nz);

      if (rz < 0) continue; // behind globe

      final px = cx + rx * r;
      final py = cy - ry * r;

      // Full faint arc
      if (!fadeMoved) { fadePath.moveTo(px, py); fadeMoved = true; }
      else fadePath.lineTo(px, py);

      // Moving segment
      final inSeg = t >= offset && t <= offset + segLen;
      if (inSeg) {
        if (!segMoved) { path.moveTo(px, py); segMoved = true; }
        else path.lineTo(px, py);
      }
    }

    canvas.drawPath(fadePath, Paint()..color = color.withOpacity(0.18)..style = PaintingStyle.stroke..strokeWidth = 0.7..strokeCap = StrokeCap.round);
    if (segMoved) {
      canvas.drawPath(path, Paint()..color = color.withOpacity(0.85)..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round);
    }
  }

  void _drawHotspot(Canvas canvas, double cx, double cy, double r, _Hotspot h) {
    final nx = cos(h.latR) * sin(h.lngR);
    final ny = sin(h.latR);
    final nz = cos(h.latR) * cos(h.lngR);
    final rx = _applyRotX(nx, ny, nz);
    final ry = _applyRotY(nx, ny, nz);
    final rz = _applyRotZ(nx, ny, nz);
    if (rz < 0.05) return; // behind or on edge

    final px = cx + rx * r;
    final py = cy - ry * r;
    final sz = h.size * (0.5 + 0.5 * rz);

    // Glow
    canvas.drawCircle(Offset(px, py), sz + 3,
      Paint()..color = h.color.withOpacity(0.15 * rz)
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Dot
    canvas.drawCircle(Offset(px, py), sz * 0.6,
      Paint()..color = h.color.withOpacity(0.7 + 0.3 * animT));
  }

  // Rotation helpers using rotY and rotX
  double _applyRotX(double nx, double ny, double nz) =>
      nx * cos(rotY) + nz * sin(rotY);
  double _applyRotY(double nx, double ny, double nz) =>
      ny * cos(rotX) + (-nx * sin(rotY) + nz * cos(rotY)) * sin(rotX);
  double _applyRotZ(double nx, double ny, double nz) =>
      -ny * sin(rotX) + (-nx * sin(rotY) + nz * cos(rotY)) * cos(rotX);

  Offset? _project(double latR, double lngR, double cx, double cy, double r) {
    final adjLng = lngR + rotY;
    final nx = cos(latR) * sin(adjLng);
    final ny = sin(latR) * cos(rotX) + cos(latR) * cos(adjLng) * sin(rotX);
    final nz = -sin(latR) * sin(rotX) + cos(latR) * cos(adjLng) * cos(rotX);
    if (nz < 0) return null;
    return Offset(cx + nx * r, cy - ny * r);
  }

  @override bool shouldRepaint(_GlobePainter o) =>
      o.rotY != rotY || o.rotX != rotX || o.animT != animT;

  // ── Continent outlines [lng, lat] ──────────────────────────────────────────
  static const _europeAsia = [
    [-10.0,35.0],[30.0,35.0],[30.0,42.0],[45.0,42.0],[60.0,38.0],[75.0,35.0],
    [90.0,30.0],[110.0,22.0],[130.0,35.0],[140.0,45.0],[141.0,55.0],[130.0,65.0],
    [105.0,70.0],[75.0,72.0],[50.0,70.0],[30.0,68.0],[10.0,62.0],[-5.0,55.0],[-10.0,35.0],
  ];
  static const _africa = [
    [-18.0,15.0],[5.0,37.0],[25.0,37.0],[42.0,12.0],[52.0,12.0],[50.0,0.0],
    [40.0,-10.0],[32.0,-25.0],[18.0,-35.0],[14.0,-35.0],[10.0,-25.0],
    [8.0,4.0],[0.0,8.0],[-5.0,5.0],[-18.0,15.0],
  ];
  static const _northAmerica = [
    [-168.0,60.0],[-140.0,60.0],[-120.0,49.0],[-95.0,49.0],[-67.0,47.0],
    [-67.0,44.0],[-74.0,40.0],[-80.0,32.0],[-90.0,28.0],[-97.0,28.0],
    [-110.0,28.0],[-117.0,32.0],[-120.0,35.0],[-125.0,48.0],[-130.0,54.0],[-168.0,60.0],
  ];
  static const _southAmerica = [
    [-75.0,12.0],[-60.0,5.0],[-50.0,2.0],[-35.0,-8.0],[-40.0,-20.0],
    [-48.0,-28.0],[-58.0,-38.0],[-65.0,-55.0],[-68.0,-45.0],[-70.0,-35.0],
    [-70.0,-20.0],[-68.0,-10.0],[-75.0,-5.0],[-75.0,12.0],
  ];
  static const _australia = [
    [114.0,-22.0],[130.0,-12.0],[145.0,-15.0],[150.0,-25.0],[152.0,-32.0],
    [148.0,-38.0],[140.0,-38.0],[130.0,-34.0],[120.0,-34.0],[114.0,-30.0],[114.0,-22.0],
  ];
  // Conflict overlays
  static const _conflictMiddleEast = [
    [36.0,37.0],[44.0,37.0],[60.0,36.0],[63.0,25.0],[55.0,22.0],[44.0,12.0],
    [36.0,15.0],[32.0,22.0],[30.0,30.0],[34.0,33.0],[36.0,37.0],
  ];
  static const _conflictUkraine = [
    [22.0,48.0],[40.0,52.0],[40.0,47.0],[22.0,44.0],[22.0,48.0],
  ];
  static const _conflictSudan = [
    [24.0,22.0],[38.0,22.0],[38.0,8.0],[24.0,8.0],[24.0,22.0],
  ];
}
