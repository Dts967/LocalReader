import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'reader_settings.g.dart';

/// 阅读器设置，全局一份，存在 settings 盒子的 'defaults' 键下
@HiveType(typeId: 1)
class ReaderSettings {
  @HiveField(0)
  double fontSize;

  @HiveField(1)
  double lineHeight;

  /// 0 跟随系统 / 1 浅色 / 2 深色
  @HiveField(2)
  int themeMode;

  /// 是否使用 Android 12+ 的壁纸动态取色
  @HiveField(3)
  bool dynamicColor;

  /// 动态色不可用时的备选种子色索引
  @HiveField(4)
  int seedIndex;

  ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.themeMode = 0,
    this.dynamicColor = true,
    this.seedIndex = 0,
  });

  ThemeMode get theme => switch (themeMode) {
        1 => ThemeMode.light,
        2 => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

/// 备选种子色，动态取色关闭时用
const List<int> kSeedColors = <int>[
  0xFF6750A4, // 紫（M3 基准）
  0xFF3D6CB3, // 蓝
  0xFF00695C, // 青绿
  0xFF8A4A2F, // 棕
  0xFF7A4C9E, // 紫罗兰
  0xFFB3261E, // 红
];
