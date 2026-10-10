// طبقة المستخدمين الموحدة - تطبيق Firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String id;
  final String phone;
  final String name;
  final String role;
  final int points;
  final int stored;

  const AppUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.points = 0,
    this.stored = 0,
  });

  Map<String, dynamic> toMap() => {
        'phone': phone,
        'name': name,
        'role': role,
        'points': points,
        'stored': stored,
      };

  factory AppUser.fromDoc(String id, Map<String, dynamic> m) => AppUser(
        id: id,
        phone: '${m['phone'] ?? ''}',
        name: '${m['name'] ?? ''}',
        role: '${m['role'] ?? 'client'}',
        points: (m['points'] as num?)?.toInt() ?? 0,
        stored: (m['stored'] as num?)?.toInt() ?? 0,
      );
}

abstract class UserRepo {
  Future<AppUser?> login(String phone, String password);
  Future<AppUser?> register(String phone, String name, String password);
  Future<AppUser> guest();
  Future<AppUser?> restore();
  Future<void> logout();
  Future<void> save(AppUser u);
  Future<List<AppUser>> listUsers();
  Future<AppUser> createUser(
      String phone, String name, String password, String role);
  Future<void> updateUser(String id, Map<String, dynamic> fields);
  Future<void> deleteUser(String id);
}

class FbUserRepo implements UserRepo {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _email(String phone) => '${phone.trim()}@fawori.app';

  Future<AppUser?> _profile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(uid, doc.data()!);
  }

  @override
  Future<AppUser?> login(String phone, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: _email(phone), password: password);
      return _profile(cred.user!.uid);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser?> register(String phone, String name, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: _email(phone), password: password);
      final u = AppUser(
          id: cred.user!.uid, phone: phone.trim(), name: name, role: 'client');
      await _db.collection('users').doc(cred.user!.uid).set(u.toMap());
      return u;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> guest() async {
    final cred = await _auth.signInAnonymously();
    return AppUser(id: cred.user!.uid, phone: '', name: 'ضيف', role: 'guest');
  }

  @override
  Future<AppUser?> restore() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    if (u.isAnonymous) {
      return AppUser(id: u.uid, phone: '', name: 'ضيف', role: 'guest');
    }
    return _profile(u.uid);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<void> save(AppUser u) async {
    await _db
        .collection('users')
        .doc(u.id)
        .set(u.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<AppUser>> listUsers() async {
    final snap = await _db.collection('users').get();
    final list = snap.docs
        .map((d) => AppUser.fromDoc(d.id, d.data() ?? {}))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<AppUser> createUser(
      String phone, String name, String password, String role) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: _email(phone), password: password);
    final u = AppUser(
      id: cred.user!.uid,
      phone: phone.trim(),
      name: name.trim(),
      role: role,
      points: 0,
      stored: 0,
    );
    await _db.collection('users').doc(cred.user!.uid).set(u.toMap());
    return u;
  }

  @override
  Future<void> updateUser(String id, Map<String, dynamic> fields) async {
    await _db
        .collection('users')
        .doc(id)
        .set(fields, SetOptions(merge: true));
  }

  @override
  Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).delete();
  }
}

final UserRepo userRepo = FbUserRepo();
