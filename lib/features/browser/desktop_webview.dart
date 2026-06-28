import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/constants/desktop_user_agent.dart';
import '../../core/injection/script_loader.dart';
import 'browser_controller.dart';

class DesktopWebView extends StatefulWidget {
  const DesktopWebView({
    super.key,
    required this.controller,
    required this.onCreated,
    this.onSizeChanged,
  });

  final BrowserController controller;
  final VoidCallback onCreated;
  final ValueChanged<Size>? onSizeChanged;

  @override
  State<DesktopWebView> createState() => _DesktopWebViewState();
}

class _DesktopWebViewState extends State<DesktopWebView> {
  String? _desktopModeScript;
  String? _mouseBridgeScript;
  Size? _lastReportedSize;

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  Future<void> _loadScripts() async {
    final desktopMode = await ScriptLoader.load('assets/js/desktop_mode.js');
    final mouseBridge = await ScriptLoader.load('assets/js/mouse_bridge.js');
    if (!mounted) {
      return;
    }
    setState(() {
      _desktopModeScript = desktopMode;
      _mouseBridgeScript = mouseBridge;
    });
  }

  void _reportSizeIfChanged(Size size) {
    if (_lastReportedSize == size) {
      return;
    }
    _lastReportedSize = size;
    widget.onSizeChanged?.call(size);
    widget.controller.syncViewport(size.width, size.height);
  }

  @override
  Widget build(BuildContext context) {
    if (_desktopModeScript == null || _mouseBridgeScript == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastReportedSize != size) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _reportSizeIfChanged(size);
          });
        }

        return IgnorePointer(
          ignoring: true,
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('about:blank'),
            ),
            initialSettings: InAppWebViewSettings(
              userAgent: DesktopUserAgent.chromeWindows,
              javaScriptEnabled: true,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              supportZoom: true,
              builtInZoomControls: false,
              displayZoomControls: false,
              disableHorizontalScroll: false,
              disableVerticalScroll: false,
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
              useHybridComposition: true,
              transparentBackground: false,
            ),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: _desktopModeScript!,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
              UserScript(
                source: _mouseBridgeScript!,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
            onWebViewCreated: (webViewController) {
              webViewController.addJavaScriptHandler(
                handlerName: 'deleteBookmark',
                callback: (args) async {
                  final id = args.isNotEmpty ? args.first?.toString() : null;
                  if (id == null || id.isEmpty) {
                    return;
                  }
                  await widget.controller.handleDeleteBookmark(id);
                },
              );
              widget.controller.attach(webViewController);
              widget.onCreated();
            },
            onLoadStart: (controller, url) {
              widget.controller.onLoadStart(url);
            },
            onLoadStop: (controller, url) async {
              await widget.controller.onLoadStop(url);
            },
            onProgressChanged: (controller, progress) {
              widget.controller.onProgressChanged(progress);
            },
            onTitleChanged: (controller, title) {
              widget.controller.updateNavigationState();
            },
          ),
        );
      },
    );
  }
}
