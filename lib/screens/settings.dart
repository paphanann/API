import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../app/theme.dart';
import '../core/api.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;
  int _permTab = 0;
  int _userPage = 1;
  static const _pageSize = 10;

  final _company = TextEditingController();
  final _code = TextEditingController();
  final _tax = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _endpoint = TextEditingController();
  final _database = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _cardCode = TextEditingController();
  final _warehouse = TextEditingController();
  final _branch = TextEditingController();
  final _taxCode = TextEditingController();

  String _currency = 'THB - บาทไทย';
  String _timezone = 'Asia/Bangkok (UTC+7)';
  String _dateFormat = 'DD/MM/YYYY';
  String _numberFormat = '1,234.56';
  String _erp = 'SAP Business One';
  String _env = 'Sandbox';
  bool _so = true;
  bool _dn = true;
  bool _re = true;
  bool _cm = false;
  bool _auto = true;
  bool _errNoti = true;
  bool _okNoti = false;
  DateTime? _erpChecked;

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _error;
  String? _erpOk;
  List<StaffUser> _users = [];
  String _logo = '';
  Uint8List? _logoBytes;
  String? _logoName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _company.dispose();
    _code.dispose();
    _tax.dispose();
    _phone.dispose();
    _address.dispose();
    _email.dispose();
    _endpoint.dispose();
    _database.dispose();
    _username.dispose();
    _password.dispose();
    _cardCode.dispose();
    _warehouse.dispose();
    _branch.dispose();
    _taxCode.dispose();
    super.dispose();
  }

  AppSettings _draft() {
    return AppSettings(
      companyName: _company.text.trim(),
      companyCode: _code.text.trim(),
      taxId: _tax.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      email: _email.text.trim(),
      currency: _currency,
      timezone: _timezone,
      dateFormat: _dateFormat,
      numberFormat: _numberFormat,
      erp: _erp,
      environment: _env,
      endpoint: _endpoint.text.trim(),
      database: _database.text.trim(),
      username: _username.text.trim(),
      autoSync: _auto,
      notifyError: _errNoti,
      notifySuccess: _okNoti,
      createSalesOrder: _so,
      createDelivery: _dn,
      createReturn: _re,
      createCreditMemo: _cm,
      defaultCardCode: _cardCode.text.trim(),
      defaultWarehouse: _warehouse.text.trim(),
      defaultBranch: _branch.text.trim(),
      defaultTax: _taxCode.text.trim(),
      erpLastChecked: _erpChecked,
      logo: _logo,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await Api.getSettings();
      _company.text = s.companyName;
      _code.text = s.companyCode;
      _tax.text = s.taxId;
      _phone.text = s.phone;
      _address.text = s.address;
      _email.text = s.email;
      _endpoint.text = s.endpoint;
      _database.text = s.database;
      _username.text = s.username;
      _cardCode.text = s.defaultCardCode;
      _warehouse.text = s.defaultWarehouse;
      _branch.text = s.defaultBranch;
      _taxCode.text = s.defaultTax;
      _currency = s.currency;
      _timezone = s.timezone;
      _dateFormat = s.dateFormat;
      _numberFormat = s.numberFormat;
      _erp = s.erp;
      _env = s.environment.isEmpty ? 'Sandbox' : s.environment;
      _so = s.createSalesOrder;
      _dn = s.createDelivery;
      _re = s.createReturn;
      _cm = s.createCreditMemo;
      _auto = s.autoSync;
      _errNoti = s.notifyError;
      _okNoti = s.notifySuccess;
      _erpChecked = s.erpLastChecked;
      _logo = s.logo;
      _logoBytes = _bytesFromDataUrl(s.logo);
      _logoName = null;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
    }
    try {
      _users = await Api.getUsers();
    } catch (_) {
      _users = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.saveSettings(_draft(), password: _password.text);
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

  Uint8List? _bytesFromDataUrl(String raw) {
    if (!raw.startsWith('data:') || !raw.contains(',')) return null;
    try {
      return Uint8List.fromList(base64Decode(raw.substring(raw.indexOf(',') + 1)));
    } catch (_) {
      return null;
    }
  }

  String _logoSrc(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('data:') || raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '$apiUrl$raw';
    return raw;
  }

  Future<void> _pickLogo() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'image/png,image/jpeg,.png,.jpg,.jpeg';
    final done = Completer<web.File?>();
    input.addEventListener(
      'change',
      (web.Event _) {
        final files = input.files;
        done.complete(files != null && files.length > 0 ? files.item(0) : null);
      }.toJS,
    );
    input.click();
    final file = await done.future;
    if (file == null || !mounted) return;

    final name = file.name.toLowerCase();
    final okType = name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') ||
        file.type == 'image/png' || file.type == 'image/jpeg';
    if (!okType) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปโหลดได้เฉพาะ PNG หรือ JPG')));
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ขนาดไฟล์ต้องไม่เกิน 2 MB')));
      return;
    }

    final reader = web.FileReader();
    final loaded = Completer<String>();
    reader.addEventListener(
      'load',
      (web.Event _) {
        final result = reader.result;
        loaded.complete(result == null ? '' : (result as JSString).toDart);
      }.toJS,
    );
    reader.addEventListener(
      'error',
      (web.Event _) {
        if (!loaded.isCompleted) loaded.completeError('อ่านไฟล์ไม่สำเร็จ');
      }.toJS,
    );
    reader.readAsDataURL(file);
    try {
      final dataUrl = await loaded.future;
      if (!mounted || dataUrl.isEmpty) return;
      setState(() {
        _logo = dataUrl;
        _logoBytes = _bytesFromDataUrl(dataUrl);
        _logoName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _testErp() async {
    setState(() {
      _testing = true;
      _erpOk = null;
    });
    try {
      final msg = await Api.testErp(_draft(), password: _password.text);
      _erpOk = msg;
      _erpChecked = DateTime.now();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Pal.err),
      );
    }
    if (mounted) setState(() => _testing = false);
  }

  List<String> get _roleOptions {
    const base = ['Admin', 'User', 'Manager'];
    final extra = [
      for (final u in _users)
        if (u.role.isNotEmpty && u.role != '-') u.role,
    ];
    return [...{...base, ...extra}];
  }

  Future<void> _reloadUsers() async {
    try {
      final users = await Api.getUsers();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Pal.err),
      );
    }
  }

  Future<void> _openUserForm([StaffUser? user]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _UserFormDialog(user: user, roles: _roleOptions),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(user == null ? 'เพิ่มผู้ใช้งานแล้ว' : 'บันทึกผู้ใช้งานแล้ว')),
      );
      await _reloadUsers();
    }
  }

  Future<void> _confirmDeleteUser(StaffUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบผู้ใช้งาน'),
        content: Text('ต้องการลบ ${user.name} หรือไม่'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Pal.err, foregroundColor: Colors.white),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบผู้ใช้งานแล้ว')));
      await _reloadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Pal.err),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator(minHeight: 3)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: Pal.err)),
            ),
          _tabs(),
          const SizedBox(height: 16),
          if (_tab == 0) _companyTab(),
          if (_tab == 1) _erpTab(),
          if (_tab == 2) _usersTab(),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(int i, IconData icon, String label) {
      final on = _tab == i;
      return InkWell(
        onTap: () => setState(() => _tab = i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? Pal.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? Pal.primary : Pal.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: on ? Pal.primary : Pal.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: on ? Pal.primary : Pal.text,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        tab(0, Icons.apartment_outlined, 'ข้อมูลบริษัท'),
        tab(1, Icons.dns_outlined, 'ERP / SAP'),
        tab(2, Icons.manage_accounts_outlined, 'สิทธิ์การใช้งาน'),
      ],
    );
  }

  Widget _header(String title, String sub, IconData icon) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: Pal.muted, fontSize: 13)),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: Pal.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Pal.primary),
        ),
      ],
    );
  }

  Widget _saveBar() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า'),
      ),
    );
  }

  Widget _companyTab() {
    return Panel(
      pad: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('ข้อมูลบริษัท', 'ตั้งค่าข้อมูลพื้นฐานของบริษัทที่ใช้ในการออกเอกสารและเชื่อมต่อระบบ', Icons.apartment_outlined),
          const SizedBox(height: 22),
          const Text('ข้อมูลทั่วไป', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          _pair(
            _box('ชื่อบริษัท *', TextField(controller: _company)),
            _box('รหัสบริษัท (Company Code)', TextField(controller: _code)),
          ),
          const SizedBox(height: 12),
          _pair(
            _box('เลขประจำตัวผู้เสียภาษี', TextField(controller: _tax)),
            _box('เบอร์โทรศัพท์', TextField(controller: _phone)),
          ),
          const SizedBox(height: 12),
          _pair(
            _box('ที่อยู่', TextField(controller: _address, maxLines: 3)),
            _box('อีเมล', TextField(controller: _email)),
          ),
          const SizedBox(height: 22),
          const Text('ข้อมูลเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          _pair(
            _box('สกุลเงินเริ่มต้น', _drop(_currency, const ['THB - บาทไทย', 'USD - ดอลลาร์สหรัฐ', 'EUR - ยูโร'], (v) => _currency = v)),
            _box('เขตเวลา (Time Zone)', _drop(_timezone, const ['Asia/Bangkok (UTC+7)', 'UTC'], (v) => _timezone = v)),
          ),
          const SizedBox(height: 12),
          _pair(
            _box('รูปแบบวันที่', _drop(_dateFormat, const ['DD/MM/YYYY', 'YYYY-MM-DD', 'MM/DD/YYYY'], (v) => _dateFormat = v)),
            _box('รูปแบบตัวเลข', _drop(_numberFormat, const ['1,234.56', '1.234,56'], (v) => _numberFormat = v)),
          ),
          const SizedBox(height: 22),
          const Text('โลโก้บริษัท', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _pickLogo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Pal.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: _logoPreview(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _logoName ?? (_logo.isEmpty ? 'คลิกเพื่ออัปโหลด' : 'คลิกเพื่อเปลี่ยนโลโก้'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          const Text('PNG, JPG ขนาดไม่เกิน 2 MB', style: TextStyle(color: Pal.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _saveBar(),
        ],
      ),
    );
  }

  Widget _logoPreview() {
    if (_logoBytes != null) {
      return Image.memory(_logoBytes!, fit: BoxFit.cover);
    }
    final src = _logoSrc(_logo);
    if (src.isNotEmpty) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const LogoMark(size: 48, withName: false),
      );
    }
    return const LogoMark(size: 48, withName: false);
  }

  Widget _erpTab() {
    return Panel(
      pad: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('การเชื่อมต่อ ERP / SAP', 'ตั้งค่าการเชื่อมต่อระบบ ERP/SAP และรูปแบบการสร้างเอกสาร', Icons.dns_outlined),
          const SizedBox(height: 22),
          const Text('ข้อมูลการเชื่อมต่อ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          _pair(
            _box('ระบบปลายทาง', _drop(_erp, const ['SAP Business One', 'SAP S/4HANA', 'Custom ERP'], (v) => _erp = v)),
            _box('สภาพแวดล้อม', _drop(_env, const ['Sandbox', 'Production'], (v) => _env = v)),
          ),
          const SizedBox(height: 12),
          _pair(
            _box('Endpoint (Service Layer URL) *', TextField(controller: _endpoint)),
            _box('ชื่อฐานข้อมูล (Company Database) *', TextField(controller: _database)),
          ),
          const SizedBox(height: 12),
          _pair(
            _box('ชื่อผู้ใช้', TextField(controller: _username)),
            _box(
              'รหัสผ่าน',
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: '••••••••')),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _testing ? null : _testErp,
              child: Text(_testing ? 'กำลังทดสอบ...' : 'ทดสอบการเชื่อมต่อ'),
            ),
          ),
          if (_erpOk != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Pal.okBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Pal.ok, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _erpChecked == null ? _erpOk! : 'เชื่อมต่อสำเร็จ    Last checked: ${dtFmt.format(_erpChecked!)}',
                      style: const TextStyle(color: Pal.ok, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text('การตั้งค่าการสร้างเอกสาร', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          _check('สร้างใบสั่งขาย (Sales Order)', _so, (v) => setState(() => _so = v)),
          _check('สร้างใบส่งของ (Delivery)', _dn, (v) => setState(() => _dn = v)),
          _check('สร้างใบรับคืน (Return)', _re, (v) => setState(() => _re = v)),
          _check('สร้างใบลดหนี้ (A/R Credit Memo)', _cm, (v) => setState(() => _cm = v)),
          const SizedBox(height: 18),
          const Text('ค่าเริ่มต้น (Default)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          _pair(
            _box('ลูกค้าเริ่มต้น (CardCode)', TextField(controller: _cardCode)),
            _box('คลังสินค้า (WhsCode)', TextField(controller: _warehouse)),
          ),
          const SizedBox(height: 12),
          _pair(
            _box('สาขา (Branch)', TextField(controller: _branch)),
            _box('รหัสภาษี (Tax Code)', TextField(controller: _taxCode)),
          ),
          const SizedBox(height: 20),
          _saveBar(),
        ],
      ),
    );
  }

  Widget _usersTab() {
    final pages = (_users.length / _pageSize).ceil().clamp(1, 9999);
    if (_userPage > pages) _userPage = pages;
    final start = (_userPage - 1) * _pageSize;
    final rows = _users.skip(start).take(_pageSize).toList();

    return Panel(
      pad: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('สิทธิ์การใช้งาน', 'จัดการผู้ใช้งานและสิทธิ์การเข้าถึงในระบบ', Icons.manage_accounts_outlined),
          const SizedBox(height: 18),
          Row(
            children: [
              _miniTab('ผู้ใช้งาน', 0),
              const SizedBox(width: 8),
              _miniTab('กลุ่มสิทธิ์', 1),
              const Spacer(),
              if (_permTab == 0)
                ElevatedButton.icon(
                  onPressed: () => _openUserForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('เพิ่มผู้ใช้งาน'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_permTab == 0) ...[
            FillTable(
              minWidth: 920,
              child: DataTable(
                headingRowColor: tableHeadBg,
                headingTextStyle: tableHead,
                columns: const [
                  DataColumn(label: Text('ผู้ใช้งาน')),
                  DataColumn(label: Text('อีเมล')),
                  DataColumn(label: Text('กลุ่มสิทธิ์')),
                  DataColumn(label: Text('สถานะ')),
                  DataColumn(label: SizedBox.shrink(), numeric: true),
                ],
                rows: [
                  for (final u in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(u.email)),
                        DataCell(Text(u.role)),
                        DataCell(u.active ? pill('ใช้งาน', const Color(0xFF15803D), Pal.okBg) : pill('ปิดใช้งาน', Pal.muted, const Color(0xFFF3F4F6))),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'แก้ไข',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _openUserForm(u),
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Pal.primary),
                                ),
                                IconButton(
                                  tooltip: 'ลบ',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmDeleteUser(u),
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Pal.err),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('ไม่พบผู้ใช้งาน')),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _users.isEmpty ? 'แสดง 0 รายการ' : 'แสดง ${start + 1} - ${start + rows.length} จาก ${_users.length} รายการ',
                  style: const TextStyle(color: Pal.muted, fontSize: 13),
                ),
                const Spacer(),
                Pages(page: _userPage, total: pages, onTap: (p) => setState(() => _userPage = p)),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('กลุ่มสิทธิ์กำหนดที่ Backend — หน้านี้แสดงเฉพาะรายชื่อผู้ใช้งานจาก API', style: TextStyle(color: Pal.muted)),
            ),
        ],
      ),
    );
  }

  Widget _miniTab(String label, int i) {
    final on = _permTab == i;
    return InkWell(
      onTap: () => setState(() => _permTab = i),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Pal.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: on ? Pal.primary : Pal.muted)),
      ),
    );
  }

  Widget _pair(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 720) {
          return Column(children: [a, const SizedBox(height: 12), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)],
        );
      },
    );
  }

  Widget _box(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _drop(String value, List<String> items, ValueChanged<String> onPick) {
    final v = items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
      key: ValueKey(v),
      initialValue: v,
      items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
      onChanged: (x) => setState(() => onPick(x ?? v)),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(8),
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }

  Widget _check(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v == true)),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({this.user, required this.roles});

  final StaffUser? user;
  final List<String> roles;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _password = TextEditingController();
  late String _role = widget.roles.contains(widget.user?.role) ? widget.user!.role : (widget.roles.isEmpty ? 'User' : widget.roles.first);
  late bool _active = widget.user?.active ?? true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.user != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = 'กรอกชื่อและอีเมล');
      return;
    }
    if (!_editing && _password.text.isEmpty) {
      setState(() => _error = 'กรอกรหัสผ่าน');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Api.saveUser(
        StaffUser(
          id: widget.user?.id ?? '',
          name: name,
          email: email,
          role: _role,
          active: _active,
        ),
        password: _password.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'แก้ไขผู้ใช้งาน' : 'เพิ่มผู้ใช้งาน'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'ชื่อ')),
            const SizedBox(height: 12),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'อีเมล')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_role),
              initialValue: _role,
              items: [for (final r in widget.roles) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (v) => setState(() => _role = v ?? _role),
              decoration: const InputDecoration(labelText: 'กลุ่มสิทธิ์'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: _editing ? 'รหัสผ่านใหม่ (ถ้าเปลี่ยน)' : 'รหัสผ่าน'),
            ),
            Row(
              children: [
                const Expanded(child: Text('ใช้งาน')),
                Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
              ],
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Pal.err, fontSize: 13)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก')),
      ],
    );
  }
}
