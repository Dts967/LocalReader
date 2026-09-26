import 'dart:math' as math;

/// 一条分章规则。
///
/// [pattern] 用于匹配"章节标题所在行"，统一以多行模式使用，
/// 因此规则里可以安全地用 ^ 定位行首。
class ChapterRule {
  /// 唯一标识，自动检测结果里用来回显给用户
  final String id;

  /// 展示名
  final String name;

  /// 正则
  final String pattern;

  /// 命中示例，预览界面里给用户看
  final String sample;

  ChapterRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.sample,
  });
}

/// 中文数字（含大小写）与阿拉伯数字
const String _num =
    r'0-9零一二三四五六七八九十百千万两壹贰叁肆伍陆柒捌玖拾佰仟';

/// 标题允许出现的空白（含全角空格）
const String _sp = r'[ \t　]*';

/// 预置的常用分章格式，会自动挑一个最合适的。
/// 用户不满意时可以在预览页手动切换或自己写正则。
final List<ChapterRule> kPresetRules = <ChapterRule>[
  ChapterRule(
    id: 'cn_unit',
    name: '第X章 / 第 X 章（最常用）',
    pattern: r'^' + _sp + r'第' + _sp + r'[' + _num + r']{1,12}' + _sp +
        r'[章节回集卷篇部]' + _sp + r'[^\n]{0,40}',
    sample: '第一章 初入江湖 / 第 1024 章 飞升 / 第二十回',
  ),
  ChapterRule(
    id: 'cn_no_unit',
    name: '第X / 第 X（无章节单位）',
    pattern: r'^' + _sp + r'第' + _sp + r'[' + _num + r']{1,12}' + _sp +
        r'[、.．,，:：]?' + _sp + r'[^\n]{0,40}',
    sample: '第一百二十三 雪山 / 第88、意外',
  ),
  ChapterRule(
    id: 'zhang_first',
    name: '章X / 节X（章字在前）',
    pattern: r'^' + _sp + r'[章节回]' + _sp + r'[' + _num + r']{1,12}' + _sp +
        r'[^\n]{0,40}',
    sample: '章一 起始 / 节3 转折',
  ),
  ChapterRule(
    id: 'num_zhang',
    name: '1章 / 12章（数字加章）',
    pattern: r'^' + _sp + r'[0-9]{1,7}' + _sp + r'[章节回]' + _sp + r'[^\n]{0,40}',
    sample: '1章 开始 / 256章',
  ),
  ChapterRule(
    id: 'num_dot',
    name: '1. / 1、/ 001.（数字序号）',
    pattern: r'^' + _sp + r'[0-9]{1,7}' + _sp + r'[、.．,，]' + _sp + r'[^\n]{0,40}',
    sample: '1. 初入江湖 / 12、突变',
  ),
  ChapterRule(
    id: 'num_line',
    name: '纯数字行',
    pattern: r'^' + _sp + r'[0-9]{1,7}' + _sp + r'$',
    sample: '1\n2\n123',
  ),
  ChapterRule(
    id: 'juan',
    name: '卷X / 卷 X',
    pattern: r'^' + _sp + r'卷' + _sp + r'[' + _num + r']{1,12}' + _sp +
        r'[^\n]{0,40}',
    sample: '卷一 少年 / 卷三',
  ),
  ChapterRule(
    id: 'bracket',
    name: '（一） / [12] / 【三】',
    pattern: r'^' + _sp + r'[（(【\[]' + _sp + r'[' + _num + r']{1,12}' + _sp +
        r'[)）】\]]' + _sp + r'[^\n]{0,40}',
    sample: '（一）初见 / 【12】决战',
  ),
  ChapterRule(
    id: 'en_chapter',
    name: 'Chapter 1 / Part II（英文）',
    pattern: r'^' + _sp + r'(chapter|chap|part|volume|book|section)' + _sp +
        r'[0-9ivxlcIVXLC]{1,7}' + _sp + r'[^\n]{0,60}',
    sample: 'Chapter 1 / Part II',
  ),
  ChapterRule(
    id: 'special',
    name: '序章 / 楔子 / 番外 等',
    pattern: r'^' + _sp +
        r'(序章|序言|楔子|引子|前言|后记|尾声|终章|番外|外传|结语|自序|附录)' + _sp +
        r'[^\n]{0,40}',
    sample: '序章 / 楔子 / 番外 十年后',
  ),
];

/// 分章结果。只记录每一章在原文里的起始下标，正文永远不复制、不改动，
/// 所以删除/重命名目录项都不会破坏原始 txt。
class ChapterSplit {
  /// 每章起始字符下标，升序，第一章固定为 0
  final List<int> offsets;

  /// 每章在目录里显示的名字
  final List<String> titles;

  /// 使用的正则；按长度切分时为空
  final String? pattern;

  /// 规则 id；自定义正则时为 null
  final String? ruleId;

  /// 切分方式：auto / pattern / length / epub
  final String mode;

  const ChapterSplit({
    required this.offsets,
    required this.titles,
    this.pattern,
    this.ruleId,
    this.mode = 'auto',
  });

