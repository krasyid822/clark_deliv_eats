import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:clark_deliv_eats/location_service.dart';
import 'package:clark_deliv_eats/permission_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep system status bar visible and readable on Android
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFDFF7E6),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  // No explicit platform override needed for current webview_flutter API
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SafeArea(child: Scaffold(body: FullscreenWebView())),
    );
  }
}

class FullscreenWebView extends StatefulWidget {
  const FullscreenWebView({super.key});

  @override
  State<FullscreenWebView> createState() => _FullscreenWebViewState();
}

class _FullscreenWebViewState extends State<FullscreenWebView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      transparentBackground: true,
    );

    return SizedBox.expand(
      child: InAppWebView(
        // Load bundled HTML directly from assets to avoid blank screen while awaiting initial data
        initialFile: 'assets/index.html',
        initialSettings: settings,
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: 'AppChannel',
            callback: (args) async {
              try {
                final msg = args.isNotEmpty ? args[0] : null;
                if (msg == 'getLocation') {
                  final pos = await LocationService.getCurrentPosition();
                  if (pos != null) {
                    final js =
                        "window.onFlutterLocationCallback && window.onFlutterLocationCallback({lat: ${pos.latitude}, lon: ${pos.longitude}});";
                    await controller.evaluateJavascript(source: js);
                  } else {
                    await controller.evaluateJavascript(
                      source:
                          "window.onFlutterLocationCallback && window.onFlutterLocationCallback(null);",
                    );
                  }
                }
              } catch (e) {
                await controller.evaluateJavascript(
                  source:
                      "window.onFlutterLocationCallback && window.onFlutterLocationCallback(null);",
                );
              }
              return null;
            },
          );
        },
        onLoadStop: (controller, url) async {
          // Request runtime permission on page load and provide location to the web page
          final granted = await PermissionService.requestLocationPermission();
          if (granted) {
            final pos = await LocationService.getCurrentPosition();
            if (pos != null) {
              final js =
                  "window.onFlutterLocationCallback && window.onFlutterLocationCallback({lat: ${pos.latitude}, lon: ${pos.longitude}});";
              await controller.evaluateJavascript(source: js);
            } else {
              await controller.evaluateJavascript(
                source:
                    "window.onFlutterLocationCallback && window.onFlutterLocationCallback(null);",
              );
            }
          } else {
            await controller.evaluateJavascript(
              source:
                  "window.onFlutterLocationCallback && window.onFlutterLocationCallback(null);",
            );
          }

          // Inject shim for specific domain
          try {
            if (url != null &&
                url.toString().contains('deliveats.ruswanda.my.id')) {
              final shim = '''(function(){
  if (window.__flutter_geo_shim_installed) return; window.__flutter_geo_shim_installed = true;
  try{ if (!navigator.permissions) { navigator.permissions = { query: function(param){ if (param && param.name==='geolocation') return Promise.resolve({state:'prompt', onchange:null}); return Promise.resolve({state:'granted', onchange:null}); } }; } else if (!navigator.permissions.__flutter_override) { var originalQuery = navigator.permissions.query.bind(navigator.permissions); navigator.permissions.__flutter_override = true; navigator.permissions.query = function(param){ try{ if (param && param.name === 'geolocation') { return Promise.resolve({ state: (window.flutter_geolocation_granted ? 'granted' : 'prompt'), onchange: null }); } }catch(e){} return originalQuery(param); }; } }catch(e){}
  try{ if (!window.AppChannel) { window.AppChannel = { postMessage: function(m){ try{ if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) { window.flutter_inappwebview.callHandler('AppChannel', m); } else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppChannel) { window.webkit.messageHandlers.AppChannel.postMessage(m); } else if (window.AppChannelNative && window.AppChannelNative.postMessage) { window.AppChannelNative.postMessage(m); } }catch(e){} } }; } }catch(e){}
  try{ if (!navigator.geolocation) navigator.geolocation = {}; navigator.geolocation.getCurrentPosition = function(success, error, options){ var finished = false; function cleanup(){ finished = true; window.removeEventListener('flutterLocationResult', handler); if (window._clearFlutterLocationTimeout) window._clearFlutterLocationTimeout(); } function handler(e){ if (finished) return; cleanup(); var pos = e.detail; if (!pos) { if (typeof error === 'function') error({code:1, message:'permission denied or unavailable'}); return; } if (typeof success === 'function') success({coords:{latitude: pos.lat, longitude: pos.lon}, timestamp: Date.now()}); } window.addEventListener('flutterLocationResult', handler); try{ window.AppChannel.postMessage('getLocation'); } catch(e){ cleanup(); if (typeof error === 'function') error(e); } var to = setTimeout(function(){ if (finished) return; cleanup(); if (typeof error === 'function') error({code:3, message:'timeout'}); }, (options && options.timeout) || 8000); window._clearFlutterLocationTimeout = function(){ clearTimeout(to); }; }; navigator.geolocation.watchPosition = function(success, error, options){ var id = Math.random().toString(36).slice(2,9); function handler(e){ var pos = e.detail; if (!pos) { if (typeof error==='function') error({code:1,message:'permission denied or unavailable'}); return; } if (typeof success==='function') success({coords:{latitude: pos.lat, longitude: pos.lon}, timestamp: Date.now()}); } window.addEventListener('flutterLocationResult', handler); try{ window.AppChannel.postMessage('getLocation'); } catch(e){ if (typeof error==='function') error(e); } return id; }; navigator.geolocation.clearWatch = function(id){}; window.onFlutterLocationCallback = function(pos){ try{ window.flutter_geolocation_granted = !!pos; window.dispatchEvent(new CustomEvent('flutterLocationResult', {detail: pos})); }catch(e){} } }catch(e){}
  try{ if (window.fetch) { try{ window.__origFetch = window.fetch.bind(window); window.fetch = function(input, init){ init = init || {}; if (!init.cache) init.cache = 'no-store'; return window.__origFetch(input, init); }; }catch(e){} } if (window.XMLHttpRequest) { try{ var _origOpen = XMLHttpRequest.prototype.open; var _origSend = XMLHttpRequest.prototype.send; XMLHttpRequest.prototype.open = function(method, url, async){ this._method = method; return _origOpen.apply(this, arguments); }; XMLHttpRequest.prototype.send = function(body){ try{ this.setRequestHeader && this.setRequestHeader('Cache-Control', 'no-store'); }catch(e){} return _origSend.apply(this, arguments); }; }catch(e){} } try{ function hijackForms(){ var forms = document.getElementsByTagName('form'); for(var i=0;i<forms.length;i++){ (function(f){ if (f.__flutter_hijacked) return; f.__flutter_hijacked = true; f.addEventListener('submit', function(ev){ try{ ev.preventDefault(); var method = (f.method || 'GET').toUpperCase(); var action = f.action || window.location.href; var fd = new FormData(f); var opts = { method: method }; if (method === 'GET'){ var params = new URLSearchParams(fd).toString(); var target = action + (action.indexOf('?')===-1 ? '?' : '&') + params; window.location.href = target; return; } else { opts.body = fd; } fetch(action, opts).then(function(resp){ return resp.text(); }).then(function(text){ try{ document.open(); document.write(text); document.close(); }catch(e){ window.location.reload(); } }).catch(function(){ window.location.reload(); }); }catch(e){ } }); })(forms[i]); } } if (document && document.readyState === 'complete') hijackForms(); else window.addEventListener('load', hijackForms); }catch(e){}
})();''';
              await controller.evaluateJavascript(source: shim);
            }
          } catch (e) {
            // ignore injection errors
          }
        },
        // Allow the web page to use navigator.geolocation when native permission is granted
        onGeolocationPermissionsShowPrompt: (controller, origin) async =>
            GeolocationPermissionShowPromptResponse(
              origin: origin,
              allow: true,
              retain: true,
            ),
      ),
    );
  }
}
