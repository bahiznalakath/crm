// lib/widgets/lead_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';

class LeadCard extends StatelessWidget {
  final Lead lead;
  const LeadCard({required this.lead, super.key});

  @override
  Widget build(BuildContext context) {
    final createdStr = lead.createdAt != null ? DateFormat.yMd().add_jm().format(lead.createdAt.toDate()) : '—';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lead.leadName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Phone: ${lead.mobile}'),
          Text('Project: ${lead.projectName}'),
          Text('Status: ${lead.status}'),
          const SizedBox(height: 8),
          Text('Created: $createdStr', style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
