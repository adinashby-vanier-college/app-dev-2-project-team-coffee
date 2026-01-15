import 'package:cloud_firestore/cloud_firestore.dart';

class MomentModel {
  final String id;
  final String title;
  final String? description;
  final String locationId;
  final String locationName;
  final String locationAddress;
  final DateTime dateTime;
  final String createdBy;
  final DateTime createdAt;
  final String? shareCode; // Unique code for shareable web link
  final List<String> invitedFriends; // List of friend UIDs invited
  final Map<String, String> responses; // UID/guestName -> 'going', 'maybe', 'not_going'
  final List<Map<String, dynamic>> guestResponses; // Responses from non-app users via web form

  MomentModel({
    required this.id,
    required this.title,
    this.description,
    required this.locationId,
    required this.locationName,
    required this.locationAddress,
    required this.dateTime,
    required this.createdBy,
    required this.createdAt,
    this.shareCode,
    this.invitedFriends = const [],
    this.responses = const {},
    this.guestResponses = const [],
  });

  factory MomentModel.fromFirestore(Map<String, dynamic> doc, String id) {
    return MomentModel(
      id: id,
      title: doc['title'] as String? ?? '',
      description: doc['description'] as String?,
      locationId: doc['locationId'] as String? ?? '',
      locationName: doc['locationName'] as String? ?? '',
      locationAddress: doc['locationAddress'] as String? ?? '',
      dateTime: (doc['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: doc['createdBy'] as String? ?? '',
      createdAt: (doc['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shareCode: doc['shareCode'] as String?,
      invitedFriends: List<String>.from(doc['invitedFriends'] as List? ?? []),
      responses: Map<String, String>.from(doc['responses'] as Map? ?? {}),
      guestResponses: List<Map<String, dynamic>>.from(
        (doc['guestResponses'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'locationId': locationId,
      'locationName': locationName,
      'locationAddress': locationAddress,
      'dateTime': Timestamp.fromDate(dateTime),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'shareCode': shareCode,
      'invitedFriends': invitedFriends,
      'responses': responses,
      'guestResponses': guestResponses,
    };
  }

  MomentModel copyWith({
    String? id,
    String? title,
    String? description,
    String? locationId,
    String? locationName,
    String? locationAddress,
    DateTime? dateTime,
    String? createdBy,
    DateTime? createdAt,
    String? shareCode,
    List<String>? invitedFriends,
    Map<String, String>? responses,
    List<Map<String, dynamic>>? guestResponses,
  }) {
    return MomentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      dateTime: dateTime ?? this.dateTime,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      shareCode: shareCode ?? this.shareCode,
      invitedFriends: invitedFriends ?? this.invitedFriends,
      responses: responses ?? this.responses,
      guestResponses: guestResponses ?? this.guestResponses,
    );
  }

  bool get isUpcoming => dateTime.isAfter(DateTime.now());
  bool get isPast => dateTime.isBefore(DateTime.now());
  
  int get goingCount => responses.values.where((r) => r == 'going').length + 
      guestResponses.where((g) => g['response'] == 'going').length;
  int get maybeCount => responses.values.where((r) => r == 'maybe').length +
      guestResponses.where((g) => g['response'] == 'maybe').length;
  
  /// Generate the shareable URL for this moment
  String getShareUrl(String baseUrl) {
    if (shareCode == null) return '';
    return '$baseUrl/moment/$shareCode';
  }
}
