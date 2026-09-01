import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _auto = true;
  bool _errNoti = true;
  bool _okNoti = false;
  String _erp = 'SAP S/4HANA';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Panel(
            title: 'ข้อมูลบริษัท',
            child: Column(
              children: [
                TextFormField(initialValue: 'PASS Co., Ltd.', decoration: const InputDecoration(labelText: 'ชื่อบริษัท')),
                const SizedBox(height: 12),
                TextFormField(initialValue: 'TAX-0105567000000', decoration: const InputDecoration(labelText: 'เลขผู้เสียภาษี')),
                const SizedBox(height: 12),
                TextFormField(initialValue: 'กรุงเทพมหานคร, ประเทศไทย', decoration: const InputDecoration(labelText: 'ที่อยู่')),
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
                  decoration: const InputDecoration(labelText: 'ระบบปลายทาง'),
                ),
                const SizedBox(height: 12),
                const TextField(decoration: InputDecoration(labelText: 'Endpoint', hintText: 'https://erp.example.com/api')),
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกแล้ว')));
              },
              child: const Text('บันทึกการตั้งค่า'),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ข้อมูลที่แสดงเป็น Demo / Test Data', style: TextStyle(color: Pal.faint, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
