// lib/services/data_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class NewsArticle {
  final String title;
  final String source;
  final String url;
  final String publishedAt;
  final String category;
  final bool isBreaking;
  final String description;

  NewsArticle({
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    this.category = 'GENERAL',
    this.isBreaking = false,
    this.description = '',
  });

  factory NewsArticle.fromGdelt(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? '';
    final domain = json['domain'] as String? ?? 'unknown';
    final url = json['url'] as String? ?? '';
    final seenDate = json['seendate'] as String? ?? '';
    return NewsArticle(
      title: title,
      source: domain.toUpperCase().replaceAll('.COM', '').replaceAll('.NET', ''),
      url: url,
      publishedAt: seenDate,
      category: _categorize(title),
      isBreaking: _isBreaking(title),
      description: json['socialimage'] as String? ?? '',
    );
  }

  static String _categorize(String title) {
    final t = title.toLowerCase();
    if (t.contains('iran') || t.contains('attack') || t.contains('strike') || t.contains('missile')) return 'CONFLICT';
    if (t.contains('ukraine') || t.contains('russia') || t.contains('military') || t.contains('war')) return 'MILITARY';
    if (t.contains('market') || t.contains('stock') || t.contains('economy') || t.contains('dollar')) return 'MARKETS';
    if (t.contains('cyber') || t.contains('hack') || t.contains('breach')) return 'CYBER';
    if (t.contains('disaster') || t.contains('earthquake') || t.contains('flood') || t.contains('hurricane')) return 'DISASTER';
    if (t.contains('china') || t.contains('taiwan') || t.contains('asia')) return 'GEOPOLITICS';
    if (t.contains('nuclear') || t.contains('radiation') || t.contains('bomb')) return 'NUCLEAR';
    if (t.contains('health') || t.contains('disease') || t.contains('pandemic') || t.contains('virus')) return 'HEALTH';
    return 'INTEL';
  }

  static bool _isBreaking(String title) {
    final t = title.toLowerCase();
    return t.contains('breaking') || t.contains('urgent') || t.contains('alert') || t.contains('just in');
  }
}

class CountryData {
  final String name;
  final String iso2;
  final String iso3;
  final double lat;
  final double lng;
  int instabilityScore;
  String trend;
  String level;
  Map<String, int> subScores;

  CountryData({
    required this.name,
    required this.iso2,
    required this.iso3,
    required this.lat,
    required this.lng,
    this.instabilityScore = 0,
    this.trend = '→',
    this.level = 'LOW',
    Map<String, int>? subScores,
  }) : subScores = subScores ?? {'unrest': 0, 'conflict': 0, 'security': 0, 'information': 0};
}

class EarthquakeEvent {
  final double lat;
  final double lng;
  final double magnitude;
  final String place;
  final DateTime time;

  EarthquakeEvent({
    required this.lat,
    required this.lng,
    required this.magnitude,
    required this.place,
    required this.time,
  });
}

class GdeltEvent {
  final double lat;
  final double lng;
  final String title;
  final String type;
  final double intensity;
  final DateTime time;

  GdeltEvent({
    required this.lat,
    required this.lng,
    required this.title,
    required this.type,
    required this.intensity,
    required this.time,
  });
}

class DataService extends ChangeNotifier {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  List<NewsArticle> _news = [];
  List<EarthquakeEvent> _earthquakes = [];
  List<GdeltEvent> _gdeltEvents = [];
  List<CountryData> _countries = _buildDefaultCountries();
  bool _loading = false;
  String? _error;
  Timer? _refreshTimer;
  DateTime _lastUpdate = DateTime.now();
  bool _isDisposed = false;

  List<NewsArticle> get news => _news;
  List<EarthquakeEvent> get earthquakes => _earthquakes;
  List<GdeltEvent> get gdeltEvents => _gdeltEvents;
  List<CountryData> get countries => _countries;
  bool get loading => _loading;
  String? get error => _error;
  DateTime get lastUpdate => _lastUpdate;

