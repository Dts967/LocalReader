import 'package:hive/hive.dart';

import '../utils/chapter_splitter.dart';

part 'book_chapters.g.dart';

/// 一本书的正文与目录。
///
/// 关键设计：正文原文 [content] 一旦导入就不再改动，
/// 目录只记录每章的起始下标 [offsets] 和显示名 [titles]。
/// 这样在目录里"删除"或"改名"都只是动目录，不会破坏原始 txt。
@HiveType(typeId: 3)
class BookChapters extends HiveObject {
  /// 全文纯文本，永不修改
  @HiveField(1)
  String content;

  /// 兼容旧版本数据库：直接切好的正文列表。
  /// 新导入的书不会再用这个字段。
  @HiveField(2)
  List<String> chapters = [];

  /// 每章起始下标
  @HiveField(3)
  List<int> offsets = [];

  /// 目录显示名，可单独编辑
  @HiveField(4)
  List<String> titles = [];

  /// 当前使用的正则，按长度切分时为空
  @HiveField(5)
  String? pattern;

  /// auto / pattern / length / epub
  @HiveField(6)
  String mode = 'auto';

  BookChapters({
    required this.content,
  });

  /// 旧数据（只有 chapters，没有 offsets）
  bool get legacy => offsets.isEmpty;

  int get count => legacy ? chapters.length : offsets.length;

  bool get isEmpty => count == 0;

  /// 第 [index] 章正文
  String chapterContent(int index) {
    if (index < 0) return '';
    if (legacy) {
      return index < chapters.length ? chapters[index] : '';
    }
    if (index >= offsets.length) return '';
    final start = offsets[index];
    final end = index + 1 < offsets.length ? offsets[index + 1] : content.length;
    if (start >= content.length) return '';
    return content.substring(start, end.clamp(start, content.length).toInt());
  }

  /// 第 [index] 章在目录里显示的名字
  String chapterTitle(int index) {
    if (index < 0) return '';
    if (legacy) {
      if (index >= chapters.length) return '';
      final first = chapters[index].trim().split(RegExp(r'\r\n|\r|\n')).first;
      return first.length > 40 ? '${first.substring(0, 40)}…' : first;
    }
    if (index >= titles.length) return '第 ${index + 1} 章';
    return titles[index];
  }

  int chapterLength(int index) => chapterContent(index).length;

  int get totalLength => content.length;

  /// 应用一次分章结果（导入时或重新分章时）
  void applySplit(ChapterSplit split) {
    offsets = List<int>.from(split.offsets);
    titles = List<String>.from(split.titles);
    pattern = split.pattern;
    mode = split.mode;
    chapters = [];
    if (offsets.isEmpty) {
      offsets = [0];
      titles = ['开始'];
    }
  }

  /// 从目录里删掉一章。
  ///
  /// 只是移除下标：它的正文会自动并入上一章（首章则并入下一章），
  /// 原文 [content] 一个字都不动。
  void removeChapter(int index) {
    if (index < 0) return;
    if (legacy) {
      if (index < chapters.length) chapters.removeAt(index);
      return;
    }
    if (index >= offsets.length) return;
    if (index == 0 && offsets.length > 1) {
      // 首章内容并到下一章，避免开头那段没人认领
      offsets[1] = 0;
    }
    offsets.removeAt(index);
    if (index < titles.length) titles.removeAt(index);
  }

  /// 只改目录里显示的名字，不动正文
  void renameChapter(int index, String title) {
    if (legacy) return;
    if (index < 0 || index >= titles.length) return;
    titles[index] = title.trim().isEmpty ? titles[index] : title.trim();
  }

  /// 把当前目录导出成 ChapterSplit，方便预览页二次编辑
  ChapterSplit toSplit() {
    return ChapterSplit(
      offsets: List<int>.from(legacy ? <int>[0] : offsets),
      titles: List<String>.from(legacy ? <String>['开始'] : titles),
      pattern: pattern,
      mode: legacy ? 'length' : mode,
    );
  }
}
