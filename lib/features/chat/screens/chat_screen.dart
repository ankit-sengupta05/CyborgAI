import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';          // FIX: was ../../core
import '../../../core/constants/api_constants.dart';  // FIX: was ../../core
import '../../../core/services/backend_service.dart';
import 'dart:io';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/api_service.dart';

import 'package:flutter/foundation.dart';

import 'package:hive_flutter/hive_flutter.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final double? tokenSpeed;
  final int? totalTokens;
  final double? duration;
  final String? stopReason;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.tokenSpeed,
    this.totalTokens,
    this.duration,
    this.stopReason,
  });

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    double? tokenSpeed,
    int? totalTokens,
    double? duration,
    String? stopReason,
  }) => ChatMessage(
        id: id, role: role,
        content: content ?? this.content,
        timestamp: timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
        tokenSpeed: tokenSpeed ?? this.tokenSpeed,
        totalTokens: totalTokens ?? this.totalTokens,
        duration: duration ?? this.duration,
        stopReason: stopReason ?? this.stopReason,
      );

  Map<String, dynamic> toJson() => {
    'id': id, 'role': role, 'content': content,
    'timestamp': timestamp.toIso8601String(),
    'tokenSpeed': tokenSpeed,
    'totalTokens': totalTokens,
    'duration': duration,
    'stopReason': stopReason,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'], role: json['role'], content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    tokenSpeed: json['tokenSpeed'],
    totalTokens: json['totalTokens'],
    duration: json['duration'],
    stopReason: json['stopReason'],
  );
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;
  const ChatSession({
    required this.id, required this.title,
    required this.createdAt, required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'createdAt': createdAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'], title: json['title'],
    createdAt: DateTime.parse(json['createdAt']),
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(Map<String,dynamic>.from(m))).toList(),
  );
}

class ChatState {
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final bool isGenerating;
  final bool isListening;
  final String? selectedModel;
  const ChatState({
    this.sessions = const [], this.activeSessionId,
    this.isGenerating = false, this.isListening = false, this.selectedModel,
  });

  ChatSession? get activeSession => sessions.isEmpty
      ? null
      : sessions.firstWhere((s) => s.id == activeSessionId,
          orElse: () => sessions.first);

