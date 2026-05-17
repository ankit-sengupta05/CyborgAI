import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
// dart:io is conditionally imported — on web, a stub is used.
// We never call File() directly; all bytes come through att.bytes (withData:true).
import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─── Attachment Model ─────────────────────────────────────────────────────────

enum AttachmentType { image, document, audio }

class ChatAttachment {
  final String id;
  final String path;         // absolute local path
  final String name;         // display name
  final AttachmentType type;
  final Uint8List? bytes;    // pre-loaded bytes for image preview

  ChatAttachment({
    required this.id,
    required this.path,
    required this.name,
    required this.type,
    this.bytes,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'path': path, 'name': name, 'type': type.name,
  };
}

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
  final List<ChatAttachment> attachments;

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
    this.attachments = const [],
  });

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    double? tokenSpeed,
    int? totalTokens,
    double? duration,
    String? stopReason,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        timestamp: timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
        tokenSpeed: tokenSpeed ?? this.tokenSpeed,
        totalTokens: totalTokens ?? this.totalTokens,
        duration: duration ?? this.duration,
        stopReason: stopReason ?? this.stopReason,
        attachments: attachments,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'tokenSpeed': tokenSpeed,
        'totalTokens': totalTokens,
        'duration': duration,
        'stopReason': stopReason,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        role: json['role'],
        content: json['content'],
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
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
        messages: (json['messages'] as List)
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class ChatState {
  final List<ChatSession> sessions;
  final String? activeSessionId;
  final bool isGenerating;
  final bool isListening;
  final String? selectedModel;
  const ChatState({
    this.sessions = const [],
    this.activeSessionId,
    this.isGenerating = false,
    this.isListening = false,
    this.selectedModel,
  });

  ChatSession? get activeSession => sessions.isEmpty
      ? null
      : sessions.firstWhere((s) => s.id == activeSessionId,
          orElse: () => sessions.first);

  ChatState copyWith({
    List<ChatSession>? sessions,
    String? activeSessionId,
    bool? isGenerating,
    bool? isListening,
    String? selectedModel,
  }) =>
      ChatState(
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
        final sessions = sessionsData
            .map((s) => ChatSession.fromJson(Map<String, dynamic>.from(s)))
            .toList();
        if (sessions.isNotEmpty) {
          state = state.copyWith(
              sessions: sessions, activeSessionId: sessions.last.id);
          return;
        }
      }
    } catch (_) {}
    _createNewSession();
  }

  void _saveState(List<ChatSession> sessions) {
    _box.put(
        'chat_sessions', jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  void _createNewSession() {
    final session = ChatSession(
      id: _uuid.v4(),
      title: 'New Chat',
      createdAt: DateTime.now(),
      messages: [],
    );
    final newSessions = [...state.sessions, session];
    state = state.copyWith(
      sessions: newSessions,
      activeSessionId: session.id,
    );
    _saveState(newSessions);
  }

  Future<void> sendMessage(String content, {List<ChatAttachment> attachments = const []}) async {
    if (content.trim().isEmpty && attachments.isEmpty || state.isGenerating) return;

    final userMsg = ChatMessage(
        id: _uuid.v4(),
        role: 'user',
        content: content.trim(),
        timestamp: DateTime.now(),
        attachments: attachments);
    final assistantMsg = ChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true);

    _addMessage(userMsg);
    _addMessage(assistantMsg);
    state = state.copyWith(isGenerating: true);

    final useVoice = ref.read(voiceEnabledProvider);

    try {
      await _streamResponse(assistantMsg.id, content, attachments: attachments, useVoice: useVoice);
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

  Future<void> _streamResponse(String assistantMsgId, String content,
      {List<ChatAttachment> attachments = const [], bool useVoice = false}) async {
    // On web, Platform.isAndroid is not available — always use WebSocket path.
    // On Android+local, we could use the on-device inference backend.
    final bool isPureLocalAndroid = !kIsWeb &&
        const bool.fromEnvironment('dart.library.io') &&
        ApiConstants.wsBaseUrl.contains('127.0.0.1') &&
        // Check at runtime only on native; defaultValue keeps it false on web
        (() {
          try {
            return Platform.isAndroid;
          } catch (_) {
            return false;
          }
        }());

    final history = state.activeSession?.messages
            .where((m) => m.id != assistantMsgId && !m.isStreaming)
            .map((m) => {'role': m.role, 'content': m.content})
            .toList() ??
        [];

    int tokenCount = 0;
    final stopwatch = Stopwatch()..start();

    if (isPureLocalAndroid) {
      final backend = ref.read(inferenceBackendProvider);
      if (!backend.isReady) {
        _updateMessage(assistantMsgId,
            'Error: Local LightRT inference engine is not ready.',
            isStreaming: false);
        return;
      }

      final promptBuf = StringBuffer();
      for (var msg in history) {
        promptBuf.writeln("${msg['role']}: ${msg['content']}");
      }
      promptBuf.writeln("assistant:");

      final stream = backend.complete(
          prompt: promptBuf.toString(), modelPath: state.selectedModel);
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
      _updateMessage(assistantMsgId, accumulated,
          isStreaming: false,
          tokenSpeed: speed,
          totalTokens: tokenCount,
          duration: duration,
          stopReason: 'EOS Token Found');
      _updateSessionTitle(content);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ?? '';
    final baseWsUrl = '${ApiConstants.wsBaseUrl}${ApiConstants.chatStream}';

    // Prepare multimodal payload — images as base64 data URIs.
    // We always use att.bytes (set via withData:true in _pickImage),
    // so this is safe on both web and native.
    final List<String> imageB64List = [];

    for (final att in attachments) {
      try {
        if (att.type == AttachmentType.image && att.bytes != null) {
          final b64 = base64Encode(att.bytes!);
          final ext = att.name.split('.').last.toLowerCase();
          final mime = (ext == 'png')
              ? 'image/png'
              : (ext == 'gif')
                  ? 'image/gif'
                  : (ext == 'webp')
                      ? 'image/webp'
                      : 'image/jpeg';
          imageB64List.add('data:$mime;base64,$b64');
        }
      } catch (e) {
        debugPrint('[Chat] Image encoding failed for ${att.name}: $e');
      }
    }
    
    int retryCount = 0;
    bool connected = false;

    while (retryCount < 3 && !connected) {
      try {
        debugPrint('[Chat] Connecting to WebSocket (attempt ${retryCount + 1})...');
        
        final currentToken = await user?.getIdToken() ?? token;
        final finalWsUrl = currentToken.isNotEmpty ? '$baseWsUrl?token=$currentToken' : baseWsUrl;
        
        debugPrint('[Chat] WS URI: $finalWsUrl');
        _ws = WebSocketChannel.connect(Uri.parse(finalWsUrl));
        
        // Wait for connection to be ready
        await _ws!.ready;
        debugPrint('[Chat] WS Ready');

        final wsPayload = <String, dynamic>{
          'type': 'chat',
          'session_id': state.activeSessionId,
          'messages': history,
          // Always use Gemma-4 — the only model loaded by the backend
          'model': 'gemma-4-E4B-it-Q4_K_M',
          'voice': useVoice,
          'voice_name': 'af_sarah',
          'use_rag': true,
          'use_agent': true, // Essential for enabling LangGraph tool usage
        };
        if (imageB64List.isNotEmpty) wsPayload['images'] = imageB64List;

        _ws!.sink.add(jsonEncode(wsPayload));

        final stream = _ws!.stream.handleError((error) {
          debugPrint('[Chat] WebSocket Stream Error: $error');
        });

        String accumulated = '';
        final uiStopwatch = Stopwatch()..start();

        await for (final data in stream) {
          final parsed = jsonDecode(data as String);
          
          if (parsed['type'] == 'connected') {
            connected = true;
            debugPrint('[Chat] WebSocket connected ✓ (Handshake Acknowledged)');
            continue;
          }

          if (!connected) {
            connected = true;
            debugPrint('[Chat] WebSocket connected ✓ (First Data Received)');
          }
          if (parsed['type'] == 'token') {
            tokenCount++;
            accumulated += parsed['token'] as String;
            if (uiStopwatch.elapsedMilliseconds > 40) {
              _updateMessage(assistantMsgId, accumulated, isStreaming: true);
              uiStopwatch.reset();
            }
          } else if (parsed['type'] == 'done') {
            stopwatch.stop();
            final duration = stopwatch.elapsedMilliseconds / 1000.0;
            final speed = duration > 0 ? tokenCount / duration : 0.0;
            _updateMessage(assistantMsgId, accumulated,
                isStreaming: false,
                tokenSpeed: speed,
                totalTokens: tokenCount,
                duration: duration,
                stopReason: 'EOS Token Found');
            _updateSessionTitle(content);
            return;
          } else if (parsed['type'] == 'error') {
            _updateMessage(assistantMsgId, 'Error: ${parsed['message']}',
                isStreaming: false);
            return;
          }
        }
        
        // If we reach here, the stream ended without 'done' or 'error'
        if (!connected) {
          throw Exception('Stream closed before connection established');
        }
      } catch (e) {
        debugPrint('[Chat] WebSocket connection failed: $e');
        retryCount++;
        if (retryCount >= 3) {
          _updateMessage(assistantMsgId, 'Connection Error: $e. Please check if the backend is running on port 8765.', isStreaming: false);
          return;
        }
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }

  void _addMessage(ChatMessage msg) {
    final sessions = state.sessions.map((s) {
      if (s.id != state.activeSessionId) return s;
      return ChatSession(
          id: s.id,
          title: s.title,
          createdAt: s.createdAt,
          messages: [...s.messages, msg]);
    }).toList();
    state = state.copyWith(sessions: sessions);
    _saveState(sessions);
  }

  void _updateMessage(String msgId, String content,
      {bool? isStreaming,
      double? tokenSpeed,
      int? totalTokens,
      double? duration,
      String? stopReason}) {
    final sessions = state.sessions.map((s) {
      if (s.id != state.activeSessionId) return s;
      return ChatSession(
          id: s.id,
          title: s.title,
          createdAt: s.createdAt,
          messages: s.messages.map((m) {
            if (m.id != msgId) return m;
            return m.copyWith(
                content: content,
                isStreaming: isStreaming,
                tokenSpeed: tokenSpeed,
                totalTokens: totalTokens,
                duration: duration,
                stopReason: stopReason);
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

  void newSession() => _createNewSession();
  void setSession(String id) => state = state.copyWith(activeSessionId: id);
  void setModel(String? m) => state = state.copyWith(selectedModel: m);
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));

// ═══════════════════════════════════════════════════════════════════════════
// UI LAYER — LM Studio-style redesign (backend above is untouched)
// ═══════════════════════════════════════════════════════════════════════════

class ChatScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  const ChatScreen({super.key, this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
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
    final notifier = ref.read(chatProvider.notifier);
    ref.listen(chatProvider, (_, __) => _scrollToBottom());
    final isNarrow = MediaQuery.of(context).size.width < 800;

    final sessionsSidebar = _SessionsSidebar(
      width: isNarrow ? MediaQuery.of(context).size.width * 0.8 : 220,
      sessions: chatState.sessions,
      activeId: chatState.activeSessionId,
      onNewChat: () {
        notifier.newSession();
        if (isNarrow) _scaffoldKey.currentState?.closeDrawer();
      },
      onSelectSession: (id) {
        notifier.setSession(id);
        if (isNarrow) _scaffoldKey.currentState?.closeDrawer();
      },
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
          sessionTitle: chatState.activeSession?.title,
          isMobile: isNarrow,
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: (chatState.activeSession?.messages.isEmpty ?? true)
              ? const _EmptyChatState()
              : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                    itemCount: chatState.activeSession!.messages.length,
                    itemBuilder: (context, i) => _MessageBubble(
                        message: chatState.activeSession!.messages[i]),
                  ),
        ),
        _ChatInput(
          controller: _inputController,
          isGenerating: chatState.isGenerating,
          onSend: (attachments) {
            notifier.sendMessage(_inputController.text, attachments: attachments);
            _inputController.clear();
          },
        ),
      ],
    );

    final settingsSidebar = isNarrow
        ? SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: const _ChatSettingsPanel())
        : const _ChatSettingsPanel();

    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.backgroundMain,
        drawer: isNarrow ? Drawer(child: sessionsSidebar) : null,
        endDrawer: isNarrow ? Drawer(child: settingsSidebar) : null,
        body: Row(
          children: [
            if (!isNarrow && _showSessions) sessionsSidebar,
            if (!isNarrow && _showSessions)
              Container(width: 1, color: AppColors.border),
            Expanded(child: mainChat),
            if (!isNarrow && _showSettings)
              Container(width: 1, color: AppColors.border),
            if (!isNarrow && _showSettings) settingsSidebar,
          ],
        ),
      );
  }
}

// ─── Sessions Sidebar ─────────────────────────────────────────────────────────

class _SessionsSidebar extends StatelessWidget {
  final double width;
  final List<ChatSession> sessions;
  final String? activeId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectSession;

  const _SessionsSidebar({
    required this.width,
    required this.sessions,
    required this.activeId,
    required this.onNewChat,
    required this.onSelectSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AppColors.backgroundSidebar,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Chats',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                _SidebarIconBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'New chat',
                    onTap: onNewChat),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: sessions.length,
                itemBuilder: (context, i) {
                  final session = sessions.reversed.toList()[i];
                  final isActive = session.id == activeId;
                  return _SessionTile(
                    session: session,
                    isActive: isActive,
                    onTap: () => onSelectSession(session.id),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatefulWidget {
  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  const _SessionTile(
      {required this.session, required this.isActive, required this.onTap});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withOpacity(0.1)
                : _hovered
                    ? AppColors.backgroundSurface
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: widget.isActive
                ? Border.all(
                    color: AppColors.accent.withOpacity(0.25), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 13,
                  color: widget.isActive
                      ? AppColors.accent
                      : AppColors.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.session.title,
                  style: TextStyle(
                      fontSize: 12,
                      color: widget.isActive
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: widget.isActive
                          ? FontWeight.w500
                          : FontWeight.w400),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _SidebarIconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_SidebarIconBtn> createState() => _SidebarIconBtnState();
}

class _SidebarIconBtnState extends State<_SidebarIconBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _h ? AppColors.backgroundSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon,
                size: 16,
                color: _h ? AppColors.textPrimary : AppColors.textTertiary),
          ),
        ),
      ),
    );
  }
}

// ─── Chat Header ──────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final bool showSessions;
  final VoidCallback onToggleSessions;
  final bool showSettings;
  final VoidCallback onToggleSettings;
  final bool isMobile;
  final String? sessionTitle;

  const _ChatHeader({
    required this.showSessions,
    required this.onToggleSessions,
    required this.showSettings,
    required this.onToggleSettings,
    required this.isMobile,
    this.sessionTitle,
  });

  // Gemma-4 is the only model — locked for full multimodal performance
  static const String _modelDisplayName = 'Gemma 4 · Vision';

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.backgroundSidebar,
      child: Row(
        children: [
          if (canPop) ...[
            _HeaderIconBtn(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 4),
          ],
          _HeaderIconBtn(
              icon: isMobile ? Icons.menu : (showSessions ? Icons.menu_open : Icons.menu),
              onTap: onToggleSessions),
          const SizedBox(width: 4),
          if (sessionTitle != null)
            Expanded(
              child: Text(sessionTitle!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            )
          else
            const Spacer(),
          // Locked Gemma-4 model badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.accent.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(_modelDisplayName,
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _HeaderIconBtn(
              icon: showSettings ? Icons.tune : Icons.tune_outlined,
              onTap: onToggleSettings),
        ],
      ),
    );
  }
}

class _HeaderIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  State<_HeaderIconBtn> createState() => _HeaderIconBtnState();
}

