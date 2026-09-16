import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _company = TextEditingController();
  final _tax = TextEditingController();
  final _address = TextEditingController();
  final _endpoint = TextEditingController();
  bool _auto = true;
  bool _errNoti = true;
  bool _okNoti = false;
  String _erp = 'SAP S/4HANA';
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _company.dispose();
    _tax.dispose();
    _address.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await Api.getSettings();
      _company.text = s.companyName;
      _tax.text = s.taxId;
      _address.text = s.address;
      _endpoint.text = s.endpoint;
      _erp = s.erp.isEmpty ? 'SAP S/4HANA' : s.erp;
      _auto = s.autoSync;
      _errNoti = s.notifyError;
      _okNoti = s.notifySuccess;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.saveSettings(AppSettings(
        companyName: _company.text.trim(),
        taxId: _tax.text.trim(),
        address: _address.text.trim(),
        erp: _erp,
        endpoint: _endpoint.text.trim(),
        autoSync: _auto,
        notifyError: _errNoti,
        notifySuccess: _okNoti,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกการตั้งค่าแล้ว')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_loading) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator(minHeight: 3)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: Pal.err)),
            ),
          Panel(
            title: 'ข้อมูลบริษัท',
            child: Column(
              children: [
                TextField(controller: _company, decoration: const InputDecoration(labelText: 'ชื่อบริษัท')),
                const SizedBox(height: 12),
                TextField(controller: _tax, decoration: const InputDecoration(labelText: 'เลขผู้เสียภาษี')),
                const SizedBox(height: 12),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'ที่อยู่')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'การเชื่อมต่อ ERP / SAP',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(_erp),
                  initialValue: _erp,
                  items: const [
                    DropdownMenuItem(value: 'SAP S/4HANA', child: Text('SAP S/4HANA')),
                    DropdownMenuItem(value: 'SAP B1', child: Text('SAP Business One')),
                    DropdownMenuItem(value: 'Custom ERP', child: Text('Custom ERP')),
                  ],
                  onChanged: (v) => setState(() => _erp = v ?? _erp),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  decoration: const InputDecoration(labelText: 'ระบบปลายทาง'),
                ),
                const SizedBox(height: 12),
                TextField(controller: _endpoint, decoration: const InputDecoration(labelText: 'Endpoint')),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ซิงก์อัตโนมัติทุก 5 นาที'),
                  value: _auto,
                  onChanged: (v) => setState(() => _auto = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: 'การแจ้งเตือน',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('แจ้งเตือนเมื่อซิงก์ผิดพลาด'),
                  value: _errNoti,
                  onChanged: (v) => setState(() => _errNoti = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('แจ้งเตือนเมื่อซิงก์สำเร็จ'),
                  value: _okNoti,
                  onChanged: (v) => setState(() => _okNoti = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า'),
            ),
          ),
        ],
      ),
    );
  }
}
