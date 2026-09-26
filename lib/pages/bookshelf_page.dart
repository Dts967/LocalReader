import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/book_chapters.dart';
import '../models/reader_settings.dart';
import '../pages/reader_page.dart';
import '../utils/chapter_splitter.dart';
import '../utils/epub_parser.dart';
import '../utils/file_decoder.dart';
import '../widgets/book_cover.dart';
import 'book_info_page.dart';
import 'chapter_preview_page.dart';
import 'settings_page.dart';

class BookShelfPage extends StatefulWidget {
  const BookShelfPage({super.key});

  @override
  State<BookShelfPage> createState() => _BookShelfPageState();
}

class _BookShelfPageState extends State<BookShelfPage> {
  late Box<Book> box;
  late Box<BookChapters> chaptersBox;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    box = Hive.box<Book>('books');
    chaptersBox = Hive.box<BookChapters>('book_chapters');
  }

  List<Book> get books {
    final bookList = box.values.toList()
      ..sort((a, b) {
        if (a.lastReadTime == null && b.lastReadTime == null) return 0;
        if (a.lastReadTime == null) return 1;
        if (b.lastReadTime == null) return -1;
        return b.lastReadTime!.compareTo(a.lastReadTime!);
      });
    return bookList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          IconButton(
            tooltip: '外观设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => importBook(),
        tooltip: '导入本地小说',
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Book> _, __) {
          final list = books;
          if (list.isEmpty) {
            return _EmptyShelf(onImport: importBook);
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final book = list[index];
              final chapters = chaptersBox.get(book.key);
              return _BookCard(
                book: book,
                chapterCount: chapters?.count ?? 0,
                onTap: () => _openBook(context, book),
                onLongPress: () => _showBookMenu(context, book),
              );
            },
          );
        },
      ),
    );
  }

  void _openBook(BuildContext context, Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListenableBuilder(
          listenable: Listenable.merge(
            [
              book,
              Hive.box<ReaderSettings>('settings').listenable(),
              Hive.box<BookChapters>('book_chapters').listenable(),
            ],
          ),
          builder: (context, _) => ReaderPage(
            key: UniqueKey(),
            book: book,
          ),
        ),
      ),
    );
  }

  void _showBookMenu(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(book.subtitle),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('书籍信息'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookInfoPage(book: book)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.segment),
              title: const Text('重新分章'),
              onTap: () {
                Navigator.pop(context);
                _resplitBook(book);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '从书架删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteBook(context, book);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _resplitBook(Book book) async {
    final chapters = chaptersBox.get(book.key);
    if (chapters == null) return;

    final split = await Navigator.push<ChapterSplit>(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterPreviewPage(
          content: chapters.content,
          initial: chapters.toSplit(),
          bookTitle: book.title,
        ),
      ),
    );
    if (split == null) return;

    chapters.applySplit(split);
    await chapters.save();
    book
      ..lastReadChapterIndex = 0
      ..lastReadPosition = 0;
    await book.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重新分章，共 ${chapters.count} 章')),
    );
  }

  Future<void> importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub'],
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final fileName = result.files.single.name;
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();

    if (ext != 'txt' && ext != 'epub') {
      _snack('只支持 .txt 和 .epub');
      return;
    }

    _loading = true;
    _showLoading('正在解析…');

    try {
      final bytes = await File(path).readAsBytes();
      late String content;
      Uint8List? cover;
      String author = '';
      String description = '';
      String? metaTitle;
      ChapterSplit initial;

      if (ext == 'epub') {
        final parsed = await parseEpub(Uint8List.fromList(bytes));
        content = parsed.content;
        cover = parsed.meta.cover;
        author = parsed.meta.author ?? '';
        description = parsed.meta.description ?? '';
        metaTitle = parsed.meta.title;
        initial = ChapterSplit(
          offsets: parsed.offsets,
          titles: parsed.titles,
          mode: 'epub',
        );
      } else {
        content = decodeTextBytes(Uint8List.fromList(bytes));
        initial = autoDetectChapters(content);
      }

      if (!mounted) return;
      _hideLoading();

      final split = await Navigator.push<ChapterSplit>(
        context,
        MaterialPageRoute(
          builder: (_) => ChapterPreviewPage(
            content: content,
            initial: initial,
            bookTitle: fileName,
          ),
        ),
      );
      if (split == null) return;

      final title = (metaTitle != null && metaTitle.trim().isNotEmpty)
          ? metaTitle.trim()
          : _nameWithoutExt(fileName);

      final book = Book(
        title: title,
        filePath: path,
        sourceType: ext,
        author: author,
        description: description,
      );
      await box.add(book);

      if (cover != null) {
        final coverPath = await _saveCover(book.key, cover);
        if (coverPath != null) {
          book.coverPath = coverPath;
          await book.save();
        }
      }

      final chapters = BookChapters(content: content)..applySplit(split);
      await chaptersBox.put(book.key, chapters);

      if (!mounted) return;
      _snack('已导入《${book.title}》，共 ${chapters.count} 章');
    } catch (e) {
      if (!mounted) return;
      _hideLoading();
      _snack('导入失败：$e');
    }
  }

  void _hideLoading() {
    if (!_loading) return;
    _loading = false;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<String?> _saveCover(dynamic key, Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'covers', '$key.img'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  void _showLoading(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _deleteBook(BuildContext context, Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('删除书籍'),
        content: Text('确定要从书架移除《${book.title}》吗？\n本地源文件不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (book.coverPath != null) {
        try {
          final f = File(book.coverPath!);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      await chaptersBox.delete(book.key);
      await book.delete();
    }
  }
}

String _nameWithoutExt(String fileName) {
  final i = fileName.lastIndexOf('.');
  return i <= 0 ? fileName : fileName.substring(0, i);
}

class _BookCard extends StatelessWidget {
  final Book book;
  final int chapterCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookCard({
    required this.book,
    required this.chapterCount,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String lastRead = '暂未阅读';
    if (book.lastReadTime != null) {
      lastRead =
          '${DateFormat('MM-dd HH:mm').format(book.lastReadTime!)} 读到第 ${book.lastReadChapterIndex + 1} 章';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: BookCover(book: book, radius: 0),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chapterCount > 0 ? '共 $chapterCount 章' : book.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastRead,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  final VoidCallback onImport;

  const _EmptyShelf({required this.onImport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '书架还是空的',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '导入本地 txt / epub 小说，\n自动分章，离线阅读，没有广告。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('导入小说'),
            ),
          ],
        ),
      ),
    );
  }
}
