import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

String get _base => '${ApiConstants.baseUrl}voice-agent';

class VoiceAgentScreen extends StatefulWidget {
  const VoiceAgentScreen({super.key});
  @override
  State<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends State<VoiceAgentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _agents = [];
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _callLog = [];
  bool _loading = false;
  String _status = '';

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _sidCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _scriptCtrl = TextEditingController();
  final _leadNameCtrl = TextEditingController();
  final _leadPhoneCtrl = TextEditingController();
  final _leadEmailCtrl = TextEditingController();
  final _leadCompanyCtrl = TextEditingController();
  String _agentType = 'lead_generation';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAgents();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_nameCtrl,_phoneCtrl,_sidCtrl,_tokenCtrl,_scriptCtrl,_leadNameCtrl,_leadPhoneCtrl,_leadEmailCtrl,_leadCompanyCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('$_base/agents'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() => _agents = List<Map<String,dynamic>>.from(data['agents']));
        if (_agents.isNotEmpty && _selected == null) _selectAgent(_agents.first);
      }
    } catch (e) {
      setState(() => _status = 'Backend not running: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _selectAgent(Map<String, dynamic> a) async {
    setState(() { _selected = a; });
    await _loadLeads(a['id']);
    await _loadCallLog(a['id']);
  }

  Future<void> _loadLeads(String id) async {
    try {
      final r = await http.get(Uri.parse('$_base/agents/$id/leads'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() => _leads = List<Map<String,dynamic>>.from(data['leads']));
      }
    } catch (_) {}
  }

  Future<void> _loadCallLog(String id) async {
    try {
      final r = await http.get(Uri.parse('$_base/agents/$id/call-log'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() => _callLog = List<Map<String,dynamic>>.from(data['logs']));
      }
    } catch (_) {}
  }

  Future<void> _createAgent() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      setState(() => _status = 'Agent name and phone number are required.');
      return;
    }
    setState(() { _loading = true; _status = 'Creating agent...'; });
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'agent_type': _agentType,
        'phone_number': _phoneCtrl.text.trim(),
        'twilio_account_sid': _sidCtrl.text.trim(),
        'twilio_auth_token': _tokenCtrl.text.trim(),
        'script': _scriptCtrl.text.trim(),
      };
      final r = await http.post(Uri.parse('$_base/agents'), body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'});
      if (r.statusCode == 200) {
        setState(() => _status = '✅ Agent created!');
        _nameCtrl.clear(); _phoneCtrl.clear(); _sidCtrl.clear(); _tokenCtrl.clear(); _scriptCtrl.clear();
        await _loadAgents();
      } else {
        setState(() => _status = '❌ Error: ${r.body}');
      }
    } catch (e) {
      setState(() => _status = '❌ $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _addLead() async {
    if (_selected == null || _leadNameCtrl.text.trim().isEmpty || _leadPhoneCtrl.text.trim().isEmpty) {
      setState(() => _status = 'Select an agent and fill name + phone.');
      return;
    }
    final body = {
      'name': _leadNameCtrl.text.trim(),
      'phone': _leadPhoneCtrl.text.trim(),
      'email': _leadEmailCtrl.text.trim(),
      'company': _leadCompanyCtrl.text.trim(),
    };
    try {
      await http.post(Uri.parse('$_base/agents/${_selected!['id']}/leads'),
          body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
      setState(() => _status = '✅ Lead added!');
      _leadNameCtrl.clear(); _leadPhoneCtrl.clear(); _leadEmailCtrl.clear(); _leadCompanyCtrl.clear();
      await _loadLeads(_selected!['id']);
    } catch (e) {
      setState(() => _status = '❌ $e');
    }
  }

  Future<void> _startCampaign() async {
    if (_selected == null) return;
    setState(() { _loading = true; _status = '📞 Starting call campaign...'; });
    try {
      final r = await http.post(Uri.parse('$_base/agents/${_selected!['id']}/start-campaign'));
      final data = jsonDecode(r.body);
      setState(() => _status = '✅ Campaign: ${data['status']} — ${data['total_leads'] ?? 0} leads queued.');
    } catch (e) {
      setState(() => _status = '❌ $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _testVoice() async {
    if (_selected == null) return;
    setState(() => _status = '🔊 Synthesizing voice...');
    try {
      final r = await http.post(Uri.parse('$_base/agents/${_selected!['id']}/test-voice'),
          body: jsonEncode({'text': "Hello! I'm ${_selected!['name']}, calling on behalf of our company. How are you today?"}),
          headers: {'Content-Type': 'application/json'});
      final data = jsonDecode(r.body);
      setState(() => _status = data['status'] == 'ok' ? '✅ Voice test OK — ${data['audio_file']}' : '❌ ${data['message']}');
    } catch (e) {
      setState(() => _status = '❌ $e');
    }
  }

  Future<void> _exportCSV() async {
    if (_selected == null) return;
    try {
      final r = await http.get(Uri.parse('$_base/agents/${_selected!['id']}/export'));
      final data = jsonDecode(r.body);
      setState(() => _status = '✅ Exported to: ${data['file']}');
    } catch (e) {
      setState(() => _status = '❌ $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA);
    final card = isDark ? const Color(0xFF1A1D27) : Colors.white;
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          color: card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00C9B8)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Voice Call Agent', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text('Autonomous AI phone agent — lead gen, support & care',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.55))),
              ]),
              const Spacer(),
              if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAgents, tooltip: 'Refresh'),
            ]),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabs,
              labelColor: accent,
              indicatorColor: accent,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5),
              tabs: const [Tab(text: 'Agents'), Tab(text: 'Leads & Calls'), Tab(text: 'Create Agent')],
            ),
          ]),
        ),

        // Status bar
        if (_status.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _status.startsWith('✅') ? Colors.green.withOpacity(0.1)
                : _status.startsWith('❌') ? Colors.red.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            child: Text(_status, style: TextStyle(
              fontSize: 12,
              color: _status.startsWith('✅') ? Colors.green
                  : _status.startsWith('❌') ? Colors.red
                  : Colors.blue,
            )),
          ),

        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _buildAgentsTab(theme, card, accent),
            _buildLeadsTab(theme, card, accent),
            _buildCreateTab(theme, card, accent),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAgentsTab(ThemeData theme, Color card, Color accent) {
    return Row(children: [
      // Agents list
      Container(
        width: 220,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('My Agents', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _agents.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No agents yet.\nCreate one in the "Create Agent" tab.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))))
              : ListView.builder(
                  itemCount: _agents.length,
                  itemBuilder: (ctx, i) {
                    final a = _agents[i];
                    final sel = _selected?['id'] == a['id'];
                    return ListTile(
                      selected: sel,
                      selectedTileColor: accent.withOpacity(0.1),
                      leading: CircleAvatar(
                        backgroundColor: accent.withOpacity(0.15),
                        child: Icon(Icons.person_rounded, color: accent, size: 18),
                      ),
                      title: Text(a['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(_typeLabel(a['agent_type']), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      onTap: () => _selectAgent(a),
                    );
                  }),
          ),
        ]),
      ),

      // Agent details
      Expanded(
        child: _selected == null
          ? const Center(child: Text('Select an agent to view details'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _card(theme, card, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_selected!['name'] ?? '', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _chip(_typeLabel(_selected!['agent_type']), accent),
                      const SizedBox(height: 8),
                      _info(theme, Icons.phone_rounded, _selected!['phone_number'] ?? 'No number'),
                      _info(theme, Icons.info_outline_rounded, 'Status: ${_selected!['status'] ?? 'idle'}'),
                    ])),
                    Column(children: [
                      _actionBtn('📞 Start Campaign', accent, _startCampaign),
                      const SizedBox(height: 8),
                      _actionBtn('🔊 Test Voice', Colors.teal, _testVoice),
                      const SizedBox(height: 8),
                      _actionBtn('📊 Export CSV', Colors.orange, _exportCSV),
                    ]),
                  ]),
                ]),
                const SizedBox(height: 12),
                if (_selected!['script'] != null && (_selected!['script'] as String).isNotEmpty)
                  _card(theme, card, children: [
                    Text('Script / Persona', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text(_selected!['script'], style: const TextStyle(fontSize: 12, height: 1.5)),
                  ]),
              ]),
            ),
      ),
    ]);
  }

  Widget _buildLeadsTab(ThemeData theme, Color card, Color accent) {
    if (_selected == null) {
      return const Center(child: Text('Select an agent first from the Agents tab.'));
    }
    return Row(children: [
      // Add lead form
      Container(
        width: 260,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Lead', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _field('Full Name *', _leadNameCtrl),
            _field('Phone Number *', _leadPhoneCtrl, hint: '+1234567890'),
            _field('Email', _leadEmailCtrl),
            _field('Company', _leadCompanyCtrl),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addLead,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Lead'),
                style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text('Call Log (${_callLog.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_callLog.isEmpty)
              const Text('No calls made yet.', style: TextStyle(fontSize: 12))
            else
              ..._callLog.reversed.take(10).map((log) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(log['name'] ?? log['phone'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(log['outcome'] ?? '', style: TextStyle(fontSize: 11, color: _outcomeColor(log['outcome']))),
                  if (log['summary'] != null) Text(log['summary'], style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              )),
          ]),
        ),
      ),

      // Leads table
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Text('Leads (${_leads.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_leads.where((l) => l['status'] == 'interested').length} interested · ${_leads.where((l) => l['status'] == 'pending').length} pending',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _leads.isEmpty
                ? const Center(child: Text('No leads added yet.'))
                : ListView.separated(
                    itemCount: _leads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final l = _leads[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: _outcomeColor(l['status']).withOpacity(0.15),
                          child: Text((l['name'] ?? '?')[0].toUpperCase(), style: TextStyle(fontSize: 12, color: _outcomeColor(l['status']))),
                        ),
                        title: Text(l['name'] ?? '', style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${l['phone']} · ${l['company'] ?? ''}', style: const TextStyle(fontSize: 11)),
                        trailing: _chip(l['status'] ?? 'pending', _outcomeColor(l['status'])),
                      );
                    }),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildCreateTab(ThemeData theme, Color card, Color accent) {
    final types = {
      'lead_generation': '📞 Lead Generation',
      'tech_support': '🛠️ Tech Support',
      'customer_care': '❤️ Customer Care',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _card(theme, card, children: [
              Text('New Voice Agent', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Configure your autonomous AI phone agent', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.55))),
              const SizedBox(height: 20),
              _field('Agent Name *', _nameCtrl, hint: 'e.g. Sarah - Sales Agent'),
              const SizedBox(height: 4),
              Text('Agent Type', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: types.entries.map((e) => ChoiceChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  selected: _agentType == e.key,
                  onSelected: (_) => setState(() => _agentType = e.key),
                  selectedColor: accent.withOpacity(0.2),
                )).toList(),
              ),
              const SizedBox(height: 16),
              _field('Your Phone Number *', _phoneCtrl, hint: '+1 (your Twilio number or test number)'),
            ]),
            const SizedBox(height: 12),

            _card(theme, card, children: [
              Row(children: [
                const Icon(Icons.phone_android_rounded, size: 16),
                const SizedBox(width: 8),
                Text('Twilio Credentials (Optional — for real calls)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Text('Leave blank to use simulated call mode (great for testing). Sign up free at twilio.com.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.55))),
              const SizedBox(height: 12),
              _field('Account SID', _sidCtrl, hint: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'),
              _field('Auth Token', _tokenCtrl, hint: 'Your Twilio auth token', obscure: true),
            ]),
            const SizedBox(height: 12),

            _card(theme, card, children: [
              Text('Conversation Script / Persona', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Describe how your agent should talk, what to say, and what the goal is.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.55))),
              const SizedBox(height: 12),
              TextField(
                controller: _scriptCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Hi, I\'m calling on behalf of [Company]. We offer [Product]. Are you the decision-maker?\n\nGoal: Schedule a 15-min demo call...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ]),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createAgent,
                icon: const Icon(Icons.add_circle_rounded),
                label: const Text('Create Voice Agent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _card(ThemeData theme, Color card, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ]),
    );
  }

  Widget _info(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurface.withOpacity(0.4)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7))),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 160,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.12),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _typeLabel(String? t) => switch (t) {
    'lead_generation' => 'Lead Generation',
    'tech_support' => 'Tech Support',
    'customer_care' => 'Customer Care',
    _ => t ?? 'Unknown',
  };

  Color _outcomeColor(String? s) => switch (s) {
    'interested' => Colors.green,
    'not_interested' => Colors.red,
    'callback' => Colors.orange,
    'called' => Colors.blue,
    _ => Colors.grey,
  };
}
