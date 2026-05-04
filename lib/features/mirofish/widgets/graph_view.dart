// lib/widgets/graph_view.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/models.dart';
import '../utils/theme.dart';

// ── Color by entity type ──────────────────────────────────────────────────────
Color _nc(String type) {
  final t = type.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
  if (t == 'university') return const Color(0xFFFF6B35);
  if (t == 'student') return const Color(0xFFE74C3C);
  if (t == 'professor') return const Color(0xFFE67E22);
  if (t == 'alumni') return const Color(0xFF9B59B6);
  if (t == 'organization') return const Color(0xFF27AE60);
  if (t == 'person' || t == 'individual') return const Color(0xFF3498DB);
  if (t == 'entity') return const Color(0xFF4A90D9);
  if (t == 'mediaoutlet' || t == 'media') return const Color(0xFF8E44AD);
  if (t == 'legalauthority') return const Color(0xFF1ABC9C);
  if (t == 'opinionleader') return const Color(0xFFF39C12);
  if (t == 'governmentagency' || t == 'government') return const Color(0xFF2ECC71);
  if (t == 'ngo') return const Color(0xFF16A085);
  if (t == 'decision') return const Color(0xFFE84393);
  if (t == 'recruiter') return const Color(0xFF2980B9);
  if (t == 'candidate') return const Color(0xFFE74C3C);
  if (t == 'resume') return const Color(0xFF8E44AD);
  if (t == 'jobopening') return const Color(0xFF27AE60);
  if (t == 'skillset') return const Color(0xFFD35400);
  if (t == 'evaluationcriteria') return const Color(0xFF1ABC9C);
  if (t == 'interviewround' || t == 'interview') return const Color(0xFF9B59B6);
  if (t == 'hiringmanager') return const Color(0xFFE67E22);
  if (t == 'selectiondecision') return const Color(0xFFE84393);
  if (t == 'company') return const Color(0xFF2980B9);
  if (t == 'application') return const Color(0xFFE84393);
  if (t == 'offer') return const Color(0xFF27AE60);
  if (t == 'hospital') return const Color(0xFFE74C3C);
  if (t == 'doctor') return const Color(0xFF2980B9);
  if (t == 'patient') return const Color(0xFF27AE60);
  if (t == 'technology' || t == 'platform') return const Color(0xFF9B59B6);
  if (t == 'event') return const Color(0xFFE84393);
  if (t == 'community') return const Color(0xFF16A085);
  if (t == 'public') return const Color(0xFFF39C12);
  // Deterministic palette for unknown types
  const pal = [
    Color(0xFFFF6B35), Color(0xFFE74C3C), Color(0xFF9B59B6), Color(0xFF3498DB),
    Color(0xFF27AE60), Color(0xFFE67E22), Color(0xFF1ABC9C), Color(0xFFE84393),
    Color(0xFFF39C12), Color(0xFF2ECC71), Color(0xFF8E44AD), Color(0xFF16A085),
    Color(0xFFD35400), Color(0xFF2980B9), Color(0xFF7D3C98), Color(0xFF117A65),
  ];
  final h = type.codeUnits.fold(0, (p, c) => p * 31 + c).abs();
  return pal[h % pal.length];
}

// ── Mutable physics node ──────────────────────────────────────────────────────
class _N {
  final String id, label, type;
  double x, y, vx = 0, vy = 0;
  int degree = 0; // connection count — affects node size
  _N({required this.id, required this.label, required this.type,
      required this.x, required this.y});
}

// ── Main widget ───────────────────────────────────────────────────────────────
class GraphView extends StatefulWidget {
  final GraphData data;
  final bool showEdgeLabels;
  final VoidCallback? onRefresh;
  const GraphView({super.key, required this.data,
      this.showEdgeLabels = true, this.onRefresh});
  @override
  State<GraphView> createState() => _GVS();
}

