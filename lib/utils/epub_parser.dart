import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// EPUB 里带出来的元数据
class EpubMeta {
  String? title;
  String? author;
  String? description;

  /// 封面原始字节（jpg/png 都可能）
  Uint8List? cover;

  EpubMeta({this.title, this.author, this.description, this.cover});
}

/// 解析后的书：统一成"全文纯文本 + 每章起始下标 + 目录名"，
/// 后面的分页、目录编辑逻辑跟 txt 完全一致。
class ParsedBook {
  final String content;
  final List<int> offsets;
  final List<String> titles;
  final EpubMeta meta;

  ParsedBook({
    required this.content,
    required this.offsets,
    required this.titles,
    required this.meta,
  });
}

class EpubParseError implements Exception {
  final String message;
  EpubParseError(this.message);

  @override
  String toString() => message;
}

/// 解析一个 epub 文件的字节内容。
///
/// 不依赖第三方 epub 库，直接用 archive 解 zip + xml 读 opf，
/// 依赖少、行为可控。
Future<ParsedBook> parseEpub(Uint8List bytes) async {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw EpubParseError('不是有效的 epub 文件：$e');
  }

  final container = _readText(archive, 'META-INF/container.xml');
  if (container == null) {
    throw EpubParseError('缺少 META-INF/container.xml');
  }

  final opfPath = _findRootFile(container);
  if (opfPath == null) {
    throw EpubParseError('找不到 opf 文件');
  }

  final opfText = _readText(archive, opfPath);
  if (opfText == null) {
    throw EpubParseError('读不到 $opfPath');
  }

  final XmlDocument opf;
  try {
    opf = XmlDocument.parse(opfText);
  } catch (_) {
    throw EpubParseError('opf 解析失败');
  }

  final meta = _readMeta(opf);
  meta.cover = _readCover(archive, opf, _baseDir(opfPath));

  // manifest: id -> href
  final manifest = <String, String>{};
  final mediaTypes = <String, String>{};
  for (final item in opf.findAllElements('item', namespace: '*')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    manifest[id] = href;
    mediaTypes[id] = item.getAttribute('media-type') ?? '';
  }

  // spine 顺序 = 阅读顺序
  final order = <String>[];
  for (final ref in opf.findAllElements('itemref', namespace: '*')) {
    final idref = ref.getAttribute('idref');
    if (idref != null && manifest.containsKey(idref)) {
      order.add(idref);
    }
  }
  if (order.isEmpty) {
    order.addAll(manifest.keys);
  }

  final buffer = StringBuffer();
  final offsets = <int>[];
  final titles = <String>[];
  var seen = 0;

  for (final id in order) {
    final type = mediaTypes[id] ?? '';
    if (!type.contains('html') && !type.contains('xhtml')) {
      // 有些书的 spine 直接指向整个 .xhtml，media-type 可能写成 text/xml
      final href = manifest[id] ?? '';
      if (!(href.endsWith('.html') ||
          href.endsWith('.xhtml') ||
          href.endsWith('.htm'))) {
        continue;
      }
    }
    final href = manifest[id]!;
    final fullPath = _resolve(_baseDir(opfPath), href);
    final html = _readText(archive, fullPath);
    if (html == null) continue;

    final text = htmlToText(html);
    if (text.trim().isEmpty) continue;

    seen++;
    final chapterTitle = _firstNonEmpty(_chapterTitle(html));
    offsets.add(buffer.length);
    titles.add(chapterTitle ?? '第 $seen 节');
    buffer.write(text);
    buffer.write('\n\n');
  }

  if (offsets.isEmpty || offsets.first != 0) {
    offsets.insert(0, 0);
    titles.insert(0, '开始');
  }

  return ParsedBook(
    content: buffer.toString(),
    offsets: offsets,
    titles: titles,
    meta: meta,
  );
}

