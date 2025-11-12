// lib/pages/add_lead_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class AddLeadPage extends ConsumerStatefulWidget {
  const AddLeadPage({super.key});
  @override
  ConsumerState<AddLeadPage> createState() => _AddLeadPageState();
}

class _AddLeadPageState extends ConsumerState<AddLeadPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _projectController = TextEditingController();
  String _status = 'New';
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _projectController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(leadRepositoryProvider);
      await repo.addLead(
        leadName: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        projectName: _projectController.text.trim(),
        status: _status,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead added')));
      _formKey.currentState!.reset();
      _status = 'New';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // center and constraint for wide screens
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Add Lead', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Lead Name'),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile Number'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 6) return 'Invalid mobile';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _projectController,
                    decoration: const InputDecoration(labelText: 'Project Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: 'New', child: Text('New')),
                      DropdownMenuItem(value: 'Follow-up', child: Text('Follow-up')),
                      DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'New'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Save'),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