class _GVS extends State<GraphView> with TickerProviderStateMixin {
  late AnimationController _phys, _spin;
  List<_N> _nodes = [];
  List<String> _prevIds = [];
  double _scale = 0.85;
  Offset _pan = Offset.zero;
  Offset? _ps, _po; // pan start, pan origin
  String? _hov, _drag, _sel;
  bool _settled = false;
  bool _showToast = false;

  @override
  void initState() {
    super.initState();
    _phys = AnimationController(vsync: this, duration: const Duration(seconds: 180))
      ..addListener(_tick)..forward();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _layout();
  }

  @override
  void didUpdateWidget(GraphView old) {
    super.didUpdateWidget(old);
    final ids = widget.data.nodes.map((n) => n.id).toList();
    if (ids.length != _prevIds.length || ids.join() != _prevIds.join()) {
      setState(() { _showToast = true; });
      _layout();
      _settled = false;
      if (!_phys.isAnimating) _phys.forward(from: 0);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showToast = false);
      });
    }
  }

  void _layout() {
    _prevIds = widget.data.nodes.map((n) => n.id).toList();
    final rng = math.Random(12345);
    final n = widget.data.nodes.length;

    // Group nodes by type for cluster seeding
    final groups = <String, List<int>>{};
    for (int i = 0; i < n; i++) {
      (groups[widget.data.nodes[i].type] ??= []).add(i);
    }
    final gList = groups.entries.toList();
    final positions = List<Offset>.filled(n, Offset.zero);

    for (int g = 0; g < gList.length; g++) {
      // Place group clusters around a big circle with organic offsets
      final ga = 2 * math.pi * g / math.max(gList.length, 1)
               + rng.nextDouble() * 0.5 - 0.25;
      final cr = 120.0 + rng.nextDouble() * 200;
      final cx = 500 + cr * math.cos(ga);
      final cy = 380 + cr * math.sin(ga);
      final idxs = gList[g].value;
      for (int k = 0; k < idxs.length; k++) {
        final a = 2 * math.pi * k / math.max(idxs.length, 1)
                + rng.nextDouble() * 1.2 - 0.6;
        final r = 20.0 + rng.nextDouble() * 80;
        positions[idxs[k]] = Offset(
          cx + r * math.cos(a) + rng.nextDouble() * 30 - 15,
          cy + r * math.sin(a) + rng.nextDouble() * 30 - 15,
        );
      }
    }

    final existing = <String, _N>{for (final n in _nodes) n.id: n};

    // Compute degrees
    final degrees = <String, int>{};
    for (final e in widget.data.edges) {
      degrees[e.source] = (degrees[e.source] ?? 0) + 1;
      degrees[e.target] = (degrees[e.target] ?? 0) + 1;
    }

    _nodes = List.generate(n, (i) {
      final src = widget.data.nodes[i];
      final node = existing.containsKey(src.id)
          ? existing[src.id]!
          : _N(id: src.id, label: src.label, type: src.type,
               x: positions[i].dx, y: positions[i].dy);
      node.degree = degrees[src.id] ?? 0;
      return node;
    });
  }

  void _tick() {
    if (!mounted || _nodes.isEmpty || _settled) return;
    double ke = 0;
    final n = _nodes.length;

    for (int i = 0; i < n; i++) {
      if (_nodes[i].id == _drag) continue;
      double fx = 0, fy = 0;

      // Node-node repulsion (stronger for hubs)
      for (int j = 0; j < n; j++) {
        if (i == j) continue;
        final dx = _nodes[i].x - _nodes[j].x;
        final dy = _nodes[i].y - _nodes[j].y;
        final d2 = (dx * dx + dy * dy).clamp(25.0, 800000.0);
        final d = math.sqrt(d2);
        final f = 15000.0 / d2;
        fx += dx / d * f;
        fy += dy / d * f;
      }

      // Spring attraction along edges — longer rest length = more spread
      for (final e in widget.data.edges) {
        final isSource = e.source == _nodes[i].id;
        final isTarget = e.target == _nodes[i].id;
        if (!isSource && !isTarget) continue;
        final oid = isSource ? e.target : e.source;
        final o = _nodes.where((n) => n.id == oid).firstOrNull;
        if (o == null) continue;
        final dx = o.x - _nodes[i].x;
        final dy = o.y - _nodes[i].y;
        final d = math.sqrt(dx * dx + dy * dy).clamp(1.0, 9999.0);
        // Target edge length ~120px for normal, longer for hubs
        final idealLen = 100.0 + _nodes[i].degree * 8.0;
        final stretch = (d - idealLen) / d;
        fx += dx * stretch * 0.06;
        fy += dy * stretch * 0.06;
      }

      // Soft center gravity
      fx += (500 - _nodes[i].x) * 0.002;
      fy += (380 - _nodes[i].y) * 0.002;

      _nodes[i].vx = (_nodes[i].vx + fx * 0.055) * 0.78;
      _nodes[i].vy = (_nodes[i].vy + fy * 0.055) * 0.78;
      ke += _nodes[i].vx * _nodes[i].vx + _nodes[i].vy * _nodes[i].vy;
      _nodes[i].x = (_nodes[i].x + _nodes[i].vx).clamp(20, 1020);
      _nodes[i].y = (_nodes[i].y + _nodes[i].vy).clamp(20, 760);
    }

    if (ke < 0.15) _settled = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() { _phys.dispose(); _spin.dispose(); super.dispose(); }

  Offset _s2g(Offset s, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2;
    return Offset((s.dx - cx - _pan.dx) / _scale + cx,
                  (s.dy - cy - _pan.dy) / _scale + cy);
  }

  Offset _g2s(Offset g, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2;
    return Offset((g.dx - cx) * _scale + cx + _pan.dx,
                  (g.dy - cy) * _scale + cy + _pan.dy);
  }

  String? _hit(Offset gp) {
    for (final n in _nodes.reversed) {
      final r = _nodeR(n) + 4;
      final dx = n.x - gp.dx, dy = n.y - gp.dy;
      if (dx * dx + dy * dy < r * r) return n.id;
    }
    return null;
  }

  double _nodeR(_N n) => (7.0 + math.sqrt(n.degree.toDouble()) * 2.5).clamp(7.0, 20.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final sz = Size(c.maxWidth, c.maxHeight);
      final sel = _sel != null ? _nodes.where((n) => n.id == _sel).firstOrNull : null;
      final types = widget.data.entityTypes.isNotEmpty
          ? widget.data.entityTypes
          : _nodes.map((n) => n.type).toSet().toList();

      return Stack(children: [
        // ── Canvas ──────────────────────────────────────────────────────────
        Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) setState(() =>
              _scale = (_scale * (e.scrollDelta.dy > 0 ? 0.88 : 1.12)).clamp(0.06, 12.0));
          },
          child: GestureDetector(
            onPanStart: (d) {
              final gp = _s2g(d.localPosition, sz);
              final h = _hit(gp);
              if (h != null) {
                setState(() { _drag = h; _settled = false; });
              } else {
                _ps = d.globalPosition; _po = _pan;
              }
            },
            onPanUpdate: (d) {
              if (_drag != null) {
                final gp = _s2g(d.localPosition, sz);
                final i = _nodes.indexWhere((n) => n.id == _drag);
                if (i >= 0) setState(() {
                  _nodes[i].x = gp.dx; _nodes[i].y = gp.dy;
                  _nodes[i].vx = 0; _nodes[i].vy = 0;
                });
              } else if (_ps != null) {
                setState(() => _pan = _po! + d.globalPosition - _ps!);
              }
            },
            onPanEnd: (_) { _ps = null; _drag = null; },
            onTapUp: (d) {
              final h = _hit(_s2g(d.localPosition, sz));
              setState(() { _sel = (h == _sel) ? null : h; });
            },
            child: MouseRegion(
              cursor: _hov != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
              onHover: (e) {
                final h = _hit(_s2g(e.localPosition, sz));
                if (h != _hov) setState(() => _hov = h);
              },
              onExit: (_) => setState(() => _hov = null),
              child: CustomPaint(
                size: sz,
                painter: _P(
                  nodes: _nodes, edges: widget.data.edges,
                  scale: _scale, panX: _pan.dx, panY: _pan.dy,
                  showLabels: widget.showEdgeLabels,
                  hov: _hov, sel: _sel, drag: _drag,
                ),
              ),
            ),
          ),
        ),

        // ── Header ──────────────────────────────────────────────────────────
        Positioned(top: 10, left: 10,
          child: const Text('Graph Relationship Visualization',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500))),

        // ── Buttons ─────────────────────────────────────────────────────────
        Positioned(top: 6, right: 8,
          child: Row(children: [
            _GB(icon: Icons.refresh, label: 'Refresh', onTap: () {
              setState(() { _layout(); _settled = false; _sel = null; });
              if (!_phys.isAnimating) _phys.forward(from: 0);
              widget.onRefresh?.call();
            }),
            const SizedBox(width: 6),
            _GB(icon: Icons.fullscreen, onTap: () {}),
          ])),

        // ── Edge label toggle ────────────────────────────────────────────────
        Positioned(top: 40, right: 8, child: _Tog(value: widget.showEdgeLabels)),

        // ── Legend ──────────────────────────────────────────────────────────
        Positioned(bottom: 8, left: 8, child: _Leg(types: types)),

        // ── Node count ──────────────────────────────────────────────────────
        Positioned(bottom: 8, right: 8,
          child: Text('${_nodes.length}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)))),

        // ── "Updating in real-time..." toast (matches original) ──────────────
        if (_showToast)
          Positioned(
            bottom: 50, left: 0, right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Transform.rotate(
                      angle: _spin.value * 2 * math.pi,
                      child: const Icon(Icons.refresh, color: Color(0xFF22C55E), size: 16)),
                    const SizedBox(width: 8),
                    const Text('Updating in real-time...',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ),
          ),

        // ── Node detail panel ────────────────────────────────────────────────
        if (sel != null) ...[
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() => _sel = null),
            child: const ColoredBox(color: Colors.transparent))),
          Positioned(
            left: _px(sel, sz), top: _py(sel, sz),
            child: _Det(node: sel, edges: widget.data.edges,
              allNodes: _nodes, onClose: () => setState(() => _sel = null))),
        ],
      ]);
    });
  }

  double _px(_N n, Size sz) {
    final sx = _g2s(Offset(n.x, n.y), sz).dx;
    final l = sx + 18;
    return l + 300 > sz.width ? sx - 318 : l;
  }

  double _py(_N n, Size sz) =>
    (_g2s(Offset(n.x, n.y), sz).dy - 80).clamp(8.0, sz.height - 460.0);
}

