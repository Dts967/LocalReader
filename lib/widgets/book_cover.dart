import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';

/// 书封。
///
/// epub 有内嵌封面就用封面，没有（txt 或 epub 无封面）就按书名生成
/// 一个纯色占位，颜色由书名决定，同一本书每次都一样。
class BookCover extends StatelessWidget {
  final Book book;
  final double radius;

  const BookCover({super.key, required this.book, this.radius = 12});

  static const List<Color> _tones = <Color>[
    Color(0xFFEADDFF),
    Color(0xFFD0E4FF),
    Color(0xFFC8E7D8),
    Color(0xFFFFD8C2),
    Color(0xFFF2D9F0),
    Color(0xFFD6E4F0),
  ];

  static const List<Color> _tonesDark = <Color>[
    Color(0xFF4A3780),
    Color(0xFF2E4879),
    Color(0xFF1F4A3D),
    Color(0xFF5A3B2E),
    Color(0xFF4E2E58),
    Color(0xFF33455B),
  ];

  int get _hash {
    var h = 0;
    for (final unit in book.title.codeUnits) {
      h = (h * 31 + unit) & 0xFFFFFFFF;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base = dark ? _tonesDark[_hash % _tonesDark.length] : _tones[_hash % _tones.length];
    final onBase = dark ? const Color(0xFFF5EFFF) : const Color(0xFF1D1B20);

    final path = book.coverPath;
    final hasCover = path != null && path.isNotEmpty && File(path).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: base,
        child: hasCover
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Placeholder(book: book, color: onBase),
              )
            : _Placeholder(book: book, color: onBase),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Book book;
  final Color color;

  const _Placeholder({required this.book, required this.color});

  @override
  Widget build(BuildContext context) {
    final first = book.title.trim().isEmpty ? '书' : book.title.trim().substring(0, 1);
    return Center(
      child: Text(
        first,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: color.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
