import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

class GoogleMapsUIWidget extends StatefulWidget {
  const GoogleMapsUIWidget({super.key});

  @override
  State<GoogleMapsUIWidget> createState() => _GoogleMapsUIWidgetState();
}

class _GoogleMapsUIWidgetState extends State<GoogleMapsUIWidget> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) async {
            // Load OSM file and inject it into the WebView
            await _loadOSMFile();
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadFlutterAsset('lib/googleMapsUI/index.html');
  }

  Future<void> _loadOSMFile() async {
    try {
      final osmBytes = await rootBundle.load('lib/googleMapsUI/public/map.osm');
      final osmContent = utf8.decode(osmBytes.buffer.asUint8List());
      
      // Use base64 encoding to safely pass the content to JavaScript
      final base64Content = base64Encode(utf8.encode(osmContent));
      
      // Inject the OSM data into the WebView
      await _controller.runJavaScript('''
        if (window.loadOSMDataFromFlutter) {
          try {
            const base64Content = '$base64Content';
            const osmText = atob(base64Content);
            window.loadOSMDataFromFlutter(osmText);
          } catch (e) {
            console.error('Error decoding OSM data:', e);
            window.loadOSMDataFromFlutter(null);
          }
        }
      ''');
    } catch (e) {
      // If file loading fails, notify the WebView
      await _controller.runJavaScript('''
        if (window.loadOSMDataFromFlutter) {
          window.loadOSMDataFromFlutter(null);
        }
      ''');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