// ── Painter ───────────────────────────────────────────────────────────────────
class _P extends CustomPainter {
  final List<_N> nodes;
  final List<GraphEdge> edges;
  final double scale, panX, panY;
  final bool showLabels;
  final String? hov, sel, drag;

  const _P({required this.nodes, required this.edges,
    required this.scale, required this.panX, required this.panY,
    required this.showLabels, this.hov, this.sel, this.drag});

  Offset _ts(double x, double y, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2;
    return Offset((x - cx) * scale + cx + panX, (y - cy) * scale + cy + panY);
  }

  double _nr(_N n) => ((7.0 + math.sqrt(n.degree.toDouble()) * 2.5).clamp(7.0, 20.0) * scale).clamp(4.0, 24.0);

  @override
  void paint(Canvas canvas, Size sz) {
    // ── Background: dotted grid matching original ────────────────────────────
    final gp = Paint()..color = const Color(0xFFD8D8D8)..style = PaintingStyle.fill;
    for (double x = 20; x < sz.width;  x += 32)
    for (double y = 20; y < sz.height; y += 32)
      canvas.drawCircle(Offset(x, y), 1.2, gp);

    final nmap = <String, _N>{for (final n in nodes) n.id: n};

    // Highlight sets
    final hlIds = <String>{};
    final hlEdges = <GraphEdge>[];
    final focus = sel ?? hov;
    if (focus != null) {
      hlIds.add(focus);
      for (final e in edges) {
        if (e.source == focus || e.target == focus) {
          hlEdges.add(e); hlIds.add(e.source); hlIds.add(e.target);
        }
      }
    }

    // ── Draw normal edges — CURVED bezier ────────────────────────────────────
    final ep = Paint()..color = const Color(0xFFC8C8C8)..strokeWidth = 0.7
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    for (final e in edges) {
      if (hlEdges.contains(e)) continue;
      final a = nmap[e.source], b = nmap[e.target];
      if (a == null || b == null) continue;
      _drawCurvedEdge(canvas, _ts(a.x, a.y, sz), _ts(b.x, b.y, sz), ep, null);
    }

    // ── Highlighted edges — hot pink curved ──────────────────────────────────
    final hp = Paint()..color = const Color(0xFFE8196A)..strokeWidth = 2.0
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    for (final e in hlEdges) {
      final a = nmap[e.source], b = nmap[e.target];
      if (a == null || b == null) continue;
      final p1 = _ts(a.x, a.y, sz), p2 = _ts(b.x, b.y, sz);
      _drawCurvedEdge(canvas, p1, p2, hp, const Color(0xFFE8196A));
    }

    // ── Edge labels ──────────────────────────────────────────────────────────
    if (showLabels && scale > 0.38) {
      for (final e in edges) {
        final a = nmap[e.source], b = nmap[e.target];
        if (a == null || b == null || e.label.isEmpty) continue;
        final p1 = _ts(a.x, a.y, sz), p2 = _ts(b.x, b.y, sz);
        // Place label at bezier midpoint (roughly)
        final ctrl = _ctrl(p1, p2);
        final mid = Offset(
          0.25 * p1.dx + 0.5 * ctrl.dx + 0.25 * p2.dx,
          0.25 * p1.dy + 0.5 * ctrl.dy + 0.25 * p2.dy,
        );
        final isHl = hlEdges.contains(e);
        _txt(canvas, mid, e.label,
          col: isHl ? const Color(0xFFE8196A) : const Color(0xFFAAAAAA),
          fs: (6.0 * scale).clamp(4.5, 10.0), bold: isHl);
      }
    }

    // ── Draw nodes ───────────────────────────────────────────────────────────
    for (final node in nodes) {
      final pos = _ts(node.x, node.y, sz);
      final col = _nc(node.type);
      final r = _nr(node);
      final isSel  = node.id == sel;
      final isHov  = node.id == hov;
      final isDrag = node.id == drag;
      final isHl   = hlIds.contains(node.id);
      final hasFocus = sel != null || hov != null;

      // Fade non-connected when something selected
      if (hasFocus && !isHl) {
        canvas.drawCircle(pos, r,
          Paint()..color = col.withOpacity(0.18)..style = PaintingStyle.fill);
        if (scale > 0.35) {
          final lbl = node.label.length > 12 ? '${node.label.substring(0,10)}...' : node.label;
          _txt(canvas, pos + Offset(0, r+2), lbl,
            col: col.withOpacity(0.25), fs: (8.0*scale).clamp(5.5, 12.0));
        }
        continue;
      }

      // Glow ring
      if (isSel) {
        canvas.drawCircle(pos, r+8,
          Paint()..color=col.withOpacity(0.15)..style=PaintingStyle.fill);
        canvas.drawCircle(pos, r+8,
          Paint()..color=col.withOpacity(0.4)..style=PaintingStyle.stroke..strokeWidth=1.8);
      } else if (isHov || isDrag) {
        canvas.drawCircle(pos, r+5,
          Paint()..color=col.withOpacity(0.2)..style=PaintingStyle.fill);
      }

      // Main circle with subtle gradient effect (draw two circles)
      canvas.drawCircle(pos, r,
        Paint()..color=col..style=PaintingStyle.fill);
      // Highlight top-left for 3D feel
      canvas.drawCircle(pos - Offset(r*0.2, r*0.2), r*0.55,
        Paint()..color=Colors.white.withOpacity(0.18)..style=PaintingStyle.fill);
      // Border
      canvas.drawCircle(pos, r,
        Paint()..color=Colors.white.withOpacity(0.35)..style=PaintingStyle.stroke..strokeWidth=1.2);

      // Label
      if (scale > 0.32) {
        final lbl = node.label.length > 12 ? '${node.label.substring(0,10)}...' : node.label;
        _txt(canvas, pos + Offset(0, r+2.5), lbl,
          col: Colors.black.withOpacity((isSel||isHov) ? 0.88 : 0.68),
          fs: (8.0*scale).clamp(5.5, 12.5));
      }
    }
  }

