import 'dart:collection';

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
  });

  final BrowserController controller;
  final VoidCallback onCreated;

  @override
  State<DesktopWebView> createState() => _DesktopWebViewState();
}

class _DesktopWebViewState extends State<DesktopWebView> {
  String? _desktopModeScript;
  String? _mouseBridgeScript;

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

    return _InAppWebViewHost(
      key: const ValueKey('inapp-webview-host'),
      controller: widget.controller,
      desktopModeScript: _desktopModeScript!,
      mouseBridgeScript: _mouseBridgeScript!,
      onCreated: widget.onCreated,
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
          useHybridComposition: false,
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
          widget.controller.updateNavigationState();
        },
      ),
    );
  }
}
