import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';

class RssArticlesPlaceholderView extends StatelessWidget {
  const RssArticlesPlaceholderView({
    super.key,
    required this.sourceName,
    required this.sourceUrl,
  });

  final String sourceName;
  final String sourceUrl;

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: sourceName.isEmpty ? 'RSS 文章列表' : sourceName,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _PlaceholderCard(
            title: 'RSS 文章列表（扩展阶段）',
            message: '已接入订阅入口与打开链路，本页将在下一阶段迁移 legado 文章列表与分页逻辑。',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            label: '源名称',
            value: sourceName.isEmpty ? '未命名源' : sourceName,
          ),
          const SizedBox(height: 10),
          _InfoCard(
            label: '源地址',
            value: sourceUrl,
          ),
        ],
      ),
    );
  }
}

class RssReadPlaceholderView extends StatelessWidget {
  const RssReadPlaceholderView({
    super.key,
    required this.title,
    required this.origin,
  });

  final String title;
  final String origin;

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: title.isEmpty ? 'RSS 阅读' : title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const _PlaceholderCard(
            title: 'RSS 阅读页（扩展阶段）',
            message: 'singleUrl 已按 legado 语义完成分支解析；阅读承载页将在后续阶段迁移。',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            label: 'origin',
            value: origin,
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
