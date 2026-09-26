import 'dart:convert';
import 'dart:typed_data';

import 'package:gbk_codec/gbk_codec.dart';

/// 本地 txt 的编码探测。
///
/// 网上下来的中文小说绝大多数是 UTF-8 或 GBK，
/// 只用 utf8 硬解会整本乱码，所以这里按顺序试：
/// BOM → UTF-16 → UTF-8 严格 → GBK → UTF-8 容错。
String decodeTextBytes(Uint8List bytes) {
  if (bytes.isEmpty) return '';

  // UTF-8 BOM
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  // UTF-16 LE / BE
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), false);
    }
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), true);
    }
  }

  try {
    return utf8.decode(bytes);
  } catch (_) {
    // 不是合法 UTF-8，按 GBK 处理
  }

  try {
    final gbkText = gbk.decode(bytes);
    if (gbkText.isNotEmpty) return gbkText;
  } catch (_) {
    // 继续兜底
  }

  return utf8.decode(bytes, allowMalformed: true);
}

String _decodeUtf16(List<int> bytes, bool bigEndian) {
  final buffer = StringBuffer();
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final unit = bigEndian
        ? (bytes[i] << 8) | bytes[i + 1]
        : (bytes[i + 1] << 8) | bytes[i];
    buffer.writeCharCode(unit);
  }
  return buffer.toString();
}
