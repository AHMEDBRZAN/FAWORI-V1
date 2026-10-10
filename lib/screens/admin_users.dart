import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/repositories/user_repo.dart';
import '../core/store_service.dart';
import '../core/theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<AppUser> _users = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final list = await userRepo.listUsers();
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isCtrl => context.read<AppSettings>().isController;

  Future<void> _create() async {
    final ok = await _CreateDialog.show(context);
    if (ok == true) _load();
  }

  Future<void> _edit(AppUser u) async {
    final ok = await _EditDialog.show(context, u);
    if (ok == true) _load();
  }

  Future<void> _delete(AppUser u) async {
    if (!_isCtrl) {
      _snack(context, 'الحذف للمتحكم فقط', Colors.red, Icons.lock_rounded);
      return;
    }
    final s = context.read<AppSettings>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isArabic ? 'حذف الحساب' : 'Delete account'),
        content: Text(s.isArabic
            ? 'هل أنت متأكد من حذف ${u.name}؟'
            : 'Delete ${u.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.isArabic ? 'حذف' : 'Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await userRepo.deleteUser(u.id);
      if (mounted) {
        _snack(context, 'تم الحذف', Colors.green, Icons.check_rounded);
        _load();
      }
    } catch (e) {
      if (mounted) _snack(context, 'فشل: $e', Colors.red, Icons.error_rounded);
    }
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
        title: Text(s.isArabic ? 'إدارة المستخدمين' : 'Users management',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : AppColors.ink)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.orange),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        onPressed: _create,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(s.isArabic ? 'حساب جديد' : 'New user',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 10),
                      Text('$_err',
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _userCard(_users[i], dark, s),
                  ),
                ),
    );
  }

  Widget _userCard(AppUser u, bool dark, AppSettings s) {
    final isMe = u.id == s.user?.id;
    final color = _roleColor(u.role);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(80)),
        boxShadow: [
          BoxShadow(
              color: color.withAlpha(30),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: <Color>[color, color.withAlpha(180)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_roleIcon(u.role), color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(u.name.isEmpty ? '—' : u.name,
                          style: TextStyle(
                              color: dark ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ),
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s.isArabic ? 'أنت' : 'You',
                            style: const TextStyle(
                                color: AppColors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(u.phone.isEmpty ? '—' : u.phone,
                    style: TextStyle(
                        color:
                            dark ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_roleLabel(u.role, s.isArabic),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              _miniBtn(Icons.edit_rounded, AppColors.teal, () => _edit(u)),
              const SizedBox(height: 6),
              _miniBtn(
                Icons.delete_rounded,
                _isCtrl ? Colors.red : Colors.grey,
                isMe ? null : () => _delete(u),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(IconData ic, Color c, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: c.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(ic, color: c, size: 18),
      ),
    );
  }

  Color _roleColor(String r) {
    switch (r) {
      case 'ctrl':
        return const Color(0xFFB71C1C);
      case 'admin':
        return Colors.red;
      case 'agent':
        return const Color(0xFF9B59B6);
      case 'tech':
        return AppColors.orange;
      default:
        return AppColors.teal;
    }
  }

  IconData _roleIcon(String r) {
    switch (r) {
      case 'ctrl':
        return Icons.shield_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'agent':
        return Icons.support_agent_rounded;
      case 'tech':
        return Icons.format_paint_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _roleLabel(String r, bool ar) {
    switch (r) {
      case 'ctrl':
        return ar ? 'متحكم' : 'Controller';
      case 'admin':
        return ar ? 'مدير' : 'Admin';
      case 'agent':
        return ar ? 'وكيل' : 'Agent';
      case 'tech':
        return ar ? 'صباغ' : 'Painter';
      case 'guest':
        return ar ? 'ضيف' : 'Guest';
      default:
        return ar ? 'عميل' : 'Client';
    }
  }
}

// ======================================================
// ✏️ نافذة تعديل مستخدم
// ======================================================

class _EditDialog {
  static Future<bool> show(BuildContext context, AppUser u) async {
    final s = context.read<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final nameC = TextEditingController(text: u.name);
    final phoneC = TextEditingController(text: u.phone);
    String role = u.role;
    final isCtrl = s.isController;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          Widget roleChip(String label, String value, Color c) {
            final active = role == value;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, bottom: 8),
              child: InkWell(
                onTap: () => setSt(() => role = value),
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

          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                const Icon(Icons.edit_rounded, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.isArabic ? 'تعديل المستخدم' : 'Edit user',
                      style: const TextStyle(
                          color: AppColors.teal, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fld(nameC, s.isArabic ? 'الاسم' : 'Name',
                      Icons.person_rounded, AppColors.orange, dark),
                  const SizedBox(height: 10),
                  _fld(phoneC, s.isArabic ? 'الهاتف' : 'Phone',
                      Icons.phone_rounded, AppColors.teal, dark,
                      kt: TextInputType.phone),
                  const SizedBox(height: 14),
                  if (isCtrl) ...[
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(s.isArabic ? 'الدور:' : 'Role:',
                          style: TextStyle(
                              color: dark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Wrap(
                        children: [
                          roleChip(s.isArabic ? 'متحكم' : 'Controller', 'ctrl',
                              const Color(0xFFB71C1C)),
                          roleChip(s.isArabic ? 'مدير' : 'Admin', 'admin',
                              Colors.red),
                          roleChip(s.isArabic ? 'وكيل' : 'Agent', 'agent',
                              const Color(0xFF9B59B6)),
                          roleChip(s.isArabic ? 'صباغ' : 'Painter', 'tech',
                              AppColors.orange),
                          roleChip(s.isArabic ? 'عميل' : 'Client', 'client',
                              AppColors.teal),
                        ],
                      ),
                    ),
                  ],
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
                      phoneC.text.trim().isEmpty) {
                    _snack(context, s.isArabic ? 'املأ الحقول' : 'Fill fields',
                        Colors.red, Icons.warning_rounded);
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
      final fields = <String, dynamic>{
        'name': nameC.text.trim(),
        'phone': phoneC.text.trim(),
      };
      if (isCtrl) fields['role'] = role;
      await userRepo.updateUser(u.id, fields);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Widget _fld(TextEditingController c, String hint, IconData icon,
      Color ic, bool dark,
      {bool obscure = false, TextInputType? kt}) {
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
// ➕ نافذة إنشاء حساب جديد
// ======================================================

class _CreateDialog {
  static Future<bool> show(BuildContext context) async {
    final s = context.read<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final passC = TextEditingController();
    String role = 'client';
    final isCtrl = s.isController;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          Widget roleChip(String label, String value, Color c) {
            final active = role == value;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, bottom: 8),
              child: InkWell(
                onTap: () => setSt(() => role = value),
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

          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                const Icon(Icons.person_add_rounded, color: AppColors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.isArabic ? 'حساب جديد' : 'New account',
                      style: const TextStyle(
                          color: AppColors.orange, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fld(nameC, s.isArabic ? 'الاسم' : 'Name',
                      Icons.person_rounded, AppColors.orange, dark),
                  const SizedBox(height: 10),
                  _fld(phoneC, s.isArabic ? 'الهاتف' : 'Phone',
                      Icons.phone_rounded, AppColors.teal, dark,
                      kt: TextInputType.phone),
                  const SizedBox(height: 10),
                  _fld(passC,
                      s.isArabic
                          ? 'كلمة السر (6 أحرف على الأقل)'
                          : 'Password (min 6)',
                      Icons.lock_rounded, const Color(0xFF9B59B6), dark,
                      obscure: true),
                  if (isCtrl) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(s.isArabic ? 'الدور:' : 'Role:',
                          style: TextStyle(
                              color: dark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Wrap(
                        children: [
                          roleChip(s.isArabic ? 'متحكم' : 'Controller', 'ctrl',
                              const Color(0xFFB71C1C)),
                          roleChip(s.isArabic ? 'مدير' : 'Admin', 'admin',
                              Colors.red),
                          roleChip(s.isArabic ? 'وكيل' : 'Agent', 'agent',
                              const Color(0xFF9B59B6)),
                          roleChip(s.isArabic ? 'صباغ' : 'Painter', 'tech',
                              AppColors.orange),
                          roleChip(s.isArabic ? 'عميل' : 'Client', 'client',
                              AppColors.teal),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (nameC.text.trim().isEmpty ||
                      phoneC.text.trim().isEmpty ||
                      passC.text.trim().isEmpty) {
                    _snack(context, s.isArabic ? 'املأ الحقول' : 'Fill all',
                        Colors.red, Icons.warning_rounded);
                    return;
                  }
                  if (passC.text.length < 6) {
                    _snack(context,
                        s.isArabic
                            ? 'كلمة السر 6 أحرف على الأقل'
                            : 'Password min 6 chars',
                        Colors.red, Icons.warning_rounded);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(s.isArabic ? 'إنشاء' : 'Create'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return false;
    try {
      await userRepo.createUser(
          phoneC.text.trim(), nameC.text.trim(), passC.text, role);
      return true;
    } catch (e) {
      _snack(context, '$e', Colors.red, Icons.error_rounded);
      return false;
    }
  }

  static Widget _fld(TextEditingController c, String hint, IconData icon,
      Color ic, bool dark,
      {bool obscure = false, TextInputType? kt}) {
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

void _snack(BuildContext c, String msg, Color color, IconData ic) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(ic, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(
          child: Text(msg,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800))),
    ]),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ));
}

// ======================================================
// 🌉 جسر التوافق: يبقي simple_screens.dart يعمل بدون تعديل
// ======================================================

class CreateAccountPage extends AdminUsersPage {
  const CreateAccountPage({super.key});
}

class EditUserDialog {
  static Future<dynamic> show(BuildContext context, User u) async {
    final au = AppUser(
      id: u.id,
      phone: u.phone,
      name: u.name,
      role: u.role,
      points: u.points,
      stored: u.stored,
    );
    return await _EditDialog.show(context, au);
  }
}
