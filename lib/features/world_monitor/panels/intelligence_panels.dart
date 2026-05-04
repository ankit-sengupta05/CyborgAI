// lib/panels/intelligence_panels.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wm_theme.dart';
import '../widgets/floating_panel.dart';
import '../services/dashboard_provider.dart';
import '../services/data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI INSIGHTS
// ─────────────────────────────────────────────────────────────────────────────
class AiInsightsPanel extends StatelessWidget {
  const AiInsightsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    return GridPanel(
      title: 'AI INSIGHTS',
      isLive: true,
      onClose: () => context.read<DashboardProvider>().togglePanel(PanelId.aiInsights),
      headerActions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: WMColors.accentGreen.withOpacity(0.15),
            border: Border.all(color: WMColors.accentGreen.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Text('LIVE', style: TextStyle(color: WMColors.accentGreen, fontSize: 7, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.settings, color: WMColors.textMuted, size: 12),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: WMColors.border))),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: WMColors.accentBlue, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('WORLD BRIEF', style: TextStyle(color: WMColors.accentBlue, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ds.loading
                      ? const _Shimmer()
                      : _AiBriefText(text: _generateBrief(ds.news)),
                  const SizedBox(height: 16),
                  const Text('KEY INDICATORS', style: TextStyle(color: WMColors.textSecond, fontSize: 8, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  ..._buildIndicators(ds),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateBrief(List<NewsArticle> news) {
    if (news.isEmpty) return 'Connecting to live intelligence feeds...';
    final conflict = news.where((n) => n.category == 'CONFLICT' || n.category == 'MILITARY').take(2).toList();
    final markets  = news.where((n) => n.category == 'MARKETS').take(1).toList();
    final buf = StringBuffer();
    for (final n in conflict) { buf.write('${n.title}. '); }
    for (final n in markets)  { buf.write('On the financial front, ${n.title.toLowerCase()}. '); }
    buf.write('Global risk index currently elevated. Monitoring ${news.length} live intelligence feeds across all regions.');
    return buf.toString();
  }

  List<Widget> _buildIndicators(DataService ds) {
    final top = List<CountryData>.from(ds.countries)
      ..sort((a, b) => b.instabilityScore.compareTo(a.instabilityScore));
    return top.take(6).map((c) {
      final color = c.instabilityScore >= 70 ? WMColors.accentRed
          : c.instabilityScore >= 50 ? WMColors.accentOrange : WMColors.accentYellow;
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(c.name, style: const TextStyle(color: WMColors.textSecond, fontSize: 9))),
          Text('${c.instabilityScore}', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(c.trend, style: TextStyle(color: color, fontSize: 9)),
        ]),
      );
    }).toList();
  }
}

class _AiBriefText extends StatefulWidget {
  final String text;
  const _AiBriefText({required this.text});
  @override State<_AiBriefText> createState() => _AiBriefTextState();
}
class _AiBriefTextState extends State<_AiBriefText> {
  String _displayed = '';
  int _charIndex = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_charIndex < widget.text.length) {
        if (mounted) setState(() => _displayed = widget.text.substring(0, ++_charIndex));
      } else {
        _timer?.cancel();
      }
    });
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Text(_displayed,
    style: const TextStyle(color: WMColors.textPrimary, fontSize: 10, height: 1.6));
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override State<_Shimmer> createState() => _ShimmerState();
}
class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(duration: const Duration(seconds: 1), vsync: this)..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Column(children: List.generate(4, (i) => Container(
      margin: const EdgeInsets.only(bottom: 6), height: 10,
      width: i == 3 ? 120 : double.infinity,
      decoration: BoxDecoration(
        color: WMColors.borderLight.withOpacity(0.3 + 0.4 * _c.value),
        borderRadius: BorderRadius.circular(2),
      ),
    ))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AI FORECASTS
// ─────────────────────────────────────────────────────────────────────────────
class AiForecastsPanel extends StatefulWidget {
  const AiForecastsPanel({super.key});
  @override State<AiForecastsPanel> createState() => _AiForecastsPanelState();
}

class _AiForecastsPanelState extends State<AiForecastsPanel> {
  String _cat = 'All';
  String _region = 'All Regions';
  static const _cats    = ['All','Conflict','Market','Supply Chain','Political','Military','Cyber','Infra'];
  static const _regions = ['All Regions','MENA','East Asia','Europe','South Asia','Africa','LatAm','N. America'];

  List<Map<String, dynamic>> _forecasts(DataService ds) {
    final rng = Random(42);
    final base = [
      {'title':'Iran-Israel direct confrontation probability rising',     'cat':'Conflict',      'region':'MENA',       'prob':67, 'tf':'72h', 'trend':'↑'},
      {'title':'Russian Baltic maritime provocation likely',              'cat':'Military',      'region':'Europe',     'prob':54, 'tf':'7d',  'trend':'↑'},
      {'title':'EU energy grid cyber-attack risk elevated',               'cat':'Cyber',         'region':'Europe',     'prob':41, 'tf':'14d', 'trend':'→'},
      {'title':'DPRK missile test window approaching',                    'cat':'Military',      'region':'East Asia',  'prob':38, 'tf':'30d', 'trend':'↑'},
      {'title':'Strait of Hormuz disruption risk',                        'cat':'Supply Chain',  'region':'MENA',       'prob':29, 'tf':'14d', 'trend':'↑'},
      {'title':'India-Pakistan border escalation',                        'cat':'Military',      'region':'South Asia', 'prob':23, 'tf':'30d', 'trend':'→'},
      {'title':'Venezuela regime instability peak',                       'cat':'Political',     'region':'LatAm',      'prob':45, 'tf':'7d',  'trend':'↑'},
      {'title':'Taiwan Strait tension spike',                             'cat':'Military',      'region':'East Asia',  'prob':32, 'tf':'30d', 'trend':'↑'},
      {'title':'Global shipping disruption via Red Sea',                  'cat':'Supply Chain',  'region':'MENA',       'prob':58, 'tf':'7d',  'trend':'↑'},
      {'title':'US-China semiconductor decoupling escalates',             'cat':'Market',        'region':'East Asia',  'prob':71, 'tf':'30d', 'trend':'↑'},
    ];
    // Nudge probabilities from live instability scores
    for (final f in base) {
      final region = f['region'] as String;
      final related = ds.countries.where((c) {
        if (region == 'MENA')       return ['Iran','Israel','Yemen','Iraq','Syria','Lebanon','Saudi Arabia'].contains(c.name);
        if (region == 'Europe')     return ['Ukraine','Russia','Germany','Poland'].contains(c.name);
        if (region == 'East Asia')  return ['China','North Korea','South Korea','Japan'].contains(c.name);
        if (region == 'South Asia') return ['Pakistan','India','Afghanistan'].contains(c.name);
        if (region == 'LatAm')      return ['Venezuela','Colombia','Brazil'].contains(c.name);
        return false;
      }).toList();
      if (related.isNotEmpty) {
        final avg = related.map((c) => c.instabilityScore).reduce((a,b) => a+b) / related.length;
        f['prob'] = ((f['prob'] as int) + (avg * 0.08 - 4).round()).clamp(5, 95);
      }
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final all = _forecasts(ds);
    final filtered = all.where((f) =>
      (_cat == 'All' || f['cat'] == _cat) &&
      (_region == 'All Regions' || f['region'] == _region)
    ).toList();

    return GridPanel(
      title: 'AI FORECASTS',
      isLive: true,
      count: all.length,
      countColor: WMColors.accentGreen,
      onClose: () => context.read<DashboardProvider>().togglePanel(PanelId.aiForecasts),
      child: Column(children: [
        _buildFilters(),
        Expanded(child: ListView.builder(
          itemCount: filtered.length,
          padding: const EdgeInsets.all(6),
          itemBuilder: (_, i) => _ForecastCard(data: filtered[i]),
        )),
      ]),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: WMColors.border))),
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _cats.map((c) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: WMBtn(label: c, isActive: _cat == c, onTap: () => setState(() => _cat = c)),
          )).toList()),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _regions.map((r) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: WMBtn(label: r, isActive: _region == r, onTap: () => setState(() => _region = r)),
          )).toList()),
        ),
      ]),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ForecastCard({required this.data});

  Color get _color {
    final p = data['prob'] as int;
    if (p >= 60) return WMColors.accentRed;
    if (p >= 40) return WMColors.accentOrange;
    return WMColors.accentYellow;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: WMColors.bgHeader, border: Border.all(color: WMColors.border),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          color: _color.withOpacity(0.2),
          child: Text('${data['prob']}%', style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(data['title'] as String,
          style: const TextStyle(color: WMColors.textPrimary, fontSize: 9), maxLines: 2)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(1), child: LinearProgressIndicator(
        value: (data['prob'] as int) / 100, backgroundColor: WMColors.border,
        valueColor: AlwaysStoppedAnimation(_color), minHeight: 3,
      )),
      const SizedBox(height: 5),
      Row(children: [
        _Chip(label: data['cat'] as String, color: WMColors.accentPurple),
        const SizedBox(width: 4),
        _Chip(label: data['region'] as String, color: WMColors.accentBlue),
        const Spacer(),
        Text('${data['trend']} ${data['tf']}', style: TextStyle(color: _color, fontSize: 8, fontWeight: FontWeight.bold)),
      ]),
    ]),
  );
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(1)),
    child: Text(label, style: TextStyle(color: color, fontSize: 7)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY INSTABILITY
// ─────────────────────────────────────────────────────────────────────────────
class CountryInstabilityPanel extends StatelessWidget {
  const CountryInstabilityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final countries = List<CountryData>.from(ds.countries)
      ..sort((a, b) => b.instabilityScore.compareTo(a.instabilityScore));

    return GridPanel(
      title: 'COUNTRY INSTABILITY',
      isLive: true,
      onClose: () => context.read<DashboardProvider>().togglePanel(PanelId.countryInstability),
      headerActions: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(border: Border.all(color: WMColors.border), borderRadius: BorderRadius.circular(2)),
          child: const Icon(Icons.help_outline, color: WMColors.textMuted, size: 9),
        ),
      ],
      child: ListView.builder(
        padding: const EdgeInsets.all(6),
        itemCount: countries.length,
        itemBuilder: (_, i) => _CountryRow(country: countries[i]),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  final CountryData country;
  const _CountryRow({required this.country});

  Color get _color {
    final s = country.instabilityScore;
    if (s >= 75) return WMColors.accentRed;
    if (s >= 55) return WMColors.accentOrange;
    if (s >= 35) return WMColors.accentYellow;
    return WMColors.accentBlue;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(country.name,
          style: const TextStyle(color: WMColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w600))),
        Text('${country.instabilityScore} ${country.trend}',
          style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        const Icon(Icons.upload, color: WMColors.textMuted, size: 12),
      ]),
      const SizedBox(height: 3),
      ClipRRect(borderRadius: BorderRadius.circular(1), child: LinearProgressIndicator(
        value: country.instabilityScore / 100, backgroundColor: WMColors.border,
        valueColor: AlwaysStoppedAnimation(_color), minHeight: 4,
      )),
      const SizedBox(height: 2),
      Text(
        'U:${country.subScores['unrest']}  C:${country.subScores['conflict']}  S:${country.subScores['security']}  I:${country.subScores['information']}',
        style: const TextStyle(color: WMColors.textMuted, fontSize: 7, letterSpacing: 0.4),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STRATEGIC RISK OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────
class StrategicRiskPanel extends StatelessWidget {
  const StrategicRiskPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final ds       = context.watch<DataService>();
    final avgScore = ds.countries.isEmpty ? 50.0
        : ds.countries.map((c) => c.instabilityScore).reduce((a,b) => a+b) / ds.countries.length;
    final score = (avgScore + provider.globalRisk) / 2;

    return GridPanel(
      title: 'STRATEGIC RISK OVERVIEW',
      isLive: true,
      onClose: () => context.read<DashboardProvider>().togglePanel(PanelId.strategicRisk),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Expanded(child: _Gauge(score: score)),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(children: [
            const Text('TREND', style: TextStyle(color: WMColors.textSecond, fontSize: 8, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.arrow_forward, color: WMColors.accentBlue, size: 14),
              const SizedBox(width: 6),
              Text(provider.riskTrend,
                style: const TextStyle(color: WMColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Gauge extends StatelessWidget {
  final double score;
  const _Gauge({required this.score});
  Color get _color {
    if (score >= 70) return WMColors.accentRed;
    if (score >= 50) return WMColors.accentOrange;
    if (score >= 30) return WMColors.accentYellow;
    return WMColors.accentGreen;
  }
  String get _label {
    if (score >= 70) return 'HIGH';
    if (score >= 50) return 'ELEVATED';
    if (score >= 30) return 'MODERATE';
    return 'LOW';
  }
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GaugePainter(score: score, color: _color),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 24),
      Text('${score.round()}', style: TextStyle(
        color: _color, fontSize: 34, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      Text(_label, style: TextStyle(color: _color, fontSize: 10, letterSpacing: 1.5)),
    ])),
  );
}

class _GaugePainter extends CustomPainter {
  final double score; final Color color;
  _GaugePainter({required this.score, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.62;
    final r  = min(size.width, size.height) * 0.40;
    const sa = pi * 0.75;
    const sw = pi * 1.5;
    final base = Paint()..color = WMColors.border..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    final glow = Paint()..color = color.withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx,cy), radius: r), sa, sw, false, base);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx,cy), radius: r), sa, sw*(score/100), false, glow);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx,cy), radius: r), sa, sw*(score/100), false, fill);
  }
  @override bool shouldRepaint(_) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// AI STRATEGIC POSTURE
