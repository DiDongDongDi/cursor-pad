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

        return _InAppWebViewHost(
          key: const ValueKey('inapp-webview-host'),
          controller: widget.controller,
          desktopModeScript: _desktopModeScript!,
          mouseBridgeScript: _mouseBridgeScript!,
          onCreated: widget.onCreated,
        );
      },
    );
  }
}

class _InAppWebViewHost extends StatefulWidget {
  const _InAppWebViewHost({
    super.key,
    required this.controller,
    required this.desktopModeScript,
    required this.mouseBridgeScript,
    required this.onCreated,
  });

  final BrowserController controller;
  final String desktopModeScript;
  final String mouseBridgeScript;
  final VoidCallback onCreated;

  @override
  State<_InAppWebViewHost> createState() => _InAppWebViewHostState();
}

class _InAppWebViewHostState extends State<_InAppWebViewHost> {
  bool _created = false;

  @override
  Widget build(BuildContext context) {
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
            source: widget.desktopModeScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
          UserScript(
            source: widget.mouseBridgeScript,
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
          if (!_created) {
            _created = true;
            widget.onCreated();
          }
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
          if (!widget.controller.state.isLoading) {
            widget.controller.updateNavigationState();
          }
        },
      ),
    );
  }
}
