import 'package:flutter/material.dart';

import '../app/session.dart';
import '../app/theme.dart';
import '../core/api.dart';
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
  int _userPage = 1;
  static const _pageSize = 10;

  final _company = TextEditingController();
  final _code = TextEditingController();
  final _tax = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _endpoint = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _database = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  int _erpStep = 1;
  bool _showPass = false;
  String _dbQuery = '';
  List<SapDatabase> _sapDbs = [];
  String _cardCode = '';
  String _warehouse = '';
  String _branch = '';
  String _taxCode = '';
  String _onOrder = 'salesOrder';
  String _onShip = 'delivery';
  String _onReturn = 'return';
  String _onRefund = 'none';
  List<String> _cardCodes = [];
  List<String> _warehouses = [];
  List<String> _branches = [];
  List<String> _taxCodes = [];

  String _currency = 'THB - บาทไทย';
  String _timezone = 'Asia/Bangkok (UTC+7)';
  String _dateFormat = 'DD/MM/YYYY';
  String _numberFormat = '1,234.56';
  String _erp = 'SAP Business One';
  String _env = 'Sandbox';
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
    _host.dispose();
    _port.dispose();
    _database.dispose();
    _username.dispose();
    _password.dispose();
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
      endpoint: _host.text.trim().isEmpty ? _endpoint.text.trim() : '${_host.text.trim()}:${_port.text.trim().isEmpty ? '14333' : _port.text.trim()}',
      host: _host.text.trim(),
      port: _port.text.trim(),
      database: _database.text.trim(),
      username: _username.text.trim(),
      autoSync: _auto,
      notifyError: _errNoti,
      notifySuccess: _okNoti,
      createSalesOrder: _onOrder != 'none',
      createDelivery: _onShip != 'none',
      createReturn: _onReturn != 'none',
      createCreditMemo: _onRefund != 'none',
      onMarketplaceOrder: _onOrder,
      onShipment: _onShip,
      onReturn: _onReturn,
      onRefund: _onRefund,
      defaultCardCode: _cardCode,
      defaultWarehouse: _warehouse,
      defaultBranch: _branch,
      defaultTax: _taxCode,
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
      _applyHostPort(s);
      _database.text = s.database;
      _username.text = s.username;
      _cardCode = s.defaultCardCode;
      _warehouse = s.defaultWarehouse;
      _branch = s.defaultBranch;
      _taxCode = s.defaultTax;
      _currency = s.currency;
      _timezone = s.timezone;
      _dateFormat = s.dateFormat;
      _numberFormat = s.numberFormat;
      _erp = s.erp;
      _env = s.environment.isEmpty ? 'Sandbox' : s.environment;
      _onOrder = s.onMarketplaceOrder;
      _onShip = s.onShipment;
      _onReturn = s.onReturn;
      _onRefund = s.onRefund;
      _auto = s.autoSync;
      _errNoti = s.notifyError;
      _okNoti = s.notifySuccess;
      _erpChecked = s.erpLastChecked;
      _logo = s.logo;
      if (s.database.trim().isNotEmpty && (s.host.trim().isNotEmpty || s.endpoint.trim().isNotEmpty)) {
        _erpStep = 3;
      }
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
    }
    try {
      _users = await Api.getUsers();
      Session.instance.syncFromUsers(_users);
    } catch (_) {
      _users = [];
    }
    await _loadErpOptions();
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _save({bool quiet = false}) async {
    setState(() => _saving = true);
    try {
      await Api.saveSettings(_draft(), password: _password.text);
      if (!mounted) return true;
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกการตั้งค่าแล้ว')));
      }
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
      setState(() => _saving = false);
      return false;
    }
  }

  void _applyHostPort(AppSettings s) {
    if (s.host.trim().isNotEmpty) {
      _host.text = s.host.trim();
      _port.text = s.port.trim().isEmpty ? '14333' : s.port.trim();
      return;
    }
    final t = s.endpoint.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) {
      final u = Uri.tryParse(t);
      _host.text = u?.host ?? '';
      _port.text = (u != null && u.hasPort) ? '${u.port}' : '14333';
      return;
    }
    final i = t.lastIndexOf(':');
    if (i > 0) {
      _host.text = t.substring(0, i);
      _port.text = t.substring(i + 1);
    } else {
      _host.text = t;
      _port.text = '14333';
    }
  }

  Future<void> _testErp({bool stay = false}) async {
    if (_host.text.trim().isEmpty || _username.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอก Server, ชื่อผู้ใช้ และรหัสผ่าน'), backgroundColor: Pal.err),
      );
      return;
    }
    setState(() {
      _testing = true;
      _erpOk = null;
    });
    try {
      final result = await Api.testErp(_draft(), password: _password.text);
      _erpOk = result.message;
      _erpChecked = DateTime.now();
      final seen = <String>{};
      final dbs = <SapDatabase>[
        for (final d in [...result.databases, ..._sapDbs])
          if (seen.add(d.name)) d,
      ];
      if (_database.text.trim().isNotEmpty && !seen.contains(_database.text.trim())) {
        dbs.insert(0, SapDatabase(name: _database.text.trim()));
      }
      _sapDbs = dbs;
      _dbQuery = '';
      if (stay) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('การเชื่อมต่อปกติ'), backgroundColor: Pal.ok),
          );
        }
      } else {
        _erpStep = 2;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Pal.err),
      );
    }
    if (mounted) setState(() => _testing = false);
    await _loadErpOptions();
  }

  Future<void> _loadErpOptions() async {
    try {
      final opts = await Api.getErpOptions();
      if (!mounted) return;
      setState(() {
        _cardCodes = opts.cardCodes;
        _warehouses = opts.warehouses;
        _branches = opts.branches;
        _taxCodes = opts.taxCodes;
        if (opts.databases.isNotEmpty) {
          final seen = {for (final d in _sapDbs) d.name};
          _sapDbs = [
            ..._sapDbs,
            for (final d in opts.databases)
              if (seen.add(d.name)) d,
          ];
        }
      });
    } catch (_) {}
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
      Session.instance.syncFromUsers(users);
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
          if (_tab == 0) _erpTab(),
          if (_tab == 1) _usersTab(),
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
        tab(0, Icons.dns_outlined, 'ERP / SAP'),
        tab(1, Icons.manage_accounts_outlined, 'สิทธิ์การใช้งาน'),
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

  Widget _erpTab() {
    if (_erpStep == 3) return _successStep();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('การเชื่อมต่อ SAP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('เชื่อมต่อฐานข้อมูล SAP Business One เพื่อใช้งานข้อมูลในระบบ', style: TextStyle(color: Pal.muted, fontSize: 14)),
        const SizedBox(height: 24),
        _erpStepper(),
        const SizedBox(height: 20),
        if (_erpStep == 1) _serverStep() else _databaseStep(),
      ],
    );
  }

  Widget _erpStepper() {
    Widget step(int n, String title, String sub, {required bool done, required bool on}) {
      return Expanded(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done || on ? Pal.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: done || on ? Pal.primary : Pal.line, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                  : Text('$n', style: TextStyle(color: on ? Colors.white : Pal.muted, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: done || on ? Pal.text : Pal.muted)),
                  Text(sub, style: const TextStyle(color: Pal.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        step(1, 'เชื่อมต่อ Server', _erpStep == 2 ? 'เชื่อมต่อสำเร็จ' : 'กรอกข้อมูลเพื่อเชื่อมต่อ SQL Server', done: _erpStep == 2, on: _erpStep == 1),
        Expanded(
          child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 8), color: _erpStep == 2 ? Pal.primary : Pal.line),
        ),
        step(2, 'เลือกฐานข้อมูล', 'เลือกฐานข้อมูล SAP Business One', done: false, on: _erpStep == 2),
      ],
    );
  }

  Widget _serverStep() {
    return Panel(
      pad: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Pal.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.dns_outlined, color: Pal.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('เชื่อมต่อ SAP Server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('กรอกข้อมูลของ Microsoft SQL Server ที่ติดตั้ง SAP Business One', style: TextStyle(color: Pal.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _box(
            'Server / Host *',
            TextField(
              controller: _host,
              decoration: const InputDecoration(hintText: 'เช่น 192.168.1.10'),
            ),
          ),
          const SizedBox(height: 4),
          const Text('IP Address หรือ Hostname ของ SQL Server', style: TextStyle(color: Pal.muted, fontSize: 12)),
          const SizedBox(height: 14),
          _box(
            'Port *',
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '14333'),
            ),
          ),
          const SizedBox(height: 4),
          const Text('พอร์ตสำหรับเชื่อมต่อ (ปกติ 14333)', style: TextStyle(color: Pal.muted, fontSize: 12)),
          const SizedBox(height: 14),
          _box('ชื่อผู้ใช้ *', TextField(controller: _username)),
          const SizedBox(height: 14),
          _box(
            'รหัสผ่าน *',
            TextField(
              controller: _password,
              obscureText: !_showPass,
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPass = !_showPass),
                  icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _testErp,
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(_testing ? 'กำลังทดสอบ...' : 'ทดสอบการเชื่อมต่อ Server'),
            ),
          ),
        ],
      ),
    );
  }

  List<SapDatabase> get _visibleDbs {
    final q = _dbQuery.trim().toLowerCase();
    return [
      for (final d in _sapDbs)
        if (q.isEmpty || d.name.toLowerCase().contains(q) || d.detail.toLowerCase().contains(q)) d,
    ];
  }

  Widget _databaseStep() {
    final selected = _database.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(color: Pal.okBg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Pal.ok),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เชื่อมต่อ Server สำเร็จ', style: TextStyle(fontWeight: FontWeight.w800, color: Pal.ok)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _erpStep = 1),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('เปลี่ยน Server'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          pad: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Pal.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.storage_outlined, color: Pal.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('เลือกฐานข้อมูล SAP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('เลือกฐานข้อมูลบริษัทที่ต้องการใช้งานในระบบ', style: TextStyle(color: Pal.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _box(
                'ฐานข้อมูล *',
                TextField(
                  onChanged: (v) => setState(() => _dbQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาชื่อฐานข้อมูล',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_visibleDbs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('ยังไม่พบรายชื่อฐานข้อมูลจากเซิร์ฟเวอร์', style: TextStyle(color: Pal.muted)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in _visibleDbs)
                        Material(
                          color: selected == d.name ? Pal.primarySoft : Colors.white,
                          child: InkWell(
                            onTap: () => setState(() => _database.text = d.name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Pal.line.withValues(alpha: 0.8))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        if (d.detail.isNotEmpty)
                                          Text(d.detail, style: const TextStyle(color: Pal.muted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  if (selected == d.name) const Icon(Icons.check_rounded, color: Pal.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: selected.isEmpty ? null : _confirmConnect,
                  child: const Text('ถัดไป'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _disconnectErp() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกการเชื่อมต่อ'),
        content: const Text('การเชื่อมต่อ SAP นี้จะถูกลบออกจากระบบ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ไม่')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Pal.err, foregroundColor: Colors.white),
            child: const Text('ยกเลิกการเชื่อมต่อ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _host.clear();
    _port.clear();
    _database.clear();
    _username.clear();
    _password.clear();
    _endpoint.clear();
    _erpChecked = null;
    _erpOk = null;
    _sapDbs = [];
    setState(() => _saving = true);
    try {
      await Api.saveSettings(_draft(), clearPassword: true);
      if (!mounted) return;
      setState(() {
        _erpStep = 1;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Pal.err),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _confirmConnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Pal.warn),
            SizedBox(width: 8),
            Expanded(child: Text('ยืนยันการเชื่อมต่อ')),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('คุณต้องการเชื่อมต่อฐานข้อมูลนี้?'),
              const SizedBox(height: 16),
              _confirmRow('Server / Host', _host.text.trim()),
              _confirmRow('Port', _port.text.trim().isEmpty ? '14333' : _port.text.trim()),
              _confirmRow('ชื่อผู้ใช้', _username.text.trim()),
              _confirmRow('ฐานข้อมูล', _database.text.trim()),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยันการเชื่อมต่อ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConnectingDialog(database: _database.text.trim(), onSave: () => _save(quiet: true)),
    );
    if (saved == true && mounted) setState(() => _erpStep = 3);
  }

  Widget _confirmRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13))),
          Expanded(child: Text(v.isEmpty ? '-' : v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _successStep() {
    final host = _host.text.trim();
    final port = _port.text.trim().isEmpty ? '14333' : _port.text.trim();
    final db = _database.text.trim();
    final when = formatDt(_erpChecked, withSeconds: true);

    Widget kv(IconData icon, String k, Widget v) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Pal.muted),
            const SizedBox(width: 10),
            SizedBox(width: 160, child: Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13))),
            Expanded(child: v),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('การเชื่อมต่อ SAP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('จัดการการเชื่อมต่อ SAP Business One เพื่อใช้งานข้อมูลในระบบ', style: TextStyle(color: Pal.muted, fontSize: 14)),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _erpStep = 1),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('เพิ่มการเชื่อมต่อใหม่'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          pad: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: LayoutBuilder(
            builder: (context, c) {
              final info = Column(
                children: [
                  kv(Icons.dns_outlined, 'Server / Host', Text(host.isEmpty ? '-' : host, style: const TextStyle(fontWeight: FontWeight.w700))),
                  kv(Icons.settings_ethernet_rounded, 'Port', Text(port, style: const TextStyle(fontWeight: FontWeight.w700))),
                  kv(Icons.storage_outlined, 'ฐานข้อมูล (Database)', Text(db.isEmpty ? '-' : db, style: const TextStyle(fontWeight: FontWeight.w700))),
                  kv(Icons.schedule_rounded, 'เชื่อมต่อเมื่อ', Text(when, style: const TextStyle(fontWeight: FontWeight.w700))),
                  kv(
                    Icons.graphic_eq_rounded,
                    'สถานะ',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: Pal.ok),
                            SizedBox(width: 6),
                            Text('เชื่อมต่อสำเร็จ', style: TextStyle(fontWeight: FontWeight.w700, color: Pal.ok)),
                          ],
                        ),
                        Text('ตรวจสอบล่าสุด $when', style: const TextStyle(color: Pal.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _erpStep = 1),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('แก้ไขการตั้งค่า Server'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _disconnectErp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Pal.err,
                        side: const BorderSide(color: Pal.err),
                      ),
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('ยกเลิกการเชื่อมต่อ'),
                    ),
                  ),
                ],
              );
              if (c.maxWidth < 800) {
                return Column(children: [info, const SizedBox(height: 16), actions]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: info),
                  const SizedBox(width: 24),
                  SizedBox(width: 260, child: actions),
                ],
              );
            },
          ),
        ),
      ],
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
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _openUserForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('เพิ่มผู้ใช้งาน'),
            ),
          ),
          const SizedBox(height: 16),
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
        ],
      ),
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

}

