// lib/services/dashboard_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../wm_theme.dart';

enum PanelId {
  liveNews,
  liveWebcams,
  aiInsights,
  aiForecasts,
  countryInstability,
  strategicRisk,
  aiStrategicPosture,
  debtClock,
}

class PanelDef {
  final PanelId id;
  final String title;
  bool visible;
  int order;

  PanelDef({
    required this.id,
    required this.title,
    this.visible = true,
    this.order = 0,
  });
}

class DashboardProvider extends ChangeNotifier {
  DateTime _now = DateTime.now().toUtc();
  Timer? _clockTimer;
  Timer? _riskTimer;
  bool _disposed = false;

  MapVariant _mapVariant = MapVariant.world;
  String _mapMode = '2D';
  String _timeFilter = '7d';
  int _defconLevel = 5;
  bool _settingsOpen = false;
  String _selectedCountry = '';
  String _newsSource = 'BLOOMBERG';
  String _webcamCategory = 'IRAN ATTACKS';
  double _globalRisk = 53.0;
  String _riskTrend = 'Stable';

  final List<PanelDef> _panels = [
    PanelDef(id: PanelId.liveNews, title: 'LIVE NEWS', visible: true, order: 0),
    PanelDef(
        id: PanelId.liveWebcams,
        title: 'LIVE WEBCAMS',
        visible: true,
        order: 1),
    PanelDef(
        id: PanelId.aiInsights, title: 'AI INSIGHTS', visible: true, order: 2),
    PanelDef(
        id: PanelId.aiForecasts,
        title: 'AI FORECASTS',
        visible: true,
        order: 3),
    PanelDef(
        id: PanelId.countryInstability,
        title: 'COUNTRY INSTABILITY',
        visible: true,
        order: 4),
    PanelDef(
        id: PanelId.strategicRisk,
        title: 'STRATEGIC RISK',
        visible: true,
        order: 5),
    PanelDef(
        id: PanelId.aiStrategicPosture,
        title: 'AI STRATEGIC POSTURE',
        visible: true,
        order: 6),
    PanelDef(
        id: PanelId.debtClock,
        title: 'NATIONAL DEBT CLOCK',
        visible: false,
        order: 7),
  ];

  DateTime get now => _now;
  MapVariant get mapVariant => _mapVariant;
  String get mapMode => _mapMode;
  String get timeFilter => _timeFilter;
  int get defconLevel => _defconLevel;
  bool get settingsOpen => _settingsOpen;
  String get selectedCountry => _selectedCountry;
  String get newsSource => _newsSource;
  String get webcamCategory => _webcamCategory;
  double get globalRisk => _globalRisk;
  String get riskTrend => _riskTrend;
  List<PanelDef> get panels => _panels;
  List<PanelDef> get visiblePanels {
    final v = _panels.where((p) => p.visible).toList();
    v.sort((a, b) => a.order.compareTo(b.order));
    return v;
  }

  DashboardProvider() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) {
        _now = DateTime.now().toUtc();
        notifyListeners();
      }
    });
    _riskTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_disposed) {
        _globalRisk =
            (_globalRisk + (Random().nextDouble() * 4 - 2)).clamp(20.0, 90.0);
        notifyListeners();
      }
    });
  }

  void setMapVariant(MapVariant v) {
    _mapVariant = v;
    notifyListeners();
  }

  void setMapMode(String m) {
    _mapMode = m;
    notifyListeners();
  }

  void setTimeFilter(String f) {
    _timeFilter = f;
    notifyListeners();
  }

  void toggleSettings() {
    _settingsOpen = !_settingsOpen;
    notifyListeners();
  }

  void setNewsSource(String s) {
    _newsSource = s;
    notifyListeners();
  }

  void setWebcamCategory(String c) {
    _webcamCategory = c;
    notifyListeners();
  }

  void selectCountry(String name) {
    _selectedCountry = _selectedCountry == name ? '' : name;
    notifyListeners();
  }

  void togglePanel(PanelId id) {
    final p = _panels.firstWhere((p) => p.id == id);
    p.visible = !p.visible;
    notifyListeners();
  }

  bool isPanelVisible(PanelId id) =>
      _panels.firstWhere((p) => p.id == id).visible;

  /// Reorder panels by drag-and-drop index swap
  void reorderPanels(int oldIndex, int newIndex) {
    final visible = visiblePanels;
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    if (newIndex < 0 || newIndex >= visible.length) return;
    final a = visible[oldIndex];
    final b = visible[newIndex];
    final tmp = a.order;
    a.order = b.order;
    b.order = tmp;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clockTimer?.cancel();
    _riskTimer?.cancel();
    super.dispose();
  }
}
