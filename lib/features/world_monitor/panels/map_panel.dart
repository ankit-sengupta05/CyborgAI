// lib/panels/map_panel.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../wm_theme.dart';
import '../widgets/globe_3d.dart';
import '../services/dashboard_provider.dart';
import '../services/data_service.dart';

// ── Country conflict detail card data ────────────────────────────────────────
class ConflictDetail {
  final String name, level, startDate, casualties, displaced, location, summary;
  final List<String> belligerents, keyDevelopments;
  const ConflictDetail({
    required this.name,
    required this.level,
    required this.startDate,
    required this.casualties,
    required this.displaced,
    required this.location,
    required this.summary,
    required this.belligerents,
    required this.keyDevelopments,
  });
}

const _conflictDetails = <String, ConflictDetail>{
  'Sudan': ConflictDetail(
    name: 'SUDAN CIVIL WAR',
    level: 'HIGH',
    startDate: 'Apr 15, 2023',
    casualties: '150,000+ killed (est.)',
    displaced: '14M+ internally displaced, 3M+ refugees',
    location: 'Sudan (nationwide)',
    summary:
        'Power struggle between SAF and RSF paramilitary has engulfed the entire country. RSF controls most of Darfur and Khartoum; SAF holds Port Sudan and eastern regions. World\'s largest displacement crisis. Famine conditions in multiple states.',
    belligerents: [
      'SUDANESE ARMED FORCES (SAF)',
      'RAPID SUPPORT FORCES (RSF)',
      'ALLIED MILITIAS'
    ],
    keyDevelopments: [
      'Khartoum destruction',
      'Darfur ethnic massacres',
      'El Fasher siege',
      'Wad Madani fall to RSF',
      'Famine declared in North Darfur',
      'SAF counter-offensives',
      'Regional proxy involvement (UAE, Egypt)'
    ],
  ),
  'Ukraine': ConflictDetail(
    name: 'UKRAINE-RUSSIA WAR',
    level: 'HIGH',
    startDate: 'Feb 24, 2022',
    casualties: '500,000+ casualties (est.)',
    displaced: '8M+ refugees abroad',
    location: 'Eastern & Southern Ukraine',
    summary:
        'Full-scale Russian invasion continues. Front lines largely static in Zaporizhzhia, Kherson, Donetsk. Russia holds ~18% of Ukrainian territory. Drone warfare escalating on both sides. Nuclear plant risks remain.',
    belligerents: [
      'UKRAINE ARMED FORCES',
      'RUSSIAN FEDERATION',
      'NATO SUPPORT COALITION'
    ],
    keyDevelopments: [
      'Avdiivka capture',
      'Kharkiv front pressure',
      'F-16 deployment',
      'Kursk incursion',
      'Black Sea Fleet attrition',
      'Energy grid targeting'
    ],
  ),
  'Iran': ConflictDetail(
    name: 'IRAN-ISRAEL CONFLICT',
    level: 'CRITICAL',
    startDate: 'Oct 7, 2023',
    casualties: '50,000+ (est.)',
    displaced: '2M+ in Gaza',
    location: 'Gaza, Lebanon, Iran, Israel',
    summary:
        'Iran-Israel direct confrontation ongoing. Multiple missile exchanges. Hezbollah front active. US carrier groups repositioned. Hormuz shipping risk elevated. DEFCON raised.',
    belligerents: [
      'ISRAEL DEFENSE FORCES',
      'IRAN IRGC',
      'HEZBOLLAH',
      'HAMAS',
      'US CENTCOM'
    ],
    keyDevelopments: [
      'Direct Iran-Israel missile exchanges',
      'Lebanon ground operation',
      'Hezbollah degraded',
      'Red Sea Houthi attacks',
      'Gaza ceasefire collapse',
      'Nuclear facility threats'
    ],
  ),
  'Myanmar': ConflictDetail(
    name: 'MYANMAR CIVIL WAR',
    level: 'HIGH',
    startDate: 'Feb 1, 2021',
    casualties: '50,000+ killed',
    displaced: '3M+ internally displaced',
    location: 'Nationwide, Sagaing, Chin, Shan',
    summary:
        'Military junta losing ground to resistance forces. PDF and ethnic armies control large territories. Junta airstrikes on civilian areas escalating. Economy collapsed.',
    belligerents: [
      'MYANMAR MILITARY (SAC)',
      'PEOPLE\'S DEFENCE FORCE',
      'ETHNIC RESISTANCE ORGS'
    ],
    keyDevelopments: [
      'Brotherhood alliance advances',
      'Lashio capture',
      'Junta airstrikes on civilians',
      'China border trade impact',
      'Economic collapse'
    ],
  ),
  'Yemen': ConflictDetail(
    name: 'YEMEN / RED SEA CRISIS',
    level: 'ELEVATED',
    startDate: 'Mar 26, 2015',
    casualties: '377,000+ (incl. indirect)',
    displaced: '4.5M displaced',
    location: 'Yemen & Red Sea corridor',
    summary:
        'Houthi forces controlling Red Sea shipping lanes, disrupting global trade. Iran-backed attacks on commercial vessels. Coalition airstrikes ongoing. Humanitarian crisis continues.',
    belligerents: [
      'HOUTHI FORCES (ANSARALLAH)',
      'SAUDI-LED COALITION',
      'US/UK FORCES'
    ],
    keyDevelopments: [
      'Red Sea shipping blockade',
      'Commercial vessel attacks',
      'US/UK airstrikes on Houthis',
      'Oil tanker seizures',
      'Humanitarian access denied'
    ],
  ),
};

// ── Arc path data for animated 3D-style lines ─────────────────────────────
class ArcPath {
  final LatLng from, to;
  final Color color;
  final double intensity;
  ArcPath(
      {required this.from,
      required this.to,
      required this.color,
      required this.intensity});
}

class MapPanel extends StatefulWidget {
  const MapPanel({super.key});
  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> with TickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  bool _showLayers = true;
  String? _hoveredCountry;
  List<Map<String, dynamic>> _geoFeatures = [];
  bool _geoLoaded = false;

  // Arc animation
  late AnimationController _arcCtrl;
  late Animation<double> _arcAnim;