  // Compute bezier control point — curves upward/sideways for visual interest
  Offset _ctrl(Offset p1, Offset p2) {
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    // Perpendicular offset proportional to edge length (max 40px curve)
    final curveAmt = (len * 0.15).clamp(10.0, 40.0);
    // Use hash of endpoints to get consistent curve direction
    final hash = (p1.dx * 7 + p1.dy * 13 + p2.dx * 17 + p2.dy * 19).toInt().abs();
    final sign = (hash % 2 == 0) ? 1.0 : -1.0;
    // Perpendicular direction
    final px = -dy / math.max(len, 1) * curveAmt * sign;
    final py =  dx / math.max(len, 1) * curveAmt * sign;
    return Offset(mid.dx + px, mid.dy + py);
  }

  void _drawCurvedEdge(Canvas canvas, Offset p1, Offset p2, Paint paint, Color? arrowColor) {
    final ctrl = _ctrl(p1, p2);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);
    canvas.drawPath(path, paint);

    // Arrow tip for highlighted edges
    if (arrowColor != null) {
      final dx = p2.dx - ctrl.dx, dy = p2.dy - ctrl.dy;
      final d = math.sqrt(dx * dx + dy * dy).clamp(1.0, 9999.0);
      final ux = dx / d, uy = dy / d;
      const al = 8.0, aa = 0.4;
      final tip = Offset(p2.dx - ux * 12, p2.dy - uy * 12);
      final ap = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - al*(ux*math.cos(aa)-uy*math.sin(aa)),
                 tip.dy - al*(uy*math.cos(aa)+ux*math.sin(aa)))
        ..lineTo(tip.dx - al*(ux*math.cos(-aa)-uy*math.sin(-aa)),
                 tip.dy - al*(uy*math.cos(-aa)+ux*math.sin(-aa)))
        ..close();
      canvas.drawPath(ap, Paint()..color=arrowColor..style=PaintingStyle.fill);
    }
  }

  void _txt(Canvas c, Offset pos, String text,
      {required Color col, required double fs, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: col, fontSize: fs,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, pos - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(_P o) =>
    o.nodes != nodes || o.scale != scale || o.panX != panX || o.panY != panY ||
    o.showLabels != showLabels || o.hov != hov || o.sel != sel || o.drag != drag;
}

// ── Node Detail Panel ─────────────────────────────────────────────────────────
class _Det extends StatelessWidget {
  final _N node;
  final List<GraphEdge> edges;
  final List<_N> allNodes;
  final VoidCallback onClose;
  const _Det({required this.node, required this.edges,
    required this.allNodes, required this.onClose});

  List<_N> get _conn {
    final ids = <String>{};
    for (final e in edges) {
      if (e.source == node.id) ids.add(e.target);
      if (e.target == node.id) ids.add(e.source);
    }
    return allNodes.where((n) => ids.contains(n.id)).toList();
  }

  String _uuid() {
    final h = node.id.codeUnits.fold(0,(p,c)=>p*31+c).abs().toRadixString(16).padLeft(16,'0');
    return '${h.substring(0,8)}-${h.substring(0,4)}-${h.substring(4,8)}-${h.substring(8,12)}';
  }

  String _date() {
    final h = node.id.codeUnits.fold(0,(p,c)=>p*31+c).abs();
    return 'Feb ${(h%28)+1}, 2026, ${(h%14)+8}:${(h%60).toString().padLeft(2,"0")} AM';
  }

  @override
  Widget build(BuildContext context) {
    final col = _nc(node.type);
    final conn = _conn;
    return Material(elevation: 12, borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 295,
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14),
            blurRadius: 24, offset: const Offset(0, 4))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14,11,11,11),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(children: [
              const Text('Node Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal:9, vertical:3),
                decoration: BoxDecoration(color:col, borderRadius:BorderRadius.circular(5)),
                child: Text(node.type, style: const TextStyle(
                  color:Colors.white, fontSize:10, fontWeight:FontWeight.w600))),
              const SizedBox(width:8),
              GestureDetector(onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color:const Color(0xFFF3F4F6),
                    borderRadius:BorderRadius.circular(4)),
                  child: const Icon(Icons.close, size:13, color:Color(0xFF6B7280)))),
            ])),
          // Body
          Padding(padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _kv('Name:', node.label, bold:true),
              const SizedBox(height:9),
              _kv('UUID:', _uuid(), mono:true, small:true),
              const SizedBox(height:9),
              _kv('Created:', _date()),
              const SizedBox(height:13),
              const Text('Properties:',
                style: TextStyle(fontSize:11, fontWeight:FontWeight.w600)),
              const SizedBox(height:5),
              _prop('type', node.type.toLowerCase()),
              _prop('connections', '${conn.length}'),
              _prop('degree', '${node.degree}'),
              if (conn.isNotEmpty) ...[
                const SizedBox(height:13),
                Text('Connected (${conn.length}):',
                  style: const TextStyle(fontSize:11, fontWeight:FontWeight.w600)),
                const SizedBox(height:5),
                Wrap(spacing:4, runSpacing:4,
                  children: conn.take(6).map((c) {
                    final cc = _nc(c.type);
                    final lbl = c.label.length>13 ? '${c.label.substring(0,11)}...' : c.label;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal:6, vertical:2),
                      decoration: BoxDecoration(color:cc.withOpacity(0.10),
                        border:Border.all(color:cc.withOpacity(0.35)),
                        borderRadius:BorderRadius.circular(4)),
                      child: Text(lbl, style:TextStyle(fontSize:9.5, color:cc)));
                  }).toList()),
              ],
              const SizedBox(height:13),
              const Text('Labels:',
                style: TextStyle(fontSize:11, fontWeight:FontWeight.w600)),
              const SizedBox(height:5),
              Wrap(spacing:5, runSpacing:4, children:[
                _chip('Entity', const Color(0xFF6B7280)),
                _chip(node.type, col),
              ]),
            ])),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold=false, bool mono=false, bool small=false}) =>
    Row(crossAxisAlignment:CrossAxisAlignment.start, children:[
      SizedBox(width:68, child:Text(k,
        style:const TextStyle(fontSize:11, color:Color(0xFF9CA3AF)))),
      Expanded(child:Text(v, style:TextStyle(
        fontSize: small?9.5:11,
        fontWeight: bold?FontWeight.w600:FontWeight.normal,
        fontFamily: mono?'monospace':null))),
    ]);

  Widget _prop(String k, String v) => Padding(
    padding:const EdgeInsets.only(bottom:3),
    child:Row(children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:1),
        color:const Color(0xFFF3F4F6),
        child:Text(k, style:const TextStyle(fontSize:9.5,
          fontFamily:'monospace', color:Color(0xFF9CA3AF)))),
      const SizedBox(width:8),
      Text(v, style:const TextStyle(fontSize:9.5, color:Color(0xFF6B7280))),
    ]));

  Widget _chip(String t, Color c) => Container(
    padding:const EdgeInsets.symmetric(horizontal:8, vertical:3),
    decoration:BoxDecoration(color:c.withOpacity(0.09),
      border:Border.all(color:c.withOpacity(0.35)),
      borderRadius:BorderRadius.circular(4)),
    child:Text(t, style:TextStyle(fontSize:9.5, color:c, fontWeight:FontWeight.w500)));
}

