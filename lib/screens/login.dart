import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hide = true;
  bool _remember = true;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await widget.session.login(_email.text, _pass.text);
    if (!ok) {
      setState(() => _err = 'กรุณากรอกอีเมลและรหัสผ่าน');
      return;
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        return Scaffold(
          body: Row(
            children: [
              if (wide) const Expanded(child: _Left()),
              Expanded(
                child: ColoredBox(
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0, box.maxHeight - 64),
                            minWidth: math.max(0, box.maxWidth - 64),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Form(
                                key: _form,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!wide) ...[
                                      const LogoMark(size: 36),
                                      const SizedBox(height: 28),
                                    ],
                                    const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'ลงชื่อเข้าใช้เพื่อจัดการออเดอร์และการซิงก์ข้อมูลกับ ERP',
                                      style: TextStyle(color: Pal.muted),
                                    ),
                                    const SizedBox(height: 28),
                                    const Text('อีเมล / ชื่อผู้ใช้', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded)),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกอีเมล' : null,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('รหัสผ่าน', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _pass,
                                      obscureText: _hide,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(() => _hide = !_hide),
                                          icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                        ),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่าน' : null,
                                      onFieldSubmitted: (_) => _go(),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? false)),
                                            const Text('จดจำฉันไว้'),
                                          ],
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('กรุณาติดต่อผู้ดูแลระบบเพื่อรีเซ็ตรหัสผ่าน')),
                                            );
                                          },
                                          child: const Text('ลืมรหัสผ่าน?'),
                                        ),
                                      ],
                                    ),
                                    if (_err != null) ...[
                                      const SizedBox(height: 8),
                                      Text(_err!, style: const TextStyle(color: Pal.err)),
                                    ],
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: widget.session.loading ? null : _go,
                                        child: widget.session.loading
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text('Login'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Left extends StatelessWidget {
  const _Left();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07101F), Color(0xFF0F1C33), Color(0xFF123056)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LogoMark(size: 42, light: true),
            const Spacer(),
            const Text(
              'Marketplace\nIntegration System',
              style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1.15),
            ),
            const SizedBox(height: 16),
            Text(
              'ซิงก์คำสั่งซื้อจาก Shopee, TikTok Shop และ Lazada\nแปลงข้อมูล และส่งเข้า ERP/SAP อัตโนมัติ',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in Channel.values)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChannelDot(channel: c, size: 22),
                        const SizedBox(width: 8),
                        Text(c.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              'Profile Verification · Application Status · API Access',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
