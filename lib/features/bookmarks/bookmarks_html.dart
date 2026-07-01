import 'bookmark.dart';

class BookmarksHtml {
  BookmarksHtml._();

  static String generate(List<Bookmark> bookmarks) {
    final items = bookmarks.isEmpty
        ? '<p class="empty">暂无收藏，浏览网页后点击 ★ 收藏当前页面。</p>'
        : bookmarks.map(_renderItem).join('\n');

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <link rel="icon" href="data:,">
  <title>收藏夹</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 32px 48px;
      font-family: "Segoe UI", system-ui, sans-serif;
      background: #111827;
      color: #f3f4f6;
    }
    h1 {
      margin: 0 0 8px;
      font-size: 28px;
      font-weight: 600;
    }
    .subtitle {
      margin: 0 0 24px;
      color: #9ca3af;
      font-size: 14px;
    }
    ul {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    li {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 0;
      border-bottom: 1px solid #374151;
    }
    a {
      flex: 1;
      color: #93c5fd;
      text-decoration: none;
      font-size: 16px;
    }
    a:hover { text-decoration: underline; }
    .url {
      display: block;
      margin-top: 4px;
      color: #6b7280;
      font-size: 12px;
      word-break: break-all;
    }
    .delete {
      border: 1px solid #4b5563;
      background: #1f2937;
      color: #fca5a5;
      border-radius: 6px;
      padding: 6px 10px;
      cursor: pointer;
      font-size: 14px;
    }
    .delete:hover { background: #374151; }
    .empty {
      color: #9ca3af;
      font-size: 16px;
      line-height: 1.6;
    }
  </style>
</head>
<body>
  <h1>收藏夹</h1>
  <p class="subtitle">点击链接打开网页，或使用虚拟鼠标操作。</p>
  <ul>
    $items
  </ul>
  <script>
    document.querySelectorAll('.delete').forEach(function (button) {
      button.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        var id = button.getAttribute('data-id');
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('deleteBookmark', id);
        }
      });
    });
  </script>
</body>
</html>
''';
  }

  static String _renderItem(Bookmark bookmark) {
    final title = _escapeHtml(bookmark.title);
    final url = _escapeHtml(bookmark.url);
    final id = _escapeHtml(bookmark.id);

    return '''
<li>
  <a href="$url">
    $title
    <span class="url">$url</span>
  </a>
  <button class="delete" data-id="$id" type="button">×</button>
</li>''';
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