  DataService() {
    _initData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refreshAll());
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _initData() async {
    await Future.wait([
      fetchNews(),
      fetchEarthquakes(),
      _simulateGdeltEvents(),
    ]);
    _updateCountryScores();
  }

  Future<void> _refreshAll() async {
    await _initData();
  }

  /// GDELT GKG API – free, no key required
  Future<void> fetchNews() async {
    try {
      _loading = true;
      _safeNotifyListeners();

      // GDELT Project free API
      final url = 'https://api.gdeltproject.org/api/v2/doc/doc?query=conflict+OR+geopolitics+OR+military+OR+iran&mode=artlist&maxrecords=50&format=json&timespan=1d&sort=hybridrel';
      final resp = await _dio.get(url);
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
        final articles = data['articles'] as List? ?? [];
        _news = articles.map((a) => NewsArticle.fromGdelt(a as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      // Fallback: generate realistic simulated news
      _news = _simulatedNews();
    } finally {
      _loading = false;
      _lastUpdate = DateTime.now();
      _safeNotifyListeners();
    }
  }

  /// USGS Earthquake API – free, no key
  Future<void> fetchEarthquakes() async {
    try {
      final url = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_week.geojson';
      final resp = await _dio.get(url);
      if (resp.statusCode == 200) {
        final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
        final features = data['features'] as List? ?? [];
        _earthquakes = features.map((f) {
          final props = f['properties'] as Map;
          final coords = (f['geometry']['coordinates'] as List);
          return EarthquakeEvent(
            lng: (coords[0] as num).toDouble(),
            lat: (coords[1] as num).toDouble(),
            magnitude: (props['mag'] as num?)?.toDouble() ?? 2.5,
            place: props['place'] as String? ?? '',
            time: DateTime.fromMillisecondsSinceEpoch(props['time'] as int),
          );
        }).toList();
      }
    } catch (_) {
      _earthquakes = [];
    }
  }

  Future<void> _simulateGdeltEvents() async {
    // Simulate GDELT conflict events with realistic locations
    final rng = Random();
    final hotspots = [
      [32.1, 34.8, 'Israel-Lebanon Tension', 'conflict', 0.9],
      [35.7, 51.4, 'Iran Military Activity', 'conflict', 0.95],
      [50.4, 30.5, 'Ukraine Front Line', 'conflict', 0.85],
      [48.0, 37.5, 'Donetsk Artillery', 'conflict', 0.9],
      [31.5, 34.5, 'Gaza Strip', 'conflict', 0.92],
      [15.3, 38.9, 'Eritrea Alert', 'unrest', 0.6],
      [3.5, 26.5, 'South Sudan Crisis', 'unrest', 0.75],
      [12.4, 15.4, 'Chad Lake Basin', 'disaster', 0.5],
      [37.9, 32.9, 'Turkey-Syria Border', 'military', 0.65],
      [39.0, 125.8, 'DPRK Activity', 'military', 0.7],
      [28.6, 77.2, 'India-Pakistan Border', 'military', 0.55],
      [24.9, 67.0, 'Karachi Unrest', 'unrest', 0.5],
      [9.0, 38.7, 'Ethiopia Conflict', 'conflict', 0.75],
      [1.3, 103.8, 'Singapore Naval', 'military', 0.4],
      [10.5, -66.9, 'Venezuela Crisis', 'unrest', 0.6],
      [4.4, 18.6, 'CAR Conflict', 'conflict', 0.7],
      [16.8, 43.0, 'Yemen Strike', 'conflict', 0.8],
      [17.0, 96.0, 'Myanmar Coup Area', 'conflict', 0.78],
      // Add more with some randomness
      for (int i = 0; i < 40; i++) ...[
        [
          (rng.nextDouble() * 80 - 30),
          (rng.nextDouble() * 340 - 170),
          'Intel Event #$i',
          ['conflict', 'unrest', 'military', 'disaster'][rng.nextInt(4)],
          rng.nextDouble() * 0.8 + 0.1,
        ]
      ],
    ];

    _gdeltEvents = hotspots.map((h) => GdeltEvent(
      lat: (h[0] as num).toDouble(),
      lng: (h[1] as num).toDouble(),
      title: h[2] as String,
      type: h[3] as String,
      intensity: (h[4] as num).toDouble(),
      time: DateTime.now().subtract(Duration(hours: rng.nextInt(168))),
    )).toList();
  }

  void _updateCountryScores() {
    final rng = Random();
    // Dynamically score countries based on GDELT events nearby
    for (final country in _countries) {
      int score = 0;
      int eventCount = 0;
      for (final ev in _gdeltEvents) {
        final dist = _haversine(country.lat, country.lng, ev.lat, ev.lng);
        if (dist < 800) {
          score += (ev.intensity * 30 * (1 - dist / 800)).round();
          eventCount++;
        }
      }
      // Add earthquake contribution
      for (final eq in _earthquakes) {
        final dist = _haversine(country.lat, country.lng, eq.lat, eq.lng);
        if (dist < 500 && eq.magnitude > 4.5) {
          score += ((eq.magnitude - 4.5) * 8).round();
        }
      }
      country.instabilityScore = (score + rng.nextInt(15)).clamp(0, 100);
      country.trend = rng.nextDouble() > 0.5 ? '↑' : (rng.nextDouble() > 0.5 ? '↓' : '→');
      country.level = _scoreToLevel(country.instabilityScore);

      // Sub scores
      country.subScores = {
        'unrest': (country.instabilityScore * (0.6 + rng.nextDouble() * 0.4)).round().clamp(0, 100),
        'conflict': eventCount > 3 ? (country.instabilityScore * 0.8).round().clamp(0, 100) : rng.nextInt(10),
        'security': (country.instabilityScore * (0.5 + rng.nextDouble() * 0.4)).round().clamp(0, 100),
        'information': rng.nextInt(60),
      };
    }
    _safeNotifyListeners();
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  String _scoreToLevel(int score) {
    if (score >= 80) return 'CRISIS';
    if (score >= 60) return 'HIGH';
    if (score >= 35) return 'ELEVATED';
    if (score >= 15) return 'MODERATE';
    return 'LOW';
  }

  List<NewsArticle> _simulatedNews() => [
    NewsArticle(title: 'Iran launches coordinated drone and missile strike on Israeli border positions', source: 'AL ARABIYA', url: '', publishedAt: '2m ago', category: 'CONFLICT', isBreaking: true),
    NewsArticle(title: 'US Navy repositions carrier strike group in Eastern Mediterranean amid escalation', source: 'BLOOMBERG', url: '', publishedAt: '5m ago', category: 'MILITARY'),
    NewsArticle(title: 'Russia thermal escalation: 3.8k MW spike detected across 12 sites', source: 'INTEL', url: '', publishedAt: '12m ago', category: 'INTEL', isBreaking: true),
    NewsArticle(title: 'DEFCON updated following coordinated cyberattacks on NATO infrastructure', source: 'DW', url: '', publishedAt: '18m ago', category: 'CYBER'),
    NewsArticle(title: 'Nikkei surges 0.97% as Asia markets open higher on Fed rate signals', source: 'BLOOMBERG', url: '', publishedAt: '8m ago', category: 'MARKETS'),
    NewsArticle(title: 'WHO: New antimicrobial resistance strain detected in Southeast Asia', source: 'WHO', url: '', publishedAt: '1h ago', category: 'HEALTH'),
    NewsArticle(title: 'North Korea fires ballistic missile into Sea of Japan', source: 'SKYNEWS', url: '', publishedAt: '22m ago', category: 'MILITARY', isBreaking: true),
    NewsArticle(title: 'Venezuela: Military mobilization near Colombian border reported', source: 'CNN', url: '', publishedAt: '35m ago', category: 'MILITARY'),
    NewsArticle(title: 'China conducts naval exercises near Taiwan Strait', source: 'CNBC', url: '', publishedAt: '2h ago', category: 'MILITARY'),
    NewsArticle(title: 'Sudan humanitarian crisis deepens as aid corridors blocked by RSF', source: 'ALJAZEERA', url: '', publishedAt: '45m ago', category: 'CRISIS'),
    NewsArticle(title: 'Ukraine: Russian forces deploy new electronic warfare systems near Zaporizhzhia', source: 'EURONEWS', url: '', publishedAt: '1h ago', category: 'MILITARY'),
    NewsArticle(title: 'Oil prices rise 3% on Iran conflict risk premium', source: 'BLOOMBERG', url: '', publishedAt: '30m ago', category: 'MARKETS'),
    NewsArticle(title: 'Italy marks 81st anniversary of liberation from Nazi fascism', source: 'PRESSTV', url: '', publishedAt: '3m ago', category: 'GEOPOLITICS'),
    NewsArticle(title: '200,000+ UK citizens sign petition against Palantir government data contract', source: 'QUDS NEWS', url: '', publishedAt: '4m ago', category: 'POLITICS'),
    NewsArticle(title: 'Pakistan: Earthquake 5.8M near Afghanistan border, casualties reported', source: 'REUTERS', url: '', publishedAt: '1.5h ago', category: 'DISASTER'),
    NewsArticle(title: 'ECDC: Communicable disease threats report Week 17 — elevated risk in 3 regions', source: 'ECDC', url: '', publishedAt: '2h ago', category: 'HEALTH'),
    NewsArticle(title: 'Myanmar junta airstrike kills 11 civilians in Sagaing region', source: 'BBC', url: '', publishedAt: '3h ago', category: 'CONFLICT'),
    NewsArticle(title: 'Federal Reserve signals potential rate hold — global markets react', source: 'FT', url: '', publishedAt: '4h ago', category: 'MARKETS'),
    NewsArticle(title: 'Ethiopia: Tigray forces report ceasefire violations in northern region', source: 'ALARABIYA', url: '', publishedAt: '6h ago', category: 'CONFLICT'),
    NewsArticle(title: 'Brazil Amazon deforestation rate drops 50% in Q1 2026', source: 'FRANCE24', url: '', publishedAt: '8h ago', category: 'ENVIRONMENT'),
  ];

  static List<CountryData> _buildDefaultCountries() => [
    CountryData(name: 'Iran', iso2: 'IR', iso3: 'IRN', lat: 32.0, lng: 53.0),
    CountryData(name: 'Russia', iso2: 'RU', iso3: 'RUS', lat: 61.5, lng: 105.0),
    CountryData(name: 'Ukraine', iso2: 'UA', iso3: 'UKR', lat: 48.4, lng: 31.2),
    CountryData(name: 'Sudan', iso2: 'SD', iso3: 'SDN', lat: 12.9, lng: 30.2),
    CountryData(name: 'Myanmar', iso2: 'MM', iso3: 'MMR', lat: 17.0, lng: 96.0),
    CountryData(name: 'North Korea', iso2: 'KP', iso3: 'PRK', lat: 40.3, lng: 127.5),
    CountryData(name: 'Yemen', iso2: 'YE', iso3: 'YEM', lat: 15.6, lng: 48.5),
    CountryData(name: 'Ethiopia', iso2: 'ET', iso3: 'ETH', lat: 9.1, lng: 40.5),
    CountryData(name: 'Syria', iso2: 'SY', iso3: 'SYR', lat: 34.8, lng: 38.9),
    CountryData(name: 'Venezuela', iso2: 'VE', iso3: 'VEN', lat: 6.4, lng: -66.6),
    CountryData(name: 'Pakistan', iso2: 'PK', iso3: 'PAK', lat: 30.4, lng: 69.3),
    CountryData(name: 'DRC', iso2: 'CD', iso3: 'COD', lat: -4.0, lng: 21.8),
    CountryData(name: 'Somalia', iso2: 'SO', iso3: 'SOM', lat: 5.2, lng: 46.2),
    CountryData(name: 'Mali', iso2: 'ML', iso3: 'MLI', lat: 17.6, lng: -4.0),
    CountryData(name: 'Haiti', iso2: 'HT', iso3: 'HTI', lat: 18.9, lng: -72.3),
    CountryData(name: 'Afghanistan', iso2: 'AF', iso3: 'AFG', lat: 33.9, lng: 67.7),
    CountryData(name: 'Libya', iso2: 'LY', iso3: 'LBY', lat: 26.3, lng: 17.2),
    CountryData(name: 'Niger', iso2: 'NE', iso3: 'NER', lat: 17.6, lng: 8.1),
    CountryData(name: 'China', iso2: 'CN', iso3: 'CHN', lat: 35.0, lng: 105.0),
    CountryData(name: 'Israel', iso2: 'IL', iso3: 'ISR', lat: 31.0, lng: 34.8),
    CountryData(name: 'United States', iso2: 'US', iso3: 'USA', lat: 37.1, lng: -95.7),
    CountryData(name: 'India', iso2: 'IN', iso3: 'IND', lat: 20.6, lng: 78.9),
    CountryData(name: 'Brazil', iso2: 'BR', iso3: 'BRA', lat: -14.2, lng: -51.9),
    CountryData(name: 'Turkey', iso2: 'TR', iso3: 'TUR', lat: 38.9, lng: 35.2),
    CountryData(name: 'Saudi Arabia', iso2: 'SA', iso3: 'SAU', lat: 23.9, lng: 45.1),
    CountryData(name: 'Egypt', iso2: 'EG', iso3: 'EGY', lat: 26.8, lng: 30.8),
    CountryData(name: 'Germany', iso2: 'DE', iso3: 'DEU', lat: 51.2, lng: 10.5),
    CountryData(name: 'United Kingdom', iso2: 'GB', iso3: 'GBR', lat: 55.4, lng: -3.4),
    CountryData(name: 'France', iso2: 'FR', iso3: 'FRA', lat: 46.2, lng: 2.2),
    CountryData(name: 'South Africa', iso2: 'ZA', iso3: 'ZAF', lat: -28.5, lng: 24.7),
    CountryData(name: 'Nigeria', iso2: 'NG', iso3: 'NGA', lat: 9.1, lng: 8.7),
    CountryData(name: 'Indonesia', iso2: 'ID', iso3: 'IDN', lat: -0.8, lng: 113.9),
    CountryData(name: 'Mexico', iso2: 'MX', iso3: 'MEX', lat: 23.6, lng: -102.6),
    CountryData(name: 'Argentina', iso2: 'AR', iso3: 'ARG', lat: -38.4, lng: -63.6),
    CountryData(name: 'Japan', iso2: 'JP', iso3: 'JPN', lat: 36.2, lng: 138.2),
    CountryData(name: 'South Korea', iso2: 'KR', iso3: 'KOR', lat: 35.9, lng: 127.8),
    CountryData(name: 'Philippines', iso2: 'PH', iso3: 'PHL', lat: 12.9, lng: 121.8),
    CountryData(name: 'Iraq', iso2: 'IQ', iso3: 'IRQ', lat: 33.2, lng: 43.7),
    CountryData(name: 'Lebanon', iso2: 'LB', iso3: 'LBN', lat: 33.9, lng: 35.9),
    CountryData(name: 'Colombia', iso2: 'CO', iso3: 'COL', lat: 4.1, lng: -72.3),
  ];

  @override
  void dispose() {
    _isDisposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}
