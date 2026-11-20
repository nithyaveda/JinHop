// Profile tab and the Edit profile screen (the app's Create/Edit form).
//
// Profile --(Edit profile: Navigator.push)--> EditProfileScreen
// EditProfileScreen --(Save: Navigator.pop(profile))--> Profile, which saves
// it and shows a SnackBar. Cancel / back just pops with no result.

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/profile.dart';
import 'auth_screens.dart';
import 'how_to_play_screen.dart';
import 'palette.dart';
import 'settings_screen.dart';
import 'theme.dart';

const _worldNames = {1: 'Misty Pond', 2: 'Lantern Marsh'};

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Future<void> _edit() async {
    final storage = AppScope.of(context).storage;
    final updated = await Navigator.push<PlayerProfile>(
      context,
      MaterialPageRoute<PlayerProfile>(builder: (_) => EditProfileScreen(profile: storage.profile)),
    );
    if (updated == null || !mounted) return; // cancelled
    await storage.saveProfile(updated);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  Future<void> _logOut() async {
    await AppScope.of(context).storage.logOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final st = scope.storage;
    final p = st.profile;
    final ids = scope.levels.ids;
    final text = Theme.of(context).textTheme;

    return ListView(
      key: const Key('profile'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Profile', style: text.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: jinCard(),
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Jin.jade,
              child: Text(p.initial,
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            Text(p.name, key: const Key('profile_name'), style: text.titleLarge),
            Text(p.guest ? 'Guest player' : (p.email.isEmpty ? '-' : p.email), style: text.bodySmall),
            if (p.motto.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"${p.motto}"',
                  key: const Key('profile_motto'),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Fact(label: 'Favourite world', value: _worldNames[p.favouriteWorld] ?? '-')),
              Expanded(child: _Fact(label: 'Stars', value: '${st.totalStars(ids)} / ${ids.length * 3}')),
              Expanded(child: _Fact(label: 'Coins', value: '${st.coins}')),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('edit_profile'),
              onPressed: _edit,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit profile'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: jinCard(),
          clipBehavior: Clip.antiAlias,
          // Material so the ListTile tap ripple shows on top of the card.
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.settings_rounded, color: Jin.jade),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: Jin.jade),
                title: const Text('How to play'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('logout'),
                leading: const Icon(Icons.logout_rounded, color: Jin.red),
                title: Text(p.guest ? 'Leave guest mode' : 'Log out'),
                onTap: _logOut,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(children: [
      FittedBox(child: Text(value, style: text.titleMedium)),
      FittedBox(child: Text(label, style: text.bodySmall)),
    ]);
  }
}

// ---------------------------------------------------------------- Edit

/// Create/Edit screen: a form to change the player's profile.
class EditProfileScreen extends StatefulWidget {
  final PlayerProfile profile;
  const EditProfileScreen({super.key, required this.profile});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _motto = TextEditingController(text: widget.profile.motto);
  late int _world = widget.profile.favouriteWorld;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _motto.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.profile.copyWith(
        name: _name.text.trim(),
        email: _email.text.trim(),
        motto: _motto.text.trim(),
        favouriteWorld: _world,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.profile.guest;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: IconButton(
          key: const Key('edit_cancel'),
          tooltip: 'Cancel',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('This is how you appear in JinHop.', style: text.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('edit_name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Player name', prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: validateName,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('edit_email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: guest ? 'Email (optional for guests)' : 'Email',
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) => guest && (v ?? '').trim().isEmpty ? null : validateEmail(v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('edit_motto'),
                    controller: _motto,
                    maxLength: 40,
                    decoration: const InputDecoration(
                        labelText: 'Lucky motto (optional)', prefixIcon: Icon(Icons.auto_awesome_rounded)),
                    validator: validateMotto,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    key: const Key('edit_world'),
                    initialValue: _world,
                    decoration:
                        const InputDecoration(labelText: 'Favourite world', prefixIcon: Icon(Icons.public_rounded)),
                    items: [
                      for (final e in _worldNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _world = v ?? _world),
                    validator: (v) => v == null ? 'Choose a world' : null,
                  ),
                  const SizedBox(height: 26),
                  FilledButton(key: const Key('edit_save'), onPressed: _save, child: const Text('Save changes')),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
