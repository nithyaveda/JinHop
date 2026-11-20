import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'how_to_play_screen.dart';
import 'palette.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final st = scope.storage;

    Widget toggle(String key, String title, String subtitle, bool value,
            Future<void> Function(bool) onChanged) =>
        SwitchListTile(
          key: Key(key),
          title:
              Text(title, style: const TextStyle(fontSize: 18, color: Jin.ink)),
          subtitle:
              Text(subtitle, style: TextStyle(color: Jin.ink.withAlpha(170))),
          value: value,
          activeThumbColor: Jin.cream,
          activeTrackColor: Jin.jade,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          onChanged: (v) async {
            await onChanged(v);
            if (mounted) setState(() {});
          },
        );

    return Scaffold(
      backgroundColor: Jin.cream,
      appBar: AppBar(
        backgroundColor: Jin.cream,
        foregroundColor: Jin.jadeDeep,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          toggle('set_sound', 'Sound effects', 'Croaks, splashes and chimes',
              st.soundOn, (v) async {
            await st.setSoundOn(v);
            await scope.audio.setSound(v);
          }),
          toggle('set_music', 'Music', 'The pond\'s soft ambience', st.musicOn,
              (v) async {
            await st.setMusicOn(v);
            await scope.audio.setMusic(v);
          }),
          toggle('set_haptics', 'Haptics', 'A light touch on every tap',
              st.hapticsOn, (v) async {
            await st.setHapticsOn(v);
            scope.haptics.enabled = v;
          }),
          toggle(
              'set_colorblind',
              'Colourblind-safe arrows',
              'Dark arrows with a bold light outline',
              st.colorblindArrows,
              (v) => st.setColorblindArrows(v)),
          const Divider(indent: 20, endIndent: 20),
          ListTile(
            key: const Key('set_howto'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading:
                const Icon(Icons.help_outline_rounded, color: Jin.jadeDeep),
            title: const Text('How to play',
                style: TextStyle(fontSize: 18, color: Jin.ink)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const HowToPlayScreen())),
          ),
        ],
      ),
    );
  }
}
