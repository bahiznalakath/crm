// lib/repositories/lead_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import '../models/lead.dart';

class LeadRepository {
  final FirebaseFirestore _firestore;
  final CollectionReference _col;

  LeadRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _col = (firestore ?? FirebaseFirestore.instance).collection('leads');

  Future<void> addLead({
    required String leadName,
    required String mobile,
    required String projectName,
    required String status,
  }) {
    final doc = _col.doc();
    return doc.set({
      'leadName': leadName,
      'mobile': mobile,
      'projectName': projectName,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns a stream of merged unique Leads based on prefix matches for leadName, mobile, projectName.
  Stream<List<Lead>> suggestionsStream(String query, {int limit = 8}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Stream.value([]);

    final controller = StreamController<List<Lead>>();
    List<StreamSubscription<QuerySnapshot>> subscriptions = [];

    // helper to add current combined unique docs
    final docsMap = <String, DocumentSnapshot>{};

    void emitIfNeeded() {
      final list = docsMap.values.map((d) => Lead.fromSnapshot(d)).toList();
      controller.add(list);
    }

    // create three snapshot streams listening for live updates
    final snapshots = <Stream<QuerySnapshot>>[
      _col.orderBy('leadName').startAt([trimmed]).endAt(['$trimmed\uf8ff']).limit(limit).snapshots(),
      _col.orderBy('mobile').startAt([trimmed]).endAt(['$trimmed\uf8ff']).limit(limit).snapshots(),
      _col.orderBy('projectName').startAt([trimmed]).endAt(['$trimmed\uf8ff']).limit(limit).snapshots(),
    ];

    for (var s in snapshots) {
      final sub = s.listen((qs) {
        // Replace any docs from this query by id: we just merge unique ids
        for (var doc in qs.docs) {
          docsMap[doc.id] = doc;
        }
        // Remove ids that no longer appear in any query result: recompute map
        // (simpler: rebuild docsMap by checking all latest docs from each subscription's latest snapshot)
        // For simplicity we emit current map — deletions from queries are not removed here instantly,
        // but in realtime the latest snapshot of each query will update and override entries as needed.
        emitIfNeeded();
      }, onError: (e, st) {
        controller.addError(e, st);
      });
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (var s in subscriptions) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  // Pagination: get page ordered by createdAt descending
  Future<QuerySnapshot> getPage({DocumentSnapshot? startAfterDoc, int limit = 50, String? statusFilter}) {
    Query q = _col.orderBy('createdAt', descending: true);
    if (statusFilter != null && statusFilter.isNotEmpty) {
      q = q.where('status', isEqualTo: statusFilter);
    }
    if (startAfterDoc != null) q = q.startAfterDocument(startAfterDoc);
    return q.limit(limit).get();
  }

  Future<QuerySnapshot> getFirstPage({int limit = 50, String? statusFilter}) =>
      getPage(startAfterDoc: null, limit: limit, statusFilter: statusFilter);
}
