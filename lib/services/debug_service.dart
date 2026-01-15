import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebugService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> seedFriendLocations() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Create 3 dummy friends
    final friends = [
      {
        'uid': 'friend_alice',
        'name': 'Alice',
        'email': 'alice@example.com',
        'photoURL': 'https://i.pravatar.cc/150?u=alice',
        'location': {'x': 1200, 'y': 1500}, // Near Downtown
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'friend_bob',
        'name': 'Bob',
        'email': 'bob@example.com',
        'photoURL': 'https://i.pravatar.cc/150?u=bob',
        'location': {'x': 2000, 'y': 1100}, // Near Old Port
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'friend_charlie',
        'name': 'Charlie',
        'email': 'charlie@example.com',
        'photoURL': 'https://i.pravatar.cc/150?u=charlie',
        'location': {'x': 1500, 'y': 2200}, // Near Griffintown
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final friend in friends) {
      await _firestore.collection('users').doc(friend['uid'] as String).set(friend);
    }

    // 2. Add them to current user's friend list
    await _firestore.collection('users').doc(user.uid).update({
      'friends': FieldValue.arrayUnion(friends.map((f) => f['uid']).toList()),
    });
    
    print('Seeded 3 friends with locations.');
  }
}
