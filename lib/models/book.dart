import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'book.g.dart';

/// 书架里的一本书。
///
/// 只存索引信息，正文在 BookChapters 里按 book.key 对应存放。
@HiveType(typeId: 0)
class Book extends HiveObject with ChangeNotifier {
  @HiveField(0)
  final String title;

  @HiveField(1)
  int lastReadChapterIndex = 0;

  @HiveField(2)
  int lastReadPosition = 0;

  @HiveField(3)
  DateTime? lastReadTime;

  /// 源文件路径（txt / epub），重新导入或查看信息时用
  @HiveField(4)
  String filePath = '';

  /// 'txt' 或 'epub'
  @HiveField(5)
  String sourceType = 'txt';

  /// 作者，epub 从 dc:creator 读，txt 一般为空
  @HiveField(6)
  String author = '';

  /// 简介，epub 从 dc:description 读
  @HiveField(7)
  String description = '';

  /// 封面图缓存路径，空表示用书名生成的占位封面
  @HiveField(8)
  String? coverPath;

  Book({
    required this.title,
    String filePath = '',
    String sourceType = 'txt',
    String author = '',
    String description = '',
    String? coverPath,
  }) {
    this.filePath = filePath;
    this.sourceType = sourceType;
    this.author = author;
    this.description = description;
    this.coverPath = coverPath;
    lastReadTime = null;
  }

  bool get isEpub => sourceType == 'epub';

  /// 目录里显示的副标题
  String get subtitle => author.isEmpty ? (isEpub ? 'EPUB' : 'TXT') : author;

  void updateLastReadTime() {
    lastReadTime = DateTime.now();
    save();
  }

  void updateLastReadPosition(int index) {
    lastReadPosition = index;
    updateLastReadTime();
  }

  void previousChapter() {
    lastReadPosition = -1;
    lastReadChapterIndex--;
    updateLastReadTime();
    notifyListeners();
  }

  void nextChapter() {
    lastReadPosition = 0;
    lastReadChapterIndex++;
    updateLastReadTime();
    notifyListeners();
  }

  void updateLastReadChapterIndex(int index) {
    lastReadPosition = 0;
    lastReadChapterIndex = index;
    updateLastReadTime();
    notifyListeners();
  }
}
