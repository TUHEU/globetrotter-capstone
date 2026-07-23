import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final Set<String> _selected = {};
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _name.text.trim(),
      _email.text.trim(),
      _password.text,
      _selected.toList(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? "Inscription impossible"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AuthScaffold(
      title: "Rejoignez l'aventure",
      subtitle: "Créez votre compte et explorez Yaoundé autrement ✨",
      form: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Créer un compte",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFFCD116),
              decoration: glassInput(
                context,
                label: "Nom complet",
                icon: Icons.person_outline,
              ),
              validator: (v) =>
                  v != null && v.trim().length >= 2 ? null : "Entrez votre nom",
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFFCD116),
              decoration: glassInput(
                context,
                label: "Email",
                icon: Icons.mail_outline,
              ),
              validator: (v) => v != null && v.contains("@")
                  ? null
                  : "Entrez un email valide",
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFFCD116),
              decoration: glassInput(
                context,
                label: "Mot de passe (6 min)",
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 21,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : "6 caractères minimum",
            ),
            const SizedBox(height: 22),
            const Text(
              "Qu'est-ce qui vous intéresse à Yaoundé ?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Vos choix alimentent vos recommandations personnalisées",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: PreferenceTags.all.map((t) {
                final sel = _selected.contains(t);
                return _InterestChip(
                  label: t,
                  selected: sel,
                  onTap: () => setState(
                    () => sel ? _selected.remove(t) : _selected.add(t),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),
            GradientButton(
              onPressed: _submit,
              loading: auth.loading,
              label: "Créer mon compte",
              icon: Icons.rocket_launch_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

/// High-contrast interest chip: a solid dark navy panel when unselected
/// (readable against the green auth background) and a solid gold pill
/// with a check icon when selected. Deliberately NOT translucent white —
/// that was blending into the background and reading as washed-out.
class _InterestChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: selected ? const Color(0xFFFCD116) : const Color(0xFF0D2557),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFCD116)
                  : const Color(0xFF4FA3F7).withValues(alpha: 0.35),
              width: 1.3,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFCD116).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Color(0xFF0F2418),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF0F2418) : Colors.white,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
