import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/saved_locations_provider.dart';
import '../services/saved_locations_service.dart';
import '../services/locations_service.dart';
import '../utils/locations_initializer.dart';
import '../services/friends_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';

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
        'FlutterShowSendSceneModal',
        onMessageReceived: (JavaScriptMessage message) {
          final locationId = message.message;
          debugPrint('LOG-WEBVIEW: showSendSceneModal triggered for $locationId');
          // The HTML modal will handle displaying - just send fresh friends data
          _sendFriendsToWebView();
        },
      )
      ..addJavaScriptChannel(
        'FlutterGetFriends',
        onMessageReceived: (JavaScriptMessage message) async {
          debugPrint('LOG-WEBVIEW: FlutterGetFriends requested');
          await _sendFriendsToWebView();
        },
      )
      ..addJavaScriptChannel(
        'FlutterSendScene',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            debugPrint('LOG-WEBVIEW: FlutterSendScene received: ${message.message}');
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final locationId = data['locationId'] as String;
            final friendIds = List<String>.from(data['friendIds'] as List);
            
            debugPrint('LOG-WEBVIEW: Sending scene - locationId: $locationId, friendIds: $friendIds');
            
            final chatService = ChatService();
            
            for (final friendId in friendIds) {
              final conversationId = await chatService.getOrCreateConversation(friendId);
              await chatService.sendMessage(
                conversationId,
                locationId: locationId,
              );
              debugPrint('LOG-WEBVIEW: Sent scene to friend $friendId in conversation $conversationId');
            }
            
            debugPrint('LOG-WEBVIEW: Successfully sent scene to ${friendIds.length} friends');
          } catch (e, stackTrace) {
            debugPrint('LOG-WEBVIEW: ERROR sending scene: $e');
            debugPrint('LOG-WEBVIEW: Stack trace: $stackTrace');
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
            // Load saved locations from Firebase (will be sent via provider listener)
            _sendSavedLocationsToWebView();
            // Load friends from Firebase and send to WebView
            await _sendFriendsToWebView();
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

  Future<void> _sendFriendsToWebView() async {
    if (!mounted) return;
    try {
      debugPrint('LOG-WEBVIEW: Fetching friends from Firebase...');
      final friendUids = await _friendsService.getFriendsListOnce();
      debugPrint('LOG-WEBVIEW: Got ${friendUids.length} friend UIDs');
      
      if (friendUids.isEmpty) {
        debugPrint('LOG-WEBVIEW: No friends found, sending empty list');
        final emptyList = jsonEncode([]);
        _controller.runJavaScript('''
          if (window.loadFriendsFromFlutter) {
            window.loadFriendsFromFlutter($emptyList);
          } else {
            window._friendsQueue = window._friendsQueue || [];
            window._friendsQueue.push($emptyList);
          }
        ''');
        return;
      }
      
      final friendProfiles = await _friendsService.getFriendProfiles(friendUids);
      debugPrint('LOG-WEBVIEW: Loaded ${friendProfiles.length} friend profiles');
      
      // Helper function to get display name with email fallback
      String getDisplayName(UserModel friend) {
        if (friend.name?.isNotEmpty == true) {
          return friend.name!;
        }
        if (friend.displayName?.isNotEmpty == true) {
          return friend.displayName!;
        }
        return friend.email ?? 'Unknown';
      }

      // Helper function to get initials
      String getInitials(UserModel friend) {
        final displayName = getDisplayName(friend);
        if (displayName.isEmpty || displayName == 'Unknown') {
          return '?';
        }
        final trimmed = displayName.trim();
        final parts = trimmed.split(' ');
        if (parts.length >= 2) {
          return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        }
        return trimmed[0].toUpperCase();
      }

      // Convert friend profiles to JSON format expected by JavaScript
      final friendsJson = jsonEncode(
        friendProfiles.map((friend) => {
          'id': friend.uid,
          'name': getDisplayName(friend),
          'photoURL': friend.photoURL ?? '',
          'email': friend.email ?? '',
          'avatar': getInitials(friend),
        }).toList(),
      );
      
      _controller.runJavaScript('''
        if (window.loadFriendsFromFlutter) {
          try {
            const friendsData = $friendsJson;
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
      debugPrint('LOG-WEBVIEW: Error loading friends: $e');
      // Send empty list on error
      final emptyList = jsonEncode([]);
      _controller.runJavaScript('''
        if (window.loadFriendsFromFlutter) {
          window.loadFriendsFromFlutter($emptyList);
        }
      ''');
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
