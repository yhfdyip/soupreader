class SourceHelpTexts {
  static const String manage = '书源管理说明：\n'
      '1. 长按条目进入选择模式，可批量启停、分组、校验、置顶/置底。\n'
      '2. 导入支持：剪贴板/文件/网络/扫码；支持 sourceUrls 聚合导入。\n'
      '3. 校验前可设置关键词，便于快速复现搜索链路问题。';

  static const String debug = '调试输入规则：\n'
      '\n'
      '1. 搜索调试：\n'
      '直接输入关键字，例如：我的、系统\n'
      '\n'
      '2. 详情调试：\n'
      '输入详情页绝对 URL（http/https）\n'
      '\n'
      '3. 发现调试：\n'
      '输入 标题::url，例如：系统::https://example.com/explore\n'
      '\n'
      '4. 目录调试：\n'
      '输入 ++tocUrl，例如：++https://example.com/book/1/toc\n'
      '\n'
      '5. 正文调试：\n'
      '输入 --contentUrl，例如：--https://example.com/book/1/1.html\n'
      '\n'
      '快捷入口说明：\n'
      '- 我的/系统：直接填充并执行调试\n'
      '- 详情URL：按当前 Key 重新执行\n'
      '- ++目录/--正文：自动加前缀并执行（当已有 key 时）\n'
      '- 发现候选：从书源发现规则中提取候选项';
}
