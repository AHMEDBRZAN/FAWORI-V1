import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ مستودع المفضلة
class FavoritesRepo {
  DocumentReference _doc(String uid) =>
      FirebaseFirestore.instance.collection('favorites').doc(uid);

  Future<List<String>> load(String uid) async {
    if (uid.isEmpty) return [];
    final d = await _doc(uid).get();
    final m = d.data() as Map<String, dynamic>?;
    if (m == null) return [];
    final ids = m['ids'];
    if (ids is List) return ids.map((e) => '$e').toList();
    return [];
  }

  Stream<List<String>> stream(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _doc(uid).snapshots().map((d) {
      final m = d.data() as Map<String, dynamic>?;
      if (m == null) return <String>[];
      final ids = m['ids'];
      if (ids is List) return ids.map((e) => '$e').toList();
      return <String>[];
    });
  }

  Future<void> toggle(String uid, String productId) async {
    if (uid.isEmpty) return;
    final cur = await load(uid);
    if (cur.contains(productId)) {
      cur.remove(productId);
    } else {
      cur.add(productId);
    }
    await _doc(uid).set({'ids': cur});
  }
}

final favoritesRepo = FavoritesRepo();
