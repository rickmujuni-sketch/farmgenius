import 'package:flutter/material.dart';
import '../models/biological_asset.dart';
import '../services/biological_asset_service.dart';

class DailyAssetCheckFormScreen extends StatefulWidget {
  const DailyAssetCheckFormScreen({super.key, this.existingCheck});

  final DailyAssetCheck? existingCheck;

  @override
  State<DailyAssetCheckFormScreen> createState() => _DailyAssetCheckFormScreenState();
}

class _DailyAssetCheckFormScreenState extends State<DailyAssetCheckFormScreen> {
  final _notesController = TextEditingController();
  final _alertsController = TextEditingController();
  final _receiptPhotosController = TextEditingController();
  final _animalPhotosController = TextEditingController();
  final _plantPhotosController = TextEditingController();
  final _infrastructurePhotosController = TextEditingController();
  final _otherPhotosController = TextEditingController();

  bool _isSaving = false;
  DateTime _checkDate = DateTime.now();
  String _timeBlock = '06:00-08:00';
  String _checklistType = 'morning_livestock_check';
  String? _zoneId;
  List<AssetZoneOption> _zones = [];

  static const List<String> _timeBlocks = [
    '05:30-06:00',
    '06:00-08:00',
    '08:00-09:00',
    '09:00-12:30',
    '12:30-14:00',
    '14:00-17:00',
    '17:00-18:00',
    '18:00-19:00',
    '19:00-06:00',
  ];

  static const List<String> _checkTypes = [
    'morning_livestock_check',
    'tree_health_inspection',
    'egg_collection',
    'harvest_recording',
    'general_zone_check',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCheck;
    if (existing != null) {
      _checkDate = existing.checkDate;
      _timeBlock = existing.timeBlock;
      _checklistType = existing.checklistType;
      _zoneId = existing.zoneId;
      _notesController.text = existing.observations['notes']?.toString() ?? '';
      _alertsController.text = existing.alerts.map((e) => e.toString()).join(', ');
      final evidence = existing.observations['evidence'];
      if (evidence is Map<String, dynamic>) {
        _receiptPhotosController.text = _toCsvList(evidence['receipts']);
        _animalPhotosController.text = _toCsvList(evidence['animals']);
        _plantPhotosController.text = _toCsvList(evidence['plants']);
        _infrastructurePhotosController.text = _toCsvList(evidence['infrastructure']);
        _otherPhotosController.text = _toCsvList(evidence['other']);
      }
    }
    _loadZones();
  }

  String _toCsvList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).join(', ');
    }
    return '';
  }

  List<String> _parseCsvUrls(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _loadZones() async {
    final zones = await BiologicalAssetService.getAssetZones();
    if (!mounted) return;

    setState(() {
      _zones = zones;
      if (_zoneId == null && zones.isNotEmpty) {
        _zoneId = zones.first.id;
      }
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _checkDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() {
        _checkDate = selected;
      });
    }
  }

  Future<void> _save() async {
    if (_zoneId == null || _zoneId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a zone before saving.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final alerts = _alertsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final evidence = <String, dynamic>{
      'receipts': _parseCsvUrls(_receiptPhotosController.text),
      'animals': _parseCsvUrls(_animalPhotosController.text),
      'plants': _parseCsvUrls(_plantPhotosController.text),
      'infrastructure': _parseCsvUrls(_infrastructurePhotosController.text),
      'other': _parseCsvUrls(_otherPhotosController.text),
    };

    final totalEvidenceCount =
        (evidence['receipts'] as List).length +
        (evidence['animals'] as List).length +
        (evidence['plants'] as List).length +
        (evidence['infrastructure'] as List).length +
        (evidence['other'] as List).length;

    evidence['total_count'] = totalEvidenceCount;
    evidence['last_updated_at'] = DateTime.now().toIso8601String();

    final observations = <String, dynamic>{
      'notes': _notesController.text.trim(),
      'source': 'mobile_form',
      'evidence': evidence,
    };

    try {
      if (widget.existingCheck == null) {
        await BiologicalAssetService.createDailyAssetCheck(
          checkDate: _checkDate,
          timeBlock: _timeBlock,
          zoneId: _zoneId,
          checklistType: _checklistType,
          observations: observations,
          alerts: alerts,
        );
      } else {
        await BiologicalAssetService.updateDailyAssetCheck(
          id: widget.existingCheck!.id,
          checkDate: _checkDate,
          timeBlock: _timeBlock,
          zoneId: _zoneId,
          checklistType: _checklistType,
          observations: observations,
          alerts: alerts,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save check: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _alertsController.dispose();
    _receiptPhotosController.dispose();
    _animalPhotosController.dispose();
    _plantPhotosController.dispose();
    _infrastructurePhotosController.dispose();
    _otherPhotosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingCheck != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Update Daily Check' : 'Create Daily Check'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Check Date'),
            subtitle: Text(_checkDate.toIso8601String().split('T').first),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickDate,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _timeBlock,
            items: _timeBlocks
                .map((block) => DropdownMenuItem(value: block, child: Text(block)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _timeBlock = value;
                });
              }
            },
            decoration: const InputDecoration(labelText: 'Time Block'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _checklistType,
            items: _checkTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _checklistType = value;
                });
              }
            },
            decoration: const InputDecoration(labelText: 'Checklist Type'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _zoneId,
            items: _zones
                .map((zone) => DropdownMenuItem(value: zone.id, child: Text('${zone.name} (${zone.id})')))
                .toList(),
            onChanged: (value) {
              setState(() {
                _zoneId = value;
              });
            },
            decoration: const InputDecoration(labelText: 'Zone'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Observations',
              hintText: 'Enter notes from inspection/check',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _alertsController,
            decoration: const InputDecoration(
              labelText: 'Alerts (comma separated)',
              hintText: 'missing_goat, water_low, pest_signs',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Photo Evidence URLs (comma separated)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _receiptPhotosController,
            decoration: const InputDecoration(
              labelText: 'Receipts Photos',
              hintText: 'https://.../receipt1.jpg, https://.../receipt2.jpg',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _animalPhotosController,
            decoration: const InputDecoration(
              labelText: 'Animal Photos',
              hintText: 'https://.../animal1.jpg, https://.../animal2.jpg',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _plantPhotosController,
            decoration: const InputDecoration(
              labelText: 'Plant/Crop Photos',
              hintText: 'https://.../plant1.jpg, https://.../plant2.jpg',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _infrastructurePhotosController,
            decoration: const InputDecoration(
              labelText: 'Infrastructure Photos',
              hintText: 'https://.../infra1.jpg',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _otherPhotosController,
            decoration: const InputDecoration(
              labelText: 'Other Evidence Photos',
              hintText: 'https://.../other1.jpg',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : (isEdit ? 'Update Check' : 'Create Check')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
