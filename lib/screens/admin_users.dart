import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/orders_service.dart';
import '../core/store_service.dart';
import '../core/theme.dart';

// ======================================================
// ✏️ نافذة تعديل مستخدم
// ======================================================

class EditUserDialog {
  static Future<bool> show(BuildContext context, User u) async {
    final s = context.read<AppSettings>();
    final nameC = TextEditingController(text: u.name);
    final phoneC = TextEditingController(text: u.phone);
    final passC = TextEditingController(text: u.password ?? '');
    String role = u.role;
    bool adminUnlocked = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          // ✅ شارة دور داخل نافذة التعديل
          Widget roleChip(String label, String value, Color c,
              {VoidCallback? onLongPress}) {
            final active = role == value;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, bottom: 8),
              child: InkWell(
                onTap: () => setSt(() => role = value),
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(colors: <Color>[c, c.withAlpha(180)])
                        : null,
                    color: active ? null : c.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: c.withAlpha(active ? 180 : 80)),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: active ? Colors.white : c,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                const Icon(Icons.edit_rounded, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      s.isArabic ? 'تعديل المستخدم' : 'Edit user',
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fld(context, nameC,
                      s.isArabic ? 'اسم المستخدم' : 'Name',
                      Icons.person_rounded, AppColors.orange),
                  const SizedBox(height: 10),
                  _fld(context, phoneC,
                      s.isArabic ? 'رقم الهاتف' : 'Phone',
                      Icons.phone_rounded, AppColors.teal,
                      kt: TextInputType.phone),
                  const SizedBox(height: 10),
                  _fld(context, passC,
                      s.isArabic ? 'كلمة السر' : 'Password',
                      Icons.lock_rounded, const Color(0xFF9B59B6),
                      obscure: true),
                  const SizedBox(height: 14),
                  // ✅ نوع الحساب: مدير مخفي حتى ضغط مطول على وكيل
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                        s.isArabic ? 'نوع الحساب:' : 'Account type:',
                        style: TextStyle(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      children: [
                        roleChip(s.isArabic ? 'عميل' : 'Client', 'client',
                            AppColors.teal),
                        roleChip(s.isArabic ? 'صباغ' : 'Painter', 'tech',
                            AppColors.orange),
                        roleChip(
                          s.isArabic ? 'وكيل' : 'Agent',
                          'agent',
                          const Color(0xFF9B59B6),
                          onLongPress: () {
                            if (!adminUnlocked) {
                              setSt(() => adminUnlocked = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(s.isArabic
                                          ? '🔓 تم فتح خيار المدير'
                                          : 'Admin option unlocked')));
                            }
                          },
                        ),
                        if (adminUnlocked || role == 'admin')
                          roleChip(s.isArabic ? 'مدير' : 'Admin', 'admin',
                              Colors.red),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (nameC.text.trim().isEmpty ||
                      phoneC.text.trim().isEmpty ||
                      passC.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(s.isArabic
                            ? 'يرجى ملء جميع الحقول'
                            : 'Fill all fields'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(s.isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return false;
    try {
      await OrdersService.patchUser(u.id, {
        'name': nameC.text.trim(),
        'phone': phoneC.text.trim(),
        'password': passC.text.trim(),
        'role': role,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Widget _fld(BuildContext context, TextEditingController c,
      String hint, IconData icon, Color ic,
      {bool obscure = false, TextInputType? kt}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: kt,
      style: TextStyle(color: dark ? Colors.white : AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: dark ? Colors.grey.shade500 : Colors.grey.shade400),
        prefixIcon: Icon(icon, color: ic, size: 20),
        filled: true,
        fillColor: dark ? const Color(0xFF26262E) : const Color(0xFFFFFDF9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
    );
  }
}

// ======================================================
// ➕ صفحة إنشاء حساب (مع نوع الحساب)
// ======================================================

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});
  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  String? _housing;
  String? _transport;
  String _role = 'client';
  bool _adminUnlocked = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final s = context.read<AppSettings>();
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _pass.text.trim().isEmpty ||
        _housing == null ||
        _transport == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              s.isArabic ? 'يرجى ملء جميع الحقول والخيارات' : 'Fill all fields'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _busy = true);
    try {
      await OrdersService.addUserRaw({
        'id': 'u_${DateTime.now().millisecondsSinceEpoch}',
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'password': _pass.text.trim(),
        'role': _role,
        'points': 0,
        'stored': 0,
        'housing': _housing,
        'transport': _transport,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل: $e')));
      }
    }
  }

  Widget _opt(String label, String value, String? current, Color c,
      ValueChanged<String> onPick, bool dark,
      {VoidCallback? onLongPress}) {
    final active = current == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, bottom: 8),
      child: InkWell(
        onTap: () => onPick(value),
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: <Color>[c, c.withAlpha(180)])
                : null,
            color: active ? null : c.withAlpha(18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withAlpha(active ? 180 : 80)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : c,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ),
    );
  }

  Widget _fld(TextEditingController c, String hint, IconData icon, Color ic,
      {bool obscure = false, TextInputType? kt, bool dark = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: kt,
      style: TextStyle(color: dark ? Colors.white : AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: dark ? Colors.grey.shade500 : Colors.grey.shade400),
        prefixIcon: Icon(icon, color: ic, size: 20),
        filled: true,
        fillColor: dark ? const Color(0xFF26262E) : const Color(0xFFFFFDF9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _title(String t, IconData icon, Color c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[c.withAlpha(30), c.withAlpha(8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: c)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.isArabic ? 'إنشاء حساب' : 'Create account',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                  child: _fld(_name,
                      s.isArabic ? 'اسم المستخدم' : 'Name',
                      Icons.person_rounded, AppColors.orange,
                      dark: dark)),
              const SizedBox(width: 10),
              Expanded(
                  child: _fld(_phone,
                      s.isArabic ? 'رقم الهاتف' : 'Phone',
                      Icons.phone_rounded, AppColors.teal,
                      kt: TextInputType.phone, dark: dark)),
            ],
          ),
          const SizedBox(height: 12),
          _fld(_pass, s.isArabic ? 'كلمة السر' : 'Password',
              Icons.lock_rounded, const Color(0xFF9B59B6),
              obscure: true, dark: dark),
          const SizedBox(height: 20),
          _title(s.isArabic ? 'نوع الحساب' : 'Account type',
              Icons.badge_rounded, const Color(0xFF9B59B6)),
          Wrap(
            children: [
              _opt(s.isArabic ? 'عميل' : 'Client', 'client', _role,
                  AppColors.teal, (v) => setState(() => _role = v), dark),
              _opt(s.isArabic ? 'صباغ' : 'Painter', 'tech', _role,
                  AppColors.orange, (v) => setState(() => _role = v), dark),
              _opt(s.isArabic ? 'وكيل' : 'Agent', 'agent', _role,
                  const Color(0xFF9B59B6), (v) => setState(() => _role = v),
                  dark,
                  onLongPress: () {
                    if (!_adminUnlocked) {
                      setState(() => _adminUnlocked = true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(s.isArabic
                              ? '🔓 تم فتح خيار المدير'
                              : 'Admin option unlocked')));
                    }
                  }),
              if (_adminUnlocked)
                _opt(s.isArabic ? 'مدير' : 'Admin', 'admin', _role,
                    Colors.red, (v) => setState(() => _role = v), dark),
            ],
          ),
          const SizedBox(height: 12),
          _title(s.isArabic ? 'نوع السكن' : 'Housing type',
              Icons.home_rounded, AppColors.orange),
          Wrap(
            children: [
              _opt(s.isArabic ? 'إيجار' : 'Rent', 'rent', _housing,
                  AppColors.orange,
                  (v) => setState(() => _housing = v), dark),
              _opt(s.isArabic ? 'ملك' : 'Owned', 'own', _housing,
                  AppColors.teal, (v) => setState(() => _housing = v), dark),
            ],
          ),
          const SizedBox(height: 12),
          _title(s.isArabic ? 'وسائل النقل' : 'Transport',
              Icons.directions_bus_rounded, AppColors.teal),
          Wrap(
            children: [
              _opt(s.isArabic ? 'دراجة' : 'Bike', 'bike', _transport,
                  AppColors.teal,
                  (v) => setState(() => _transport = v), dark),
              _opt(s.isArabic ? 'ستوتة' : 'Tuk-tuk', 'tuk', _transport,
                  AppColors.orange,
                  (v) => setState(() => _transport = v), dark),
              _opt(s.isArabic ? 'سيارة' : 'Car', 'car', _transport,
                  const Color(0xFF9B59B6),
                  (v) => setState(() => _transport = v), dark),
              _opt(s.isArabic ? 'لا أملك' : 'None', 'none', _transport,
                  Colors.red, (v) => setState(() => _transport = v), dark),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: <Color>[
                  Color(0xFFFF8C00),
                  Color(0xFFF26B0F),
                ]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.orange.withAlpha(80),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ]),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white),
                onPressed: _busy ? null : _confirm,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        s.isArabic ? 'تأكيد إنشاء الحساب' : 'Confirm create',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
