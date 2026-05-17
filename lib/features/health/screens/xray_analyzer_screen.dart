import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../services/health_api_service.dart';

class XRayAnalyzerScreen extends StatefulWidget {
  const XRayAnalyzerScreen({super.key});
  @override
  State<XRayAnalyzerScreen> createState() => _XRayAnalyzerScreenState();
}

class _XRayAnalyzerScreenState extends State<XRayAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  final _api = HealthApiService();
  final _ageCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  PlatformFile? _image;
  bool _analyzing = false;
  Map<String, dynamic>? _result;
  String _language = 'en';
  String? _error;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  static const _languages = {
    'en': 'English',
    'es': 'Español',
    'hi': 'हिन्दी',
    'sw': 'Swahili',
    'fr': 'Français'
  };
  static const _healthBlue = Color(0xFF0ea5e9);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ageCtrl.dispose();
    _symptomsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _image = result.files.single;
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await _api.analyzeXray(
        imageFile: _image!,
        age: int.tryParse(_ageCtrl.text),
        symptoms: _symptomsCtrl.text.trim().isEmpty
            ? null
            : _symptomsCtrl.text.trim(),
        language: _language,
      );
      if (!mounted) return;
      setState(() => _result = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundMain,
        title: _buildAppBarTitle(),
      ),
      body: Row(
        children: [
          SizedBox(width: 360, child: _buildLeftPanel()),
          Container(width: 1, color: AppColors.border),
          Expanded(child: _result != null ? _buildResults() : _buildEmpty()),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() => Row(children: [
        _badge(
            Icons.medical_information_outlined, 'X-Ray Analysis', _healthBlue),
        const SizedBox(width: 8),
        _badge(Icons.wifi_off, 'Offline Mode', AppColors.textMuted),
      ]);

  Widget _badge(IconData icon, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withOpacity(0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _buildLeftPanel() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _buildUploadCard(),
          const SizedBox(height: 14),
          _buildContextCard(),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _analyzing
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.biotech_outlined, size: 17),
                label: Text(_analyzing ? 'Analyzing...' : 'Analyze X-ray'),
                onPressed: (_image != null && !_analyzing) ? _analyze : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _healthBlue,
                  disabledBackgroundColor: AppColors.backgroundInput,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _errorBanner(),
          ],
        ]),
      );

  Widget _buildUploadCard() => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _image != null
                  ? _healthBlue.withOpacity(0.5)
                  : AppColors.border),
        ),
        child: Column(children: [
          GestureDetector(
            onTap: _pick,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: AppColors.backgroundMain,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11))),
              child: _image != null
                  ? ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(11)),
                      child: kIsWeb
                          ? Image.memory(_image!.bytes!, fit: BoxFit.contain)
                          : Image.file(File(_image!.path!) as dynamic, fit: BoxFit.contain))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.textMuted, size: 44),
                          const SizedBox(height: 10),
                          Text('Tap to upload Chest X-ray',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('PNG, JPG, DICOM',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.image_search, size: 15),
                  label: Text(_image != null ? 'Change Image' : 'Select Image'),
                  onPressed: _pick,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _healthBlue,
                      side: BorderSide(color: _healthBlue)),
                )),
          ),
        ]),
      );

  Widget _buildContextCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Patient Context',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text('Optional — improves accuracy',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          TextField(
            controller: _ageCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
                labelText: 'Patient Age',
                labelStyle:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12),
                prefixIcon: Icon(Icons.person_outline,
                    size: 15, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _symptomsCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
                labelText: 'Symptoms',
                hintText: 'fever, cough...',
                labelStyle:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _language,
            dropdownColor: AppColors.backgroundSurface,
            decoration: const InputDecoration(
                labelText: 'Language',
                labelStyle:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            items: _languages.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _language = v!),
          ),
        ]),
      );

  Widget _errorBanner() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AppColors.accentRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accentRed.withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.accentRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      color: AppColors.accentRed, fontSize: 12))),
        ]),
      );

  Widget _buildEmpty() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) =>
              Transform.scale(scale: _pulseAnim.value, child: child),
          child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _healthBlue.withOpacity(0.1),
                  border: Border.all(
                      color: _healthBlue.withOpacity(0.3), width: 2)),
              child: const Icon(Icons.medical_information,
                  color: _healthBlue, size: 44)),
        ),
        const SizedBox(height: 20),
        Text('Gemma 4',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Upload a chest X-ray to begin AI-assisted analysis',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center),
      ]));

  Widget _buildResults() {
    final r = _result!;
    final conf = (r['confidence'] as num?)?.toInt() ?? 85;
    final confColor = conf >= 86
        ? const Color(0xFF10b981)
        : conf >= 61
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.biotech, color: _healthBlue, size: 20),
          const SizedBox(width: 8),
          Text('Analysis Results',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        _section(
            _healthBlue,
            Icons.search,
            'Possible Findings',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  r['diagnosis_suggestion'] ??
                      'No acute abnormalities detected',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Text('Confidence: ',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                Text('$conf%',
                    style: TextStyle(
                        color: confColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                    child: LinearProgressIndicator(
                        value: conf / 100,
                        backgroundColor: AppColors.backgroundInput,
                        valueColor: AlwaysStoppedAnimation(confColor),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 5)),
              ]),
            ])),
        const SizedBox(height: 10),
        _section(
            const Color(0xFF10b981),
            Icons.chat_bubble_outline,
            'Plain-Language Explanation',
            Text(r['plain_language_explanation'] ?? r['full_response'] ?? '',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, height: 1.6))),
        if ((r['risk_factors'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          _section(
            const Color(0xFFF59E0B),
            Icons.warning_amber_outlined,
            'Risk Factors',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (r['risk_factors'] as List)
                    .map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(color: Color(0xFFF59E0B))),
                              Expanded(
                                  child: Text(f.toString(),
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          height: 1.5))),
                            ])))
                    .toList()),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.accentRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentRed.withOpacity(0.3))),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    color: AppColors.accentRed, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        '⚠️ This AI assistance is not a substitute for professional medical diagnosis. Always consult a qualified healthcare provider.',
                        style: TextStyle(
                            color: AppColors.accentRed,
                            fontSize: 12,
                            height: 1.5))),
              ]),
        ),
      ]),
    );
  }

  Widget _section(Color color, IconData icon, String title, Widget child) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5))
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );
}
