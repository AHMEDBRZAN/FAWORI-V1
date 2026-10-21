import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _obscure = true;
  bool _isRegisterMode = false; // ← وضع جديد للتسجيل الأول

  @override
  void initState() {
    super.initState();
    // ✅ فحص فوري للجلسة المحفوظة عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    if (!mounted) return;
    final s = context.read<AppSettings>();
    await s.restoreSession(); // ← دالة جديدة نستوردها من app_settings
    if (s.isLoggedIn && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()), (r) => false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    
    try {
      final email = _email.text.trim().toLowerCase();
      final pass = _pass.text.trim();
      
      if (email.isEmpty || pass.isEmpty) {
        throw Exception('أدخل البريد وكلمة المرور');
      }
      
      if (!_isValidEmail(email)) {
        throw Exception('صيغة البريد الإلكتروني غير صحيحة');
      }
      
      if (_isRegisterMode) {
        await context.read<AppSettings>().registerWithEmail(email, pass);
      } else {
        await context.read<AppSettings>().loginWithEmail(email, pass);
      }
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()), (r) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  bool _isValidEmail(String e) => 
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(e);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final dark = s.isDark;
    final ar = s.isArabic;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const <Color>[Color(0xFF141419), Color(0xFF1B1B21)]
                : const <Color>[Color(0xFFFFF8F1), Color(0xFFFDEFDE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شعار فاوري
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.orange.withAlpha(90),
                            blurRadius: 26,
                            offset: const Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/images/logo.webp',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (c, o, st) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: <Color>[
                                    Color(0xFFFFA500),
                                    Color(0xFFFF8C00)
                                  ]),
                                ),
                                child: const Center(
                                  child: Text('FAWORI',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900)),
                                ),
                              )),
                    ),
                  ),
                  const SizedBox(height: 26),
                  
                  // نموذج الدخول/التسجيل
                  Container(
                    margin: const EdgeInsets.all(7),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF1E1E28) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.orange.withAlpha(60)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // عنوان الديناميكي
                        Text(
                          _isRegisterMode
                              ? (ar ? 'إنشاء حساب جديد' : 'Create Account')
                              : (ar ? 'تسجيل الدخول' : 'Sign In'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: dark ? Colors.white : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 18),
                        
                        // حقل البريد الإلكتروني
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: dark ? Colors.white : AppColors.ink),
                          decoration: InputDecoration(
                            hintText: ar ? 'البريد الإلكتروني' : 'Email',
                            filled: true,
                            fillColor: dark ? const Color(0xFF26262E) : const Color(0xFFFAFAFA),
                            prefixIcon: const Icon(Icons.email_rounded, color: AppColors.orange),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: AppColors.orange.withAlpha(90)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.teal, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        
                        // حقل كلمة المرور
                        TextField(
                          controller: _pass,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          style: TextStyle(color: dark ? Colors.white : AppColors.ink),
                          decoration: InputDecoration(
                            hintText: ar ? 'كلمة المرور' : 'Password',
                            filled: true,
                            fillColor: dark ? const Color(0xFF26262E) : const Color(0xFFFAFAFA),
                            prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.orange),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey.shade500),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: AppColors.orange.withAlpha(90)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.teal, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        
                        // زر الإرسال الرئيسي
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: <Color>[AppColors.orange, Color(0xFFF26B0F)]),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: AppColors.orange.withAlpha(110), blurRadius: 18, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(
                                    _isRegisterMode ? (ar ? 'إنشاء الحساب' : 'Create') : (ar ? 'دخول' : 'Sign In'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                          ),
                        ),
                        
                        // رابط التبديل بين الوضعين
                        TextButton(
                          onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                          child: Text(
                            _isRegisterMode
                                ? (ar ? 'لديك حساب بالفعل؟ سجّل دخولك' : 'Have an account? Sign in')
                                : (ar ? 'ليس لديك حساب؟ أنشئ واحداً' : 'No account? Create one'),
                            style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        
                        // رسالة الخطأ
                        if (_err != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withAlpha(60)),
                            ),
                            child: Text(_err!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 18),
                  Text(
                    ar ? 'شركة فاوِري — جودة تدوم' : 'FAWORI Co. — Quality that lasts',
                    style: TextStyle(color: dark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