EpubMeta _readMeta(XmlDocument opf) {
  String? firstText(String name) {
    for (final e in opf.findAllElements(name, namespace: '*')) {
      final t = e.innerText.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  final creator = firstText('creator');
  final description = firstText('description');

  return EpubMeta(
    title: firstText('title'),
    author: creator,
    description: description == null ? null : _stripTags(description),
  );
}

Uint8List? _readCover(Archive archive, XmlDocument opf, String base) {
  String? coverId;
  for (final m in opf.findAllElements('meta', namespace: '*')) {
    if (m.getAttribute('name') == 'cover') {
      coverId = m.getAttribute('content');
    }
  }

  String? href;
  for (final item in opf.findAllElements('item', namespace: '*')) {
    final props = item.getAttribute('properties') ?? '';
    if (props.contains('cover-image')) {
      href = item.getAttribute('href');
      break;
    }
    if (coverId != null && item.getAttribute('id') == coverId) {
      href = item.getAttribute('href');
    }
  }
  if (href == null) return null;
  return _readBytes(archive, _resolve(base, href));
}

String? _findRootFile(String containerXml) {
  try {
    final doc = XmlDocument.parse(containerXml);
    for (final rf in doc.findAllElements('rootfile', namespace: '*')) {
      final path = rf.getAttribute('full-path');
      if (path != null && path.isNotEmpty) return path;
    }
  } catch (_) {
    // 老老实实用正则兜底
    final m = RegExp(r'full-path\s*=\s*"([^"]+)"').firstMatch(containerXml);
    return m?.group(1);
  }
  return null;
}

ArchiveFile? _findFile(Archive archive, String name) {
  for (final f in archive.files) {
    if (f.name == name) return f;
  }
  // 有些打包工具会加 ./ 或者大小写不一致
  final lower = name.toLowerCase();
  for (final f in archive.files) {
    if (f.name.toLowerCase() == lower) return f;
    if (f.name.toLowerCase().endsWith('/$lower')) return f;
  }
  return null;
}

String? _readText(Archive archive, String name) {
  final bytes = _readBytes(archive, name);
  if (bytes == null) return null;
  return utf8.decode(bytes, allowMalformed: true);
}

Uint8List? _readBytes(Archive archive, String name) {
  final file = _findFile(archive, name);
  if (file == null) return null;
  try {
    final content = file.content;
    if (content is Uint8List) return content;
    return Uint8List.fromList(List<int>.from(content as List));
  } catch (_) {
    return null;
  }
}

String _baseDir(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i);
}

String _resolve(String base, String href) {
  if (base.isEmpty) return href;
  return '$base/$href';
}

String? _chapterTitle(String html) {
  final patterns = <RegExp>[
    RegExp(r'(?is)<h[1-4][^>]*>([\s\S]*?)</h[1-4]>'),
    RegExp(r'(?is)<title[^>]*>([\s\S]*?)</title>'),
    RegExp(r'(?is)<(p|div)[^>]*class="[^"]*title[^"]*"[^>]*>([\s\S]*?)</\1>'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(html);
    if (m != null) {
      final raw = m.groupCount > 1 ? (m.group(2) ?? m.group(1)) : m.group(1);
      if (raw != null) {
        final t = _stripTags(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (t.isNotEmpty) return t.length > 40 ? '${t.substring(0, 40)}…' : t;
      }
    }
  }
  return null;
}

String? _firstNonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

/// 把一段 HTML 变成可读纯文本
String htmlToText(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'(?is)<(script|style)\b[\s\S]*?</\1>'), '');
  s = s.replaceAll(RegExp(r'(?i)<br\s*/?>'), '\n');
  s = s.replaceAll(RegExp(r'(?i)</(p|div|h[1-6]|li|tr|blockquote)>'), '\n');
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  s = _decodeEntities(s);
  s = s.replaceAll('\u00a0', ' ');
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

String _decodeEntities(String s) {
  return s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&mdash;', '—')
      .replaceAll('&hellip;', '…');
}
