part of 'speak_engine_manage_view.dart';

extension _SpeakEngineManageImportHistoryActions
    on _SpeakEngineManageViewState {
  Future<String?> _showOnlineImportInputSheet() async {
    final history = await _loadOnlineImportHistory();
    final inputController = TextEditingController();
    try {
      return showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(
              height: math.min(MediaQuery.of(context).size.height * 0.72, 560),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '网络导入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(popupContext),
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: inputController,
                                placeholder: 'url',
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  popupContext,
                                  inputController.text.trim(),
                                );
                              },
                              child: const Text('导入'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '历史记录',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: history.isEmpty
                            ? const AppEmptyState(
                                illustration:
                                    AppEmptyPlanetIllustration(size: 76),
                                title: '暂无历史记录',
                                message: '输入 URL 并导入后会自动保存',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey6
                                          .resolveFrom(context),
                                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
                                    ),
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              inputController.text = item;
                                            },
                                            child: Text(
                                              item,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(28, 28),
                                          onPressed: () async {
                                            history.removeAt(index);
                                            await _saveOnlineImportHistory(
                                              history,
                                            );
                                            if (mounted) {
                                              setDialogState(() {});
                                            }
                                          },
                                          child: Icon(
                                            CupertinoIcons.delete,
                                            size: 18,
                                            color: CupertinoColors.systemRed
                                                .resolveFrom(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      inputController.dispose();
    }
  }

  bool _isHttpUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    return parsed.scheme == 'http' || parsed.scheme == 'https';
  }

  Future<List<String>> _loadOnlineImportHistory() async {
    return _onlineImportHistoryStore.load(
      _SpeakEngineManageViewState._onlineImportHistoryKey,
    );
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    await _onlineImportHistoryStore.save(
      _SpeakEngineManageViewState._onlineImportHistoryKey,
      history,
    );
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    await _onlineImportHistoryStore.push(
      _SpeakEngineManageViewState._onlineImportHistoryKey,
      url,
    );
  }

}
