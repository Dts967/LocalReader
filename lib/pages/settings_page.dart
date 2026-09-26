import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reader_settings.dart';

/// 外观设置：主题模式、动态取色、备选种子色，顺手也能调字号行距
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Box<ReaderSettings> box;
  late ReaderSettings setting;

  @override
  void initState() {
    super.initState();
    box = Hive.box<ReaderSettings>('settings');
    setting = box.get('defaults') ?? ReaderSettings();
  }

  void _save() {
    box.put('defaults', setting);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('主题', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('跟随系统'), icon: Icon(Icons.brightness_auto)),
              ButtonSegment<int>(value: 1, label: Text('浅色'), icon: Icon(Icons.light_mode)),
              ButtonSegment<int>(value: 2, label: Text('深色'), icon: Icon(Icons.dark_mode)),
            ],
            selected: {setting.themeMode.clamp(0, 2).toInt()},
            onSelectionChanged: (s) {
              setting.themeMode = s.first;
              _save();
            },
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用壁纸动态取色'),
            subtitle: const Text('Android 12+ 从壁纸取色，关闭则用下面的固定配色'),
            value: setting.dynamicColor,
            onChanged: (v) {
              setting.dynamicColor = v;
              _save();
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            '固定配色',
            style: theme.textTheme.titleSmall?.copyWith(
              color: setting.dynamicColor
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(kSeedColors.length, (index) {
              final color = Color(kSeedColors[index]);
              final selected = setting.seedIndex == index;
              return InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  setting.seedIndex = index;
                  _save();
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('字体大小'),
            subtitle: Slider(
              value: setting.fontSize.clamp(12.0, 32.0).toDouble(),
              min: 12,
              max: 32,
              divisions: 20,
              label: setting.fontSize.round().toString(),
              onChanged: (v) {
                setting.fontSize = v;
                _save();
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('行间距'),
            subtitle: Slider(
              value: setting.lineHeight.clamp(1.0, 3.0).toDouble(),
              min: 1.0,
              max: 3.0,
              divisions: 20,
              label: setting.lineHeight.toStringAsFixed(1),
              onChanged: (v) {
                setting.lineHeight = v;
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }
}