  ChatState copyWith({
    List<ChatSession>? sessions, String? activeSessionId,
    bool? isGenerating, bool? isListening, String? selectedModel,
  }) => ChatState(
        sessions: sessions ?? this.sessions,
        activeSessionId: activeSessionId ?? this.activeSessionId,
        isGenerating: isGenerating ?? this.isGenerating,
        isListening: isListening ?? this.isListening,
        selectedModel: selectedModel ?? this.selectedModel,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;
  final _box = Hive.box('cyborg_cache');
  ChatNotifier(this.ref) : super(const ChatState()) {
    _loadState();
    // Load voice settings from Hive
    final voiceEnabled = _box.get('voice_enabled', defaultValue: false);
    final handsFree = _box.get('hands_free_enabled', defaultValue: false);

    // Defer setting to avoid build-time update issues
    Future.microtask(() {
      ref.read(voiceEnabledProvider.notifier).state = voiceEnabled;
      ref.read(handsFreeEnabledProvider.notifier).state = handsFree;
      if (handsFree) {
        _initVoiceListener();
      }
    });
  }

  void toggleHandsFree(bool enabled) {
    _box.put('hands_free_enabled', enabled);
    if (enabled) {
      _initVoiceListener();
    } else {
      _stopVoiceListener();
    }
  }

  void toggleVoice(bool enabled) {
    _box.put('voice_enabled', enabled);
  }

  @override
  void dispose() {
    _ws?.sink.close();
    _stopVoiceListener();
    super.dispose();
  }

  final _uuid = const Uuid();
  WebSocketChannel? _ws;
  WebSocketChannel? _voiceWs;

  void _initVoiceListener() {
    if (_voiceWs != null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _connectVoiceWs('guest');
    } else {
      user.getIdToken().then((token) => _connectVoiceWs(token ?? 'anonymous'));
    }
  }

  void _connectVoiceWs(String token) {
    if (_voiceWs != null) return;
    try {
      final wsUrl = '${ApiConstants.wsBaseUrl}voice/stream?token=$token';
      _voiceWs = WebSocketChannel.connect(Uri.parse(wsUrl));

      _voiceWs!.sink.add(jsonEncode({'type': 'start_wake_word'}));

      _voiceWs!.stream.listen((data) {
        final parsed = jsonDecode(data as String);
        if (parsed['type'] == 'wake_word_detected') {
          final transcript = parsed['transcript'] as String;
          if (transcript.isNotEmpty) {
            sendMessage(transcript);
          }
        }
      }, onDone: () {
        _voiceWs = null;
        if (ref.read(handsFreeEnabledProvider)) {
          Future.delayed(const Duration(seconds: 5), _initVoiceListener);
        }
      }, onError: (err) {
        debugPrint('Voice WS error: $err');
        _voiceWs = null;
      });
    } catch (e) {
      debugPrint('Voice WS connection failed: $e');
      _voiceWs = null;
    }
  }

  void _stopVoiceListener() {
    _voiceWs?.sink.add(jsonEncode({'type': 'stop_wake_word'}));
    _voiceWs?.sink.close();
    _voiceWs = null;
  }

  void _loadState() {
    try {
      final data = _box.get('chat_sessions');
      if (data != null) {
        final List sessionsData = jsonDecode(data);
        final sessions = sessionsData.map((s) => ChatSession.fromJson(Map<String,dynamic>.from(s))).toList();
        if (sessions.isNotEmpty) {
           state = state.copyWith(sessions: sessions, activeSessionId: sessions.last.id);
           return;
        }
      }
    } catch (_) {}
    _createNewSession();
  }

  void _saveState(List<ChatSession> sessions) {
    _box.put('chat_sessions', jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  void _createNewSession() {
    final session = ChatSession(
      id: _uuid.v4(), title: 'New Chat',
      createdAt: DateTime.now(), messages: [],
    );
    final newSessions = [...state.sessions, session];
    state = state.copyWith(
      sessions: newSessions,
      activeSessionId: session.id,
    );
    _saveState(newSessions);
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || state.isGenerating) return;

    final userMsg = ChatMessage(
        id: _uuid.v4(), role: 'user',
        content: content.trim(), timestamp: DateTime.now());
    final assistantMsg = ChatMessage(
        id: _uuid.v4(), role: 'assistant',
        content: '', timestamp: DateTime.now(), isStreaming: true);

    _addMessage(userMsg);
    _addMessage(assistantMsg);
    state = state.copyWith(isGenerating: true);

    final useVoice = ref.read(voiceEnabledProvider);

    try {
      await _streamResponse(assistantMsg.id, content, useVoice: useVoice);
    } catch (e) {
      _updateMessage(assistantMsg.id, 'Error: $e', isStreaming: false);
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  Future<void> startVoiceChat() async {
    if (state.isGenerating || state.isListening) return;
    state = state.copyWith(isListening: true);

    try {
      final response = await ApiService().dio.post('voice/listen');
      final transcript = response.data['transcript'] as String;

      state = state.copyWith(isListening: false);
      if (transcript.isNotEmpty) {
        await sendMessage(transcript);
      }
    } catch (e) {
      state = state.copyWith(isListening: false);
      debugPrint('Voice chat failed: $e');
    }
  }

  Future<void> stopVoiceChat() async {
    if (!state.isListening) return;
    try {
      await ApiService().dio.post('voice/stop');
    } catch (_) {}
    state = state.copyWith(isListening: false);
  }

  Future<void> _streamResponse(String assistantMsgId, String content, {bool useVoice = false}) async {
    final isPureLocalAndroid = !kIsWeb && Platform.isAndroid && ApiConstants.wsBaseUrl.contains('127.0.0.1');

    final history = state.activeSession?.messages
            .where((m) => m.id != assistantMsgId && !m.isStreaming)
            .map((m) => {'role': m.role, 'content': m.content})
            .toList() ?? [];

    int tokenCount = 0;
    final stopwatch = Stopwatch()..start();

    if (isPureLocalAndroid) {
      final backend = ref.read(inferenceBackendProvider);
      if (!backend.isReady) {
        _updateMessage(assistantMsgId, 'Error: Local LightRT inference engine is not ready.', isStreaming: false);
        return;
      }

      // Simple stringify history
      final promptBuf = StringBuffer();
      for (var msg in history) {
        promptBuf.writeln("${msg['role']}: ${msg['content']}");
      }
      promptBuf.writeln("assistant:");

      final stream = backend.complete(
        prompt: promptBuf.toString(),
        modelPath: state.selectedModel
      );
      String accumulated = '';
      final uiStopwatch = Stopwatch()..start();
      await for (final token in stream) {
         tokenCount++;
         accumulated += token;

         if (uiStopwatch.elapsedMilliseconds > 40) {
           _updateMessage(assistantMsgId, accumulated, isStreaming: true);
           uiStopwatch.reset();
         }
      }
      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds / 1000.0;
      final speed = duration > 0 ? tokenCount / duration : 0.0;

      _updateMessage(
        assistantMsgId, accumulated, isStreaming: false,
        tokenSpeed: speed, totalTokens: tokenCount,
        duration: duration, stopReason: 'EOS Token Found'
      );
      _updateSessionTitle(content);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ?? '';
    final wsUrl = '${ApiConstants.wsBaseUrl}${ApiConstants.chatStream}?token=$token';
    _ws = WebSocketChannel.connect(Uri.parse(wsUrl));

    _ws!.sink.add(jsonEncode({
      'type': 'chat',
      'session_id': state.activeSessionId,
      'messages': history,
      'model': state.selectedModel,
      'voice': useVoice,
      'voice_name': 'af_sarah',
    }));

    String accumulated = '';
    final uiStopwatch = Stopwatch()..start();

    await for (final data in _ws!.stream) {
      final parsed = jsonDecode(data as String);
      if (parsed['type'] == 'token') {
        tokenCount++;
        accumulated += parsed['token'] as String;

        // Throttle UI updates to 40ms for a responsive "lightning fast" feel.
        // AXTree crashes are now mitigated by global ExcludeSemantics in main.dart.
        if (uiStopwatch.elapsedMilliseconds > 40) {
          _updateMessage(assistantMsgId, accumulated, isStreaming: true);
          uiStopwatch.reset();
        }
      } else if (parsed['type'] == 'done') {
        stopwatch.stop();
        final duration = stopwatch.elapsedMilliseconds / 1000.0;
        final speed = duration > 0 ? tokenCount / duration : 0.0;

        _updateMessage(
          assistantMsgId, accumulated, isStreaming: false,
          tokenSpeed: speed, totalTokens: tokenCount,
          duration: duration, stopReason: 'EOS Token Found'
        );
        _updateSessionTitle(content);
        break;
      } else if (parsed['type'] == 'error') {
        _updateMessage(assistantMsgId,
            'Error: ${parsed['message']}', isStreaming: false);
        break;
      }
    }
  }

  void _addMessage(ChatMessage msg) {
    final sessions = state.sessions.map((s) {
      if (s.id != state.activeSessionId) return s;
      return ChatSession(
          id: s.id, title: s.title, createdAt: s.createdAt,
          messages: [...s.messages, msg]);
    }).toList();
    state = state.copyWith(sessions: sessions);
    _saveState(sessions);
  }

  void _updateMessage(String msgId, String content, {bool? isStreaming, double? tokenSpeed, int? totalTokens, double? duration, String? stopReason}) {
    final sessions = state.sessions.map((s) {
      if (s.id != state.activeSessionId) return s;
      return ChatSession(
          id: s.id, title: s.title, createdAt: s.createdAt,
          messages: s.messages.map((m) {
            if (m.id != msgId) return m;
            return m.copyWith(
              content: content, isStreaming: isStreaming,
              tokenSpeed: tokenSpeed, totalTokens: totalTokens,
              duration: duration, stopReason: stopReason
            );
          }).toList());
    }).toList();
    state = state.copyWith(sessions: sessions);

    // Only save to disk when the stream is fully finished to prevent severe UI stutter
    if (isStreaming == false) {
      _saveState(sessions);
    }
  }

  void _updateSessionTitle(String firstMessage) {
    final sessions = state.sessions.map((s) {
      if (s.id != state.activeSessionId || s.title != 'New Chat') return s;
      return ChatSession(
          id: s.id,
          title: firstMessage.length > 40
              ? '${firstMessage.substring(0, 40)}...'
              : firstMessage,
          createdAt: s.createdAt,
          messages: s.messages);
    }).toList();
    state = state.copyWith(sessions: sessions);
    _saveState(sessions);
  }

  void newSession()          => _createNewSession();
  void setSession(String id) => state = state.copyWith(activeSessionId: id);
  void setModel(String? m)   => state = state.copyWith(selectedModel: m);

}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  const ChatScreen({super.key, this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController  = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showSessions = true;
  bool _showSettings = true;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final notifier  = ref.read(chatProvider.notifier);
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    final isNarrow = MediaQuery.of(context).size.width < 800;

    final sessionsSidebar = Container(
      width: isNarrow ? MediaQuery.of(context).size.width * 0.75 : 200,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Chat',
                    style: TextStyle(fontSize: 12)),
                onPressed: () {
                  notifier.newSession();
                  if (isNarrow) Navigator.of(context).pop();
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ExcludeSemantics(
              excluding: true,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: chatState.sessions.length,
                itemBuilder: (context, i) {
                  final session = chatState.sessions.reversed.toList()[i];
                  final isActive = session.id == chatState.activeSessionId;
                  return ListTile(
                    dense: true,
                    selected: isActive,
                    selectedTileColor: AppColors.accent.withOpacity(0.1),
                    title: Text(
                      session.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      notifier.setSession(session.id);
                      if (isNarrow) Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    final mainChat = Column(
      children: [
        _ChatHeader(
          showSessions: _showSessions,
          onToggleSessions: () {
            if (isNarrow) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              setState(() => _showSessions = !_showSessions);
            }
          },
          showSettings: _showSettings,
          onToggleSettings: () {
            if (isNarrow) {
              _scaffoldKey.currentState?.openEndDrawer();
            } else {
              setState(() => _showSettings = !_showSettings);
            }
          },
          selectedModel: chatState.selectedModel,
          onModelChanged: notifier.setModel,
        ),
        const Divider(height: 1),
        Expanded(
          child: (chatState.activeSession?.messages.isEmpty ?? true)
              ? const _EmptyChatState()
              : ExcludeSemantics(
                  excluding: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.activeSession!.messages.length,
                    itemBuilder: (context, i) => _MessageBubble(
                        message: chatState.activeSession!.messages[i]),
                  ),
                ),
        ),
        SafeArea(
          bottom: true,
          child: _ChatInput(
            controller: _inputController,
            isGenerating: chatState.isGenerating,
            onSend: () {
              notifier.sendMessage(_inputController.text);
              _inputController.clear();
            },
          ),
        ),
      ],
    );

    final settingsSidebar = isNarrow
      ? SizedBox(width: MediaQuery.of(context).size.width * 0.75, child: const _ChatSettingsPanel())
      : const _ChatSettingsPanel();

    return ExcludeSemantics(
      excluding: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        drawer: isNarrow ? Drawer(child: sessionsSidebar) : null,
        endDrawer: isNarrow ? Drawer(child: settingsSidebar) : null,
        body: Row(
          children: [
            if (!isNarrow && _showSessions) sessionsSidebar,
            Expanded(child: mainChat),
            if (!isNarrow && _showSettings) settingsSidebar,
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final bool showSessions;
  final VoidCallback onToggleSessions;
  final bool showSettings;
  final VoidCallback onToggleSettings;
  final String? selectedModel;
  final ValueChanged<String?> onModelChanged;

  const _ChatHeader({
    required this.showSessions,
    required this.onToggleSessions,
    required this.showSettings,
    required this.onToggleSettings,
    required this.selectedModel,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              showSessions ? Icons.menu_open : Icons.menu,
              size: 18,
            ),
            onPressed: onToggleSessions,
          ),
          const SizedBox(width: 8),
          const Text('Chat',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              )),
          const Spacer(),
          _ModelSelector(
              selectedModel: selectedModel,
              onModelChanged: onModelChanged),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              showSettings ? Icons.tune : Icons.tune_outlined,
              size: 18,
            ),
            onPressed: onToggleSettings,
          ),
        ],
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  final String? selectedModel;
  final ValueChanged<String?> onModelChanged;
  const _ModelSelector(
      {required this.selectedModel, required this.onModelChanged});

  static const _models = [
    'gemma-4-e2b-it-q8-0',
    'qwen2.5-1.5b-instruct-q4',
    'qwen2.5-coder-14b',
    'llama-3.2-8b',
    'mistral-7b',
    'deepseek-r1-7b',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String?>(
        value: selectedModel,
        hint: const Text('Auto',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        dropdownColor: AppColors.surfaceVariant,
        underline: const SizedBox(),
        icon: const Icon(Icons.expand_more,
            size: 16, color: AppColors.textSecondary),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Auto',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
          ..._models.map((m) => DropdownMenuItem<String?>(
                value: m,
                child: Text(m,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12)),
              )),
        ],
        onChanged: onModelChanged,
        isDense: true,
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.android,
                size: 48, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          const Text('Cyborg AI',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          const Text(
            'Your local-first AGI assistant.\nHow can I help you today?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _SuggestionChip('Analyze my codebase'),
              _SuggestionChip('Create a project plan'),
              _SuggestionChip('Build a knowledge graph'),
              _SuggestionChip('Search my documents'),
            ],
          ),
        ],
      )),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip(this.text);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: () {},
    );
  }
}


class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  bool get isUser => message.role == 'user';

  Widget _buildMarkdown(String data) {
    final text = data.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    // Append a newline when streaming to force flutter_markdown to close pending blocks
    // and prevent the _inlines.isEmpty assertion crash.
    final renderText = message.isStreaming ? '$text\n' : text;

    return MarkdownBody(
      data: renderText,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.6),
        code: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.accent, backgroundColor: Colors.transparent),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(),
        h1: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        h2: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCustomCodeBlock(String language, String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.isEmpty ? 'text' : language,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                  },
                  child: Row(
                    children: const [
                      Icon(Icons.copy, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Copy', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFD4D4D4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMessageContent(String content) {
    if (!content.contains('```')) {
      return [_buildMarkdown(content)];
    }

    final parts = <Widget>[];
    final regex = RegExp(r'```([a-zA-Z0-9_+-]*)(?:\n)?([\s\S]*?)(?:```|$)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(content)) {
      if (match.start > lastMatchEnd) {
        final text = content.substring(lastMatchEnd, match.start);
        if (text.trim().isNotEmpty) {
          parts.add(_buildMarkdown(text));
        }
      }

      final language = match.group(1) ?? '';
      final code = match.group(2) ?? '';

      parts.add(_buildCustomCodeBlock(language, code));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < content.length) {
      final text = content.substring(lastMatchEnd);
      if (text.trim().isNotEmpty) {
        parts.add(_buildMarkdown(text));
      }
    }

    return parts;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.android,
                  size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.accent.withOpacity(0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUser
                      ? AppColors.accent.withOpacity(0.2)
                      : AppColors.border,
                ),
              ),
              child: ExcludeSemantics(
                excluding: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isStreaming && message.content.isEmpty)
                      const _TypingIndicator()
                    else
                      ..._buildMessageContent(message.content),
                    if (!message.isStreaming && !isUser && message.tokenSpeed != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatBadge(icon: Icons.bolt, text: '${message.tokenSpeed!.toStringAsFixed(2)} tok/sec'),
                          _StatBadge(icon: Icons.layers_outlined, text: '${message.totalTokens} tokens'),
                          _StatBadge(icon: Icons.timer_outlined, text: '${message.duration!.toStringAsFixed(2)}s'),
                          _StatBadge(icon: Icons.stop_circle_outlined, text: 'Stop reason: ${message.stopReason}'),
                        ],
                      ),
                    ],
                    if (message.isStreaming) ...[
                      const SizedBox(height: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceVariant,
              child: Icon(Icons.person,
                  size: 16, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600));
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(c))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (context, _) => Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textSecondary
                  .withOpacity(0.3 + 0.7 * _anims[i].value),
            ),
          ),
        );
      }),
    );
  }
}

