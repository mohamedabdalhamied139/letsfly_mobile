import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/settings/settings_store.dart';
import '../../../core/settings/game_settings_registry.dart';

class GameSettingsResult {
  final int targetScore;
  final Map<String, dynamic> rules;
  const GameSettingsResult(this.targetScore, this.rules);
}

/// Mobile presentation of the authoritative Windows game-settings registry.
/// The registry, defaults, constraints and normalization are shared logically
/// with the Windows/server contract; Android only changes the input widgets.
class GameSettingsDialog extends StatefulWidget {
  final String game;
  final int defaultTarget;
  const GameSettingsDialog({super.key, required this.game, required this.defaultTarget});
  @override State<GameSettingsDialog> createState() => _GameSettingsDialogState();
}

class _GameSettingsDialogState extends State<GameSettingsDialog> {
  late final TextEditingController _target;
  late final GameSettingsDefinition _definition;
  final Map<String, dynamic> _values = {};

  @override
  void initState() {
    super.initState();
    _definition = gameSettingsRegistry[widget.game.toUpperCase()] ?? GameSettingsDefinition(widget.game.toUpperCase(), widget.defaultTarget, const {}, const []);
    _target = TextEditingController(text: '${widget.defaultTarget}');
    _values.addAll(_definition.defaults);
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    final saved = SettingsStore(p).gamePreferences(widget.game);
    if (!mounted) return;
    final target = saved['target_score'];
    final rules = saved['rules'];
    setState(() {
      if (target != null) _target.text = '$target';
      if (rules is Map) _values.addAll(Map<String, dynamic>.from(rules));
    });
  }

  int? _number(String key) => int.tryParse('${_values[key]}');

  Widget _field(GameSettingField f) {
    if (f.kind == 'number') {
      final c = TextEditingController(text: '${_values[f.key] ?? f.defaultValue}');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: f.label, helperText: f.maximum == null ? 'الحد الأدنى: ${f.minimum}' : '${f.minimum} إلى ${f.maximum}'),
          onChanged: (v) => _values[f.key] = int.tryParse(v) ?? f.defaultValue,
        ),
      );
    }
    if (f.kind == 'choice') {
      final current = '${_values[f.key] ?? f.defaultValue}';
      return DropdownButtonFormField<String>(
        value: f.options.contains(current) ? current : (f.options.isEmpty ? null : f.options.first),
        decoration: InputDecoration(labelText: f.label),
        items: [for (final v in f.options) DropdownMenuItem(value: v, child: Text(_choiceLabel(v)))],
        onChanged: (v) { if (v != null) setState(() => _values[f.key] = v); },
      );
    }
    return SwitchListTile(title: Text(f.label), value: _values[f.key] == true, onChanged: (v) => setState(() => _values[f.key] = v));
  }

  String _choiceLabel(String v) => switch(v) {
    'draw' => 'السحب (Draw)', 'block' => 'القفل (Block)', 'standard' => 'النظام المباشر', 'unit' => 'نظام الوحدات',
    'classic' => 'كلاسيك', 'escoba_15' => 'إسكوبا 15', 'asso_piglia_tutto' => 'الآس يمسح الكل', 'scopone' => 'إسكوبوني',
    'EASY' => 'سهل', 'NORMAL' => 'متوسط', 'HARD' => 'صعب', 'EXPERT' => 'محترف', _ => v,
  };

  Future<void> _save() async {
    var target = int.tryParse(_target.text.trim()) ?? _definition.defaultTarget;
    GameSettingField? targetField;
    for (final f in _definition.fields) {
      if (f.key == 'target_score') { targetField = f; break; }
    }
    if (targetField != null) {
      target = target.clamp(targetField.minimum, targetField.maximum ?? 9999);
    } else {
      target = target.clamp(1, 9999);
    }
    final values = Map<String, dynamic>.from(_values);
    if (widget.game.toUpperCase() == 'NINETY_NINE') values['starting_tokens'] = target;
    final mapped = mapGameSettings(widget.game, target, values);
    final p = await SharedPreferences.getInstance();
    await SettingsStore(p).setGamePreferences(widget.game, mapped.$1, mapped.$2);
    if (mounted) Navigator.pop(context, GameSettingsResult(mapped.$1, mapped.$2));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إعدادات ${_definition.game}'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(controller: _target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد النقاط النهائي')),
            const SizedBox(height: 10),
            for (final f in _definition.fields) _field(f),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: const Text('بدء')),
      ],
    );
  }

  @override
  void dispose() { _target.dispose(); super.dispose(); }
}
