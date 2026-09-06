import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/accessibility/accessible_widgets.dart';
import '../../../core/audio/audio_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_cubit.dart';
import '../../../core/settings/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsStore _store;
  bool _ready = false;
  bool _autoLogin = true, _keepCredentials = true, _voiceAutoJoin = false, _speechMute = false;
  String _speaker = 'default', _pm = 'everyone', _invite = 'everyone', _join = 'everyone';
  final Map<String,String> _speechModes = {};
  static const _categories = ['friends','invitations','table_chat','private_messages','game_events'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _store = context.read<SettingsStore>();
    _reload();
  }

  void _reload() {
    setState(() {
      _ready = true;
      _autoLogin = _store.autoLogin;
      _keepCredentials = _store.keepCredentials;
      _voiceAutoJoin = _store.voiceAutoJoin;
      _speechMute = _store.speechMute;
      _speaker = _store.speaker;
      _pm = _store.pmPolicy; _invite = _store.invitePolicy; _join = _store.joinPolicy;
      for (final c in _categories) _speechModes[c] = _store.speechMode(c);
    });
  }

  Future<void> _speechMode(String category) async {
    final options = const ['speech_and_sound','speech','sound_only'];
    final labels = const {'speech_and_sound':'نطق + صوت','speech':'نطق فقط','sound_only':'صوت فقط'};
    final selected = await showDialog<String>(context: context, builder: (c) => SimpleDialog(
      title: Text('إعداد إشعار $category'),
      children: [for(final v in options) RadioListTile<String>(value:v, groupValue:_speechModes[category], title:Text(labels[v]!), onChanged:(x)=>Navigator.pop(c,x))],
    ));
    if(selected!=null){ await _store.setSpeechMode(category,selected); setState(()=>_speechModes[category]=selected); }
  }

  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[AccessibleHeader(title), Card(color:AppColors.surface, child:Column(children:children)), const SizedBox(height:16)]);
  Widget _policy(String title, String value, Future<void> Function(String) save) => ListTile(title:Text(title), subtitle:Text(value), onTap:() async { final v=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:Text(title),children:[for(final x in const ['everyone','friends','nobody'])SimpleDialogOption(onPressed:()=>Navigator.pop(c,x),child:Text(x=='everyone'?'الكل':x=='friends'?'الأصدقاء':'لا أحد'))])); if(v!=null){await save(v); setState((){});} });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>();
    final audio = context.watch<AudioCubit>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.translate('nav.settings')),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'عام'),
              Tab(text: 'الصوت'),
              Tab(text: 'النطق والإشعارات'),
              Tab(text: 'الخصوصية'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: عام
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('عام', [
                  RadioListTile<String>(
                    title: const Text('لغة الجهاز'),
                    value: 'system',
                    groupValue: _store.language,
                    onChanged: (v) {
                      if (v != null) {
                        _store.setLanguage(v);
                        locale.setLanguage(v);
                        setState(() {});
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('العربية'),
                    value: 'ar',
                    groupValue: _store.language,
                    onChanged: (v) {
                      if (v != null) {
                        _store.setLanguage(v);
                        locale.setLanguage(v);
                        setState(() {});
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('English'),
                    value: 'en',
                    groupValue: _store.language,
                    onChanged: (v) {
                      if (v != null) {
                        _store.setLanguage(v);
                        locale.setLanguage(v);
                        setState(() {});
                      }
                    },
                  ),
                  SwitchListTile(
                    title: const Text('تسجيل الدخول تلقائيًا'),
                    value: _autoLogin,
                    onChanged: (v) async {
                      await _store.setAutoLogin(v);
                      setState(() => _autoLogin = v);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('الاحتفاظ ببيانات الدخول'),
                    value: _keepCredentials,
                    onChanged: (v) async {
                      await _store.setKeepCredentials(v);
                      setState(() => _keepCredentials = v);
                    },
                  ),
                ]),
              ],
            ),

            // Tab 2: الصوت
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('الصوت', [
                  SwitchListTile(
                    title: const Text('كتم كل الأصوات'),
                    value: audio.state.isMuted,
                    onChanged: (v) => audio.setMute(v),
                  ),
                  ListTile(
                    title: Text('الصوت الرئيسي: ${(audio.state.masterVolume * 100).round()}%'),
                    subtitle: Slider(
                      value: audio.state.masterVolume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: audio.state.isMuted ? null : audio.setMasterVolume,
                    ),
                  ),
                  ListTile(
                    title: Text('أصوات المؤثرات: ${(audio.state.effectsVolume * 100).round()}%'),
                    subtitle: Slider(
                      value: audio.state.effectsVolume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: audio.state.isMuted ? null : audio.setEffectsVolume,
                    ),
                  ),
                  ListTile(
                    title: Text('أصوات اللعبة: ${(audio.state.gameVolume * 100).round()}%'),
                    subtitle: Slider(
                      value: audio.state.gameVolume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: audio.state.isMuted ? null : audio.setGameVolume,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('الدخول للمحادثة الصوتية تلقائيًا'),
                    value: _voiceAutoJoin,
                    onChanged: (v) async {
                      await _store.setVoiceAutoJoin(v);
                      setState(() => _voiceAutoJoin = v);
                    },
                  ),
                  ListTile(
                    title: const Text('مخرج الصوت'),
                    subtitle: Text(_speaker == 'default' ? 'الافتراضي' : _speaker),
                    onTap: () async {
                      final v = await showDialog<String>(
                        context: context,
                        builder: (c) => SimpleDialog(
                          title: const Text('مخرج الصوت'),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(c, 'default'),
                              child: const Text('الافتراضي'),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(c, 'speaker'),
                              child: const Text('مكبر الصوت'),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(c, 'headset'),
                              child: const Text('سماعة الرأس'),
                            ),
                          ],
                        ),
                      );
                      if (v != null) {
                        await _store.setSpeaker(v);
                        setState(() => _speaker = v);
                      }
                    },
                  ),
                ]),
              ],
            ),

            // Tab 3: النطق والإشعارات
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('النطق والإشعارات', [
                  SwitchListTile(
                    title: const Text('كتم النطق بالكامل'),
                    value: _speechMute,
                    onChanged: (v) async {
                      await _store.setSpeechMute(v);
                      setState(() => _speechMute = v);
                    },
                  ),
                  for (final c in _categories)
                    ListTile(
                      title: Text(c),
                      subtitle: Text(_speechModes[c] ?? ''),
                      onTap: () => _speechMode(c),
                    ),
                ]),
              ],
            ),

            // Tab 4: الخصوصية
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('الخصوصية', [
                  _policy('من يمكنه إرسال رسائل خاصة', _pm, (v) => _store.setPmPolicy(v)),
                  _policy('من يمكنه إرسال الدعوات', _invite, (v) => _store.setInvitePolicy(v)),
                  _policy('من يمكنه الانضمام إلى طاولاتي', _join, (v) => _store.setJoinPolicy(v)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
