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
  final ScrollController _scrollController = ScrollController();

  // For web/tablet pagination
  int webPageSize = 10;
  List<DocumentSnapshot> pageStarts = [];
  List<DocumentSnapshot> currentDocs = [];
  bool hasNextPage = false;

  // For mobile infinite scroll
  List<DocumentSnapshot> allMobileDocs = [];
  DocumentSnapshot? lastMobileDoc;
  bool hasMoreMobile = true;
  int mobilePageSize = 10;

  bool loading = false;
  String? statusFilter;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Loading moved to didChangeDependencies to ensure context is ready
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadFirst();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener for mobile infinite scroll
  void _onScroll() {
    if (!ResponsiveLayout.isMobile(context)) return;
    // trigger when scrolled near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!loading && hasMoreMobile) {
        _loadMoreMobile();
      }
    }
  }

  Future<void> _loadFirst() async {
    setState(() => loading = true);

    try {
      if (ResponsiveLayout.isMobile(context)) {
        // Mobile: load first batch for infinite scroll
        allMobileDocs.clear();
        lastMobileDoc = null;
        hasMoreMobile = true;

        final snap = await repo.getFirstPage(limit: mobilePageSize, statusFilter: statusFilter);

        allMobileDocs = snap.docs;
        lastMobileDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        // If we fetched as many as mobilePageSize, there may be more
        hasMoreMobile = snap.docs.length >= mobilePageSize;
        debugPrint("Mobile first load: ${allMobileDocs.length} docs, hasMore: $hasMoreMobile");
      } else {
        // Web/Tablet: load first page + check if there's a next page
        pageStarts.clear();
        currentDocs.clear();
        hasNextPage = false;

        // Load one extra to check if there's more data
        final snap = await repo.getFirstPage(limit: webPageSize + 1, statusFilter: statusFilter);

        if (snap.docs.length > webPageSize) {
          // There's more data
          currentDocs = snap.docs.sublist(0, webPageSize);
          hasNextPage = true;
        } else {
          // No more data
          currentDocs = snap.docs;
          hasNextPage = false;
        }

        if (currentDocs.isNotEmpty) {
          // store the start doc for this page (used for page counting / previous)
          pageStarts.add(currentDocs.first);
        }

        debugPrint("Web/Tablet first load: ${currentDocs.length} docs, hasNext: $hasNextPage");
      }
    } catch (e, st) {
      debugPrint("Error in _loadFirst: $e\n$st");
      // Optionally show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leads: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Mobile: Load more for infinite scroll
  Future<void> _loadMoreMobile() async {
    if (loading || !hasMoreMobile) return;

    // If no last doc yet (e.g. first page returned exactly page size and lastMobileDoc set),
    // the method will rely on lastMobileDoc presence before fetching.
    if (lastMobileDoc == null) {
      // Nothing more to load
      return;
    }

    setState(() => loading = true);

    try {
      final snap = await repo.getPage(
        startAfterDoc: lastMobileDoc!,
        limit: mobilePageSize,
        statusFilter: statusFilter,
      );

      if (snap.docs.isEmpty) {
        hasMoreMobile = false;
        debugPrint("Mobile loadMore: no more docs");
      } else {
        allMobileDocs.addAll(snap.docs);
        lastMobileDoc = snap.docs.last;
        hasMoreMobile = snap.docs.length >= mobilePageSize;
        debugPrint("Mobile loaded more: total ${allMobileDocs.length} docs, hasMore: $hasMoreMobile");
      }
    } catch (e, st) {
      debugPrint("Error in _loadMoreMobile: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more leads: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Web/Tablet: Next page
  Future<void> _next() async {
    if (currentDocs.isEmpty || !hasNextPage) return;

    setState(() => loading = true);

    try {
      final last = currentDocs.last;

      // Load one extra to check if there's more data after this page
      final snap = await repo.getPage(
        startAfterDoc: last,
        limit: webPageSize + 1,
        statusFilter: statusFilter,
      );

      if (snap.docs.isEmpty) {
        // no more data
        setState(() {
          hasNextPage = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No more leads')),
          );
        }
        return;
      }

      if (snap.docs.length > webPageSize) {
        // There's more data after this page
        currentDocs = snap.docs.sublist(0, webPageSize);
        hasNextPage = true;
      } else {
        // This is the last page
        currentDocs = snap.docs;
        hasNextPage = false;
      }

      if (currentDocs.isNotEmpty) {
        // Save the start doc for this page
        pageStarts.add(currentDocs.first);
      }

      debugPrint("Next page loaded: ${currentDocs.length} docs, hasNext: $hasNextPage");
    } catch (e, st) {
      debugPrint("Error in _next: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load next page: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Web/Tablet: Previous page
  Future<void> _previous() async {
    if (pageStarts.length <= 1) {
      // Already at first page - reload
      await _loadFirst();
      return;
    }

    setState(() => loading = true);

    try {
      // Remove current page start and use previous page's start
      pageStarts.removeLast();
      final startDoc = pageStarts.isNotEmpty ? pageStarts.last : null;

      QuerySnapshot snap;
      if (startDoc == null) {
        snap = await repo.getFirstPage(limit: webPageSize + 1, statusFilter: statusFilter);
      } else {
        // We want the page starting at startDoc; we fetch starting after it and take webPageSize+1
        snap = await repo.getPage(
          startAfterDoc: startDoc,
          limit: webPageSize + 1,
          statusFilter: statusFilter,
        );
      }

      if (snap.docs.length > webPageSize) {
        currentDocs = snap.docs.sublist(0, webPageSize);
        hasNextPage = true;
      } else {
        currentDocs = snap.docs;
        hasNextPage = false;
      }

      debugPrint("Previous page loaded: ${currentDocs.length} docs, hasNext: $hasNextPage");
    } catch (e, st) {
      debugPrint("Error in _previous: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load previous page: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  DataRow _makeRow(DocumentSnapshot doc) {
    final lead = Lead.fromSnapshot(doc);
    final createdStr = lead.createdAt != null
        ? DateFormat.yMd().add_jm().format(lead.createdAt.toDate())
        : '—';
    return DataRow(cells: [
      DataCell(Text(lead.leadName)),
      DataCell(Text(lead.mobile)),
      DataCell(Text(lead.projectName)),
      DataCell(Text(lead.status)),
      DataCell(Text(createdStr)),
    ]);
  }

  Widget _buildMobileView() {
    return Column(
      children: [
        // Header with filter
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text(
                'All Leads',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Make Dropdown nullable type String? so value: null is valid
              DropdownButton<String?>(
                hint: const Text('Filter'),
                value: statusFilter,
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('All')),
                  DropdownMenuItem<String?>(value: 'New', child: Text('New')),
                  DropdownMenuItem<String?>(value: 'Contacted', child: Text('Contacted')),
                  DropdownMenuItem<String?>(value: 'Interested', child: Text('Interested')),
                  DropdownMenuItem<String?>(value: 'Follow-up', child: Text('Follow-up')),
                  DropdownMenuItem<String?>(value: 'Meeting Scheduled', child: Text('Meeting Scheduled')),
                  DropdownMenuItem<String?>(value: 'Proposal Sent', child: Text('Proposal Sent')),
                  DropdownMenuItem<String?>(value: 'Negotiation', child: Text('Negotiation')),
                  DropdownMenuItem<String?>(value: 'Converted', child: Text('Converted')),
                  DropdownMenuItem<String?>(value: 'Not Interested', child: Text('Not Interested')),
                  DropdownMenuItem<String?>(value: 'Invalid', child: Text('Invalid')),
                  DropdownMenuItem<String?>(value: 'On Hold', child: Text('On Hold')),
                  DropdownMenuItem<String?>(value: 'Closed', child: Text('Closed')),
                ],
                onChanged: (v) async {
                  // v may be null (means All)
                  setState(() {
                    statusFilter = v;
                  });
                  await _loadFirst();
                },
              ),
            ],
          ),
        ),
        if (loading && allMobileDocs.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator())),
        if (allMobileDocs.isEmpty && !loading)
          const Expanded(child: Center(child: Text('No leads found'))),
        if (allMobileDocs.isNotEmpty)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: allMobileDocs.length + (hasMoreMobile ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= allMobileDocs.length) {
                  // loader indicator at the end
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final lead = Lead.fromSnapshot(allMobileDocs[index]);
                final createdStr = lead.createdAt != null
                    ? DateFormat.yMd().add_jm().format(lead.createdAt.toDate())
                    : '—';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                      lead.leadName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('📱 ${lead.mobile}'),
                        Text('📋 ${lead.projectName}'),
                        Text('📅 $createdStr', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        lead.status,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: _getStatusColor(lead.status),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildWebTabletView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header with filter and refresh
          Row(
            children: [
              const Text(
                'All Leads',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Text(
                'Page ${pageStarts.length} • Showing ${currentDocs.length} leads',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Spacer(),
              DropdownButton<String?>(
                hint: const Text('Filter by Status'),
                value: statusFilter,
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('All')),
                  DropdownMenuItem<String?>(value: 'New', child: Text('New')),
                  DropdownMenuItem<String?>(value: 'Contacted', child: Text('Contacted')),
                  DropdownMenuItem<String?>(value: 'Interested', child: Text('Interested')),
                  DropdownMenuItem<String?>(value: 'Follow-up', child: Text('Follow-up')),
                  DropdownMenuItem<String?>(value: 'Meeting Scheduled', child: Text('Meeting Scheduled')),
                  DropdownMenuItem<String?>(value: 'Proposal Sent', child: Text('Proposal Sent')),
                  DropdownMenuItem<String?>(value: 'Negotiation', child: Text('Negotiation')),
                  DropdownMenuItem<String?>(value: 'Converted', child: Text('Converted')),
                  DropdownMenuItem<String?>(value: 'Not Interested', child: Text('Not Interested')),
                  DropdownMenuItem<String?>(value: 'Invalid', child: Text('Invalid')),
                  DropdownMenuItem<String?>(value: 'On Hold', child: Text('On Hold')),
                  DropdownMenuItem<String?>(value: 'Closed', child: Text('Closed')),
                ],
                onChanged: (v) async {
                  setState(() => statusFilter = v);
                  await _loadFirst();
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loadFirst,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Expanded(
            child: currentDocs.isEmpty && !loading
                ? const Center(child: Text('No leads found'))
                : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
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
          ),
          const SizedBox(height: 12),
          // Pagination controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: pageStarts.length <= 1 || loading ? null : _previous,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 12),
              // Only show Next button if there's more data
              if (hasNextPage)
                ElevatedButton.icon(
                  onPressed: loading ? null : _next,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Next'),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue.shade100;
      case 'Contacted':
        return Colors.orange.shade100;
      case 'Interested':
        return Colors.green.shade100;
      case 'Follow-up':
        return Colors.amber.shade100;
      case 'Meeting Scheduled':
        return Colors.purple.shade100;
      case 'Proposal Sent':
        return Colors.cyan.shade100;
      case 'Negotiation':
        return Colors.indigo.shade100;
      case 'Converted':
        return Colors.green.shade300;
      case 'Not Interested':
        return Colors.red.shade100;
      case 'Invalid':
        return Colors.grey.shade400;
      case 'On Hold':
        return Colors.yellow.shade200;
      case 'Closed':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    return isMobile ? _buildMobileView() : _buildWebTabletView();
  }
}
