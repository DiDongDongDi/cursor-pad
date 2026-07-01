import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/constants/desktop_user_agent.dart';
import '../../core/injection/script_loader.dart';
import 'browser_controller.dart';

/// Hosts [InAppWebView] in an isolated subtree so parent rebuilds
/// (progress, cursor, toolbar) do not recreate the platform view.
class DesktopWebView extends StatefulWidget {
  const DesktopWebView({
    super.key,
    required this.controller,
    required this.onCreated,
    this.initialHtml,
    this.hostKey = 0,
    this.onSizeChanged,
  });

  final BrowserController controller;
  final VoidCallback onCreated;
  final String? initialHtml;
  final int hostKey;
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

  @override
  Widget build(BuildContext context) {
    if (_desktopModeScript == null || _mouseBridgeScript == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (width <= 0 || height <= 0) {
          return const Center(child: CircularProgressIndicator());
        }

        final size = Size(width, height);
        if (_lastReportedSize != size) {
          _lastReportedSize = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onSizeChanged?.call(size);
            }
          });
        }

        return SizedBox(
          width: width,
          height: height,
          child: _InAppWebViewHost(
            key: ValueKey('inapp-webview-host-${widget.hostKey}'),
            controller: widget.controller,
            desktopModeScript: _desktopModeScript!,
            mouseBridgeScript: _mouseBridgeScript!,
            initialHtml: widget.initialHtml,
            onCreated: widget.onCreated,
          ),
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
    this.initialHtml,
  });

  final BrowserController controller;
  final String desktopModeScript;
  final String mouseBridgeScript;
  final VoidCallback onCreated;
  final String? initialHtml;

  @override
  State<_InAppWebViewHost> createState() => _InAppWebViewHostState();
}

class _InAppWebViewHostState extends State<_InAppWebViewHost> {
  bool _created = false;

  @override
  void dispose() {
    widget.controller.detachWebView();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialHtml = widget.initialHtml;

    return IgnorePointer(
      ignoring: true,
      child: InAppWebView(
        initialUrlRequest: initialHtml == null
            ? URLRequest(url: WebUri('about:blank'))
            : null,
        initialData: initialHtml == null
            ? null
            : InAppWebViewInitialData(
                data: initialHtml,
                mimeType: 'text/html',
                encoding: 'utf-8',
                baseUrl: WebUri('https://localhost/bookmarks'),
                historyUrl: WebUri('https://localhost/bookmarks'),
              ),
        initialSettings: InAppWebViewSettings(
          userAgent: DesktopUserAgent.chromeWindows,
          javaScriptEnabled: true,
          useWideViewPort: true,
          loadWithOverviewMode: false,
          textZoom: 100,
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
          widget.controller.attach(
            webViewController,
            skipInitialLoad: widget.initialHtml != null,
          );
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
        onReceivedError: (controller, request, error) {
          if (!kDebugMode) {
            return;
          }
          final url = request.url?.toString() ?? '';
          if (url.contains('localhost/favicon.ico')) {
            return;
          }
          debugPrint(
            'WebView error: ${error.type} ${error.description} ($url)',
          );
        },
        onConsoleMessage: (controller, consoleMessage) {
          if (kDebugMode &&
              consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
            debugPrint('WebView console: ${consoleMessage.message}');
          }
        },
        onRenderProcessGone: (controller, detail) {
          if (kDebugMode) {
            debugPrint(
              'WebView render process gone (didCrash=${detail.didCrash})',
            );
          }
          widget.controller.handleRenderProcessGone();
        },
      ),
    );
  }
}