  // Layer toggles per variant
  final Map<MapVariant, Map<String, bool>> _layers = {
    MapVariant.world: {
      'IRAN ATTACKS': true,
      'INTEL HOTSPOTS': true,
      'CONFLICT ZONES': true,
      'MILITARY BASES': true,
      'NUCLEAR SITES': true,
      'GAMMA IRRADIATORS': false,
      'RADIATION WATCH': false,
      'SPACEPORTS': false,
    },
    MapVariant.tech: {
      'STARTUP HUBS': true,
      'TECH HQS': true,
      'ACCELERATORS': false,
      'CLOUD REGIONS': true,
      'AI DATA CENTERS': true,
      'UNDERSEA CABLES': true,
      'INTERNET DISRUPTIONS': true,
      'CYBER THREATS': false,
    },
    MapVariant.finance: {
      'STOCK EXCHANGES': true,
      'FINANCIAL CENTERS': true,
      'CENTRAL BANKS': true,
      'COMMODITY HUBS': false,
      'GCC INVESTMENTS': false,
      'TRADE ROUTES': true,
      'UNDERSEA CABLES': true,
      'PIPELINES': true,
    },
    MapVariant.commodity: {
      'MINING SITES': true,
      'PROCESSING PLANTS': true,
      'COMMODITY PORTS': true,
      'COMMODITY HUBS': true,
      'CRITICAL MINERALS': true,
      'PIPELINES': true,
      'CHOKEPOINTS': true,
      'TRADE ROUTES': true,
    },
    MapVariant.energy: {
      'PIPELINES': true,
      'STORAGE FACILITIES': true,
      'FUEL SHORTAGES': true,
      'CHOKEPOINTS': true,
      'COMMODITY PORTS': true,
      'COMMODITY HUBS': true,
      'SHIP TRAFFIC': true,
      'LIVE TANKER POSITIONS': true,
    },
    MapVariant.goodNews: {
      'POSITIVE EVENTS': true,
      'ACTS OF KINDNESS': true,
      'WORLD HAPPINESS': true,
      'RESILIENCE': false,
      'SPECIES RECOVERY': true,
      'CLEAN ENERGY': true,
    },
  };

  @override
  void initState() {
    super.initState();
    _arcCtrl =
        AnimationController(duration: const Duration(seconds: 3), vsync: this)
          ..repeat();
    _arcAnim = Tween(begin: 0.0, end: 1.0).animate(_arcCtrl);
    _loadGeoJson();
  }

  Future<void> _loadGeoJson() async {
    try {
      final raw =
          await rootBundle.loadString('assets/geojson/countries.geojson');
      final parsed = json.decode(raw) as Map<String, dynamic>;
      final features = parsed['features'] as List;
      setState(() {
        _geoFeatures = features.cast<Map<String, dynamic>>();
        _geoLoaded = true;
      });
    } catch (e) {
      setState(() => _geoLoaded = true); // proceed without GeoJSON
    }
  }

  @override
  void dispose() {
    _arcCtrl.dispose();
    super.dispose();
  }

  Map<String, bool> _currentLayers(MapVariant v) => _layers[v] ?? {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final ds = context.read<DataService>();
    final variant = provider.mapVariant;

    return Container(
      color: WMColors.bgPrimary,
      child: Column(children: [
        _buildHeader(provider, variant),
        Expanded(
            child: Stack(children: [
          provider.mapMode == '3D'
              ? Globe3D(variant: variant)
              : _buildMap(provider, ds, variant),
          _buildTimeFilter(provider),
          if (_showLayers) _buildLayersPanel(provider, variant),
          _buildLegend(variant),
          _buildZoomControls(),
          // Country detail panel (right side on click)
          if (provider.selectedCountry.isNotEmpty)
            _buildCountryDetailPanel(provider, ds),
        ])),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(DashboardProvider p, MapVariant v) {
    final title = v == MapVariant.goodNews
        ? 'GOOD NEWS MAP'
        : v == MapVariant.tech
            ? 'GLOBAL TECH'
            : 'GLOBAL SITUATION';
    return Container(
      height: 32,
      color: WMColors.bgHeader,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        Text(title,
            style: const TextStyle(
                color: WMColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
        const Spacer(),
        Text(_fmtDate(p.now),
            style: const TextStyle(color: WMColors.textSecond, fontSize: 9)),
        const Spacer(),
        _MapModeBtn(mode: p.mapMode, onChange: p.setMapMode),
        const SizedBox(width: 8),
        const Icon(Icons.fullscreen, color: WMColors.textMuted, size: 15),
        const SizedBox(width: 6),
        const Icon(Icons.push_pin_outlined,
            color: WMColors.textMuted, size: 13),
      ]),
    );
  }

  String _fmtDate(DateTime t) {
    final wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][t.weekday - 1];
    final mn = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ][t.month - 1];
    return '$wd, ${t.day.toString().padLeft(2, '0')} $mn ${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')} UTC';
  }

  // ── Main Map ─────────────────────────────────────────────────────────────
  Widget _buildMap(DashboardProvider p, DataService ds, MapVariant variant) {
    final tileUrl = variant == MapVariant.goodNews
        ? 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png'
        : 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: const LatLng(20, 20),
        initialZoom: 2.2,
        minZoom: 1.5,
        maxZoom: 12,
        backgroundColor: variant == MapVariant.goodNews
            ? const Color(0xFFe8f5e9)
            : const Color(0xFF050a10),
        onTap: (_, __) {
          p.selectCountry('');
        },
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.worldmonitor.app',
        ),

        // ── GeoJSON country polygons (hover + click highlight) ──
        if (_geoLoaded) _buildCountryPolygonLayer(p, ds),
        if (_geoLoaded) _buildCountryHoverLayer(p, ds),

        // ── Animated arc paths ──
        AnimatedBuilder(
          animation: _arcAnim,
          builder: (_, __) => PolylineLayer(polylines: _buildArcs(variant, ds)),
        ),

        // ── Conflict zone filled circles ──
        if (variant == MapVariant.world) _buildConflictCircles(p),

        // ── GDELT event markers ──
        if (variant == MapVariant.world) _buildGdeltMarkers(ds),

        // ── Earthquake markers ──
        if (variant == MapVariant.world) _buildEarthquakeMarkers(ds),

        // ── Variant-specific markers ──
        if (variant == MapVariant.tech) _buildTechMarkers(),
        if (variant == MapVariant.finance) _buildFinanceMarkers(),
        if (variant == MapVariant.commodity) _buildCommodityMarkers(),
        if (variant == MapVariant.energy) _buildEnergyMarkers(),
        if (variant == MapVariant.goodNews) _buildGoodNewsMarkers(),

