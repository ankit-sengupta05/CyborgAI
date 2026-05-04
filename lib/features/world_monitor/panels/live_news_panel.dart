// lib/panels/live_news_panel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';
import '../wm_theme.dart';
import '../widgets/floating_panel.dart';
import '../services/data_service.dart';
import '../services/dashboard_provider.dart';

class LiveNewsPanel extends StatefulWidget {
  const LiveNewsPanel({super.key});
  @override
  State<LiveNewsPanel> createState() => _LiveNewsPanelState();
}

class _LiveNewsPanelState extends State<LiveNewsPanel> {
  static const _sources = [
    'BLOOMBERG',
    'SKYNEWS',
    'EURONEWS',
    'DW',
    'CNBC',
    'CNN',
    'FRANCE 24',
    'ALARABIYA',
    'ALJAZEERA',
  ];
  static const _videoIds = {
    'BLOOMBERG': 'dp8PhLsUcFE',
    'SKYNEWS': '9Auq9mYxFEE',
    'EURONEWS': '8qoLBHqLMRQ',
    'DW': 'mGnFABax00A',
    'CNBC': 'sBdchIrpQ1Y',
    'CNN': 'F57BKKSQpME',
    'FRANCE 24': 'h3MuIUNCCLI',
    'ALARABIYA': 'xMMCvHt0LCI',
    'ALJAZEERA': 'F-POY4J9ro0',
  };
  static const _sourceColors = {
    'BLOOMBERG': Color(0xFF1a6bff),
    'SKYNEWS': Color(0xFF0066cc),
    'EURONEWS': Color(0xFF0055aa),
    'DW': Color(0xFF555555),
    'CNBC': Color(0xFF003399),
    'CNN': Color(0xFFcc0000),
    'FRANCE 24': Color(0xFF004080),
    'ALARABIYA': Color(0xFF880000),
    'ALJAZEERA': Color(0xFF006699),
  };

  String _current = 'BLOOMBERG';
  bool _showList = false;
  bool _wvReady = false;
  bool _wvFailed = false;
  final _ctrl = WebviewController();

  @override
  void initState() {
    super.initState();
    _initWv();
  }

  Future<void> _initWv() async {
    try {
      await _ctrl.initialize();
      await _ctrl.setBackgroundColor(Colors.black);
      await _ctrl.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      // Load YouTube watch page directly — WebView2 handles it natively
      final vid = _videoIds['BLOOMBERG']!;
      await _ctrl.loadUrl('https://www.youtube.com/watch?v=$vid');
      if (mounted) setState(() => _wvReady = true);
    } catch (e) {
      if (mounted) setState(() => _wvFailed = true);
    }
  }

  Future<void> _switchSource(String src) async {
    setState(() => _current = src);
    if (!_wvReady) return;
    final vid = _videoIds[src] ?? _videoIds['BLOOMBERG']!;
    _ctrl.loadUrl('https://www.youtube.com/watch?v=$vid');
  }

  Future<void> _openBrowser() async {
    final vid = _videoIds[_current] ?? '';
    final uri = Uri.parse('https://www.youtube.com/watch?v=$vid');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Safety check for DataService provider
    DataService? ds;
    try {
      ds = context.watch<DataService>();
    } catch (_) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ds == null) return const Center(child: CircularProgressIndicator());
    return GridPanel(
      title: 'LIVE NEWS',
      isLive: true,
      count: ds.news.length,
      countColor: WMColors.accentRed,
      onClose: () =>
          context.read<DashboardProvider>().togglePanel(PanelId.liveNews),
      headerActions: [
        GestureDetector(
          onTap: () => setState(() => _showList = !_showList),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
                _showList ? Icons.videocam_outlined : Icons.article_outlined,
                color: WMColors.textMuted,
                size: 13),
          ),
        ),
        GestureDetector(
            onTap: _openBrowser,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.open_in_new,
                    color: WMColors.textMuted, size: 13))),
        const Icon(Icons.fullscreen, color: WMColors.textMuted, size: 13),
      ],
      child: Column(children: [
        // Source bar
        Container(
          height: 34,
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: WMColors.border))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
                children: _sources
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: () => _switchSource(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _current == s
                                    ? (_sourceColors[s] ?? WMColors.accentGreen)
                                    : Colors.transparent,
                                border: Border.all(
                                    color: _current == s
                                        ? (_sourceColors[s] ??
                                            WMColors.accentGreen)
                                        : WMColors.borderLight),
                                borderRadius: BorderRadius.circular(1),
                              ),
                              child: Text(s,
                                  style: TextStyle(
                                      color: _current == s
                                          ? Colors.white
                                          : WMColors.textSecond,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ))
                    .toList()),
          ),
        ),
        // Content
        Expanded(
            child: _showList
                ? _buildNewsList(ds.news)
                : Column(children: [
                    Expanded(
                        flex: 3,
                        child: _wvReady
                            ? Webview(_ctrl)
                            : _FakeTV(
                                source: _current,
                                color: _sourceColors[_current] ??
                                    WMColors.accentGreen,
                                onOpen: _openBrowser)),
                    Expanded(
                        flex: 2,
                        child: _buildNewsList(ds.news.take(8).toList())),
                  ])),
      ]),
    );
  }

  Widget _buildNewsList(List<NewsArticle> news) {
    if (news.isEmpty)
      return const Center(
          child:
              Text('Loading...', style: TextStyle(color: WMColors.textMuted)));
    return ListView.builder(
      itemCount: news.length,
      itemBuilder: (_, i) => _NRow(a: news[i]),
    );
  }
}