// ─────────────────────────────────────────────────────────────────────────────
class AiStrategicPosturePanel extends StatelessWidget {
  const AiStrategicPosturePanel({super.key});

  static const _theaters = [
    {'name':'Iran Theater',   'trend':'stable → Iran', 'assets':{'⚓':1,'✈':12}},
    {'name':'Baltic Theater', 'trend':'stable',        'assets':{'🇺🇸':4,'⚓':3,'🚢':9,'✈':187}},
    {'name':'South China Sea','trend':'escalating',    'assets':{'⚓':8,'✈':24}},
    {'name':'Ukraine Front',  'trend':'active',        'assets':{'🚀':340,'🛡':89}},
    {'name':'Red Sea',        'trend':'hot',           'assets':{'⚓':12,'✈':30}},
  ];

  @override
  Widget build(BuildContext context) => GridPanel(
    title: 'AI STRATEGIC POSTURE',
    count: 1,
    countColor: WMColors.accentOrange,
    onClose: () => context.read<DashboardProvider>().togglePanel(PanelId.aiStrategicPosture),
    headerActions: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(border: Border.all(color: WMColors.border), borderRadius: BorderRadius.circular(2)),
        child: const Icon(Icons.help_outline, color: WMColors.textMuted, size: 9),
      ),
    ],
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: WMColors.bgHeader, border: Border.all(color: WMColors.border), borderRadius: BorderRadius.circular(2)),
        child: const Row(children: [
          Icon(Icons.lightbulb_outline, color: WMColors.accentYellow, size: 12),
          SizedBox(width: 6),
          Text('Emoji Key', style: TextStyle(color: WMColors.textSecond, fontSize: 9)),
          Spacer(),
          Icon(Icons.chevron_right, color: WMColors.textMuted, size: 13),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          itemCount: _theaters.length,
          itemBuilder: (_, i) => _TheaterCard(data: _theaters[i]),
        ),
      ),
    ]),
  );
}

class _TheaterCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TheaterCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final assets = data['assets'] as Map<String, int>;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: WMColors.critBg, border: Border.all(color: WMColors.critBorder),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(data['name'] as String,
            style: const TextStyle(color: WMColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            color: WMColors.highAlert.withOpacity(0.25),
            child: const Text('CRIT', style: TextStyle(color: WMColors.highAlert, fontSize: 7, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 5),
        Wrap(spacing: 10, children: assets.entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(e.key, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text('${e.value}', style: const TextStyle(color: WMColors.textSecond, fontSize: 9)),
        ])).toList()),
        const SizedBox(height: 4),
        Text('→ ${data['trend']}', style: const TextStyle(color: WMColors.textMuted, fontSize: 8)),
      ]),
    );
  }
}
