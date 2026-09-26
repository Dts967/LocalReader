# 本地小说阅读器（local_novel_reader 改版）

一款轻量级本地小说阅读器：导入本地 txt / epub，自动分章，离线阅读，没有开屏广告、没有联网请求。

在原项目 [eirueirufu/local_novel_reader](https://github.com/eirueirufu/local_novel_reader)（GPL-3.0）基础上做的增量改造。

## 这次改了什么

| 改造点 | 说明 |
| --- | --- |
| 自动识别分章 | 内置 10 种常见章节格式（第X章 / 第 X 章 / 章X / 1章 / 1. / 卷X / （一）/ Chapter 1 / 序章楔子…），导入时逐个试并按章节数、单章长度、标题长度打分，挑最合适的一个 |
| 分章预览 | 导入后先进预览页，列出识别出的全部目录和每章字数，确认后才入库 |
| 预置 + 自定义正则 | 预览页顶部的格式 chip 一键切换，下方可以直接写正则、即时看到目录变化；正则非法会提示而不是崩 |
| 目录可编辑 | 目录里长按章节 → 编辑显示名称 / 从目录删除。两个操作都只动目录，原始 txt 一个字都不改（删除的章节正文自动并入相邻章节） |
| epub 支持 | 用 archive + xml 直接解 zip 读 opf，按 spine 顺序拼正文，读取 dc:title / dc:creator / dc:description 与内嵌封面 |
| 中文编码 | 网文常见 GBK 不再乱码：BOM → UTF-16 → UTF-8 → GBK 依次探测 |
| Material 3 | 用 `dynamic_color` 在 Android 12+ 取壁纸动态配色，低版本回退 6 套种子色；主题可跟随系统/浅色/深色 |
| 新图标 | 换成 Material Symbols 的 `auto_stories`（Apache-2.0），纯色底 + 矢量前景的自适应图标 |
| 书架 | 网格卡片，显示封面/章节数/上次读到第几章；长按出菜单（书籍信息 / 重新分章 / 删除） |

## 目录结构

```
lib/
  main.dart                    入口，Hive 初始化 + 动态取色主题
  models/
    book.dart                  书籍索引（含作者/简介/封面/来源格式）
    book_chapters.dart         正文 + 目录（只存章节起始下标）
    reader_settings.dart       字号行距 / 主题 / 动态取色
  utils/
    chapter_splitter.dart      预置正则库 + 自动检测打分 + 按长度兜底
    epub_parser.dart           epub → 纯文本 + 元数据
    file_decoder.dart          编码探测（UTF-8 / UTF-16 / GBK）
    text.dart                  分页测量
  pages/
    bookshelf_page.dart        书架
    reader_page.dart           阅读页 + 目录抽屉
    chapter_preview_page.dart  分章预览
    book_info_page.dart        书籍信息
    settings_page.dart         外观设置
  widgets/                     封面占位、翻页控件
```

## 数据设计（为什么删除目录不会破坏原文）

`BookChapters` 只保存一份 `content` 原文，目录是 `offsets`（每章起始下标）+ `titles`（显示名）：

- 读第 i 章 = `content.substring(offsets[i], offsets[i+1])`
- 改名 = 只改 `titles[i]`
- 删除 = 从 `offsets`/`titles` 里移除一项，正文自动并入上一章（首章并入下一章）

原始文件从头到尾没有被复制、截断或改写过。

## 构建

```bash
flutter pub get
flutter test          # 分章识别的单元测试
flutter build apk --release --split-per-abi
```

仓库里已带 GitHub Actions：推到 `main` 会构建 debug APK 并作为 artifact 上传，打 `v*.*.*` tag 会构建 release 分包并发版。
如果本地报缺少 gradlew / wrapper，先跑一次 `flutter create --platforms=android .` 补齐即可。

## 依赖

| 包 | 许可 | 用途 |
| --- | --- | --- |
| flutter / hive / hive_flutter | BSD / MIT | 框架与本地存储 |
| file_picker | BSD | 选择本地文件 |
| archive | MIT | 解 epub（zip） |
| xml | MIT | 读 epub 的 opf 元数据 |
| gbk_codec | MIT | GBK 编码解码 |
| dynamic_color | BSD | Material You 动态取色 |
| Material Symbols `auto_stories` | Apache-2.0 | 应用图标 |

## 已知限制

- 网络小说入口这版没做，保持纯离线。
- epub 只取文本与常见元数据，CSS 排版、脚注、内嵌音频不支持。
- 分章是按纯文本做的，epub 若目录层级很细，可以在"重新分章"里改用正则合并。
- Hive 的 `.g.dart` 是手写的（新增字段后同步更新过）；改字段后请跑
  `flutter pub run build_runner build --delete-conflicting-outputs` 重新生成。

## 许可

沿用原项目 GPL-3.0。
