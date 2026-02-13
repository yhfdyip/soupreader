import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/exception_log_service.dart';
import 'exception_logs_view.dart';

class DeveloperToolsView extends StatelessWidget {
  const DeveloperToolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final logService = ExceptionLogService();
    return AppCupertinoPageScaffold(
      title: '开发工具',
      child: ValueListenableBuilder<List<ExceptionLogEntry>>(
        valueListenable: logService.listenable,
        builder: (context, logs, _) {
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            children: [
              CupertinoListSection.insetGrouped(
                header: const Text('诊断'),
                children: [
                  CupertinoListTile.notched(
                    title: const Text('异常日志'),
                    additionalInfo: Text('${logs.length} 条'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => const ExceptionLogsView(),
                      ),
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('说明'),
                children: const [
                  CupertinoListTile(
                    title: Text(
                      '该页面用于查看关键节点的异常原因（启动、全局异常、书源五段链路、导入流程等）。',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

