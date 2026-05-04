import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/health_edu_service.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with SingleTickerProviderStateMixin {
  final HealthEduService _healthService = HealthEduService();

  late TabController _tabController;
  int _currentTab = 0; // 0: X-Ray, 1: EHR

  String? _selectedXRayPath;
  bool _isAnalyzingXRay = false;
  Map<String, dynamic>? _xrayResults;

  String? _ehrPatientId;
  String _ehrQueryType = 'summary';
  bool _isQueryingEHR = false;
  Map<String, dynamic>? _ehrResults;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _patientIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ageController.dispose();
    _symptomsController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  Future<void> _pickXRayFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'dicom'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedXRayPath = result.files.single.path!;
          _xrayResults = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _analyzeXRay() async {
    if (_selectedXRayPath == null) {
      _showError('Please select an X-ray image first');
      return;
    }

    setState(() {
      _isAnalyzingXRay = true;
      _xrayResults = null;
    });

    try {
      final age = int.tryParse(_ageController.text);
      final symptoms = _symptomsController.text.trim().isEmpty
          ? null
          : _symptomsController.text;

      final result = await _healthService.analyzeXRay(
        imagePath: _selectedXRayPath!,
        age: age,
        symptoms: symptoms,
        language: 'en',
      );

      setState(() {
        _xrayResults = result;
      });
    } catch (e) {
      _showError('Analysis failed: $e');
    } finally {
      setState(() {
        _isAnalyzingXRay = false;
      });
    }
  }

  Future<void> _queryEHR() async {
    final patientId = _patientIdController.text.trim();
    if (patientId.isEmpty) {
      _showError('Please enter a patient ID');
      return;
    }

    setState(() {
      _isQueryingEHR = true;
      _ehrResults = null;
    });

    try {
      final result = await _healthService.queryEHR(
        patientId: patientId,
        queryType: _ehrQueryType,
      );

      setState(() {
        _ehrResults = result;
      });
    } catch (e) {
      _showError('EHR query failed: $e');
    } finally {
      setState(() {
        _isQueryingEHR = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              border:
                  Border(bottom: BorderSide(color: AppColors.borderDefault)),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_services,
                    color: AppColors.accentPurple, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Track - MedGemma 4B',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'AI-powered medical analysis with offline privacy',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.accentPurple,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accentPurple,
            tabs: const [
              Tab(icon: Icon(Icons.add_chart), text: 'X-Ray Analysis'),
              Tab(icon: Icon(Icons.folder_shared), text: 'EHR Assistant'),
            ],
          ),

          // Content
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildXRayTab(),
                _buildEHRTab(),
              ],
            ),
          ),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.accentOrange.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.warning_amber,
                    color: AppColors.accentOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ MEDICAL DISCLAIMER: This tool is for educational purposes only. Not for clinical diagnosis. Always consult qualified healthcare professionals.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.accentOrange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXRayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload Section
          _buildUploadCard(),

          const SizedBox(height: 20),

          // Input Fields
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Patient Age (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _symptomsController,
                  decoration: InputDecoration(
                    labelText: 'Symptoms (optional)',
                    hintText: 'e.g., cough, fever, shortness of breath',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Analyze Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzingXRay ? null : _analyzeXRay,
              icon: _isAnalyzingXRay
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.analytics_outlined),
              label: Text(
                _isAnalyzingXRay ? 'Analyzing...' : 'Analyze X-Ray',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Results
          if (_xrayResults != null) _buildXRayResults(),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          Icon(
            _selectedXRayPath != null ? Icons.check_circle : Icons.upload_file,
            size: 64,
            color: _selectedXRayPath != null
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedXRayPath != null
                ? 'File Selected: ${_selectedXRayPath!.split('\\').last}'
                : 'Upload Chest X-Ray Image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedXRayPath != null
                ? 'Supports: JPG, PNG, DICOM'
                : 'Supported formats: JPG, PNG, DICOM',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickXRayFile,
            icon: Icon(Icons.folder_open_outlined),
            label: const Text('Browse Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXRayResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppColors.success, size: 24),
              const SizedBox(width: 8),
              Text(
                'Analysis Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(),
          if (_xrayResults!['findings'] != null) ...[
            Text(
              'Findings:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _xrayResults!['findings'],
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
          ],
          if (_xrayResults!['confidence'] != null) ...[
            Row(
              children: [
                Text(
                  'Confidence: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                Text(
                  '${(_xrayResults!['confidence'] * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_xrayResults!['recommendations'] != null) ...[
            Text(
              'Recommendations:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _xrayResults!['recommendations'],
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEHRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient ID Input
          TextField(
            controller: _patientIdController,
            decoration: InputDecoration(
              labelText: 'Patient ID',
              hintText: 'Enter patient identifier',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // Query Type Dropdown
          DropdownButtonFormField<String>(
            value: _ehrQueryType,
            decoration: InputDecoration(
              labelText: 'Query Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
            items: const [
              DropdownMenuItem(value: 'summary', child: Text('Full Summary')),
              DropdownMenuItem(
                  value: 'medications', child: Text('Medications')),
              DropdownMenuItem(value: 'allergies', child: Text('Allergies')),
              DropdownMenuItem(
                  value: 'lab_results', child: Text('Lab Results')),
              DropdownMenuItem(value: 'vitals', child: Text('Vital Signs')),
            ],
            onChanged: (value) {
              setState(() {
                _ehrQueryType = value!;
              });
            },
          ),

          const SizedBox(height: 20),

          // Query Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isQueryingEHR ? null : _queryEHR,
              icon: _isQueryingEHR
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.search_outlined),
              label: Text(
                _isQueryingEHR ? 'Querying...' : 'Query EHR',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Results
          if (_ehrResults != null) _buildEHRResults(),

          const SizedBox(height: 20),

          // FHIR Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentBlue),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accentBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FHIR Compatible',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      Text(
                        'EHR data follows HL7 FHIR standards for interoperability',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEHRResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentPurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_shared,
                  color: AppColors.accentPurple, size: 24),
              const SizedBox(width: 8),
              Text(
                'EHR Data Retrieved',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(),

          // Display raw JSON or formatted data
          Text(
            'Data:',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _ehrResults.toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