// ── Small UI widgets ──────────────────────────────────────────────────────────
class _GB extends StatelessWidget {
  final IconData icon; final String? label; final VoidCallback onTap;
  const _GB({required this.icon, required this.onTap, this.label});
  @override
  Widget build(BuildContext _) => GestureDetector(onTap:onTap,
    child:Container(
      padding:EdgeInsets.symmetric(horizontal:label!=null?8:6, vertical:5),
      decoration:BoxDecoration(color:Colors.white.withOpacity(0.9),
        border:Border.all(color:const Color(0xFFE5E7EB)),
        borderRadius:BorderRadius.circular(4)),
      child:Row(mainAxisSize:MainAxisSize.min, children:[
        Icon(icon, size:13, color:const Color(0xFF6B7280)),
        if(label!=null)...[const SizedBox(width:4),
          Text(label!, style:const TextStyle(fontSize:10, color:Color(0xFF6B7280)))],
      ])));
}

class _Tog extends StatelessWidget {
  final bool value;
  const _Tog({required this.value});
  @override
  Widget build(BuildContext _) => Container(
    padding:const EdgeInsets.symmetric(horizontal:10, vertical:5),
    decoration:BoxDecoration(color:Colors.white.withOpacity(0.92),
      border:Border.all(color:const Color(0xFFE5E7EB)),
      borderRadius:BorderRadius.circular(20)),
    child:Row(mainAxisSize:MainAxisSize.min, children:[
      Container(width:34, height:18,
        decoration:BoxDecoration(
          color:value?const Color(0xFF22C55E):const Color(0xFFCBD5E1),
          borderRadius:BorderRadius.circular(9)),
        child:AnimatedAlign(
          duration:const Duration(milliseconds:180),
          alignment:value?Alignment.centerRight:Alignment.centerLeft,
          child:Container(width:14, height:14, margin:const EdgeInsets.all(2),
            decoration:const BoxDecoration(color:Colors.white, shape:BoxShape.circle)))),
      const SizedBox(width:7),
      const Text('Show Edge Labels',
        style:TextStyle(fontSize:10, color:Color(0xFF111827), fontWeight:FontWeight.w500)),
    ]));
}

class _Leg extends StatelessWidget {
  final List<String> types;
  const _Leg({required this.types});
  @override
  Widget build(BuildContext _) => Container(
    padding:const EdgeInsets.symmetric(horizontal:10, vertical:8),
    decoration:BoxDecoration(color:Colors.white.withOpacity(0.90),
      border:Border.all(color:const Color(0xFFE5E7EB)),
      borderRadius:BorderRadius.circular(6)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      const Text('ENTITY TYPES', style:TextStyle(fontSize:9, fontWeight:FontWeight.bold,
        color:Color(0xFFE84393), letterSpacing:0.6)),
      const SizedBox(height:6),
      Wrap(spacing:14, runSpacing:4,
        children:types.take(12).map((t)=>Row(mainAxisSize:MainAxisSize.min, children:[
          Container(width:9, height:9,
            decoration:BoxDecoration(color:_nc(t), shape:BoxShape.circle)),
          const SizedBox(width:4),
          Text(t, style:const TextStyle(fontSize:9.5, color:Color(0xFF111827))),
        ])).toList()),
    ]));
}
