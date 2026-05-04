import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/graph_view.dart';

class InteractionScreen extends StatefulWidget {
  const InteractionScreen({super.key});
  @override
  State<InteractionScreen> createState() => _InteractionScreenState();
}

class _InteractionScreenState extends State<InteractionScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  AgentProfile? _selectedAgent;
  final List<_ChatMsg> _messages = [];
  bool _thinking = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: MFColors.bg,
      body: Column(children: [
        MFTopBar(
          currentStep: 5,
          stepName: 'Interaction',
          status: 'Ready',
          activeView: p.viewMode.index,
          onGraph: () => p.setViewMode(ViewMode.graph),
          onSplit: () => p.setViewMode(ViewMode.split),
          onWorkbench: () => p.setViewMode(ViewMode.workbench),
        ),
        Expanded(child: _buildBody(context, p)),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, AppProvider p) {
    return Row(children: [
      // Left: graph
      Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFFF5F5F5),
            child:
                GraphView(data: p.graphData, showEdgeLabels: p.showEdgeLabels),
          )),
      Container(width: 1, color: MFColors.border),
      // Right: agent chat
      SizedBox(
          width: 460,
          child: _ChatPanel(
            p: p,
            selectedAgent: _selectedAgent,
            messages: _messages,
            thinking: _thinking,
            msgCtrl: _msgCtrl,
            scrollCtrl: _scrollCtrl,
            onSelectAgent: (a) => setState(() {
              _selectedAgent = a;
              _messages.clear();
            }),
            onSend: _sendMessage,
          )),
    ]);
  }

  Future<void> _sendMessage(AppProvider p) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMsg(
          role: 'user', content: text, agentName: 'You', agentType: 'User'));
      _msgCtrl.clear();
      _thinking = true;
    });

    try {
      final agentName = _selectedAgent?.name ?? 'ReportAgent';
      final agentDesc = _selectedAgent?.description ??
          'Analysis assistant with access to simulation data';
      final agentStance = _selectedAgent?.stance ?? 'neutral';

      final system = '''You are $agentName, an agent in a social simulation.
Profile: $agentDesc
Stance: $agentStance
Respond in character, in 2-4 sentences, from this agent's perspective.
Reference the simulation context when relevant.''';

      final history = _messages
          .map(
              (m) => '${m.role == "user" ? "User" : m.agentName}: ${m.content}')
          .join('\n');

      final agentMsg = _ChatMsg(
        role: 'agent',
        content: '',
        agentName: agentName,
        agentType: _selectedAgent?.type ?? 'Agent',
      );

      final stream = p.llmService.streamComplete(
        '$history\nUser: $text\n$agentName:',
        system: system,
        maxTokens: 400,
      );

      bool started = false;
      await for (final chunk in stream) {
        if (!started) {
          setState(() {
            _messages.add(agentMsg);
            _thinking = false;
          });
          started = true;
          _scrollToBottom();
        }
        setState(() {
          agentMsg.content += chunk;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMsg(
          role: 'agent',
          content: _demoReply(_selectedAgent?.name ?? 'Agent', text),
          agentName: _selectedAgent?.name ?? 'ReportAgent',
          agentType: _selectedAgent?.type ?? 'Agent',
        ));
        _thinking = false;
      });
    }
  }

  String _demoReply(String name, String q) {
    if (q.toLowerCase().contains('opinion')) {
      return 'From my perspective as $name, the public opinion situation is complex. There are strong voices on both sides — those who see this as a victory for justice and those who remain skeptical about institutional motivations.';
    }
    if (q.toLowerCase().contains('university') ||
        q.toLowerCase().contains('decision')) {
      return 'As $name, I believe the university\'s decision reflects both legal pressure and reputational calculus. Whether this represents genuine reform or merely reactive governance remains to be seen.';
    }
    return 'As $name, I can share that the simulation data shows significant polarization on this topic. The discourse has shifted from the specific incident to broader questions of procedural fairness and institutional accountability.';
  }
}

class _ChatMsg {
  final String role;
  String content;
  final String agentName;
  final String agentType;
  _ChatMsg(
      {required this.role,
      required this.content,
      required this.agentName,
      required this.agentType});
}

class _ChatPanel extends StatelessWidget {
  final AppProvider p;
  final AgentProfile? selectedAgent;
  final List<_ChatMsg> messages;
  final bool thinking;
  final TextEditingController msgCtrl;
  final ScrollController scrollCtrl;
  final void Function(AgentProfile?) onSelectAgent;
  final Future<void> Function(AppProvider) onSend;

