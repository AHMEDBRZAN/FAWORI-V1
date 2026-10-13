import 'package:cloud_firestore/cloud_firestore.dart';

class FireInvoiceItem {
  final String name;
  final int qty;
  final int price;
  final double unitPrice;
  final double subtotal;
  FireInvoiceItem({
    required this.name,
    this.qty = 1,
    this.price = 0,
    this.unitPrice = 0,
    this.subtotal = 0,
  });
  Map<String, dynamic> toMap() => {
        'name': name,
        'qty': qty,
        'price': price,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };
  factory FireInvoiceItem.fromMap(Map<String, dynamic> m) => FireInvoiceItem(
        name: '${m['name'] ?? ''}',
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        price: (m['price'] as num?)?.toInt() ?? 0,
        unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
        subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
      );
}

class FireInvoice {
  final String id;
  final String userId;
  final String date;
  final String type;
  final String no;
  final double total;
  final int points;
  final int stored;
  final List<FireInvoiceItem> items;
  final String legacyNo;
  final String customerName;
  final String cashier;
  final String time;
  final String source;

  FireInvoice({
    required this.id,
    required this.userId,
    required this.date,
    this.type = 'sale',
    this.no = '',
    this.total = 0,
    this.points = 0,
    this.stored = 0,
    this.items = const [],
    this.legacyNo = '',
    this.customerName = '',
    this.cashier = '',
    this.time = '',
    this.source = '',
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'date': date,
        'type': type,
        'no': no,
        'total': total,
        'points': points,
        'stored': stored,
        'items': items.map((e) => e.toMap()).toList(),
        'legacy_no': legacyNo,
        'customer_name': customerName,
        'cashier': cashier,
        'time': time,
        'source': source,
      };

  factory FireInvoice.fromMap(String id, Map<String, dynamic> m) =>
      FireInvoice(
        id: id,
        userId: '${m['userId'] ?? ''}',
        date: '${m['date'] ?? ''}',
        type: '${m['type'] ?? 'sale'}',
        no: '${m['no'] ?? ''}',
        total: (m['total'] as num?)?.toDouble() ?? 0,
        points: (m['points'] as num?)?.toInt() ?? 0,
        stored: (m['stored'] as num?)?.toInt() ?? 0,
        items: (m['items'] as List<dynamic>? ?? [])
            .map((e) =>
                FireInvoiceItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        legacyNo: '${m['legacy_no'] ?? ''}',
        customerName: '${m['customer_name'] ?? ''}',
        cashier: '${m['cashier'] ?? ''}',
        time: '${m['time'] ?? ''}',
        source: '${m['source'] ?? ''}',
      );
}

class InvoiceRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('invoices');

  Future<List<FireInvoice>> list() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => FireInvoice.fromMap(
            d.id, Map<String, dynamic>.from(d.data() as Map)))
        .toList();
  }

  Future<void> upsert(FireInvoice inv) => _col.doc(inv.id).set(inv.toMap());

  Future<void> update(String id, Map<String, dynamic> fields) =>
      _col.doc(id).update(fields);

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> markMigration(Map<String, dynamic> m) =>
      _db.collection('meta').doc('migration').set(m);

  Future<Map<String, dynamic>?> migrationInfo() async {
    final d = await _db.collection('meta').doc('migration').get();
    return d.exists ? Map<String, dynamic>.from(d.data() as Map) : null;
  }

  Future<void> importMany(List<FireInvoice> list) async {
    WriteBatch? batch;
    int count = 0;
    for (final inv in list) {
      batch ??= _db.batch();
      batch.set(_col.doc(inv.id), inv.toMap());
      count++;
      if (count >= 400) {
        await batch.commit();
        batch = null;
        count = 0;
      }
    }
    if (batch != null) await batch.commit();
  }
}

final invoiceRepo = InvoiceRepo();

class FireReturn {
  final String id;
  final String orderId;
  final String userId;
  final String date;
  final String no;
  final String purchaseNo;
  final int total;
  final int points;
  final int stored;
  final List<FireInvoiceItem> items;

  FireReturn({
    required this.id,
    this.orderId = '',
    required this.userId,
    required this.date,
    this.no = '',
    this.purchaseNo = '',
    this.total = 0,
    this.points = 0,
    this.stored = 0,
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'userId': userId,
        'date': date,
        'no': no,
        'purchaseNo': purchaseNo,
        'total': total,
        'points': points,
        'stored': stored,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory FireReturn.fromMap(String id, Map<String, dynamic> m) => FireReturn(
        id: id,
        orderId: '${m['orderId'] ?? ''}',
        userId: '${m['userId'] ?? ''}',
        date: '${m['date'] ?? ''}',
        no: '${m['no'] ?? ''}',
        purchaseNo: '${m['purchaseNo'] ?? ''}',
        total: (m['total'] as num?)?.toInt() ?? 0,
        points: (m['points'] as num?)?.toInt() ?? 0,
        stored: (m['stored'] as num?)?.toInt() ?? 0,
        items: (m['items'] as List<dynamic>? ?? [])
            .map((e) =>
                FireInvoiceItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class ReturnRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('returns');

  Future<List<FireReturn>> list() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => FireReturn.fromMap(
            d.id, Map<String, dynamic>.from(d.data() as Map)))
        .toList();
  }

  Future<void> upsert(FireReturn r) => _col.doc(r.id).set(r.toMap());

  Future<void> update(String id, Map<String, dynamic> fields) =>
      _col.doc(id).update(fields);

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> importMany(List<FireReturn> list) async {
    WriteBatch? batch;
    int count = 0;
    for (final r in list) {
      batch ??= _db.batch();
      batch.set(_col.doc(r.id), r.toMap());
      count++;
      if (count >= 400) {
        await batch.commit();
        batch = null;
        count = 0;
      }
    }
    if (batch != null) await batch.commit();
  }
}

final returnsRepo = ReturnRepo();
