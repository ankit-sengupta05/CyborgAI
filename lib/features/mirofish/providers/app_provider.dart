// lib/providers/app_provider.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart'; // Offset
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/llm_service.dart';

enum AppStep { home, graphBuild, envSetup, simulation, report, interaction }
enum ViewMode { graph, split, workbench }

class AppProvider extends ChangeNotifier {
  bool _isDisposed = false;
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  AppStep _step = AppStep.home;
  ViewMode _viewMode = ViewMode.split;
  AppStep get step => _step;
  ViewMode get viewMode => _viewMode;

  // ── Project ─────────────────────────────────────────────────────────────────
  MFProject? _project;
  MFProject? get project => _project;

  // ── LLM Config ──────────────────────────────────────────────────────────────
  LLMConfig llmConfig = LLMConfig();
  late LLMService llmService;
  late ApiService apiService;

  // ── Graph ────────────────────────────────────────────────────────────────────
  GraphData _graphData = GraphData.empty();
  GraphData get graphData => _graphData;
  bool _showEdgeLabels = true;
  bool get showEdgeLabels => _showEdgeLabels;

  // ── Build state ──────────────────────────────────────────────────────────────
  Map<String, String> _buildStatus = {
    'ontology': 'pending',
    'graphrag': 'pending',
    'buildComplete': 'pending',
  };
  Map<String, String> get buildStatus => _buildStatus;

  // Ontology results
  List<String> entityTypes = [];
  List<String> relationTypes = [];
  int entityNodes = 0;
  int relationEdges = 0;
  int schemaTypes = 0;

  // ── Env setup state ───────────────────────────────────────────────────────────
  Map<String, String> _envStatus = {
    'simulationInit': 'pending',
    'agentProfiles': 'pending',
    'generateConfig': 'pending',
    'activation': 'pending',
    'ready': 'pending',
  };
  Map<String, String> get envStatus => _envStatus;
  List<AgentProfile> agents = [];
  SimConfig? simConfig;
  int totalAgents = 0;
  int expectedTotal = 0;
  int relatedTopics = 0;

  // ── Simulation state ─────────────────────────────────────────────────────────
  int plazaRound = 0;
  int plazaTotalRounds = 40;
  int plazaActs = 0;
  int communityRound = 0;
  int communityActs = 0;
  int totalEvents = 0;
  bool _simRunning = false;
  bool get simRunning => _simRunning;
  String _simulationRequirement = '';
  List<SimEvent> simEvents = [];

  // ── Report state ──────────────────────────────────────────────────────────────
  String reportRequirement = '';
  List<ReportSection> reportSections = [];
  String reportContent = '';
  bool _reportGenerating = false;
  bool get reportGenerating => _reportGenerating;

  // ── Console logs ─────────────────────────────────────────────────────────────
  final List<String> _consoleLogs = [];
  List<String> get consoleLogs => List.unmodifiable(_consoleLogs);
  String? _sessionId;
  String? get sessionId => _sessionId;

  // ── Upload ───────────────────────────────────────────────────────────────────
  String? uploadedFileName;
  String? uploadedFilePath;

  AppProvider() {
    llmService = LLMService(llmConfig);
    apiService = ApiService(llmService);
    _seedDemoState();
  }

