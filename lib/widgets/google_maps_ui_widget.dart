import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/saved_locations_service.dart';

class GoogleMapsUIWidget extends StatefulWidget {
  final String? initialLocationId;

  const GoogleMapsUIWidget({super.key, this.initialLocationId});

  @override
  State<GoogleMapsUIWidget> createState() => _GoogleMapsUIWidgetState();
}

class _GoogleMapsUIWidgetState extends State<GoogleMapsUIWidget> {
  late final WebViewController _controller;
  String? _initialUrl;
  final SavedLocationsService _savedLocationsService = SavedLocationsService();
  String? _pendingLocationId;

  @override
  void initState() {
    super.initState();
    _pendingLocationId = widget.initialLocationId;
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'FlutterSaveLocation',
        onMessageReceived: (JavaScriptMessage message) async {
          final locationId = message.message;
          try {
            await _savedLocationsService.saveLocation(locationId);
          } catch (e) {
            debugPrint('Error saving location: $e');
          }
        },
      )
      ..addJavaScriptChannel(
        'FlutterUnsaveLocation',
        onMessageReceived: (JavaScriptMessage message) async {
          final locationId = message.message;
          try {
            await _savedLocationsService.unsaveLocation(locationId);
          } catch (e) {
            debugPrint('Error unsaving location: $e');
          }
        },
      )
      ..addJavaScriptChannel(
        'FlutterGetSavedLocations',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final savedLocations = await _savedLocationsService.getSavedLocations();
            final jsonList = jsonEncode(savedLocations);
            await _controller.runJavaScript('''
              if (window.loadSavedLocationsFromFlutter) {
                window.loadSavedLocationsFromFlutter($jsonList);
              }
            ''');
          } catch (e) {
            debugPrint('Error getting saved locations: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            // Store the initial URL when the page first loads
            if (_initialUrl == null) {
              _initialUrl = url;
            }
          },
          onPageFinished: (String url) async {
            // Load OSM file and inject it into the WebView
            await _loadOSMFile();
            // Load saved locations from Firebase
            await _loadSavedLocations();
            // Open initial location if requested (from profile page)
            await _openInitialLocationIfNeeded();
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            // If this is the initial page load, allow it
            if (_initialUrl == null || request.url == _initialUrl) {
              return NavigationDecision.navigate;
            }
            
            // If it's a different URL (link click), open in external browser
            _launchExternalUrl(request.url);
            
            // Prevent navigation within the WebView
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadFlutterAsset('lib/googleMapsUI/index.html');
  }

  Future<void> _loadSavedLocations() async {
    try {
      final savedLocations = await _savedLocationsService.getSavedLocations();
      final jsonList = jsonEncode(savedLocations);
      await _controller.runJavaScript('''
        if (window.loadSavedLocationsFromFlutter) {
          window.loadSavedLocationsFromFlutter($jsonList);
        }
      ''');
    } catch (e) {
      debugPrint('Error loading saved locations: $e');
    }
  }

  Future<void> _openInitialLocationIfNeeded() async {
    if (_pendingLocationId == null) return;
    final locationId = _pendingLocationId!;
    _pendingLocationId = null;

    try {
      await _controller.runJavaScript('''
        if (window.openLocationFromFlutter) {
          window.openLocationFromFlutter("$locationId");
        }
      ''');
    } catch (e) {
      debugPrint('Error opening initial location: $e');
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
