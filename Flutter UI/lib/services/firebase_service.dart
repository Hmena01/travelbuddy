import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      _logger.i('Signed in anonymously: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      _logger.e('Error signing in anonymously: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('Signed in with email: ${userCredential.user?.email}');
      return userCredential.user;
    } catch (e) {
      _logger.e('Error signing in with email: $e');
      return null;
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('Created user with email: ${userCredential.user?.email}');

      // Create user document in Firestore
      if (userCredential.user != null) {
        await createUserDocument(userCredential.user!);
      }

      return userCredential.user;
    } catch (e) {
      _logger.e('Error creating user: $e');
      return null;
    }
  }

  // Create user document in Firestore
  Future<void> createUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _logger.i('Created/updated user document for: ${user.uid}');
    } catch (e) {
      _logger.e('Error creating user document: $e');
    }
  }

  // Save chat message to Firestore
  Future<void> saveChatMessage({
    required String text,
    required bool isUser,
    String? sessionId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        _logger.w('No user logged in, cannot save chat message');
        return;
      }

      await _firestore.collection('chats').add({
        'userId': user.uid,
        'sessionId': sessionId ?? DateTime.now().toIso8601String(),
        'text': text,
        'isUser': isUser,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _logger.i('Saved chat message to Firestore');
    } catch (e) {
      _logger.e('Error saving chat message: $e');
    }
  }

  // Get chat history
  Stream<List<ChatMessageData>> getChatHistory({String? sessionId}) {
    final user = currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    Query query =
        _firestore.collection('chats').where('userId', isEqualTo: user.uid);

    if (sessionId != null) {
      query = query.where('sessionId', isEqualTo: sessionId);
    }

    return query
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ChatMessageData(
          id: doc.id,
          text: data['text'] ?? '',
          isUser: data['isUser'] ?? false,
          timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
          sessionId: data['sessionId'] ?? '',
        );
      }).toList();
    });
  }

  // Upload file to Firebase Storage
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final user = currentUser;
      if (user == null) {
        _logger.w('No user logged in, cannot upload file');
        return null;
      }

      final ref = _storage.ref().child('users/${user.uid}/$fileName');
      final uploadTask = await ref.putString(filePath);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      _logger.i('File uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      _logger.e('Error uploading file: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _logger.i('User signed out');
    } catch (e) {
      _logger.e('Error signing out: $e');
    }
  }
}

// Chat message data model
class ChatMessageData {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String sessionId;

  ChatMessageData({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.sessionId,
  });
}