  int get count => offsets.length;

  ChapterSplit copyWith({
    List<int>? offsets,
    List<String>? titles,
    String? pattern,
    String? ruleId,
    String? mode,
  }) {
    return ChapterSplit(
      offsets: offsets ?? this.offsets,
      titles: titles ?? this.titles,
      pattern: pattern ?? this.pattern,
      ruleId: ruleId ?? this.ruleId,
      mode: mode ?? this.mode,
    );
  }
}

/// 两个标题之间允许的最短距离，短于此值多半是误判（比如正文里恰好出现的数字行）
const int kMinChapterGap = 30;

/// 按给定正则切分章节。
///
/// 返回的 offsets 一定以 0 开头，保证开头到第一个标题之间的内容不会丢。
ChapterSplit splitByPattern(
  String content,
  String pattern, {
  String? ruleId,
  String mode = 'pattern',
}) {
  final List<int> offsets = <int>[];
  final List<String> titles = <String>[];

  RegExp regex;
  try {
    regex = RegExp(pattern, multiLine: true, caseSensitive: false);
  } catch (_) {
    return splitByLength(content);
  }

  for (final m in regex.allMatches(content)) {
    // 上一章太短，认为是误判，保留前一个标题
    if (offsets.isNotEmpty && m.start - offsets.last < kMinChapterGap) {
      continue;
    }
    offsets.add(m.start);
    titles.add(_cleanTitle(m.group(0)));
  }

  if (offsets.isEmpty || offsets.first != 0) {
    offsets.insert(0, 0);
    titles.insert(0, _firstLineTitle(content, offsets.length > 1 ? offsets[1] : content.length));
  }
  return ChapterSplit(
    offsets: offsets,
    titles: titles,
    pattern: pattern,
    ruleId: ruleId,
    mode: mode,
  );
}

/// 自动检测：把预置规则全试一遍，挑得分最高的。
ChapterSplit autoDetectChapters(String content) {
  ChapterSplit? best;
  double bestScore = 0;

  for (final rule in kPresetRules) {
    final split = splitByPattern(content, rule.pattern, ruleId: rule.id, mode: 'auto');
    final score = _score(content, split);
    if (score > bestScore) {
      bestScore = score;
      best = split;
    }
  }

  if (best == null || bestScore <= 0.05) {
    return splitByLength(content);
  }
  return best;
}

/// 评分：章节数够多 + 单章长度合理 + 标题不太长 + 第一刀不能太靠后
double _score(String content, ChapterSplit split) {
  final n = split.offsets.length;
  if (n < 3) return 0;

  final avgLen = content.length / n;
  double lenScore;
  if (avgLen >= 500 && avgLen <= 20000) {
    lenScore = 1.0;
  } else if (avgLen < 500) {
    lenScore = avgLen / 500;
  } else {
    lenScore = 20000 / avgLen;
  }

  var titleLen = 0;
  for (final t in split.titles) {
    titleLen += t.length;
  }
  final avgTitle = titleLen / n;
  final titleScore = avgTitle <= 30 ? 1.0 : (30 / avgTitle).clamp(0.05, 1.0).toDouble();

  // 第一个真正命中的标题出现得太晚，说明前面大段没被切到
  final firstHit = n > 1 ? split.offsets[1] : content.length;
  final headScore = firstHit > content.length * 0.25 ? 0.3 : 1.0;

  final countScore = math.min(1.0, n / 20.0);

  return lenScore * titleScore * headScore * countScore;
}

/// 兜底：正则全都不好用时按长度切，尽量在段落处断开
ChapterSplit splitByLength(
  String content, {
  int target = 5000,
  int hard = 12000,
}) {
  final List<int> offsets = <int>[0];
  final List<String> titles = <String>['开始'];
  var start = 0;
  var index = 1;

  // 优先在换行处断开，实在没有换行（有些 txt 通篇一行）就到 hard 处硬切
  while (start < content.length) {
    final end = start + target;
    if (end >= content.length) break;

    final limit = math.min(content.length, start + hard);
    final newline = content.indexOf('\n', end);
    final cut = (newline < 0 || newline + 1 > limit) ? limit : newline + 1;

    if (cut <= start || cut >= content.length) break;
    offsets.add(cut);
    titles.add('第 $index 段');
    index++;
    start = cut;
  }
  return ChapterSplit(
    offsets: offsets,
    titles: titles,
    mode: 'length',
    pattern: null,
  );
}

String _cleanTitle(String? raw) {
  if (raw == null) return '未命名';
  var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return '未命名';
  if (t.length > 40) t = '${t.substring(0, 40)}…';
  return t;
}

String _firstLineTitle(String content, int end) {
  final head = content.substring(0, end.clamp(0, content.length).toInt());
  for (final line in head.split(RegExp(r'\r\n|\r|\n'))) {
    final t = line.trim();
    if (t.isNotEmpty) {
      return t.length > 20 ? '${t.substring(0, 20)}…' : t;
    }
  }
  return '开始';
}
