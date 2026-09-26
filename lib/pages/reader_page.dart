import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/book.dart';
import '../models/book_chapters.dart';
import '../models/reader_settings.dart';
import '../utils/chapter_splitter.dart';
import '../utils/text.dart';
import '../widgets/text_page.dart';
import 'book_info_page.dart';
import 'chapter_preview_page.dart';

class ReaderPage extends StatefulWidget {
  final Book book;

  const ReaderPage({super.key, required this.book});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  late Box<Book> bookBox;
  late Box<BookChapters> chaptersBox;
  late Box<ReaderSettings> settingsBox;
  List<String> pages = const [];
  late AnimationController _controller;
  late BookChapters chapters;
  PageController? pageController;
  ReaderSettings? setting;
  ValueNotifier<bool> showSetting = ValueNotifier(false);
  ValueNotifier<double> sliderVal = ValueNotifier(0);
  int nowPage = 0;

  @override
  void initState() {
    super.initState();
    settingsBox = Hive.box<ReaderSettings>('settings');
    bookBox = Hive.box<Book>('books');
    chaptersBox = Hive.box<BookChapters>('book_chapters');
    chapters = chaptersBox.get(widget.book.key)!;

    _controller =
        AnimationController(vsync: this, duration: kThemeChangeDuration);
    setting = settingsBox.get('defaults');
  }

  @override
  void dispose() {
    _controller.dispose();
    pageController?.dispose();
    super.dispose();
  }

  TextStyle getTextStyle(BuildContext context) {
    return TextTheme.of(context).bodyMedium!.copyWith(
          fontSize: setting?.fontSize,
          height: setting?.lineHeight,
          inherit: false,
        );
  }

  String get nowChapterTitle =>
      chapters.chapterTitle(widget.book.lastReadChapterIndex);