        // ── Country dot markers ──
        MarkerLayer(
            markers: ds.countries.map((c) {
          final isSelected = p.selectedCountry == c.name;
          final isHovered = _hoveredCountry == c.name;
          final color = _scoreColor(c.instabilityScore, variant);
          final sz = isSelected
              ? 14.0
              : isHovered
                  ? 12.0
                  : 8.0;
          return Marker(
            point: LatLng(c.lat, c.lng),
            width: sz,
            height: sz,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoveredCountry = c.name),
              onExit: (_) => setState(() => _hoveredCountry = null),
              child: GestureDetector(
                onTap: () {
                  p.selectCountry(c.name);
                  // Zoom to country
                  _mapCtrl.move(LatLng(c.lat, c.lng), 5.0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: (isSelected || isHovered)
                        ? Border.all(
                            color: Colors.white, width: isSelected ? 2.5 : 1.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.7),
                                blurRadius: 10,
                                spreadRadius: 4)
                          ]
                        : isHovered
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 6,
                                    spreadRadius: 2)
                              ]
                            : null,
                  ),
                ),
              ),
            ),
          );
        }).toList()),
      ],
    );
  }

  // ── GeoJSON polygon layer ──────────────────────────────────────────────────
  PolygonLayer _buildCountryPolygonLayer(DashboardProvider p, DataService ds) {
    final polygons = <Polygon>[];
    final centroids = <Map<String, dynamic>>[];

    for (final feature in _geoFeatures) {
      final props = feature['properties'] as Map<String, dynamic>;
      final name = props['name'] as String? ?? '';
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final geoType = geometry['type'] as String;

      final isSelected = p.selectedCountry == name;
      final isHovered = _hoveredCountry == name;

      final countryData = ds.countries.where((c) => c.name == name).firstOrNull;
      final score =
          countryData?.instabilityScore ?? (props['defaultScore'] as int? ?? 0);
      final baseColor = _scoreColor(score, p.mapVariant);

      Color fillColor;
      Color borderColor;
      double borderWidth;
      if (isSelected) {
        fillColor = baseColor.withOpacity(0.55);
        borderColor = Colors.white.withOpacity(0.9);
        borderWidth = 2.5;
      } else if (isHovered) {
        fillColor = baseColor.withOpacity(0.40);
        borderColor = baseColor.withOpacity(0.85);
        borderWidth = 1.8;
      } else if (score > 40) {
        fillColor = baseColor.withOpacity(0.28);
        borderColor = baseColor.withOpacity(0.55);
        borderWidth = 1.0;
      } else if (score > 15) {
        fillColor = baseColor.withOpacity(0.15);
        borderColor = baseColor.withOpacity(0.35);
        borderWidth = 0.8;
      } else {
        fillColor = baseColor.withOpacity(0.06);
        borderColor = baseColor.withOpacity(0.18);
        borderWidth = 0.5;
      }

      List<List<dynamic>> rawCoordSets = [];
      if (geoType == 'Polygon') {
        rawCoordSets = [(geometry['coordinates'] as List)[0] as List];
      } else if (geoType == 'MultiPolygon') {
        for (final poly in (geometry['coordinates'] as List)) {
          rawCoordSets.add((poly as List)[0] as List);
        }
      }

      for (final rawCoords in rawCoordSets) {
        final points = rawCoords.map<LatLng>((pt) {
          final arr = pt as List;
          return LatLng((arr[1] as num).toDouble(), (arr[0] as num).toDouble());
        }).toList();
        if (points.length < 3) continue;
        polygons.add(Polygon(
          points: points,
          color: fillColor,
          borderColor: borderColor,
          borderStrokeWidth: borderWidth,
        ));
      }
    }

    return PolygonLayer(polygons: polygons);
  }

  // ── Hover/tap marker layer at country centroids ─────────────────────────────
  MarkerLayer _buildCountryHoverLayer(DashboardProvider p, DataService ds) {
    final centroids = <Map<String, dynamic>>[];
    for (final feature in _geoFeatures) {
      final props = feature['properties'] as Map<String, dynamic>;
      final name = props['name'] as String? ?? '';
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final geoType = geometry['type'] as String;
      List<List<dynamic>> coordSets = [];
      if (geoType == 'Polygon') {
        coordSets = [(geometry['coordinates'] as List)[0] as List];
      } else if (geoType == 'MultiPolygon') {
        for (final poly in (geometry['coordinates'] as List)) {
          coordSets.add((poly as List)[0] as List);
        }
      }
      double sumLat = 0, sumLng = 0;
      int cnt = 0;
      for (final coords in coordSets) {
        for (final pt in coords) {
          final arr = pt as List;
          sumLat += (arr[1] as num).toDouble();
          sumLng += (arr[0] as num).toDouble();
          cnt++;
        }
      }
      if (cnt > 0)
        centroids.add({'name': name, 'lat': sumLat / cnt, 'lng': sumLng / cnt});
    }
    return MarkerLayer(
      markers: centroids.map((c) {
        final name = c['name'] as String;
        return Marker(
          point: LatLng(c['lat'] as double, c['lng'] as double),
          width: 80,
          height: 50,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredCountry = name),
            onExit: (_) => setState(() => _hoveredCountry = null),
            child: GestureDetector(
              onTap: () {
                p.selectCountry(name);
                _mapCtrl.move(
                    LatLng(c['lat'] as double, c['lng'] as double), 4.5);
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Animated arc polylines (3D-style great circle paths) ─────────────────
  List<Polyline> _buildArcs(MapVariant variant, DataService ds) {
    final t = _arcAnim.value;
    switch (variant) {
      case MapVariant.world:
        return _worldArcs(ds, t);
      case MapVariant.tech:
        return _techArcs(t);
      case MapVariant.finance:
        return _financeArcs(t);
      case MapVariant.commodity:
        return _commodityArcs(t);
      case MapVariant.energy:
        return _energyArcs(t);
      default:
        return [];
    }
  }

  List<Polyline> _worldArcs(DataService ds, double t) {
    // Draw animated missile/drone arcs between conflict hotspots
    final arcs = [
      [const LatLng(35.7, 51.4), const LatLng(31.5, 34.5), WMColors.highAlert],
      [
        const LatLng(35.7, 51.4),
        const LatLng(33.9, 35.9),
        WMColors.accentOrange
      ],
      [
        const LatLng(15.5, 43.0),
        const LatLng(31.5, 34.5),
        WMColors.accentOrange
      ],
      [const LatLng(50.4, 30.5), const LatLng(55.7, 37.6), WMColors.accentRed],
      [
        const LatLng(38.9, -77.0),
        const LatLng(51.5, -0.1),
        WMColors.accentBlue
      ],
    ];
    return _animatedArcPolylines(arcs, t, strokeWidth: 1.5);
  }

  List<Polyline> _techArcs(double t) {
    final cables = [
      [const LatLng(40.7, -74.0), const LatLng(51.5, -0.1), WMColors.techCyan],
      [
        const LatLng(37.8, -122.4),
        const LatLng(35.7, 139.7),
        WMColors.techCyan
      ],
      [
        const LatLng(37.8, -122.4),
        const LatLng(1.3, 103.8),
        WMColors.accentGreen
      ],
      [const LatLng(51.5, -0.1), const LatLng(35.7, 139.7), WMColors.techCyan],
      [const LatLng(1.3, 103.8), const LatLng(51.5, -0.1), WMColors.accentCyan],
      [
        const LatLng(28.6, 77.2),
        const LatLng(1.3, 103.8),
        WMColors.accentGreen
      ],
      [
        const LatLng(23.1, 113.3),
        const LatLng(37.8, -122.4),
        WMColors.techCyan
      ],
      [
        const LatLng(40.7, -74.0),
        const LatLng(23.1, 113.3),
        WMColors.accentBlue
      ],
      [const LatLng(1.3, 103.8), const LatLng(35.7, 139.7), WMColors.techCyan],
      [const LatLng(51.5, -0.1), const LatLng(15.0, 42.0), WMColors.accentCyan],
      [
        const LatLng(15.0, 42.0),
        const LatLng(19.1, 72.9),
        WMColors.accentGreen
      ],
    ];
    return _animatedArcPolylines(cables, t, strokeWidth: 0.9, isDotted: false);
  }

  List<Polyline> _financeArcs(double t) {
    final routes = [
      [
        const LatLng(40.7, -74.0),
        const LatLng(51.5, -0.1),
        WMColors.financeGreen
      ],
      [
        const LatLng(40.7, -74.0),
        const LatLng(35.7, 139.7),
        WMColors.accentOrange
      ],
      [
        const LatLng(51.5, -0.1),
        const LatLng(35.7, 139.7),
        WMColors.accentBlue
      ],
      [
        const LatLng(37.8, -122.4),
        const LatLng(1.3, 103.8),
        WMColors.accentCyan
      ],
      [
        const LatLng(1.3, 103.8),
        const LatLng(51.5, -0.1),
        WMColors.financeGreen
      ],
      [
        const LatLng(19.1, 72.9),
        const LatLng(51.5, -0.1),
        WMColors.accentYellow
      ],
      [
        const LatLng(24.7, 46.7),
        const LatLng(48.9, 2.4),
        WMColors.accentOrange
      ],
      [
        const LatLng(23.1, 113.3),
        const LatLng(37.8, -122.4),
        WMColors.accentRed
      ],
      [
        const LatLng(-23.5, -46.6),
        const LatLng(51.5, -0.1),
        WMColors.financeGreen
      ],
    ];
    return _animatedArcPolylines(routes, t, strokeWidth: 0.8);
  }

  List<Polyline> _commodityArcs(double t) {
    final routes = [
      [
        const LatLng(27.0, 56.0),
        const LatLng(1.3, 103.8),
        WMColors.commodityOrange
      ],
      [const LatLng(27.0, 56.0), const LatLng(51.5, -0.1), WMColors.accentBlue],
      [
        const LatLng(-25.0, -50.0),
        const LatLng(51.5, -0.1),
        WMColors.accentGreen
      ],
      [
        const LatLng(15.0, 42.0),
        const LatLng(29.9, 32.5),
        WMColors.accentYellow
      ],
      [const LatLng(29.9, 32.5), const LatLng(36.0, 14.0), WMColors.accentCyan],
      [
        const LatLng(1.3, 103.8),
        const LatLng(35.7, 139.7),
        WMColors.commodityOrange
      ],
      [
        const LatLng(-25.0, 133.0),
        const LatLng(1.3, 103.8),
        WMColors.accentGreen
      ],
      [const LatLng(55.0, 82.0), const LatLng(52.5, 13.4), WMColors.accentRed],
      [
        const LatLng(-17.0, 25.0),
        const LatLng(51.5, -0.1),
        WMColors.accentPurple
      ],
      [
        const LatLng(40.0, -4.0),
        const LatLng(27.0, 10.0),
        WMColors.accentOrange
      ],
    ];
    return _animatedArcPolylines(routes, t, strokeWidth: 1.1);
  }

  List<Polyline> _energyArcs(double t) {
    final routes = [
      [
        const LatLng(55.0, 37.0),
        const LatLng(52.5, 13.4),
        WMColors.energyPurple
      ],
      [
        const LatLng(55.0, 37.0),
        const LatLng(46.0, 24.0),
        WMColors.energyPurple
      ],
      [
        const LatLng(40.0, 49.0),
        const LatLng(41.0, 29.0),
        WMColors.accentOrange
      ],
      [
        const LatLng(24.7, 46.7),
        const LatLng(29.9, 32.5),
        WMColors.accentYellow
      ],
      [
        const LatLng(27.0, 56.0),
        const LatLng(1.3, 103.8),
        WMColors.commodityOrange
      ],
      [
        const LatLng(56.0, -100.0),
        const LatLng(42.0, -87.0),
        WMColors.accentBlue
      ],
      [const LatLng(3.0, 8.0), const LatLng(30.0, 9.0), WMColors.accentGreen],
      [const LatLng(55.0, 82.0), const LatLng(43.0, 77.0), WMColors.accentRed],
    ];
    return _animatedArcPolylines(routes, t, strokeWidth: 1.3);
  }

  /// Build animated great-circle arc polylines with dash/travel effect
  List<Polyline> _animatedArcPolylines(List<List<dynamic>> routes, double t,
      {double strokeWidth = 1.0, bool isDotted = false}) {
    final result = <Polyline>[];
    for (int i = 0; i < routes.length; i++) {
      final from = routes[i][0] as LatLng;
      final to = routes[i][1] as LatLng;
      final color = routes[i][2] as Color;

      // Generate arc points (great circle approximation)
      final pts = _arcPoints(from, to, steps: 32);

      // Animated "travel" effect: show a segment traveling along the arc
      final offset = (t + i * 0.15) % 1.0;
      final segLen = 0.35; // segment length as fraction
      final segStart = offset;
      final segEnd = (offset + segLen).clamp(0.0, 1.0);

      final totalPts = pts.length;
      final startIdx = (segStart * totalPts).floor().clamp(0, totalPts - 1);
      final endIdx = (segEnd * totalPts).ceil().clamp(0, totalPts);

      if (endIdx > startIdx + 1) {
        // Faint full arc
        result.add(Polyline(
          points: pts,
          strokeWidth: strokeWidth * 0.4,
          color: color.withOpacity(0.2),
        ));
        // Bright moving segment
        result.add(Polyline(
          points: pts.sublist(startIdx, endIdx),
          strokeWidth: strokeWidth,
          color: color.withOpacity(0.85),
          gradientColors: [
            color.withOpacity(0.1),
            color,
            color.withOpacity(0.1)
          ],
        ));
      }
    }
    return result;
  }

  /// Generate intermediate points along a great-circle arc
  List<LatLng> _arcPoints(LatLng from, LatLng to, {int steps = 30}) {
    final pts = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final f = i / steps;
      // Simple linear interpolation with height offset for arc effect
      final lat = from.latitude + (to.latitude - from.latitude) * f;
      final lng = from.longitude + (to.longitude - from.longitude) * f;
      // Parabolic arc height
      final arcHeight = sin(f * pi) * 8.0;
      pts.add(LatLng(lat + arcHeight, lng));
    }
    return pts;
  }

  // ── Conflict zones ────────────────────────────────────────────────────────
  CircleLayer _buildConflictCircles(DashboardProvider p) {
    const zones = [
      [48.5, 31.0, 0xFFcc2222, 280000.0, 'Ukraine'],
      [15.0, 30.0, 0xFFcc2222, 250000.0, 'Sudan'],
      [32.0, 53.0, 0xFFcc3300, 240000.0, 'Iran'],
      [9.0, 40.0, 0xFFaa4400, 200000.0, 'Ethiopia'],
      [-3.0, 23.0, 0xFF886600, 230000.0, 'DRC'],
      [17.0, 96.0, 0xFF996600, 180000.0, 'Myanmar'],
      [34.8, 38.9, 0xFFaa2200, 140000.0, 'Syria'],
      [15.5, 47.0, 0xFFcc4400, 155000.0, 'Yemen'],
      [33.9, 67.7, 0xFF993300, 210000.0, 'Afghanistan'],
    ];
    return CircleLayer(
        circles: zones.map((z) {
      final isSelected = p.selectedCountry == z[4];
      return CircleMarker(
        point: LatLng(z[0] as double, z[1] as double),
        radius: z[3] as double,
        color: Color(z[2] as int).withOpacity(isSelected ? 0.45 : 0.28),
        borderColor: Color(z[2] as int).withOpacity(isSelected ? 0.9 : 0.55),
        borderStrokeWidth: isSelected ? 2.5 : 1.2,
        useRadiusInMeter: true,
      );
    }).toList());
  }

  // ── GDELT markers ─────────────────────────────────────────────────────────
  CircleLayer _buildGdeltMarkers(DataService ds) {
    return CircleLayer(
        circles: ds.gdeltEvents.map((ev) {
      final c = switch (ev.type) {
        'conflict' => WMColors.highAlert,
        'military' => WMColors.accentBlue,
        'unrest' => WMColors.elevated,
        _ => WMColors.monitoring,
      };
      return CircleMarker(
        point: LatLng(ev.lat, ev.lng),
        radius: (ev.intensity * 35000 + 8000).toDouble(),
        color: c.withOpacity(0.22),
        borderColor: c.withOpacity(0.55),
        borderStrokeWidth: 0.8,
        useRadiusInMeter: true,
      );
    }).toList());
  }

  // ── Earthquake markers ────────────────────────────────────────────────────
  MarkerLayer _buildEarthquakeMarkers(DataService ds) {
    return MarkerLayer(
        markers: ds.earthquakes.where((eq) => eq.magnitude >= 4.0).map((eq) {
      final sz = (eq.magnitude * 2.8).clamp(6.0, 18.0);
      return Marker(
        point: LatLng(eq.lat, eq.lng),
        width: sz,
        height: sz,
        child: Container(
            decoration: BoxDecoration(
          color: WMColors.accentPurple.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: WMColors.accentPurple, width: 1.2),
        )),
      );
    }).toList());
  }

  // ── Tech markers ──────────────────────────────────────────────────────────
  MarkerLayer _buildTechMarkers() {
    const hubs = [
      [37.8, -122.4, 137, 'SF', 0xFF00e5ff],
      [40.7, -74.0, 89, 'NYC', 0xFF00e5ff],
      [51.5, -0.1, 36, 'LON', 0xFF00e5ff],
      [52.5, 13.4, 12, 'BER', 0xFF8855ff],
      [48.9, 2.4, 18, 'PAR', 0xFF00e5ff],
      [35.7, 139.7, 29, 'TYO', 0xFF8855ff],
      [22.3, 114.2, 57, 'HKG', 0xFF8855ff],
      [1.3, 103.8, 25, 'SIN', 0xFF00ff88],
      [28.6, 77.2, 37, 'DEL', 0xFF00ff88],
      [37.0, -95.7, 11, 'CHI', 0xFF0088ff],
    ];
    return MarkerLayer(
        markers: hubs.map((h) {
      final color = Color(h[4] as int);
      return Marker(
          point: LatLng(h[0] as double, h[1] as double),
          width: 36,
          height: 28,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${h[2]}',
                style: TextStyle(
                    color: color, fontSize: 8, fontWeight: FontWeight.bold)),
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.4),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.4))),
          ]));
    }).toList());
  }

  // ── Finance markers ───────────────────────────────────────────────────────
  MarkerLayer _buildFinanceMarkers() {
    const centers = [
      [40.7, -74.0, 'NYSE', 0xFFff9500],
      [51.5, -0.1, 'LSE', 0xFF00ff66],
      [35.7, 139.7, 'TSE', 0xFF0088ff],
      [22.3, 114.2, 'HKEX', 0xFFff9500],
      [23.1, 113.3, 'SSE', 0xFFff4444],
      [1.3, 103.8, 'SGX', 0xFF00ff66],
      [48.9, 2.4, 'ENX', 0xFF0088ff],
      [19.1, 72.9, 'BSE', 0xFFff9500],
      [25.3, 55.3, 'DFM', 0xFFffcc00],
      [52.5, 13.4, 'XET', 0xFF0088ff],
    ];
    return MarkerLayer(
        markers: centers.map((c) {
      final color = Color(c[3] as int);
      return Marker(
          point: LatLng(c[0] as double, c[1] as double),
          width: 44,
          height: 26,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(c[2] as String,
                style: TextStyle(
                    color: color, fontSize: 7, fontWeight: FontWeight.bold)),
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.4))),
          ]));
    }).toList());
  }

  // ── Commodity markers ─────────────────────────────────────────────────────
  MarkerLayer _buildCommodityMarkers() {
    const sites = [
      [27.0, 56.0, 'HORMUZ', 'orange'],
      [1.3, 103.8, 'MALACCA', 'orange'],
      [29.9, 32.5, 'SUEZ', 'yellow'],
      [12.6, 43.1, 'BABELM', 'yellow'],
      [56.0, -100.0, 'ATHABASCA', 'red'],
      [-25.0, -50.0, 'SANTOS', 'green'],
      [-25.0, 133.0, 'PILBARA', 'cyan'],
      [68.0, 26.0, 'KOLA', 'purple'],
      [-17.0, 25.0, 'COPPERBELT', 'orange'],
      [5.5, -1.0, 'ACCRA', 'green'],
    ];
    return MarkerLayer(
        markers: sites.map((s) {
      final col = s[3] == 'orange'
          ? WMColors.commodityOrange
          : s[3] == 'yellow'
              ? WMColors.accentYellow
              : s[3] == 'red'
                  ? WMColors.accentRed
                  : s[3] == 'green'
                      ? WMColors.accentGreen
                      : s[3] == 'cyan'
                          ? WMColors.accentCyan
                          : WMColors.energyPurple;
      return Marker(
          point: LatLng(s[0] as double, s[1] as double),
          width: 50,
          height: 22,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(s[2] as String,
                style: TextStyle(
                    color: col, fontSize: 6, fontWeight: FontWeight.bold)),
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: col.withOpacity(0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: col, width: 1.4))),
          ]));
    }).toList());
  }

  // ── Energy markers ────────────────────────────────────────────────────────
  MarkerLayer _buildEnergyMarkers() {
    const fac = [
      [27.0, 56.0, 'HORMUZ', 12, 'orange'],
      [1.3, 103.8, 'MALACCA', 15, 'cyan'],
      [29.9, 32.5, 'SUEZ', 6, 'yellow'],
      [24.7, 46.7, 'RIYADH', 11, 'orange'],
      [59.9, 30.3, 'ST PETE', 7, 'red'],
      [29.8, -95.4, 'HOUSTON', 10, 'yellow'],
    ];
    return MarkerLayer(
        markers: fac.map((f) {
      final col = f[4] == 'orange'
          ? WMColors.commodityOrange
          : f[4] == 'yellow'
              ? WMColors.accentYellow
              : f[4] == 'cyan'
                  ? WMColors.accentCyan
                  : f[4] == 'purple'
                      ? WMColors.energyPurple
                      : WMColors.accentRed;
      return Marker(
          point: LatLng(f[0] as double, f[1] as double),
          width: 50,
          height: 24,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(f[2] as String,
                style: TextStyle(
                    color: col, fontSize: 6, fontWeight: FontWeight.bold)),
            Text('${f[3]}%',
                style: TextStyle(color: col.withOpacity(0.6), fontSize: 6)),
          ]));
    }).toList());
  }

  // ── Good news markers ─────────────────────────────────────────────────────
  MarkerLayer _buildGoodNewsMarkers() {
    const events = [
      [56.1, -106.3, 'CA', 'positive'],
      [51.2, 10.5, 'DE', 'energy'],
      [60.5, 8.0, 'NO', 'energy'],
      [56.0, 9.0, 'DK', 'energy'],
      [60.0, 25.0, 'FI', 'positive'],
      [1.3, 103.8, 'SG', 'positive'],
      [-33.9, 151.2, 'AU', 'recovery'],
      [-41.3, 174.8, 'NZ', 'recovery'],
      [37.1, -95.7, 'US', 'energy'],
      [-14.2, -51.9, 'BR', 'recovery'],
    ];
    return MarkerLayer(
        markers: events.map((e) {
      final col = e[3] == 'positive'
          ? WMColors.goodNewsGreen
          : e[3] == 'energy'
              ? WMColors.accentYellow
              : WMColors.accentCyan;
      return Marker(
          point: LatLng(e[0] as double, e[1] as double),
          width: 12,
          height: 12,
          child: Container(
              decoration: BoxDecoration(
                  color: col.withOpacity(0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: col, width: 1.4))));
    }).toList());
  }

  Color _scoreColor(int score, MapVariant variant) {
    if (variant == MapVariant.goodNews) return WMColors.goodNewsGreen;
    if (score >= 75) return WMColors.highAlert;
    if (score >= 55) return WMColors.elevated;
    if (score >= 35) return WMColors.monitoring;
    if (score >= 15) return WMColors.accentBlue;
    return const Color(0xFF334466);
  }

  // ── Country detail panel (right side) ────────────────────────────────────
  Widget _buildCountryDetailPanel(DashboardProvider p, DataService ds) {
    final countryData =
        ds.countries.where((c) => c.name == p.selectedCountry).firstOrNull;
    final conflictDetail = _conflictDetails[p.selectedCountry];

    if (conflictDetail != null) {
      return _buildConflictDetailCard(p, conflictDetail, countryData);
    }
    return _buildCountryIntelCard(p, ds, countryData);
  }

  Widget _buildConflictDetailCard(
      DashboardProvider p, ConflictDetail d, CountryData? c) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 340,
      child: Container(
        color: WMColors.bgPanel.withOpacity(0.97),
        child: Column(children: [
          // Header - fixed height to prevent overflow
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: WMColors.border))),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                  child: Text(d.name,
                      style: const TextStyle(
                          color: WMColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: d.level == 'CRITICAL'
                    ? WMColors.highAlert.withOpacity(0.3)
                    : WMColors.accentOrange.withOpacity(0.3),
                child: Text(d.level,
                    style: TextStyle(
                        color: d.level == 'CRITICAL'
                            ? WMColors.highAlert
                            : WMColors.accentOrange,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () => p.selectCountry(''),
                  child: const Icon(Icons.close,
                      color: WMColors.textMuted, size: 16)),
            ]),
          ),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Stats grid
              Row(children: [
                Expanded(
                    child: _InfoBox(label: 'START DATE', value: d.startDate)),
                const SizedBox(width: 8),
                Expanded(
                    child: _InfoBox(
                        label: 'CASUALTIES',
                        value: d.casualties,
                        color: WMColors.accentRed)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _InfoBox(label: 'DISPLACED', value: d.displaced)),
                const SizedBox(width: 8),
                Expanded(child: _InfoBox(label: 'LOCATION', value: d.location)),
              ]),
              const SizedBox(height: 12),
              // Summary
              Text(d.summary,
                  style: const TextStyle(
                      color: WMColors.textPrimary, fontSize: 10, height: 1.6)),
              const SizedBox(height: 14),
              // Belligerents
              const Text('▾ BELLIGERENTS',
                  style: TextStyle(
                      color: WMColors.textSecond,
                      fontSize: 8,
                      letterSpacing: 1.0)),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: d.belligerents
                      .map((b) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            color: WMColors.bgHeader,
                            child: Text(b,
                                style: const TextStyle(
                                    color: WMColors.textSecond, fontSize: 8)),
                          ))
                      .toList()),
              const SizedBox(height: 14),
              // Key developments
              const Text('▾ KEY DEVELOPMENTS',
                  style: TextStyle(
                      color: WMColors.textSecond,
                      fontSize: 8,
                      letterSpacing: 1.0)),
              const SizedBox(height: 6),
              ...d.keyDevelopments.map((dev) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  color: WMColors.accentRed, fontSize: 10)),
                          Expanded(
                              child: Text(dev,
                                  style: const TextStyle(
                                      color: WMColors.textPrimary,
                                      fontSize: 9))),
                        ]),
                  )),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildCountryIntelCard(
      DashboardProvider p, DataService ds, CountryData? c) {
    if (c == null) return const SizedBox.shrink();
    final color = _scoreColor(c.instabilityScore, p.mapVariant);
    final relatedNews = ds.news
        .where((n) =>
            n.title.toLowerCase().contains(c.name.toLowerCase()) ||
            n.title.toLowerCase().contains(c.iso2.toLowerCase()))
        .take(5)
        .toList();

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 320,
      child: Container(
        color: WMColors.bgPanel.withOpacity(0.97),
        child: Column(children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: WMColors.border))),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 30,
                height: 20,
                decoration:
                    BoxDecoration(border: Border.all(color: WMColors.border)),
                alignment: Alignment.center,
                child: Text(c.iso2,
                    style: const TextStyle(
                        color: WMColors.textPrimary,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text(c.name,
                        style: const TextStyle(
                            color: WMColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${c.iso2} · Country Intelligence',
                        style: const TextStyle(
                            color: WMColors.textSecond, fontSize: 9)),
                  ])),
              GestureDetector(
                  onTap: () => p.selectCountry(''),
                  child: const Icon(Icons.close,
                      color: WMColors.textMuted, size: 16)),
            ]),
          ),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Instability Index',
                  style: TextStyle(color: WMColors.textSecond, fontSize: 9)),
              const SizedBox(height: 4),
              Row(children: [
                Text('${c.instabilityScore}/100',
                    style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${c.trend} ${c.level.toLowerCase()}',
                    style: const TextStyle(
                        color: WMColors.textSecond, fontSize: 10)),
              ]),
              const SizedBox(height: 12),
              _ScoreRow(
                  label: 'Unrest',
                  val: c.subScores['unrest'] ?? 0,
                  color: WMColors.accentOrange),
              _ScoreRow(
                  label: 'Conflict',
                  val: c.subScores['conflict'] ?? 0,
                  color: WMColors.accentBlue),
              _ScoreRow(
                  label: 'Security',
                  val: c.subScores['security'] ?? 0,
                  color: WMColors.accentYellow),
              _ScoreRow(
                  label: 'Information',
                  val: c.subScores['information'] ?? 0,
                  color: WMColors.accentGreen),
              const SizedBox(height: 12),
              const Text('RESILIENCE SCORE',
                  style: TextStyle(
                      color: WMColors.textSecond,
                      fontSize: 8,
                      letterSpacing: 1.0)),
              const SizedBox(height: 4),
              ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                      value: (100 - c.instabilityScore) / 100,
                      backgroundColor: WMColors.border,
                      valueColor:
                          const AlwaysStoppedAnimation(WMColors.accentGreen),
                      minHeight: 8)),
              const SizedBox(height: 4),
              Text('${100 - c.instabilityScore}/100',
                  style: const TextStyle(
                      color: WMColors.accentGreen, fontSize: 9)),
              if (relatedNews.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('RELATED EVENTS',
                    style: TextStyle(
                        color: WMColors.textSecond,
                        fontSize: 8,
                        letterSpacing: 1.0)),
                const SizedBox(height: 6),
                ...relatedNews.map((n) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: WMColors.bgHeader,
                          border: Border.all(color: WMColors.border)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                color: (n.isBreaking
                                        ? WMColors.accentRed
                                        : WMColors.accentBlue)
                                    .withOpacity(0.3),
                                child: Text(n.isBreaking ? 'HIGH' : 'LOW',
                                    style: TextStyle(
                                        color: n.isBreaking
                                            ? WMColors.accentRed
                                            : WMColors.accentBlue,
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                  n.publishedAt.length > 15
                                      ? 'recent'
                                      : n.publishedAt,
                                  style: const TextStyle(
                                      color: WMColors.textMuted, fontSize: 7)),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                                '${n.title.substring(0, n.title.length.clamp(0, 90))}...',
                                style: const TextStyle(
                                    color: WMColors.textPrimary, fontSize: 9),
                                maxLines: 2),
                          ]),
                    )),
              ],
            ]),
          )),
        ]),
      ),
    );
  }

  // ── UI controls ───────────────────────────────────────────────────────────
  Widget _buildTimeFilter(DashboardProvider p) => Positioned(
        top: 10,
        left: 10,
        child: Container(
          decoration: BoxDecoration(
              color: WMColors.bgHeader.withOpacity(0.92),
              border: Border.all(color: WMColors.border),
              borderRadius: BorderRadius.circular(2)),
          child: Row(
              children: ['1h', '6h', '24h', '48h', '7d', 'All']
                  .map((t) => GestureDetector(
                        onTap: () => p.setTimeFilter(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                              color: p.timeFilter == t
                                  ? WMColors.accentGreen
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(2)),
                          child: Text(t,
                              style: TextStyle(
                                  color: p.timeFilter == t
                                      ? Colors.black
                                      : WMColors.textSecond,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ))
                  .toList()),
        ),
      );

  Widget _buildLayersPanel(DashboardProvider p, MapVariant variant) {
    final layers = _currentLayers(variant);
    return Positioned(
      top: 44,
      left: 10,
      child: Container(
        width: 200,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
            color: WMColors.bgPanel.withOpacity(0.95),
            border: Border.all(color: WMColors.border)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    const Text('LAYERS',
                        style: TextStyle(
                            color: WMColors.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    const SizedBox(width: 6),
                    Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            border: Border.all(color: WMColors.borderLight),
                            borderRadius: BorderRadius.circular(2)),
                        child: const Icon(Icons.help_outline,
                            color: WMColors.textMuted, size: 8)),
                    const Spacer(),
                    GestureDetector(
                        onTap: () => setState(() => _showLayers = false),
                        child: const Icon(Icons.filter_list,
                            color: WMColors.textMuted, size: 12)),
                  ])),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                        border: Border.all(color: WMColors.border),
                        borderRadius: BorderRadius.circular(2)),
                    child: const TextField(
                        style:
                            TextStyle(color: WMColors.textSecond, fontSize: 9),
                        decoration: InputDecoration(
                            hintText: 'Search layers...',
                            hintStyle: TextStyle(
                                color: WMColors.textMuted, fontSize: 9),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            isDense: true)),
                  )),
              const SizedBox(height: 4),
              Flexible(
                  child: SingleChildScrollView(
                      child: Column(
                children: layers.entries
                    .map((e) => GestureDetector(
                          onTap: () => setState(() => layers[e.key] = !e.value),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              child: Row(children: [
                                Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                        color: e.value
                                            ? WMColors.accentGreen
                                            : Colors.transparent,
                                        border: Border.all(
                                            color: e.value
                                                ? WMColors.accentGreen
                                                : WMColors.borderLight),
                                        borderRadius: BorderRadius.circular(2)),
                                    child: e.value
                                        ? const Icon(Icons.check,
                                            size: 9, color: Colors.black)
                                        : null),
                                const SizedBox(width: 6),
                                const Icon(Icons.layers,
                                    color: WMColors.accentGreen, size: 10),
                                const SizedBox(width: 6),
                                Text(e.key,
                                    style: const TextStyle(
                                        color: WMColors.textSecond,
                                        fontSize: 8)),
                              ])),
                        ))
                    .toList(),
              ))),
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: WMColors.border))),
                  child: Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: WMColors.accentGreen,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Elie Habib · Someone™',
                        style: TextStyle(
                            color: WMColors.accentGreen, fontSize: 8)),
                  ])),
            ]),
      ),
    );
  }

  Widget _buildLegend(MapVariant variant) {
    final items = switch (variant) {
      MapVariant.goodNews => [
          [WMColors.goodNewsGreen, 'Positive Event'],
          [WMColors.accentYellow, 'Breakthrough'],
          [WMColors.accentBlue, 'Act of Kindness'],
          [WMColors.accentCyan, 'Species Recovery'],
        ],
      MapVariant.tech => [
          [WMColors.techCyan, 'Startup Hub'],
          [WMColors.accentPurple, 'Tech HQ'],
          [WMColors.accentGreen, 'Cloud Region'],
          [WMColors.accentBlue, 'Datacenter'],
        ],
      MapVariant.finance => [
          [WMColors.accentOrange, 'Stock Exchange'],
          [WMColors.financeGreen, 'Financial Center'],
          [WMColors.accentYellow, 'Central Bank'],
          [WMColors.accentBlue, 'Waterway'],
        ],
      MapVariant.commodity => [
          [WMColors.commodityOrange, 'Commodity Hub'],
          [WMColors.accentRed, 'Mining Site'],
          [WMColors.accentBlue, 'Commodity Port'],
          [WMColors.accentYellow, 'Pipeline'],
          [WMColors.accentPurple, 'Processing Plant'],
        ],
      MapVariant.energy => [
          [WMColors.commodityOrange, 'Chokepoint'],
          [WMColors.energyPurple, 'Pipeline'],
          [WMColors.accentYellow, 'Storage'],
          [WMColors.accentCyan, 'Port'],
        ],
      _ => [
          [WMColors.highAlert, 'High Alert'],
          [WMColors.elevated, 'Elevated'],
          [WMColors.monitoring, 'Monitoring'],
          [WMColors.conflictZone, 'Conflict Zone'],
          [WMColors.baseMarker, 'Base'],
          [WMColors.nuclearMarker, 'Nuclear'],
        ],
    };
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Center(
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: WMColors.bgHeader.withOpacity(0.92),
            border: Border.all(color: WMColors.border),
            borderRadius: BorderRadius.circular(2)),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items
                .expand<Widget>((item) => [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: item[0] as Color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(item[1] as String,
                          style: const TextStyle(
                              color: WMColors.textSecond, fontSize: 8)),
                      const SizedBox(width: 12),
                    ])
                .toList()),
      )),
    );
  }

  Widget _buildZoomControls() => Positioned(
        top: 10,
        right: 10,
        child: Column(children: [
          _ZBtn(
              icon: Icons.add,
              onTap: () => _mapCtrl.move(
                  _mapCtrl.camera.center, _mapCtrl.camera.zoom + 1)),
          const SizedBox(height: 3),
          _ZBtn(
              icon: Icons.remove,
              onTap: () => _mapCtrl.move(
                  _mapCtrl.camera.center, _mapCtrl.camera.zoom - 1)),
          const SizedBox(height: 8),
          _ZBtn(
              icon: Icons.home_outlined,
              onTap: () => _mapCtrl.move(const LatLng(20, 20), 2.2)),
        ]),
      );
}

