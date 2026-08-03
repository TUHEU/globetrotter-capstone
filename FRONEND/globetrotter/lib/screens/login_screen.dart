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

  @override
  void initState() {
    super.initState();
    // Sur Web, le bouton Google officiel (rendu par le SDK, pas par notre
    // code) ne renvoie aucune valeur directe : la connexion aboutit via le
    // flux authenticationEvents dans AuthProvider, de façon complètement
    // asynchrone. On écoute donc les changements de isLoggedIn ici plutôt
    // que de dépendre uniquement du retour de _submitGoogle().
    context.read<AuthProvider>().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (context.read<AuthProvider>().isLoggedIn) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final s = context.read<SettingsProvider>().s;
    final ok = await auth.login(_email.text.trim(), _password.text);
    if (!mounted) return;
    // La navigation en cas de succès est gérée par _onAuthChanged ci-dessus
    // (centralisé pour les 3 chemins de connexion : email/mdp, Google
    // mobile, Google web) — ici on ne gère que l'affichage d'une erreur.
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage(s) ?? s.loginFailed),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB3261E),
      ));
    }
  }

  Future<void> _submitGoogle() async {
    final auth = context.read<AuthProvider>();
    final s = context.read<SettingsProvider>().s;
    final ok = await auth.loginWithGoogle();
    if (!mounted) return;
    if (!ok && auth.hasError) {
      // hasError == false veut dire que l'utilisateur a juste fermé la
      // fenêtre Google sans choisir de compte — pas la peine d'afficher
      // une erreur pour une simple annulation.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage(s) ?? s.loginFailed),
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
      subtitle: s.authTagline,
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
            if (auth.isGoogleSignInAvailable) ...[
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
              // Sur Web, Google EXIGE son propre bouton rendu par son SDK
              // (contrainte anti-popup-blocker) — impossible d'utiliser notre
              // bouton "maison" là-bas, contrairement à Android où ça marche.
              if (auth.supportsGoogleButtonTap)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const _GoogleLogo(),
                  label: Text(s.continueWithGoogle,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: auth.loading ? null : _submitGoogle,
                )
              else
                Center(child: auth.buildWebGoogleButton()),
            ],
            const SizedBox(height: 10),
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

/// Petit logo Google en 4 couleurs, dessiné directement (pas besoin
/// d'importer un fichier image juste pour un bouton).
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final stroke = r * 0.62;

    void arc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(radius: r - stroke / 2, center: center),
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-45, -90, const Color(0xFFEA4335));   // rouge
    arc(-135, -90, const Color(0xFF4285F4));  // bleu
    arc(135, -90, const Color(0xFF34A853));   // vert
    arc(45, -90, const Color(0xFFFBBC05));    // jaune
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