// ── Animated fallback TV ─────────────────────────────────────────────────────
class _FakeTV extends StatefulWidget {
  final String source;
  final Color color;
  final VoidCallback onOpen;
  const _FakeTV(
      {required this.source, required this.color, required this.onOpen});
  @override
  State<_FakeTV> createState() => _FakeTVState();
}

class _FakeTVState extends State<_FakeTV> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => GestureDetector(
          onTap: widget.onOpen,
          child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                  widget.color.withOpacity(0.12 + 0.04 * _c.value),
                  Colors.black87
                ])),
            child: Stack(children: [
              CustomPaint(painter: _Scan(), child: const SizedBox.expand()),
              Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: widget.color.withOpacity(0.7),
                                width: 2)),
                        child: Icon(Icons.play_arrow_rounded,
                            color: widget.color, size: 34)),
                    const SizedBox(height: 12),
                    Text('${widget.source} LIVE',
                        style: TextStyle(
                            color: widget.color,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const SizedBox(height: 6),
                    Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.open_in_new,
                          color: WMColors.textSecond, size: 11),
                      SizedBox(width: 4),
                      Text('Click to open live stream',
                          style: TextStyle(
                              color: WMColors.textSecond, fontSize: 9)),
                    ]),
                  ])),
              Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    color: Colors.black.withOpacity(0.7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: widget.color
                                  .withOpacity(0.4 + 0.6 * _c.value),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('LIVE',
                          style: TextStyle(
                              color: widget.color
                                  .withOpacity(0.7 + 0.3 * _c.value),
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ]),
                  )),
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _Ticker(source: widget.source, color: widget.color)),
            ]),
          ),
        ),
      );
}

class _Scan extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.black.withOpacity(0.09)
      ..strokeWidth = 0.5;
    for (double y = 0; y < s.height; y += 3)
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Ticker extends StatefulWidget {
  final String source;
  final Color color;
  const _Ticker({required this.source, required this.color});
  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<Offset> _s;
  int _i = 0;
  static const _h = [
    'BREAKING: Iran launches coordinated drone and missile strike on Israeli positions',
    'US Navy repositions carrier strike group in Eastern Mediterranean amid escalation',
    'Russia: 3.8k MW thermal spike across 12 sites — monitoring elevated',
    'North Korea fires ballistic missile into Sea of Japan — DPRK response awaited',
    'Global oil prices surge 3.4% on Hormuz risk premium and Middle East tensions',
  ];
  @override
  void initState() {
    super.initState();
    _c =
        AnimationController(duration: const Duration(seconds: 12), vsync: this);
    _s = Tween<Offset>(begin: const Offset(1, 0), end: const Offset(-2, 0))
        .animate(_c);
    _c.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        setState(() => _i = (_i + 1) % _h.length);
        _c.reset();
        _c.forward();
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) => Container(
        height: 22,
        color: Colors.black.withOpacity(0.75),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: widget.color,
              child: Text(widget.source,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(
              child: ClipRect(
                  child: SlideTransition(
                      position: _s,
                      child: Text(_h[_i],
                          style:
                              const TextStyle(color: Colors.white, fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.visible)))),
        ]),
      );
}

class _NRow extends StatelessWidget {
  final NewsArticle a;
  const _NRow({required this.a});
  Color get _c {
    switch (a.category) {
      case 'CONFLICT':
        return WMColors.highAlert;
      case 'MILITARY':
        return WMColors.accentBlue;
      case 'MARKETS':
        return WMColors.accentYellow;
      case 'CYBER':
        return WMColors.accentOrange;
      case 'HEALTH':
        return WMColors.accentGreen;
      default:
        return WMColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: a.isBreaking
                ? WMColors.highAlert.withOpacity(0.05)
                : Colors.transparent,
            border: Border(
                bottom: BorderSide(color: WMColors.border.withOpacity(0.4)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (a.isBreaking)
              Container(
                  margin: const EdgeInsets.only(top: 1, right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  color: WMColors.highAlert,
                  child: const Text('BREAKING',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                          fontWeight: FontWeight.bold))),
            Expanded(
                child: Text(a.title,
                    style: const TextStyle(
                        color: WMColors.textPrimary,
                        fontSize: 10,
                        height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    border: Border.all(color: _c.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(1)),
                child:
                    Text(a.category, style: TextStyle(color: _c, fontSize: 7))),
            const SizedBox(width: 6),
            Text(a.source,
                style:
                    const TextStyle(color: WMColors.accentGreen, fontSize: 8)),
            const Spacer(),
            Text(a.publishedAt.length > 15 ? 'recent' : a.publishedAt,
                style: const TextStyle(color: WMColors.textMuted, fontSize: 7)),
          ]),
        ]),
      );
}
