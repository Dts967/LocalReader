import 'package:flutter/material.dart';

import '../utils/chapter_splitter.dart';

/// 分章预览页。
///
/// 导入新书或重新分章时都走这里：
/// 先看自动识别的结果，不满意就换预置格式，还不行就自己写正则，
/// 列表实时刷新，确认后才写入数据库。
class ChapterPreviewPage extends StatefulWidget {
  /// 全书纯文本
  final String content;

  /// 初始分章结果（导入时是自动检测的，重新分章时是当前的）
  final ChapterSplit initial;

  /// 标题栏显示的书名
  final String bookTitle;

  const ChapterPreviewPage({
    super.key,
    required this.content,
    required this.initial,
    this.bookTitle = '',
  });

  @override
  State<ChapterPreviewPage> createState() => _ChapterPreviewPageState();
}

class _ChapterPreviewPageState extends State<ChapterPreviewPage> {
  late ChapterSplit _split;
  late TextEditingController _regexController;
  String _ruleId = 'auto';
  String? _error;
  bool _computing = false;

  /// 'auto' 自动 / 具体规则 id / 'custom' 自定义
  static const String kAuto = 'auto';
  static const String kCustom = 'custom';

  @override
  void initState() {
    super.initState();
    _split = widget.initial;
    _ruleId = widget.initial.ruleId ??
        (widget.initial.mode == 'length'
            ? kAuto
            : (widget.initial.pattern == null ? kAuto : kCustom));
    _regexController = TextEditingController(text: widget.initial.pattern ?? '');
  }

  @override
  void dispose() {
    _regexController.dispose();
    super.dispose();
  }

  Future<void> _applyRule(String id) async {
    setState(() {
      _ruleId = id;
      _error = null;
      _computing = true;
    });
    await Future<void>.delayed(Duration.zero);

    ChapterSplit result;
    if (id == kAuto) {
      result = autoDetectChapters(widget.content);
      if (result.pattern != null) {
        _regexController.text = result.pattern!;
      }
    } else if (id == kCustom) {
      final text = _regexController.text.trim();
      if (text.isEmpty) {
        setState(() {
          _computing = false;
          _error = '正则不能为空';
        });
        return;
      }
      try {
        RegExp(text, multiLine: true, caseSensitive: false);
      } catch (e) {
        setState(() {
          _computing = false;
          _error = '正则无效：$e';
        });
        return;
      }
      result = splitByPattern(widget.content, text, mode: 'pattern');
      if (result.count <= 1) {
        setState(() {
          _computing = false;
          _split = result;
          _error = '这个正则没匹配到任何章节，换一个试试';
        });
        return;
      }
    } else {
      final rule = kPresetRules.firstWhere(
        (r) => r.id == id,
        orElse: () => kPresetRules.first,
      );
      _regexController.text = rule.pattern;
      result = splitByPattern(widget.content, rule.pattern, ruleId: rule.id, mode: 'pattern');
    }

    if (!mounted) return;
    setState(() {
      _split = result;
      _computing = false;
    });
  }

  String get _modeLabel {
    return switch (_split.mode) {
      'length' => '按长度切分（没识别出章节格式）',
      'epub' => 'EPUB 自带目录',
      'auto' => '自动识别',
      _ => '自定义正则',
    };
  }

  ChapterRule? get _currentRule {
    if (_split.ruleId == null) return null;
    for (final r in kPresetRules) {
      if (r.id == _split.ruleId) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rule = _currentRule;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bookTitle.isEmpty ? '分章预览' : '分章预览 · ${widget.bookTitle}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          _buildRuleBar(context, colorScheme),
          if (rule != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '示例：${rule.sample}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _regexController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '章节标题正则',
                hintText: '留空点“自动识别”让它自己猜',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _applyRule(kCustom),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilledButton.tonal(
                  onPressed: () => _applyRule(kCustom),
                  child: const Text('应用正则'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _applyRule(kAuto),
                  child: const Text('自动识别'),
                ),
                const Spacer(),
                Text(
                  '${_split.count} 章',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _modeLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _computing
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _split.count,
                    itemBuilder: (context, index) => _ChapterTile(
                      index: index,
                      title: index < _split.titles.length
                          ? _split.titles[index]
                          : '第 ${index + 1} 章',
                      length: _chapterLength(index),
                    ),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                  ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  int _chapterLength(int index) {
    if (index >= _split.offsets.length) return 0;
    final start = _split.offsets[index];
    final end = index + 1 < _split.offsets.length
        ? _split.offsets[index + 1]
        : widget.content.length;
    return (end - start).clamp(0, widget.content.length).toInt();
  }

  Widget _buildRuleBar(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _RuleChip(
            label: '自动识别',
            selected: _ruleId == kAuto,
            onSelected: () => _applyRule(kAuto),
          ),
          const SizedBox(width: 8),
          ...kPresetRules.map(
            (r) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _RuleChip(
                label: r.name,
                selected: _ruleId == r.id,
                onSelected: () => _applyRule(r.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _split.count == 0
                    ? null
                    : () => Navigator.pop(context, _split),
                child: const Text('就用这个'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _RuleChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final int index;
  final String title;
  final int length;

  const _ChapterTile({
    required this.index,
    required this.title,
    required this.length,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 40,
        child: Text(
          '${index + 1}',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.end,
        ),
      ),
      title: Text(
        title.isEmpty ? '（无标题）' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '$length 字',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