  const _ChatPanel({
    required this.p,
    required this.selectedAgent,
    required this.messages,
    required this.thinking,
    required this.msgCtrl,
    required this.scrollCtrl,
    required this.onSelectAgent,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Agent selector
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MFColors.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SELECT AGENT OR REPORT AGENT',
              style: TextStyle(
                  fontSize: 9,
                  color: MFColors.textMuted,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                // ReportAgent
                _AgentChip(
                  name: 'ReportAgent',
                  type: 'AI',
                  selected: selectedAgent == null,
                  onTap: () => onSelectAgent(null),
                ),
                const SizedBox(width: 6),
                // Actual agents
                ...p.agents.take(6).map((a) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _AgentChip(
                        name: a.name,
                        type: a.type,
                        selected: selectedAgent?.id == a.id,
                        onTap: () => onSelectAgent(a),
                        stance: a.stance,
                      ),
                    )),
              ])),
        ]),
      ),

      // Agent info bar
      if (selectedAgent != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MFColors.nodeColor(selectedAgent!.type).withOpacity(0.05),
            border: const Border(bottom: BorderSide(color: MFColors.border)),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MFColors.nodeColor(selectedAgent!.type).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(
                selectedAgent!.name[0],
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: MFColors.nodeColor(selectedAgent!.type)),
              )),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(selectedAgent!.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(selectedAgent!.type,
                      style: const TextStyle(
                          fontSize: 10, color: MFColors.textSecond)),
                ])),
            MFBadge(
                label: selectedAgent!.stance.toUpperCase(),
                color: selectedAgent!.stanceColor),
          ]),
        ),

      // Chat messages
      Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 32, color: MFColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                      selectedAgent != null
                          ? 'Start a conversation with ${selectedAgent!.name}'
                          : 'Ask ReportAgent about the simulation results',
                      style: const TextStyle(
                          color: MFColors.textMuted, fontSize: 12),
                      textAlign: TextAlign.center),
                ]))
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (thinking ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (thinking && i == messages.length)
                      return const _ThinkingBubble();
                    final msg = messages[i];
                    return _MsgBubble(msg: msg);
                  },
                )),

      // Input
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: MFColors.border))),
        child: Row(children: [
          Expanded(
              child: TextField(
            controller: msgCtrl,
            onSubmitted: (_) => onSend(p),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: selectedAgent != null
                  ? 'Ask ${selectedAgent!.name}...'
                  : 'Ask ReportAgent about the analysis...',
              hintStyle:
                  const TextStyle(color: MFColors.textMuted, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: MFColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: MFColors.border),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          )),
          const SizedBox(width: 8),
          IconButton(
            onPressed: thinking ? null : () => onSend(p),
            icon: Icon(Icons.send_rounded,
                color: thinking ? MFColors.textMuted : MFColors.textPrimary),
            style: IconButton.styleFrom(
              backgroundColor: thinking
                  ? MFColors.bgSecond
                  : MFColors.textPrimary.withOpacity(0.05),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _AgentChip extends StatelessWidget {
  final String name;
  final String type;
  final bool selected;
  final VoidCallback onTap;
  final String? stance;
  const _AgentChip(
      {required this.name,
      required this.type,
      required this.selected,
      required this.onTap,
      this.stance});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? MFColors.textPrimary : Colors.transparent,
          border: Border.all(
              color: selected ? MFColors.textPrimary : MFColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(name,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : MFColors.textSecond)),
      ),
    );
  }
}

class _MsgBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _MsgBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isUser) ...[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MFColors.nodeColor(msg.agentType).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                        child: Text(msg.agentName[0],
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: MFColors.nodeColor(msg.agentType)))),
                  ),
                  const SizedBox(width: 6),
                  Text(msg.agentName,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ] else
                  Text('You',
                      style: const TextStyle(
                          fontSize: 11, color: MFColors.textSecond)),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: isUser ? MFColors.textPrimary : MFColors.bgSecond,
                border: Border.all(
                    color: isUser ? MFColors.textPrimary : MFColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: MarkdownBody(
                data: msg.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isUser ? Colors.white : MFColors.textPrimary),
                  listBullet: TextStyle(
                      fontSize: 12,
                      color: isUser ? Colors.white70 : MFColors.textSecond),
                  strong: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUser ? Colors.white : MFColors.textPrimary),
                ),
              ),
            ),
          ]),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB), shape: BoxShape.circle),
            child: const Center(
                child: Text('?',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MFColors.bgSecond,
              border: Border.all(color: MFColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                          3,
                          (i) => Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: MFColors.textMuted.withOpacity(0.3 +
                                      0.7 * (((_ctrl.value + i * 0.33) % 1.0))),
                                  shape: BoxShape.circle,
                                ),
                              )),
                    )),
          ),
        ]),
      );
}