class _ZBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: WMColors.bgHeader.withOpacity(0.92),
              border: Border.all(color: WMColors.border),
              borderRadius: BorderRadius.circular(2)),
          child: Icon(icon, color: WMColors.textSecond, size: 14)));
}

class _MapModeBtn extends StatelessWidget {
  final String mode;
  final Function(String) onChange;
  const _MapModeBtn({required this.mode, required this.onChange});
  @override
  Widget build(BuildContext ctx) => Container(
        decoration: BoxDecoration(
            border: Border.all(color: WMColors.border),
            borderRadius: BorderRadius.circular(2)),
        child: Row(
            children: ['2D', '3D']
                .map((m) => GestureDetector(
                      onTap: () => onChange(m),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: mode == m
                                  ? WMColors.accentGreen
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(2)),
                          child: Text(m,
                              style: TextStyle(
                                  color: mode == m
                                      ? Colors.black
                                      : WMColors.textSecond,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold))),
                    ))
                .toList()),
      );
}

class _InfoBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoBox(
      {required this.label,
      required this.value,
      this.color = WMColors.textPrimary});
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: WMColors.bgHeader,
            border: Border.all(color: WMColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: WMColors.textSecond, fontSize: 7, letterSpacing: 0.8)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Score bar row helper ──────────────────────────────────────────────────────
class _ScoreRow extends StatelessWidget {
  final String label;
  final int val;
  final Color color;
  const _ScoreRow(
      {required this.label, required this.val, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: const TextStyle(
                      color: WMColors.textSecond, fontSize: 9))),
          Expanded(
              child: ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: val / 100,
              backgroundColor: WMColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          )),
          const SizedBox(width: 6),
          SizedBox(
              width: 24,
              child: Text('$val',
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
      );
}
