class ApiConstants {
  static String baseUrl = 'http://127.0.0.1:8765/api/v1/';
  static String wsBaseUrl = 'ws://127.0.0.1:8765/api/v1/';

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
}
