// طبقة الطلبات الموحدة - تطبيق Firebase
import 'package:cloud_firestore/cloud_firestore.dart';

class FireOrderItem {
  final String name;
  final int qty;

  const FireOrderItem({required this.name, required this.qty});

  Map<String, dynamic> toMap() => {'name': name, 'qty': qty};

  factory FireOrderItem.fromMap(Map<String, dynamic> m) => FireOrderItem(
        name: '${m['name'] ?? ''}',
        qty: (m['qty'] as num?)?.toInt() ?? 0,
      );
}

class FireOrder {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String phone;
  final String date;
  final String status; // pending | accepted | rejected | returned
  final double total;
  final String invoiceNo;
  final List<FireOrderItem> items;

  const FireOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.phone,
    required this.date,
    required this.status,
    required this.total,
    this.invoiceNo = '',
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'phone': phone,
        'date': date,
        'status': status,
        'total': total,
        'invoiceNo': invoiceNo,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory FireOrder.fromDoc(String id, Map<String, dynamic> m) => FireOrder(
        id: id,
        userId: '${m['userId'] ?? ''}',
        userName: '${m['userName'] ?? ''}',
        userRole: '${m['userRole'] ?? ''}',
        phone: '${m['phone'] ?? ''}',
        date: '${m['date'] ?? ''}',
        status: '${m['status'] ?? 'pending'}',
        total: (m['total'] as num?)?.toDouble() ?? 0,
        invoiceNo: '${m['invoiceNo'] ?? ''}',
        items: ((m['items'] as List? ?? [])
            .map((e) => FireOrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()),
      );
}

abstract class OrdersRepo {
  Future<String> add(FireOrder o);
  Future<List<FireOrder>> list();
  Future<List<FireOrder>> mine(String uid);
  Future<List<FireOrder>> pending();
  Future<void> setStatus(String id, String status);
  Future<void> setInvoiceNo(String id, String no);
  Future<void> remove(String id);
}

class FbOrdersRepo implements OrdersRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<String> add(FireOrder o) async {
    final ref = _db.collection('orders').doc();
    await ref.set(o.toMap());
    return ref.id;
  }

  @override
  Future<List<FireOrder>> list() async {
    final snap = await _db.collection('orders').get();
    final list = snap.docs
        .map((d) => FireOrder.fromDoc(d.id, d.data() ?? {}))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<List<FireOrder>> mine(String uid) async {
    final snap = await _db
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .get();
    final list = snap.docs
        .map((d) => FireOrder.fromDoc(d.id, d.data() ?? {}))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<List<FireOrder>> pending() async {
    final snap = await _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .get();
    final list = snap.docs
        .map((d) => FireOrder.fromDoc(d.id, d.data() ?? {}))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<void> setStatus(String id, String status) async {
    await _db.collection('orders').doc(id).set(
        {'status': status}, SetOptions(merge: true));
  }

  @override
  Future<void> setInvoiceNo(String id, String no) async {
    await _db.collection('orders').doc(id).set(
        {'invoiceNo': no}, SetOptions(merge: true));
  }

  @override
  Future<void> remove(String id) async {
    await _db.collection('orders').doc(id).delete();
  }
}

final OrdersRepo ordersRepo = FbOrdersRepo();