  @override
  Widget build(BuildContext context) {
    final index = widget.book.lastReadChapterIndex.clamp(0, chapters.count - 1).toInt();

    return Scaffold(
      endDrawer: ChapterDrawer(
        chapters: chapters,
        nowChapter: index,
        onChapterChange: (i) {
          widget.book.updateLastReadChapterIndex(i);
        },
        onCatalogChanged: () async {
          await chapters.save();
          if (mounted) setState(() {});
        },
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => FutureBuilder(
                future: TextUtils.loadPages(
                  chapters.chapterContent(index),
                  getTextStyle(context),
                  constraints.maxWidth - 16,
                  constraints.maxHeight - 16,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    pages = snapshot.data!;

                    nowPage = 0;
                    if (widget.book.lastReadPosition < 0) {
                      var pos = 0;
                      for (var i = 0; i < pages.length - 1; i++) {
                        pos += pages[i].length;
                      }
                      nowPage = pages.length - 1;
                      widget.book.lastReadPosition = pos;
                    } else {
                      var pos = 0;
                      for (final page in pages) {
                        if (pos + page.length > widget.book.lastReadPosition) {
                          break;
                        }
                        pos += page.length;
                        nowPage++;
                      }
                    }
                    if (nowPage >= pages.length) nowPage = pages.length - 1;
                    if (nowPage < 0) nowPage = 0;

                    pageController = PageController(
                      initialPage: nowPage,
                    );

                    return TextPage(
                      key: UniqueKey(),
                      pageController: pageController,
                      pages: pages,
                      parentConstraints: constraints,
                      textStyle: getTextStyle(context),
                      onPageChange: (i) {
                        nowPage = i;
                        updateSliderVal();

                        var pos = 0;
                        for (var j = 0; j < i; j++) {
                          pos += pages[j].length;
                        }
                        widget.book.updateLastReadPosition(pos);
                      },
                      previousChapter: () {
                        if (widget.book.lastReadChapterIndex > 0) {
                          widget.book.previousChapter();
                        }
                      },
                      nextChapter: () {
                        if (widget.book.lastReadChapterIndex <
                            chapters.count - 1) {
                          widget.book.nextChapter();
                        }
                      },
                      onOpenSetting: () {
                        updateSliderVal();
                        showSetting.value = !showSetting.value;
                      },
                    );
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                },
              ),
            ),
            ListenableBuilder(
              listenable: showSetting,
              builder: (context, _) {
                if (showSetting.value) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
                return FadeTransition(
                  opacity: _controller,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppBar(
                        title: Text(
                          nowChapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        actions: [
                          IconButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                showDragHandle: true,
                                builder: (context) => SettingPanel(
                                  book: widget.book,
                                  chapters: chapters,
                                  onResplit: _resplit,
                                ),
                              );
                            },
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ],
                      ),
                      BottomAppBar(
                        child: ListenableBuilder(
                          listenable: sliderVal,
                          builder: (context, _) => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text("${sliderVal.value.toInt()}%"),
                              Expanded(
                                child: Slider(
                                  min: 0,
                                  max: 100,
                                  value: sliderVal.value.clamp(0.0, 100.0).toDouble(),
                                  onChanged: (value) {
                                    if (pages.isEmpty) return;
                                    sliderVal.value = value;
                                    pageController?.jumpToPage(
                                      (value / 100 * (pages.length - 1))
                                          .toInt(),
                                    );
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  Scaffold.of(context).openEndDrawer();
                                },
                                icon: const Icon(Icons.list),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resplit() async {
    final split = await Navigator.push<ChapterSplit>(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterPreviewPage(
          content: chapters.content,
          initial: chapters.toSplit(),
          bookTitle: widget.book.title,
        ),
      ),
    );
    if (split == null) return;
    chapters.applySplit(split);
    await chapters.save();
    widget.book
      ..lastReadChapterIndex = 0
      ..lastReadPosition = 0;
    await widget.book.save();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已重新分章，共 ${chapters.count} 章')),
    );
  }

  void updateSliderVal() {
    if (pages.length <= 1) {
      sliderVal.value = 0;
      return;
    }
    sliderVal.value = nowPage / (pages.length - 1) * 100;
  }
}

/// 目录抽屉。
///
/// 点一下跳章，长按弹出菜单：改目录里显示的名字，或把这一章从目录里删掉。
/// 两个操作都只动目录，不碰原始文件。
class ChapterDrawer extends StatelessWidget {
  final BookChapters chapters;
  final int nowChapter;
  final ValueChanged<int>? onChapterChange;
  final Future<void> Function()? onCatalogChanged;

  ChapterDrawer({
    super.key,
    required this.chapters,
    required this.nowChapter,
    this.onChapterChange,
    this.onCatalogChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '目录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${chapters.count} 章',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '长按可编辑',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  itemCount: chapters.count,
                  itemBuilder: (context, index) {
                    final selected = index == nowChapter;
                    return ListTile(
                      dense: true,
                      selected: selected,
                      title: Text(
                        chapters.chapterTitle(index),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        onChapterChange?.call(index);
                        Navigator.pop(context);
                      },
                      onLongPress: () => _showChapterMenu(context, index),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChapterMenu(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                chapters.chapterTitle(index),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('第 ${index + 1} 章 · ${chapters.chapterLength(index)} 字'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑显示名称'),
              onTap: () {
                Navigator.pop(context);
                _renameChapter(context, index);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text(
                '从目录删除（不改动原文）',
                style: TextStyle(color: scheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteChapter(context, index);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _renameChapter(BuildContext context, int index) async {
    final controller =
        TextEditingController(text: chapters.chapterTitle(index));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑章节名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '名称',
            helperText: '只改目录里显示的名字，正文不受影响',
            helperMaxLines: 2,
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null) return;
    chapters.renameChapter(index, name);
    await onCatalogChanged?.call();
  }

  Future<void> _deleteChapter(BuildContext context, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('删除这一章'),
        content: const Text(
          '只会从目录里移除，正文会并进相邻章节，\n原始文件不会被修改。',
        ),
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
    if (confirmed != true) return;
    chapters.removeChapter(index);
    await onCatalogChanged?.call();
  }
}

class SettingPanel extends StatefulWidget {
  final Book book;
  final BookChapters chapters;
  final Future<void> Function()? onResplit;

  const SettingPanel({
    super.key,
    required this.chapters,
    required this.book,
    this.onResplit,
  });

  @override
  State<SettingPanel> createState() => _SettingPanelState();
}

class _SettingPanelState extends State<SettingPanel> {
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
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('字体大小'),
            subtitle: Slider(
              value: setting.fontSize.clamp(12.0, 32.0).toDouble(),
              min: 12,
              max: 32,
              divisions: 20,
              label: setting.fontSize.round().toString(),
              onChanged: (double fontSize) {
                setting.fontSize = fontSize;
                _save();
              },
            ),
          ),
          ListTile(
            title: const Text('行间距'),
            subtitle: Slider(
              value: setting.lineHeight.clamp(1.0, 3.0).toDouble(),
              min: 1.0,
              max: 3.0,
              divisions: 20,
              label: setting.lineHeight.toStringAsFixed(1),
              onChanged: (double lineHeight) {
                setting.lineHeight = lineHeight;
                _save();
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.segment),
            title: const Text('重新分章'),
            subtitle: Text(
              '当前 ${widget.chapters.count} 章，可换识别格式或自定义正则',
            ),
            onTap: () {
              Navigator.pop(context);
              widget.onResplit?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('书籍信息'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookInfoPage(book: widget.book),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
