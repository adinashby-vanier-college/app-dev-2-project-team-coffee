import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/saved_locations_provider.dart';
import '../services/saved_locations_service.dart';
import '../services/locations_service.dart';
import '../services/friends_service.dart';
import '../utils/locations_initializer.dart';

class GoogleMapsUIWidget extends StatefulWidget {
  const GoogleMapsUIWidget({super.key});

  @override
  State<GoogleMapsUIWidget> createState() => _GoogleMapsUIWidgetState();
}

class _GoogleMapsUIWidgetState extends State<GoogleMapsUIWidget> {
  late final WebViewController _controller;
  String? _initialUrl;
  final SavedLocationsService _savedLocationsService = SavedLocationsService();
  final LocationsService _locationsService = LocationsService();
  final FriendsService _friendsService = FriendsService();

  @override
  void initState() {
    super.initState();
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
            // The provider will automatically update via the stream
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
            // The provider will automatically update via the stream
          } catch (e) {
            debugPrint('Error unsaving location: $e');
          }
        },
      )
      ..addJavaScriptChannel(
        'FlutterGetSavedLocations',
        onMessageReceived: (JavaScriptMessage message) async {
          // This is handled by the provider listener now
          _sendSavedLocationsToWebView();
        },
      )
      ..addJavaScriptChannel(
        'FlutterGetFriends',
        onMessageReceived: (JavaScriptMessage message) async {
          // Refresh friends when requested
          await _loadFriendsFromFirebase();
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
            // Load locations from Firebase and inject into WebView
            await _loadLocationsFromFirebase();
            // Load friends from Firebase and inject into WebView
            await _loadFriendsFromFirebase();
            // Load saved locations from Firebase (will be sent via provider listener)
            _sendSavedLocationsToWebView();
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

  void _sendSavedLocationsToWebView() {
    if (!mounted) return;
    final provider = Provider.of<SavedLocationsProvider>(context, listen: false);
    final jsonList = jsonEncode(provider.savedLocationIds);
    _controller.runJavaScript('''
      if (window.loadSavedLocationsFromFlutter) {
        window.loadSavedLocationsFromFlutter($jsonList);
      }
    ''');
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

  Future<void> _loadLocationsFromFirebase() async {
    try {
      // Check if locations exist, if not initialize them
      final initializer = LocationsInitializer();
      final locationsExist = await initializer.locationsExist();
      
      if (!locationsExist) {
        debugPrint('No locations found in Firebase. Initializing...');
        try {
          final count = await initializer.initializeLocations();
          debugPrint('Successfully initialized $count locations in Firebase');
        } catch (e) {
          debugPrint('Error initializing locations: $e');
          return;
        }
      }
      
      final locations = await _locationsService.getAllLocations();
      
      if (locations.isEmpty) {
        debugPrint('No locations found in Firebase after initialization');
        return;
      }
      
      // Convert locations to JSON and inject into WebView
      final locationsJson = jsonEncode(locations);
      
      await _controller.runJavaScript('''
        if (window.loadLocationsFromFlutter) {
          try {
            const locationsData = $locationsJson;
            window.loadLocationsFromFlutter(locationsData);
          } catch (e) {
            console.error('Error loading locations from Flutter:', e);
          }
        } else {
          // Store locations in a queue if the function isn't ready yet
          window._locationsQueue = window._locationsQueue || [];
          window._locationsQueue.push($locationsJson);
        }
      ''');
    } catch (e) {
      debugPrint('Error loading locations from Firebase: $e');
    }
  }

  Future<void> _loadFriendsFromFirebase() async {
    try {
      // Get friends list from Firebase
      final friendUids = await _friendsService.getFriendsList().first;

      if (friendUids.isEmpty) {
        debugPrint('No friends found');
        // Send empty array to webview
        await _controller.runJavaScript('''
          if (window.loadFriendsFromFlutter) {
            window.loadFriendsFromFlutter([]);
          } else {
            window._friendsQueue = window._friendsQueue || [];
            window._friendsQueue.push([]);
          }
        ''');
        return;
      }
      
      // Get friend profiles
      final friends = await _friendsService.getFriendProfiles(friendUids);

      // Convert friends to a format suitable for JavaScript
      final friendsList = friends.map((friend) {
        // Choose a display label:
        // 1) explicit profile name
        // 2) displayName
        // 3) email local-part (before @)
        // 4) uid as last resort
        String label =
            (friend.name != null && friend.name!.trim().isNotEmpty)
                ? friend.name!.trim()
                : (friend.displayName != null &&
                        friend.displayName!.trim().isNotEmpty)
                    ? friend.displayName!.trim()
                    : (friend.email != null &&
                            friend.email!.trim().isNotEmpty)
                        ? friend.email!.split('@').first
                        : friend.uid;

        // Derive initials from the label
        String initials = '?';
        if (label.isNotEmpty) {
          final parts = label.trim().split(' ');
          if (parts.length >= 2) {
            initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
          } else {
            initials = label[0].toUpperCase();
          }
        }

        return {
          'id': friend.uid,
          'name': label,
          'avatar': initials,
          'photoURL': friend.photoURL ?? '',
        };
      }).toList();

      // Convert to JSON and inject into WebView
      final friendsJson = jsonEncode(friendsList);

      debugPrint('Sending ${friendsList.length} friends to webview');
      await _controller.runJavaScript('''
        if (window.loadFriendsFromFlutter) {
          try {
            const friendsData = $friendsJson;
            console.log('Loading friends from Flutter:', friendsData.length);
            window.loadFriendsFromFlutter(friendsData);
          } catch (e) {
            console.error('Error loading friends from Flutter:', e);
          }
        } else {
          // Store friends in a queue if the function isn't ready yet
          window._friendsQueue = window._friendsQueue || [];
          window._friendsQueue.push($friendsJson);
        }
      ''');
    } catch (e) {
      debugPrint('Error loading friends from Firebase: $e');
      // Send empty array on error
      await _controller.runJavaScript('''
        if (window.loadFriendsFromFlutter) {
          window.loadFriendsFromFlutter([]);
        }
      ''');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to saved locations changes and update the WebView
    context.watch<SavedLocationsProvider>().savedLocationIds;
    // Send updated locations to WebView after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sendSavedLocationsToWebView();
      }
    });
    
    return WebViewWidget(controller: _controller);
  }
}