class _ChatInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.isGenerating,
    required this.onSend,
  });

  @override
  ConsumerState<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<_ChatInput> {
  bool _thinkEnabled = false;
  bool _visionEnabled = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary),
            offset: const Offset(0, -200),
            color: AppColors.surfaceVariant,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              // Mock action for attachment options
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'pic', child: Row(children: [const Icon(Icons.image, size: 18, color: AppColors.textPrimary), const SizedBox(width: 8), const Text('Upload Pic', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))])),
              PopupMenuItem(value: 'doc', child: Row(children: [const Icon(Icons.description, size: 18, color: AppColors.textPrimary), const SizedBox(width: 8), const Text('Upload Doc', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))])),
              PopupMenuItem(value: 'aud', child: Row(children: [const Icon(Icons.audiotrack, size: 18, color: AppColors.textPrimary), const SizedBox(width: 8), const Text('Upload Audio', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))])),
              PopupMenuItem(value: 'file', child: Row(children: [const Icon(Icons.insert_drive_file, size: 18, color: AppColors.textPrimary), const SizedBox(width: 8), const Text('Upload File', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))])),
            ],
          ),
          IconButton(
            icon: Icon(
              state.isListening ? Icons.stop : Icons.mic_none,
              color: state.isListening ? AppColors.accentRed : AppColors.textSecondary
            ),
            onPressed: state.isGenerating
              ? null
              : () {
                if (state.isListening) {
                  notifier.stopVoiceChat();
                } else {
                  notifier.startVoiceChat();
                }
              },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: widget.controller,
                  maxLines: 5,
                  minLines: 1,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Send a message to the model...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onSubmitted: (_) => widget.onSend(),
                  textInputAction: TextInputAction.send,
                ),
                Row(
                  children: [
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _thinkEnabled = !_thinkEnabled),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _thinkEnabled ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _thinkEnabled ? AppColors.accent.withOpacity(0.5) : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.psychology_alt, size: 14, color: _thinkEnabled ? AppColors.accent : AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('Think', style: TextStyle(fontSize: 12, color: _thinkEnabled ? AppColors.accent : AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _visionEnabled = !_visionEnabled),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _visionEnabled ? AppColors.accentYellow.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _visionEnabled ? AppColors.accentYellow.withOpacity(0.5) : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.remove_red_eye_outlined, size: 14, color: _visionEnabled ? AppColors.accentYellow : AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('Vision', style: TextStyle(fontSize: 12, color: _visionEnabled ? AppColors.accentYellow : AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: widget.isGenerating ? null : widget.onSend,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.all(12),
              shape: const CircleBorder(),
            ),
            child: widget.isGenerating
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.arrow_upward, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Panel ──────────────────────────────────────────────────────────

class _ChatSettingsPanel extends StatefulWidget {
  const _ChatSettingsPanel();

  @override
  State<_ChatSettingsPanel> createState() => _ChatSettingsPanelState();
}

class _ChatSettingsPanelState extends State<_ChatSettingsPanel> {
  double _temperature = 0.7;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const Row(
              children: [
                Icon(Icons.tune, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Model Parameters',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Preset
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Preset', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select a Preset...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Icon(Icons.unfold_more, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Save Preset As...', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // System Prompt
                const Row(
                  children: [
                    Icon(Icons.terminal, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('System Prompt', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 4,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Example, "Only answer in rhymes"',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Settings Accordion
                const Row(
                  children: [
                    Icon(Icons.settings, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    Spacer(),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 16),

                // Temperature
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Temperature', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(_temperature.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.textPrimary,
                    overlayColor: AppColors.accent.withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _temperature,
                    min: 0.0,
                    max: 2.0,
                    onChanged: (val) => setState(() => _temperature = val),
                  ),
                ),
                const SizedBox(height: 12),

                // Assistant Voice Response
                Consumer(
                  builder: (context, ref, _) {
                    final voiceEnabled = ref.watch(voiceEnabledProvider);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Voice Response', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                        SizedBox(
                          width: 32, height: 20,
                          child: Switch(
                            value: voiceEnabled,
                            onChanged: (val) {
                              ref.read(voiceEnabledProvider.notifier).state = val;
                              ref.read(chatProvider.notifier).toggleVoice(val);
                            },
                            activeColor: AppColors.accent,
                          ),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 16),

                // Hands-free Mode (Wake Word)
                Consumer(
                  builder: (context, ref, _) {
                    final handsFree = ref.watch(handsFreeEnabledProvider);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Voice Assistant Toggle', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                        SizedBox(
                          width: 32, height: 20,
                          child: Switch(
                            value: handsFree,
                            onChanged: (val) {
                              ref.read(handsFreeEnabledProvider.notifier).state = val;
                              if (val) {
                                ref.read(voiceEnabledProvider.notifier).state = true;
                                ref.read(chatProvider.notifier).toggleVoice(true);
                              }
                              ref.read(chatProvider.notifier).toggleHandsFree(val);
                            },
                            activeColor: AppColors.accent,
                          ),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),

                // Limit Response Length
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Limit Response Length', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    SizedBox(
                      width: 32, height: 20,
                      child: Switch(
                        value: false,
                        onChanged: (val) {},
                        activeColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Context Overflow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Context Overflow', style: TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Text('Truncate Middle', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                          SizedBox(width: 4),
                          Icon(Icons.unfold_more, size: 12, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stop Strings
                const Text('Stop Strings', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter a string and press ↵',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Conversation Notes
                const Row(
                  children: [
                    Icon(Icons.menu, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Conversation Notes', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    Icon(Icons.help_outline, size: 12, color: AppColors.textSecondary),
                    Spacer(),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                    label: const Text('Add a note', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
