// lib/providers/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/lead_repository.dart';

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository();
});
