import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

Future<String?> showSourceEditLegacyUrlOptionDialog(BuildContext context) async {
  final methodCtrl = TextEditingController();
  final charsetCtrl = TextEditingController();
  final headersCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  final typeCtrl = TextEditingController();
  final retryCtrl = TextEditingController();
  final webJsCtrl = TextEditingController();
  final jsCtrl = TextEditingController();
  var useWebView = false;

  final text = await showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (popupContext) {
      return StatefulBuilder(
        builder: (context, setPopupState) {
          return CupertinoPopupSurface(
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(popupContext),
                            child: const Text('取消'),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'URL参数',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.pop(
                                popupContext,
                                _encodeUrlOption(
                                  useWebView: useWebView,
                                  method: methodCtrl.text,
                                  charset: charsetCtrl.text,
                                  headers: headersCtrl.text,
                                  body: bodyCtrl.text,
                                  type: typeCtrl.text,
                                  retry: retryCtrl.text,
                                  webJs: webJsCtrl.text,
                                  js: jsCtrl.text,
                                ),
                              );
                            },
                            child: const Text('插入'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 1,
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('useWebView')),
                              CupertinoSwitch(
                                value: useWebView,
                                onChanged: (value) {
                                  setPopupState(() => useWebView = value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildUrlOptionField(controller: methodCtrl, placeholder: 'method'),
                          _buildUrlOptionField(controller: charsetCtrl, placeholder: 'charset'),
                          _buildUrlOptionField(controller: headersCtrl, placeholder: 'headers'),
                          _buildUrlOptionField(controller: bodyCtrl, placeholder: 'body'),
                          _buildUrlOptionField(controller: typeCtrl, placeholder: 'type'),
                          _buildUrlOptionField(
                            controller: retryCtrl,
                            placeholder: 'retry',
                            keyboardType: TextInputType.number,
                          ),
                          _buildUrlOptionField(
                            controller: webJsCtrl,
                            placeholder: 'webJs',
                            maxLines: 3,
                          ),
                          _buildUrlOptionField(
                            controller: jsCtrl,
                            placeholder: 'js',
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  _disposeControllers(<TextEditingController>[
    methodCtrl,
    charsetCtrl,
    headersCtrl,
    bodyCtrl,
    typeCtrl,
    retryCtrl,
    webJsCtrl,
    jsCtrl,
  ]);
  return text;
}

String _encodeUrlOption({
  required bool useWebView,
  required String method,
  required String charset,
  required String headers,
  required String body,
  required String type,
  required String retry,
  required String webJs,
  required String js,
}) {
  final option = <String, dynamic>{};

  void setText(String key, String value) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      option[key] = normalized;
    }
  }

  if (useWebView) {
    option['useWebView'] = true;
  }
  setText('method', method);
  setText('charset', charset);
  setText('headers', headers);
  setText('body', body);
  setText('type', type);
  setText('retry', retry);
  setText('webJs', webJs);
  setText('js', js);
  return jsonEncode(option);
}

Widget _buildUrlOptionField({
  required TextEditingController controller,
  required String placeholder,
  int maxLines = 1,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      maxLines: maxLines,
    ),
  );
}

void _disposeControllers(List<TextEditingController> controllers) {
  for (final controller in controllers) {
    controller.dispose();
  }
}
