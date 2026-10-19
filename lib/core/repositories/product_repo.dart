import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ نموذج منتج Firestore
class FireProduct {
  final String id;
  final String name;
  final String brand;
  final String description;
  final String image;
  final String category;
  final String type;
  final int price;

  const FireProduct({
    required this.id,
    required this.name,
    required this.brand,
    this.description = '',
    this.image = '',
    this.category = '',
    this.type = '',
    this.price = 0,
  });

  factory FireProduct.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return FireProduct(
      id: d.id,
      name: '${m['name'] ?? ''}',
      brand: '${m['brand'] ?? ''}',
      description: '${m['description'] ?? ''}',
      image: '${m['image'] ?? ''}',
      category: '${m['category'] ?? ''}',
      type: '${m['type'] ?? ''}',
      price: (m['price'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'brand': brand,
        'description': description,
        'image': image,
        'category': category,
        'type': type,
        'price': price,
      };
}

/// ✅ مستودع المنتجات
class ProductRepo {
  CollectionReference get _col =>
      FirebaseFirestore.instance.collection('products');

  Future<List<FireProduct>> list() async {
    final snap = await _col.get();
    final out = snap.docs.map(FireProduct.fromDoc).toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// ✅ استماع حي لتغييرات المنتجات
  Stream<List<FireProduct>> stream() {
    return _col.snapshots().map((snap) {
      final out = snap.docs.map(FireProduct.fromDoc).toList();
      out.sort((a, b) => a.name.compareTo(b.name));
      return out;
    });
  }

  Future<void> save(FireProduct p) => _col.doc(p.id).set(p.toMap());

  Future<void> update(String id, Map<String, dynamic> patch) =>
      _col.doc(id).update(patch);

  Future<void> delete(String id) => _col.doc(id).delete();

  /// ✅ ترحيل دفعات كبيرة (400 لكل دفعة)
  Future<void> importMany(List<FireProduct> items) async {
    WriteBatch? batch;
    int count = 0;
    for (final p in items) {
      batch ??= FirebaseFirestore.instance.batch();
      batch.set(_col.doc(p.id), p.toMap());
      count++;
      if (count == 400) {
        await batch.commit();
        batch = null;
        count = 0;
      }
    }
    if (batch != null) await batch.commit();
  }
}

final productRepo = ProductRepo();
