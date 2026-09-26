import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/book.dart';
import '../models/book_chapters.dart';
import '../widgets/book_cover.dart';

/// 书籍信息：epub 的元数据（作者 / 简介 / 封面）都在这里看
class BookInfoPage extends StatelessWidget {
  final Book book;

  const BookInfoPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chapters = Hive.box<BookChapters>('book_chapters').get(book.key);
    final count = chapters?.count ?? 0;
    final chars = chapters?.totalLength ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('书籍信息')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                height: 152,
                child: BookCover(book: book, radius: 12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (book.author.isNotEmpty)
                      Text(
                        book.author,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 6),
                    _ChipRow(book: book),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (book.description.isNotEmpty) ...[
            Text('简介', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              book.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Divider(height: 1),
          const SizedBox(height: 8),
          _InfoTile(label: '文件格式', value: book.isEpub ? 'EPUB' : 'TXT'),
          _InfoTile(label: '章节数', value: '$count 章'),
          _InfoTile(label: '总字数', value: _formatChars(chars)),
          _InfoTile(
            label: '分章方式',
            value: _splitLabel(chapters),
          ),
          _InfoTile(
            label: '源文件',
            value: book.filePath.isEmpty ? '（未记录）' : book.filePath,
            mono: true,
          ),
          const SizedBox(height: 12),
          if (book.lastReadTime != null)
            _InfoTile(
              label: '上次阅读',
              value: book.lastReadTime.toString().substring(0, 16),
            ),
        ],
      ),
    );
  }

  String _splitLabel(BookChapters? chapters) {
    if (chapters == null) return '未知';
    return switch (chapters.mode) {
      'epub' => 'EPUB 自带目录',
      'length' => '按长度切分',
      'pattern' => '自定义正则',
      _ => '自动识别',
    };
  }

  String _formatChars(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)} 万字';
    return '$n 字';
  }
}

class _ChipRow extends StatelessWidget {
  final Book book;

  const _ChipRow({required this.book});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text(book.isEpub ? 'EPUB' : 'TXT'),
          avatar: Icon(
            book.isEpub ? Icons.auto_stories : Icons.article_outlined,
            size: 16,
          ),
        ),
        if (book.lastReadTime != null)
          const Chip(
            visualDensity: VisualDensity.compact,
            label: Text('读过'),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _InfoTile({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