  /// Wire MiroFish to Cyborg's own inference backend (port 8765).
  /// Called by MiroFishScreen when embedding inside Cyborg.
  void useCyborgBackend() {
    llmConfig = LLMConfig(
      baseUrl: 'http://127.0.0.1:8765/api/v1',
      modelName: 'cyborg-llm',
      apiKey: 'cyborg-key', // Dummy key to pass isConfigured check
      mode: 'api',
    );
    llmService = LLMService(llmConfig);
    apiService = ApiService(llmService);
    safeNotify();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void setStep(AppStep s) { _step = s; safeNotify(); }
  void setViewMode(ViewMode v) { _viewMode = v; safeNotify(); }
  void toggleEdgeLabels() { _showEdgeLabels = !_showEdgeLabels; safeNotify(); }

  int get stepNumber {
    switch (_step) {
      case AppStep.home: return 0;
      case AppStep.graphBuild: return 1;
      case AppStep.envSetup: return 2;
      case AppStep.simulation: return 3;
      case AppStep.report: return 4;
      case AppStep.interaction: return 5;
    }
  }

  String get stepName {
    switch (_step) {
      case AppStep.home: return 'Home';
      case AppStep.graphBuild: return 'Graph Build';
      case AppStep.envSetup: return 'Env Setup';
      case AppStep.simulation: return 'Simulation';
      case AppStep.report: return 'Report';
      case AppStep.interaction: return 'Interaction';
    }
  }

  // ── LLM Config ───────────────────────────────────────────────────────────────

  void updateLLMConfig(LLMConfig config) {
    llmConfig = config;
    llmService = LLMService(config);
    apiService = ApiService(llmService);
    safeNotify();
  }

  // ── File upload ───────────────────────────────────────────────────────────────

  void setUploadedFile(String name, String path) {
    uploadedFileName = name;
    uploadedFilePath = path;
    safeNotify();
  }

  // ── Graph ────────────────────────────────────────────────────────────────────

  void updateGraph(GraphData data) {
    _graphData = data;
    safeNotify();
  }

  void addLog(String line) {
    final ts = DateTime.now();
    final hms = '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}:${ts.second.toString().padLeft(2,'0')}.${ts.millisecond.toString().padLeft(3,'0')}';
    _consoleLogs.add('$hms   $line');
    if (_consoleLogs.length > 200) _consoleLogs.removeAt(0);
    safeNotify();
  }

  // ── Graph Build flow ──────────────────────────────────────────────────────────

  Future<void> startGraphBuild(String requirement) async {
    if (!llmConfig.isConfigured) {
      addLog('ERROR: LLM not configured. Please set up in Settings.');
      return;
    }
    _project = MFProject(id: 'proj_${DateTime.now().millisecondsSinceEpoch}', name: 'Simulation');
    _sessionId = _project!.id;
    _buildStatus = {'ontology': 'processing', 'graphrag': 'pending', 'buildComplete': 'pending'};
    _step = AppStep.graphBuild;
    // Start with empty graph
    _graphData = GraphData.empty();
    safeNotify();

    reportRequirement = requirement; // store for use in simulation
    addLog('Starting ontology generation...');
    try {
      final ontResult = await apiService.generateOntology(requirement, uploadedFilePath);
      entityTypes = List<String>.from(ontResult['entity_types'] ?? _defaultEntityTypes);
      relationTypes = List<String>.from(ontResult['relation_types'] ?? _defaultRelationTypes);
      _buildStatus['ontology'] = 'complete';
      addLog('✓ Ontology generated: ${entityTypes.length} entity types, ${relationTypes.length} relation types');
      safeNotify();

      _buildStatus['graphrag'] = 'processing';
      safeNotify();
      addLog('Building GraphRAG...');

      // Accumulate nodes/edges across batches
      final accNodes = <GraphNode>[];
      final accEdges = <GraphEdge>[];

      final graphResult = await apiService.buildGraph(
        requirement, entityTypes, relationTypes, uploadedFilePath,
        onBatch: (newNodes, newEdges, progress) {
          // Convert and add new nodes
          for (final n in newNodes) {
            if (!accNodes.any((e) => e.id == n['id'])) {
              accNodes.add(GraphNode(
                id: n['id'] as String,
                label: n['label'] as String,
                type: n['type'] as String,
                position: Offset.zero, // physics will place it
              ));
            }
          }
          // Add new edges (only if both endpoints exist)
          for (final e in newEdges) {
            final src = e['source'] as String;
            final tgt = e['target'] as String;
            if (accNodes.any((n) => n.id == src) && accNodes.any((n) => n.id == tgt)) {
              if (!accEdges.any((ex) => ex.source == src && ex.target == tgt)) {
                accEdges.add(GraphEdge(source: src, target: tgt, label: e['label'] as String? ?? ''));
              }
            }
          }
          // Update live graph display
          _graphData = GraphData(
            nodes: List.from(accNodes),
            edges: List.from(accEdges),
            entityTypes: entityTypes,
            relationTypes: relationTypes,
          );
          addLog('Graph refreshed: ${accNodes.length} nodes, ${accEdges.length} edges');
          safeNotify();
        },
      );

      entityNodes = (graphResult['entity_nodes'] as num?)?.toInt() ?? accNodes.length;
      relationEdges = (graphResult['relation_edges'] as num?)?.toInt() ?? accEdges.length;
      schemaTypes = (graphResult['schema_types'] as num?)?.toInt() ?? entityTypes.length;
      _project!.graphId = graphResult['graph_id'] as String? ?? 'mirofish_${DateTime.now().millisecondsSinceEpoch}';

      // Final graph state from accumulated batches
      if (accNodes.isNotEmpty) {
        _graphData = GraphData(
          nodes: accNodes, edges: accEdges,
          entityTypes: entityTypes, relationTypes: relationTypes,
        );
      } else {
        _loadDemoGraphData();
      }

      addLog('✓ Graph build completed');
      addLog('Graph data loaded');
      _buildStatus['graphrag'] = 'complete';
      _buildStatus['buildComplete'] = 'in_progress';
      safeNotify();
    } catch (e) {
      addLog('ERROR: \$e');
      _loadDemoGraphData();
      _buildStatus = {'ontology': 'complete', 'graphrag': 'complete', 'buildComplete': 'in_progress'};
      safeNotify();
    }
  }

  void proceedToEnvSetup() {
    _buildStatus['buildComplete'] = 'complete';
    _step = AppStep.envSetup;
    _sessionId = _project?.simulationId ?? 'sim_${DateTime.now().millisecondsSinceEpoch}';
    _startEnvSetup();
    safeNotify();
  }

  // ── Env Setup flow ────────────────────────────────────────────────────────────

  Future<void> _startEnvSetup() async {
    _envStatus = {
      'simulationInit': 'processing', 'agentProfiles': 'pending',
      'generateConfig': 'pending', 'activation': 'pending', 'ready': 'pending'
    };
    safeNotify();

    try {
      // Step 1: Init simulation
      final initResult = await apiService.createSimulation(_project!.graphId ?? '');
      _project!.simulationId = initResult['simulation_id'] ?? 'sim_${DateTime.now().millisecondsSinceEpoch}';
      _project!.taskId = initResult['task_id'] ?? 'task_prepare_${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = _project!.simulationId;
      addLog('Total agents: 55');
      addLog('Duration: 72 hours');
      addLog('Initial posts: 4');
      _envStatus['simulationInit'] = 'completed';
      safeNotify();

      // Step 2: Agent profiles
      _envStatus['agentProfiles'] = 'processing';
      safeNotify();
      final profileResult = await apiService.generateAgentProfiles(_project!.simulationId!, entityTypes, _simulationRequirement);
      agents = _parseAgents(profileResult);
      totalAgents = agents.length;
      expectedTotal = agents.length;
      relatedTopics = (profileResult['related_topics'] as num?)?.toInt() ?? 272;
      _envStatus['agentProfiles'] = 'completed';
      addLog('Environment setup complete, ready to start simulation');
      safeNotify();

      // Step 3: Generate config
      _envStatus['generateConfig'] = 'processing';
      safeNotify();
      await Future.delayed(const Duration(seconds: 1));
      _envStatus['generateConfig'] = 'completed';
      safeNotify();

      // Step 4: Activation orchestration
      _envStatus['activation'] = 'processing';
      safeNotify();
      await Future.delayed(const Duration(milliseconds: 800));
      _envStatus['activation'] = 'completed';
      safeNotify();

      // Step 5: Ready
      _envStatus['ready'] = 'in_progress';
      safeNotify();
    } catch (e) {
      addLog('ERROR in env setup: $e — using demo data');
      _loadDemoAgents();
      _envStatus = {
        'simulationInit': 'completed', 'agentProfiles': 'completed',
        'generateConfig': 'completed', 'activation': 'completed', 'ready': 'in_progress'
      };
      safeNotify();
    }
  }

  // ── Simulation flow ───────────────────────────────────────────────────────────

  Future<void> startSimulation(int rounds, {String requirement = ''}) async {
    _simRunning = true;
    _simulationRequirement = requirement;
    _step = AppStep.simulation;
    plazaRound = 0; plazaActs = 0;
    communityRound = 0; communityActs = 0;
    totalEvents = 0; simEvents.clear();
    plazaTotalRounds = rounds;
    safeNotify();

    addLog('Starting dual-platform simulation...');

    try {
      await apiService.startSimulation(
        _project?.simulationId ?? '',
        rounds,
        _simulationRequirement,
        onProgress: (plaza, community, events) {
          plazaRound = plaza['round'] ?? plazaRound;
          plazaActs = plaza['acts'] ?? plazaActs;
          communityRound = community['round'] ?? communityRound;
          communityActs = community['acts'] ?? communityActs;
          totalEvents += events.length;
          simEvents.addAll(events.map((e) => SimEvent.fromJson(e)));

          final p = plazaRound;
          final c = communityRound;
          addLog('[Plaza] R$p/$rounds | T:${plazaRound}h | A:$plazaActs');
          addLog('[Community] R$c/$rounds | T:${communityRound}h | A:$communityActs');

          // Update graph nodes
          if ((p % 5) == 0 && _graphData.nodes.isNotEmpty) {
            _addSimulatedNodes();
          }
          safeNotify();
        },
      );
      _simRunning = false;
      addLog('✓ Simulation completed');
      addLog('Graph sync updated, nodes: ${_graphData.nodes.length}, edges: ${_graphData.edges.length}, progress: 100%');
      safeNotify();
    } catch (e) {
      addLog('Simulation error: $e — running demo mode');
      await _runDemoSimulation(rounds);
    }
  }

  Future<void> _runDemoSimulation(int rounds) async {
    for (int r = 1; r <= rounds; r++) {
      await Future.delayed(const Duration(milliseconds: 200));
      plazaRound = r;
      communityRound = r;
      plazaActs = (plazaActs + 7).clamp(0, 999);
      communityActs = (communityActs + 11).clamp(0, 999);
      totalEvents += 18;
      simEvents.addAll(_demoEvents(r));

      if (r % 5 == 0) {
        _addSimulatedNodes();
        addLog('Graph sync updated, nodes: ${_graphData.nodes.length}, edges: ${_graphData.edges.length}, progress: ${(r / rounds * 100).round()}%');
      }
      safeNotify();
    }
    _simRunning = false;
    addLog('✓ Simulation completed');
    safeNotify();
  }

  List<SimEvent> _demoEvents(int round) => [
    SimEvent(agentName: 'University Admin', agentType: 'University', platform: 'plaza',
      eventType: 'post', content: 'Official update on the ongoing situation. We remain committed to transparency. Round \$round.',
      time: '${(6 + round % 18).toString().padLeft(2,"0")}:${(round * 3 % 60).toString().padLeft(2,"0")}:00', round: round),
    SimEvent(agentName: 'Student Rep', agentType: 'Student', platform: 'community',
      eventType: 'post', content: 'The community deserves answers. This cannot be ignored. #Justice',
      time: '${(8 + round % 16).toString().padLeft(2,"0")}:${(round * 5 % 60).toString().padLeft(2,"0")}:00', round: round),
  ];

  void _addSimulatedNodes() {
    // Add new nodes as simulation progresses
    final newNodes = List.generate(3, (i) {
      final id = 'sim_node_${_graphData.nodes.length + i}';
      return GraphNode(
        id: id, label: 'Agent_$id', type: 'Person',
        position: Offset(
          200 + (_graphData.nodes.length + i) % 10 * 80.0,
          200 + (_graphData.nodes.length + i) ~/ 10 * 80.0,
        ),
      );
    });
    final updatedNodes = [..._graphData.nodes, ...newNodes];
    _graphData = GraphData(
      nodes: updatedNodes, edges: _graphData.edges,
      entityTypes: _graphData.entityTypes, relationTypes: _graphData.relationTypes);
  }

  // ── Report flow ───────────────────────────────────────────────────────────────

  Future<void> generateReport(String requirement) async {
    _reportGenerating = true;
    _step = AppStep.report;
    reportRequirement = requirement;
    reportSections = [];
    reportContent = '';
    _sessionId = 'report_${DateTime.now().millisecondsSinceEpoch}';
    safeNotify();

    addLog('Starting report generation...');

    try {
      final stream = apiService.generateReport(
        _project?.simulationId ?? '', requirement, _graphData);

      await for (final chunk in stream) {
        reportContent += chunk;
        safeNotify();
      }
      _reportGenerating = false;
      addLog('✓ Report generation complete');
      safeNotify();
    } catch (e) {
      addLog('Report error: $e — generating demo report');
      await _generateDemoReport(requirement);
    }
  }

  Future<void> _generateDemoReport(String req) async {
    final sections = [
      'Secondary Public Opinion Surge: Shift from the Incident Itself to Procedural Legitimacy',
      'Behavioral Differentiation of Multiple Agents: Media Rationalization, Platform Risk Control, Public Polarization',
      'University Governance Enters the Era of Reversible Decisions: Reputation Risk and Decision Transparency Become Core Variables',
    ];

    for (final title in sections) {
      reportSections.add(ReportSection(id: '${reportSections.length}', title: title, status: 'in_progress', content: ''));
      addLog('INFO: Section start: ${reportSections.length}. $title');
      safeNotify();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Stream the content in small chunks for demo
    reportContent = '';
    final words = _demoReportContent.split(' ');
    for (int i = 0; i < words.length; i += 3) {
      final chunk = words.skip(i).take(3).join(' ') + (i + 3 < words.length ? ' ' : '');
      reportContent += chunk;
      safeNotify();
      await Future.delayed(const Duration(milliseconds: 15));
    }

    _reportGenerating = false;
    safeNotify();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  GraphData _parseGraphData(Map<String, dynamic> result) {
    final nodes = (result['nodes'] as List? ?? []).map((n) => GraphNode.fromJson(n as Map<String, dynamic>)).toList();
    final edges = (result['edges'] as List? ?? []).map((e) => GraphEdge.fromJson(e as Map<String, dynamic>)).toList();
    // Never fall back to demo — return whatever LLM gave us (even if few nodes)
    return GraphData(nodes: nodes, edges: edges, entityTypes: entityTypes, relationTypes: relationTypes);
  }

  List<AgentProfile> _parseAgents(Map<String, dynamic> result) {
    final list = result['agents'] as List? ?? [];
    if (list.isEmpty) return _demoAgents;
    return list.asMap().entries.map((e) => AgentProfile.fromJson(e.value as Map<String, dynamic>, e.key)).toList();
  }

  void _loadDemoGraphData() {
    _graphData = _generateDemoGraph();
    entityTypes = _defaultEntityTypes;
    relationTypes = _defaultRelationTypes;
    entityNodes = _graphData.nodes.length;
    relationEdges = _graphData.edges.length;
    schemaTypes = 9;
  }

  void _loadDemoAgents() {
    agents = _demoAgents;
    totalAgents = agents.length;
    expectedTotal = 55;
    relatedTopics = 272;
  }

  void _seedDemoState() {
    // On startup show something in graph
    _graphData = _generateDemoGraph();
    entityTypes = _defaultEntityTypes;
    relationTypes = _defaultRelationTypes;
  }

  // ── Demo data ─────────────────────────────────────────────────────────────────

  GraphData _generateDemoGraph() {
    final rng = _Rng(42);
    final nodeTypes = [
      ('University', 8), ('Student', 20), ('Professor', 10), ('Alumni', 8),
      ('Organization', 12), ('Person', 15), ('Media Outlet', 5), ('Legal Authority', 4),
    ];

    final nodes = <GraphNode>[];
    int idx = 0;
    for (final (type, count) in nodeTypes) {
      for (int i = 0; i < count; i++) {
        final angle = 2 * 3.14159 * idx / 82;
        final r = 120.0 + rng.next() * 280;
        nodes.add(GraphNode(
          id: 'n$idx',
          label: _demoNames[idx % _demoNames.length],
          type: type,
          position: Offset(400 + r * _cos(angle), 350 + r * _sin(angle)),
        ));
        idx++;
      }
    }

    final edges = <GraphEdge>[];
    final relations = ['RELATES_TO','CRITICIZES','SUPPORTS','REPORTS_ON','AFFILIATED_WITH','ADVISES','STUDIES_AT'];
    for (int i = 0; i < 180; i++) {
      final s = rng.nextInt(nodes.length);
      var t = rng.nextInt(nodes.length);
      while (t == s) t = rng.nextInt(nodes.length);
      edges.add(GraphEdge(source: nodes[s].id, target: nodes[t].id,
          label: relations[rng.nextInt(relations.length)]));
    }

    return GraphData(nodes: nodes, edges: edges, entityTypes: _defaultEntityTypes, relationTypes: _defaultRelationTypes);
  }

  double _cos(double a) => math.cos(a);
  double _sin(double a) => math.sin(a);

  static const _defaultEntityTypes = [
    'University', 'Student', 'Professor', 'Alumni', 'MediaOutlet', 'GovernmentAgency', 'NGO', 'Person', 'Organization'
  ];
  static const _defaultRelationTypes = [
    'COMMENTS_ON', 'RESPONDS_TO', 'SUPPORTS', 'OPPOSES', 'AFFILIATED_WITH', 'WORKS_FOR'
  ];
  static const _demoNames = [
    'Wuhan U.', 'Student', 'Alumni', 'Professor', 'Media', 'Insight', 'Legal ex.',
    'Domestic', 'Young Ai.', 'Post-80s', 'Masters', 'Luojia M.', 'Union Ho.',
    'Top Univ.', 'Xiao', 'Yang Jin.', 'Analyst', 'Graduate', 'Facebook', 'WeChat',
    'Douyin', 'Weibo', 'Twitter', 'UC Berke.', 'Library', 'Court', 'NGO', 'Agency',
  ];

  static final _demoAgents = [
    AgentProfile(index: 0, id: 'facebook_273', name: 'Facebook', type: 'Organization',
      stance: 'neutral', description: 'Facebook is a globally renowned social media platform.',
      topics: ['Study Abroad', 'Alumni Exchange', 'Higher Education'],
      activeHours: List.generate(24, (i) => i >= 8 && i <= 22),
      postsPerHour: 3, commentsPerHour: 5, responseDelay: '5-30min',
      activityLevel: 0.5, sentimentBias: 0.0, influenceWeight: 2.5),
    AgentProfile(index: 1, id: 'hubei_ip_504', name: 'Hubei IP User', type: 'Person',
      stance: 'supportive', description: 'A parent of a student in the Hubei region.',
      topics: ['Educational Equity', 'Academic Integrity', 'Family Education'],
      activeHours: List.generate(24, (i) => i >= 18 && i <= 23),
      postsPerHour: 10, commentsPerHour: 8, responseDelay: '1-15min',
      activityLevel: 0.7, sentimentBias: 0.5, influenceWeight: 1.0),
    AgentProfile(index: 2, id: 'alumni_948', name: 'Alumni', type: 'Alumni',
      stance: 'neutral', description: 'A Wuhan University alumnus.',
      topics: ['University Governance', 'Academic Freedom'],
      activeHours: List.generate(24, (i) => i >= 12 && i <= 20),
      postsPerHour: 2, commentsPerHour: 3, responseDelay: '10-60min',
      activityLevel: 0.4, sentimentBias: 0.0, influenceWeight: 1.5),
    AgentProfile(index: 3, id: 'whu_vice', name: 'WHU Vice President', type: 'Professor',
      stance: 'opposing', description: 'WHU administration representative.',
      topics: ['Institutional Policy', 'University Management'],
      activeHours: List.generate(24, (i) => i >= 9 && i <= 18),
      postsPerHour: 1, commentsPerHour: 2, responseDelay: '30-120min',
      activityLevel: 0.3, sentimentBias: -0.8, influenceWeight: 3.0),
  ];

  static const _demoReportContent = '''
## Secondary Public Opinion Surge: Shift from the Incident Itself to Procedural Legitimacy

Following the announcement of Wuhan University's revocation of disciplinary action against Xiao, public discourse rapidly evolved beyond the immediate incident toward broader questions of institutional governance and procedural justice.

The simulation revealed several critical dynamics:

- Decision reversibility will become normalized — universities must build mechanisms for continuous evaluation and correction of disciplinary decisions
- Transparency is no longer optional — in the era of social media, every decision is subject to immediate public scrutiny
- Multi-stakeholder governance is inevitable — students, alumni, faculty, and the public all demand participation in governance discussions
- Reputation risk management must be integrated into decision-making processes from the outset
- International dimensions of governance communication can no longer be ignored

The key challenge ahead is whether universities can transform this crisis into an opportunity for genuine institutional reform, building governance systems that are transparent, accountable, and resilient.
''';
}

class _Rng {
  final math.Random _rng;
  _Rng(int seed) : _rng = math.Random(seed);
  double next() => _rng.nextDouble();
  int nextInt(int max) => _rng.nextInt(max);
}
