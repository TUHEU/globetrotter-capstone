import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/auth_scaffold.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_email.text.trim(), _password.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error ?? "Connexion impossible"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB3261E),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = context.watch<SettingsProvider>().s;
    return AuthScaffold(
      title: "GlobeTrotter Yaoundé",
      subtitle: "Discover Yaoundé smarter. Travel better. 🇨🇲",
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.welcomeBack,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              s.loginSubtitle,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFFCD116),
              decoration: glassInput(context,
                  label: s.email, icon: Icons.mail_outline),
              validator: (v) =>
                  v != null && v.contains("@") ? null : s.invalidEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFFCD116),
              decoration: glassInput(
                context,
                label: s.password,
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 21,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : s.min6chars,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 26),
            GradientButton(
              onPressed: _submit,
              loading: auth.loading,
              label: s.login,
              icon: Icons.login,
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(s.or,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              ),
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
            ]),
            const SizedBox(height: 14),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: Text(s.createAccountFree,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
