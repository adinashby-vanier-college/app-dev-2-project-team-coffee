import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../widgets/nav_bar.dart';
import '../widgets/user_menu_widget.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/friends_service.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import 'conversation_detail_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final FriendsService _friendsService = FriendsService();

  void _onNavBarTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/friends');
        break;
      case 2:
        break;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.user == null) {
      return Scaffold(
        appBar: AppBar(
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: UserMenuWidget(),
            ),
          ],
          title: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Image.asset(
              'lib/assets/FriendMap.png',
              height: 25,
              fit: BoxFit.contain,
            ),
          ),
          centerTitle: false,
        ),
        body: const Center(
          child: Text('Please sign in to view chats'),
        ),
        bottomNavigationBar: NavBar(
          currentIndex: 2,
          onTap: (index) => _onNavBarTap(context, index),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: UserMenuWidget(),
          ),
        ],
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Image.asset(
            'lib/assets/FriendMap.png',
            height: 25,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _chatService.getConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('ChatPage: Stream error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading conversations: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check console logs for details',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final conversations = snapshot.data ?? [];
          debugPrint('ChatPage: Displaying ${conversations.length} conversations');

          if (conversations.isEmpty) {
            return const Center(
              child: Text(
                'No conversations yet.\nStart chatting with your friends!',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final otherUserId = conversation.getOtherParticipant(
                authProvider.user!.uid,
              );

              return FutureBuilder<UserModel?>(
                future: _friendsService.getFriendProfiles([otherUserId])
                    .then((list) => list.isNotEmpty ? list.first : null),
                builder: (context, userSnapshot) {
                  final otherUser = userSnapshot.data;
                  var displayName = otherUser?.name;
                  if (displayName == null || displayName.isEmpty) {
                    displayName = otherUser?.displayName;
                  }
                  if (displayName == null || displayName.isEmpty) {
                    displayName = otherUser?.email;
                  }
                  if (displayName == null || displayName.isEmpty) {
                    displayName = 'Unknown User';
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: otherUser?.photoURL != null
                          ? CachedNetworkImageProvider(otherUser!.photoURL!)
                          : null,
                      child: otherUser?.photoURL == null
                          ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(displayName),
                    subtitle: conversation.lastMessage != null
                        ? Text(
                            conversation.lastMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : const Text('No messages yet'),
                    trailing: conversation.lastMessageTime != null
                        ? Text(
                            _formatTime(conversation.lastMessageTime),
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConversationDetailPage(
                            conversationId: conversation.id,
                            otherUser: otherUser ?? UserModel(uid: otherUserId),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: NavBar(
        currentIndex: 2,
        onTap: (index) => _onNavBarTap(context, index),
      ),
    );
  }
}
