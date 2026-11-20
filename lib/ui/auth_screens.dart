// Login and Register screens: Form + TextFormField + validator.
//
// Flow: Login --(Create an account: Navigator.push)--> Register
//       Register --(Create account: Navigator.pop(email))--> Login
//       Login / Play as guest --(pushReplacement)--> HomeShell (dashboard)
//
// Practical 1 has no database: the account is kept on the device and no
// password is stored. Practical 2 adds real authentication.

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/models.dart' show Facing;
import '../core/profile.dart';
import 'art/sprites.dart';
import 'home_shell.dart';
import 'palette.dart';

/// Centres a form and keeps it a comfortable width on tablets, and scrolls
/// when the keyboard is open on small phones (responsive layout).
class _FormPage extends StatelessWidget {
  final List<Widget> children;
  const _FormPage({required this.children});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      );
}

/// Jin Chan in a soft gold circle (Container + BoxDecoration).
class JinChanBadge extends StatelessWidget {
  final double size;
  const JinChanBadge({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1C2),
            shape: BoxShape.circle,
            border: Border.all(color: Jin.gold, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x33D9A422), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: CustomPaint(painter: _JinPainter()),
        ),
      );
}

class _JinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.84);
    Sprites.frog(canvas, Facing.s, size.width * 0.66, golden: true, shadow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JinPainter old) => false;
}

// ---------------------------------------------------------------- Login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  String? _accountError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _openHome() => Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      );

  Future<void> _logIn() async {
    setState(() => _accountError = null);
    if (!_formKey.currentState!.validate()) return; // runs every validator
    final storage = AppScope.of(context).storage;
    final registered = storage.accountEmail;
    final email = _email.text.trim().toLowerCase();
    if (registered == null || registered != email) {
      setState(() => _accountError = registered == null
          ? 'No account on this phone yet. Create one below, or play as a guest.'
          : 'No account found for this email.');
      return;
    }
    await storage.logIn(email);
    if (mounted) _openHome();
  }

  Future<void> _register() async {
    // Push the Register screen and wait for the email it pops back.
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (_) => const RegisterScreen()),
    );
    if (email == null || !mounted) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _accountError = null;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Account created! Log in to start hopping.')));
  }

  Future<void> _guest() async {
    await AppScope.of(context).storage.playAsGuest();
    if (mounted) _openHome();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: _FormPage(children: [
        const SizedBox(height: 8),
        const JinChanBadge(),
        const SizedBox(height: 18),
        Text('Welcome back!', textAlign: TextAlign.center, style: text.headlineMedium),
        const SizedBox(height: 6),
        Text('Log in to keep your stars, coins and lucky streak.', textAlign: TextAlign.center, style: text.bodyMedium),
        const SizedBox(height: 26),
        Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              key: const Key('login_email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('login_password'),
              controller: _password,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _logIn(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: validatePassword,
            ),
          ]),
        ),
        if (_accountError != null) ...[
          const SizedBox(height: 12),
          Text(_accountError!,
              key: const Key('login_error'),
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: Jin.red, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 22),
        FilledButton(key: const Key('login_submit'), onPressed: _logIn, child: const Text('Log in')),
        const SizedBox(height: 12),
        // Wrap (not Row) so this line folds instead of overflowing on narrow
        // screens or with large system text.
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('New to JinHop?', style: text.bodyMedium),
          TextButton(key: const Key('go_register'), onPressed: _register, child: const Text('Create an account')),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: text.bodySmall)),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const Key('login_guest'),
          onPressed: _guest,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Play as guest'),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Register

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
  final _confirm = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    await AppScope.of(context).storage.register(name: _name.text.trim(), email: email);
    if (mounted) Navigator.pop(context, email); // back to Login with the email
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: IconButton(
          key: const Key('register_back'),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _FormPage(children: [
        Text('Join the pond', textAlign: TextAlign.center, style: text.headlineSmall),
        const SizedBox(height: 6),
        Text('Pick a player name and you are ready to hop.', textAlign: TextAlign.center, style: text.bodyMedium),
        const SizedBox(height: 22),
        Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              key: const Key('reg_name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration:
                  const InputDecoration(labelText: 'Player name', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: validateName,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('reg_email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('reg_password'),
              controller: _password,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 6 characters, with a letter and a number',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('reg_confirm'),
              controller: _confirm,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _create(),
              decoration:
                  const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_rounded)),
              validator: (v) => validateConfirmPassword(v, _password.text),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        FilledButton(key: const Key('reg_submit'), onPressed: _create, child: const Text('Create account')),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('I already have an account')),
      ]),
    );
  }
}
