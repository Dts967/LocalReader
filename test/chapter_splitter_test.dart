import 'package:flutter_test/flutter_test.dart';
import 'package:local_novel_reader/utils/chapter_splitter.dart';

String _chapter(int n, {int len = 800}) => '第${n}章 标题$n\n${'内容' * len}\n';

void main() {
  group('自动分章', () {
    test('识别「第X章」', () {
      final content = '前言\n\n${_chapter(1)}${_chapter(2)}${_chapter(3)}';
      final split = autoDetectChapters(content);
      expect(split.count, 4); // 含最前面那段
      expect(split.titles[1], '第1章 标题1');
      expect(split.titles[2], '第2章 标题2');
    });

    test('识别带空格的「第 X 章」', () {
      final content = '简介\n\n第 1 章 开端\n${'正文' * 400}\n第 2 章 发展\n${'正文' * 400}\n第 3 章 结局\n${'正文' * 400}\n';
      final split = autoDetectChapters(content);
      expect(split.count, 4);
      expect(split.titles[1], contains('第 1 章'));
    });

    test('识别中文数字', () {
      final body = '${'x' * 600}\n';
      final content = '开篇\n\n第一章 甲\n$body第二章 乙\n$body第三章 丙\n$body';
      final split = autoDetectChapters(content);
      expect(split.count, 4);
      expect(split.titles[3], '第三章 丙');
    });

    test('识别「1. 」数字序号', () {
      final content = '说明\n\n1. 开始\n${'啊' * 600}\n2. 中段\n${'啊' * 600}\n3. 结尾\n${'啊' * 600}\n';
      final split = autoDetectChapters(content);
      expect(split.count, 4);
    });

    test('识别英文 Chapter', () {
      final content = 'Chapter 1 ${'a' * 200}\n\nChapter 2 ${'b' * 200}\n\nChapter 3 ${'c' * 200}\n\nChapter 4 ${'d' * 200}\n';
      final split = autoDetectChapters(content);
      expect(split.count, greaterThanOrEqualTo(4));
    });

    test('毫无格式时按长度兜底', () {
      final content = '没有章节标题的一大段文字' * 2000;
      final split = autoDetectChapters(content);
      expect(split.mode, 'length');
      expect(split.count, greaterThan(1));
    });
  });

  group('自定义正则', () {
    test('按用户正则切分', () {
      final content = '开头\n\nAAA 一\n${'字' * 300}\nAAA 二\n${'字' * 300}\nAAA 三\n${'字' * 300}\n';
      final split = splitByPattern(content, r'^AAA.*$', mode: 'pattern');
      expect(split.count, 4);
      expect(split.titles[1], 'AAA 一');
    });

    test('正则无效时回退按长度切分', () {
      final split = splitByPattern('随便一段文字' * 100, r'([', mode: 'pattern');
      expect(split.mode, 'length');
    });
  });

  test('第一章始终从 0 开始，开头内容不会丢', () {
    final content = '这里是序言\n${_chapter(1)}';
    final split = splitByPattern(content, kPresetRules.first.pattern, mode: 'pattern');
    expect(split.offsets.first, 0);
  });
}