class _HeaderIconBtnState extends State<_HeaderIconBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _h ? AppColors.backgroundSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(widget.icon,
              size: 17,
              color:
                  _h ? AppColors.textPrimary : AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 24)
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('GEMMA 4',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const SizedBox(height: 6),
            const Text('Vision  ·  Chat  ·  RAG',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5)),
            const SizedBox(height: 12),
            const Text(
              'Ask anything. Attach an image to use vision.\nAll inference is local and private.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.6),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _SuggestionPill(
                    text: 'Describe this image',
                    icon: Icons.image_search_outlined),
                _SuggestionPill(
                    text: 'Analyze my codebase',
                    icon: Icons.code),
                _SuggestionPill(
                    text: 'Search my knowledge',
                    icon: Icons.search),
                _SuggestionPill(
                    text: 'Read a document',
                    icon: Icons.description_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPill extends StatefulWidget {
  final String text;
  final IconData icon;
  const _SuggestionPill({required this.text, required this.icon});

  @override
  State<_SuggestionPill> createState() => _SuggestionPillState();
}

class _SuggestionPillState extends State<_SuggestionPill> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _h
              ? AppColors.backgroundSurface
              : AppColors.backgroundSidebar,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: _h
                  ? AppColors.accent.withOpacity(0.4)
                  : AppColors.border,
              width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon,
                size: 14,
                color: _h ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: 7),
            Text(widget.text,
                style: TextStyle(
                    fontSize: 13,
                    color: _h
                        ? AppColors.textPrimary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  bool get isUser => message.role == 'user';

  Widget _buildMarkdown(String data) {
    final text = data.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final renderText = message.isStreaming ? '$text\n' : text;
    return MarkdownBody(
      data: renderText,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
            color: AppColors.textPrimary, fontSize: 13.5, height: 1.65),
        code: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            color: AppColors.accent,
            backgroundColor: Colors.transparent),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(),
        h1: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700),
        h2: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600),
        h3: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCodeBlock(String language, String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF252528),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(language.isEmpty ? 'text' : language,
                    style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontFamily: 'monospace')),
                GestureDetector(
                  onTap: () =>
                      Clipboard.setData(ClipboardData(text: code)),
                  child: const Row(children: [
                    Icon(Icons.copy_outlined,
                        size: 12, color: AppColors.textTertiary),
                    SizedBox(width: 4),
                    Text('Copy',
                        style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11)),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(code,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      color: Color(0xFFD4D4D4),
                      height: 1.55)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(String content) {
    if (!content.contains('```')) return [_buildMarkdown(content)];
    final parts = <Widget>[];
    final regex =
        RegExp(r'```([a-zA-Z0-9_+-]*)(?:\n)?([\s\S]*?)(?:```|$)');
    int lastEnd = 0;
    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        final t = content.substring(lastEnd, match.start);
        if (t.trim().isNotEmpty) parts.add(_buildMarkdown(t));
      }
      parts.add(
          _buildCodeBlock(match.group(1) ?? '', match.group(2) ?? ''));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      final t = content.substring(lastEnd);
      if (t.trim().isNotEmpty) parts.add(_buildMarkdown(t));
    }
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.72;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 18,
        left: isUser ? 60 : 16,
        right: isUser ? 16 : 60,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.android,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.accent.withOpacity(0.1)
                      : AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUser
                        ? AppColors.accent.withOpacity(0.18)
                        : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Attachments (images / doc chips) ─────────────────────
                      if (message.attachments.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: message.attachments.map((att) {
                            if (att.type == AttachmentType.image) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: att.bytes != null
                                    ? Image.memory(att.bytes!,
                                        width: 220,
                                        height: 160,
                                        fit: BoxFit.cover)
                                    : (kIsWeb
                                        ? Container(
                                            width: 220, height: 160,
                                            color: AppColors.backgroundSurface,
                                            child: const Icon(Icons.image,
                                                size: 40, color: AppColors.textTertiary))
                                        : Image.network(att.path,
                                            width: 220,
                                            height: 160,
                                            fit: BoxFit.cover)),
                              );
                            } else {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.border),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(
                                    att.type == AttachmentType.audio
                                        ? Icons.audiotrack_outlined
                                        : Icons.description_outlined,
                                    size: 13,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(att.name,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ]),
                              );
                            }
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // ── Message content ─────────────────────────────────
                      if (message.isStreaming && message.content.isEmpty)
                        const _TypingIndicator()
                      else
                        ..._buildContent(message.content),
                      if (!message.isStreaming &&
                          !isUser &&
                          message.tokenSpeed != null) ...[
                        const SizedBox(height: 10),
                        const Divider(
                            height: 1, color: AppColors.border),
                        const SizedBox(height: 8),
                        Wrap(spacing: 14, runSpacing: 4, children: [
                          _StatBadge(
                              icon: Icons.bolt,
                              text:
                                  '${message.tokenSpeed!.toStringAsFixed(1)} tok/s'),
                          _StatBadge(
                              icon: Icons.layers_outlined,
                              text: '${message.totalTokens} tokens'),
                          _StatBadge(
                              icon: Icons.timer_outlined,
                              text:
                                  '${message.duration!.toStringAsFixed(2)}s'),
                          if (message.stopReason != null)
                            _StatBadge(
                                icon: Icons.stop_circle_outlined,
                                text: message.stopReason!),
                        ]),
                      ],
                      if (message.isStreaming)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.accent)),
                        ),
                    ],
                  ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.backgroundInput,
              child: Icon(Icons.person_outline,
                  size: 14, color: AppColors.textSecondary),
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
        Icon(icon, size: 11, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 10.5, color: AppColors.textTertiary)),
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
          vsync: this,
          duration: const Duration(milliseconds: 600));
      Future.delayed(Duration(milliseconds: i * 160), () {
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
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textSecondary
                  .withOpacity(0.25 + 0.75 * _anims[i].value),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Chat Input ───────────────────────────────────────────────────────────────

class _ChatInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final bool isGenerating;
  final void Function(List<ChatAttachment>) onSend;

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
  final List<ChatAttachment> _attachments = [];
  final _uuid = const Uuid();

  /// Pick an image — works on web (withData:true) and desktop/mobile (path).
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Always load bytes for web + preview
      );
      if (result == null) return;
      final file = result.files.single;
      // On web, path is null — use bytes only
      final att = ChatAttachment(
        id: _uuid.v4(),
        path: kIsWeb ? file.name : (file.path ?? file.name),
        name: file.name,
        type: AttachmentType.image,
        bytes: file.bytes,
      );
      setState(() => _attachments.add(att));
    } catch (e) {
      debugPrint('[Chat] Image pick failed: $e');
    }
  }

  void _removeAttachment(String id) =>
      setState(() => _attachments.removeWhere((a) => a.id == id));

  void _send() {
    if (widget.isGenerating) return;
    widget.onSend(List.from(_attachments));
    setState(() => _attachments.clear());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final hasImages = _attachments.any((a) => a.type == AttachmentType.image);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSidebar,
        border:
            Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasImages ? AppColors.accent.withOpacity(0.35) : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Attached image thumbnails row ───────────────────────────────
            if (_attachments.isNotEmpty) ...
              [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _attachments.map((att) {
                      if (att.type == AttachmentType.image) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: att.bytes != null
                                  ? Image.memory(att.bytes!,
                                      width: 72, height: 72, fit: BoxFit.cover)
                                  : (kIsWeb
                                      ? Container(
                                          width: 72, height: 72,
                                          color: AppColors.backgroundSurface,
                                          child: const Icon(Icons.image,
                                              color: AppColors.textTertiary))
                                      : Image.network(att.path,
                                          width: 72, height: 72, fit: BoxFit.cover)),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removeAttachment(att.id),
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentRed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 11, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }).toList(),
                  ),
                ),
              ],
            // ── Text field row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Clean image upload button (replaces paperclip popup)
                  Tooltip(
                    message: 'Attach image',
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 32, height: 32,
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          color: hasImages
                              ? AppColors.accent.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border: hasImages
                              ? Border.all(
                                  color: AppColors.accent.withOpacity(0.4), width: 1)
                              : null,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 17,
                          color: hasImages
                              ? AppColors.accent
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      maxLines: 6,
                      minLines: 1,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: _attachments.isEmpty
                            ? 'Message Gemma 4…'
                            : 'Ask about the image…',
                        hintStyle: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 13.5),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  // Send / Stop button
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 6, right: 6),
                    child: GestureDetector(
                      onTap: _send,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: widget.isGenerating
                              ? AppColors.backgroundSurface
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: widget.isGenerating
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_upward,
                                color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Bottom toolbar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Row(
                children: [
                  _ToggleChip(
                    icon: Icons.psychology_alt,
                    label: 'Think',
                    active: _thinkEnabled,
                    activeColor: AppColors.accent,
                    onTap: () =>
                        setState(() => _thinkEnabled = !_thinkEnabled),
                  ),
                  const SizedBox(width: 6),
                  // Vision chip — auto-lights when image attached
                  _ToggleChip(
                    icon: Icons.remove_red_eye_outlined,
                    label: 'Vision',
                    active: hasImages,
                    activeColor: AppColors.accentYellow,
                    onTap: hasImages ? _pickImage : _pickImage,
                  ),
                  const SizedBox(width: 6),
                  _ToggleChip(
                    icon: Icons.task_alt_outlined,
                    label: 'Task',
                    active: false,
                    activeColor: AppColors.accentBlue,
                    onTap: () {
                      widget.controller.text = "Analyze my current tasks and suggest the next best action.";
                      _send();
                    },
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: state.isGenerating
                        ? null
                        : () {
                            if (state.isListening) {
                              notifier.stopVoiceChat();
                            } else {
                              notifier.startVoiceChat();
                            }
                          },
                    child: Icon(
                      state.isListening
                          ? Icons.stop_circle_outlined
                          : Icons.mic_none,
                      size: 18,
                      color: state.isListening
                          ? AppColors.accentRed
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active
                  ? activeColor.withOpacity(0.4)
                  : AppColors.border,
              width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color:
                    active ? activeColor : AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: active
                        ? activeColor
                        : AppColors.textTertiary,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Panel ───────────────────────────────────────────────────────────

class _ChatSettingsPanel extends StatefulWidget {
  const _ChatSettingsPanel();

  @override
  State<_ChatSettingsPanel> createState() => _ChatSettingsPanelState();
}

class _ChatSettingsPanelState extends State<_ChatSettingsPanel> {
  double _temperature = 0.7;

  Widget _sectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      color: AppColors.backgroundSidebar,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Row(
              children: [
                Icon(Icons.tune, size: 15, color: AppColors.accent),
                SizedBox(width: 8),
                Text('Parameters',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _sectionHeader(Icons.terminal, 'SYSTEM PROMPT'),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 4,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'System instructions…',
                    filled: true,
                    fillColor: AppColors.backgroundInput,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(
                            color: AppColors.accent, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionHeader(
                    Icons.settings_outlined, 'GENERATION'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Temperature',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundInput,
                        borderRadius: BorderRadius.circular(5),
                        border:
                            Border.all(color: AppColors.border),
                      ),
                      child: Text(
                          _temperature.toStringAsFixed(2),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace')),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.textPrimary,
                    overlayColor:
                        AppColors.accent.withOpacity(0.18),
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _temperature,
                    min: 0,
                    max: 2,
                    onChanged: (v) =>
                        setState(() => _temperature = v),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsRow(
                  label: 'Context Overflow',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundInput,
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Truncate Middle',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        SizedBox(width: 4),
                        Icon(Icons.expand_more,
                            size: 13,
                            color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsRow(
                  label: 'Limit Response',
                  child: _MiniSwitch(
                      value: false, onChanged: (_) {}),
                ),
                const SizedBox(height: 20),
                _sectionHeader(
                    Icons.record_voice_over_outlined, 'VOICE'),
                const SizedBox(height: 12),
                Consumer(builder: (ctx, ref, _) {
                  final voiceEnabled =
                      ref.watch(voiceEnabledProvider);
                  return _SettingsRow(
                    label: 'Voice Response',
                    child: _MiniSwitch(
                      value: voiceEnabled,
                      onChanged: (v) {
                        ref
                            .read(voiceEnabledProvider.notifier)
                            .state = v;
                        ref
                            .read(chatProvider.notifier)
                            .toggleVoice(v);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Consumer(builder: (ctx, ref, _) {
                  final handsFree =
                      ref.watch(handsFreeEnabledProvider);
                  return _SettingsRow(
                    label: 'Hands-free Mode',
                    child: _MiniSwitch(
                      value: handsFree,
                      onChanged: (v) {
                        ref
                            .read(handsFreeEnabledProvider
                                .notifier)
                            .state = v;
                        if (v) {
                          ref
                              .read(
                                  voiceEnabledProvider.notifier)
                              .state = true;
                        }
                        ref
                            .read(chatProvider.notifier)
                            .toggleHandsFree(v);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 20),
                _sectionHeader(
                    Icons.notes_outlined, 'STOP STRINGS'),
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter string, press ↵',
                    filled: true,
                    fillColor: AppColors.backgroundInput,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide.none),
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

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12))),
        child,
      ],
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 20,
      child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accent),
    );
  }
}
