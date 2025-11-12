// lib/pages/all_leads_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/lead_repository.dart';
import '../models/lead.dart';
import '../common/responsive_layout.dart';

class AllLeadsPage extends StatefulWidget {
  const AllLeadsPage({super.key});
  @override
  State<AllLeadsPage> createState() => _AllLeadsPageState();
}

class _AllLeadsPageState extends State<AllLeadsPage> {
  final repo = LeadRepository();
  final int pageSize = 50;

  List<QueryDocumentSnapshot> pageStarts = [];
  List<DocumentSnapshot> currentDocs = [];
  bool loading = false;
  String? statusFilter;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() => loading = true);
    final snap = await repo.getFirstPage(limit: pageSize, statusFilter: statusFilter);
    currentDocs = snap.docs;
    debugPrint("snap:${snap}");
    debugPrint("Print:${currentDocs}");
    pageStarts = [];
    if (snap.docs.isNotEmpty) pageStarts.add(snap.docs.first);
    setState(() => loading = false);
  }

  Future<void> _next() async {
    if (currentDocs.isEmpty) return;
    setState(() => loading = true);
    final last = currentDocs.last;
    final snap = await repo.getPage(startAfterDoc: last, limit: pageSize, statusFilter: statusFilter);
    if (snap.docs.isEmpty) {
      setState(() => loading = false);
      return;
    }
    pageStarts.add(snap.docs.first);
    currentDocs = snap.docs;
    setState(() => loading = false);
  }

  Future<void> _previous() async {
    if (pageStarts.length <= 1) {
      await _loadFirst();
      return;
    }
    setState(() => loading = true);
    pageStarts.removeLast();
    final startDoc = pageStarts.isNotEmpty ? pageStarts.last : null;
    QuerySnapshot snap;
    if (startDoc == null) {
      snap = await repo.getFirstPage(limit: pageSize, statusFilter: statusFilter);
    } else {
      snap = await repo.getPage(startAfterDoc: startDoc, limit: pageSize, statusFilter: statusFilter);
    }
    currentDocs = snap.docs;
    setState(() => loading = false);
  }

  DataRow _makeRow(DocumentSnapshot doc) {
    final lead = Lead.fromSnapshot(doc);
    final createdStr = lead.createdAt != null ? DateFormat.yMd().add_jm().format(lead.createdAt.toDate()) : '—';
    return DataRow(cells: [
      DataCell(Text(lead.leadName)),
      DataCell(Text(lead.mobile)),
      DataCell(Text(lead.projectName)),
      DataCell(Text(lead.status)),
      DataCell(Text(createdStr)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          const Text('All Leads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          DropdownButton<String>(
            hint: const Text('Filter'),
            value: statusFilter,
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'New', child: Text('New')),
              DropdownMenuItem(value: 'Follow-up', child: Text('Follow-up')),
              DropdownMenuItem(value: 'Closed', child: Text('Closed')),
            ],
            onChanged: (v) async {
              setState(() => statusFilter = v);
              await _loadFirst();
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _loadFirst, child: const Text('Refresh')),
        ]),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator(),
        Expanded(
          child: currentDocs.isEmpty && !loading
              ? const Center(child: Text('No leads found'))
              : SingleChildScrollView(
            child: isMobile
                ? Column(children: currentDocs.map((d) {
              final lead = Lead.fromSnapshot(d);
              return ListTile(
                title: Text(lead.leadName),
                subtitle: Text('${lead.mobile} • ${lead.projectName}'),
                trailing: Text(lead.status),
              );
            }).toList())
                : DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Mobile')),
                DataColumn(label: Text('Project')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Created')),
              ],
              rows: currentDocs.map(_makeRow).toList(),
            ),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(onPressed: pageStarts.isEmpty ? null : _previous, child: const Text('Previous')),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: currentDocs.length < pageSize ? null : _next, child: const Text('Next')),
        ]),
      ]),
    );
  }
}
