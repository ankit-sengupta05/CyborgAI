import 'package:flutter/foundation.dart';

class ApiConstants {
  static String? _baseUrlOverride;
  static String? _wsBaseUrlOverride;

  static String get baseUrl {
    if (_baseUrlOverride != null) return _baseUrlOverride!;
    if (kIsWeb) return '${Uri.base.origin}/api/v1/';
    return 'http://127.0.0.1:8765/api/v1/';
  }

  static set baseUrl(String value) => _baseUrlOverride = value;

  static String get wsBaseUrl {
    if (_wsBaseUrlOverride != null) return _wsBaseUrlOverride!;
    if (kIsWeb) {
      final uri = Uri.base;
      final protocol = uri.scheme == 'https' ? 'wss' : 'ws';
      // In web, port might be empty
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '$protocol://${uri.host}$portPart/api/v1/';
    }
    return 'ws://127.0.0.1:8765/api/v1/';
  }

  static set wsBaseUrl(String value) => _wsBaseUrlOverride = value;

  // Chat
  static const String chatStream = 'chat/stream';
  static const String chatSessions = 'chat/sessions';

  // Graph
  static const String graphNodes = 'graph/nodes';
  static const String graphEdges = 'graph/edges';
  static const String graphFull = 'graph/full';
  static const String graphIngest = 'graph/ingest';
  static const String graphSearch = 'graph/search';
  static const String graphIngestYT = 'ingest/youtube';

  // Vault (AI-OS .md file system)
  static const String vaultNotes = 'vault/notes';
  static const String vaultFolders = 'vault/folders';
  static const String vaultGraph = 'vault/notes/graph';
  static const String vaultSearch = 'vault/notes/search';

  // Models
  static const String modelsList = 'models/list';
  static const String modelsDownload = 'models/download';
  static const String modelsLoad = 'models/load';
  static const String modelsLoadCustom = 'models/load_custom';
  static const String modelsUnload = 'models/unload';
  static const String serverStart = 'models/server/start';
  static const String serverStop = 'models/server/stop';
  static const String serverStatus = 'models/server/status';
  static const String serverConfig = 'models/server/config';

  // GSD
  static const String gsdProjects = 'gsd/projects';
  static const String gsdEngine = 'gsd-engine';

  // World Monitor
  static const String worldMetrics = 'worldmonitor/metrics';
  static const String worldNews = 'worldmonitor/news';
  static const String worldBriefing = 'worldmonitor/briefing';
  static const String worldStream = 'worldmonitor/stream';

  // CodeFlow
  static const String codeflowAnalyze = 'codeflow/analyze';
  static const String codeflowFile = 'codeflow/file';
  static const String codeflowExplain = 'codeflow/explain';

  // GitHub
  static const String githubConnect = 'github/connect';
  static const String githubRepos = 'github/repos';
  static const String githubSync = 'github/sync';
  static const String githubStatus = 'github/status';
  static const String githubVaultSet = 'github/vault/set';
  static const String githubVaultCreate = 'github/vault/create';

  // System
  static const String systemMetrics = 'system/metrics';

  // Voice
  static const String voiceListen = 'voice/listen';
  static const String voiceVoices = 'voice/voices';

  // Health & Education (Gemma 4)
  static const String healthStatus = 'health/status';
  static const String healthAnalyzeXray = 'health/analyze-xray';
  static const String healthEHRQuery = 'health/ehr/query';
  static const String healthEHRUpdate = 'health/ehr/update';
  static const String healthDemoConfig = 'health/demo-config';

  static const String educationStatus = 'education/status';
  static const String educationGradeHomework = 'education/grade-homework';
  static const String educationGenerateQuiz = 'education/generate-quiz';
  static const String educationProgress = 'education/progress';
  static const String educationTrackSubmission = 'education/track-submission';
  static const String educationDemoConfig = 'education/demo-config';

  // Skills
  static const String skillsBase = 'skills';
  static const String skillsList = 'skills/';
  static const String skillsExecute = 'skills/execute';
  static const String skillsCreate = 'skills/create';
  static const String skillsAutoGenerate = 'skills/auto-generate';
  static const String skillsAutoGenerateToggle = 'skills/auto-generate/toggle';
  static const String skillsCategories = 'skills/categories';

  // Chat — Multimodal
  static const String chatMultimodal = 'chat/multimodal';

  // Models — LM Studio
  static const String modelsLmStudio = 'models/lmstudio';

  // Vector DB stats
  static const String vectorDbStats = 'system/vector-db/stats';

  // Chat Sync
  static const String chatSyncStatus = 'chat/sync/status';
  static const String chatSyncNow = 'chat/sync/now';

  // Health check
  static const String health = 'health';
}