class _ConnectingDialog extends StatefulWidget {
  const _ConnectingDialog({required this.onSave, required this.database});

  final Future<bool> Function() onSave;
  final String database;

  @override
  State<_ConnectingDialog> createState() => _ConnectingDialogState();
}

class _ConnectingDialogState extends State<_ConnectingDialog> {
  int _done = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _done = 1);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _done = 2);
    final ok = await widget.onSave();
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'บันทึกการตั้งค่าไม่สำเร็จ');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, false);
      return;
    }
    setState(() => _done = 3);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    Widget row(int i, String label) {
      final done = _done > i;
      final on = _done == i;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (done)
              const Icon(Icons.check_circle_rounded, color: Pal.ok, size: 20)
            else if (on)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.radio_button_unchecked, color: Pal.faint, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Text(done ? 'สำเร็จ' : (on ? 'กำลังทำ...' : ''), style: TextStyle(color: done ? Pal.ok : Pal.muted, fontSize: 13)),
          ],
        ),
      );
    }

    return AlertDialog(
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('กำลังเชื่อมต่อ...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('กรุณารอสักครู่', style: TextStyle(color: Pal.muted)),
            const SizedBox(height: 20),
            row(0, 'ตรวจสอบการเชื่อมต่อ Server'),
            row(1, 'ตรวจสอบฐานข้อมูล ${widget.database}'),
            row(2, 'บันทึกการตั้งค่า'),
            if (_error != null) Text(_error!, style: const TextStyle(color: Pal.err, fontSize: 13)),
          ],
        ),
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
