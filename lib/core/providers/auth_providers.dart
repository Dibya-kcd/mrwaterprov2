import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/pin_repository.dart';

// Both repositories now read CompanySession.companyId lazily on every
// operation — no companyId is passed at construction time. This means
// these providers never need to be invalidated after login; they always
// operate on the current company session automatically.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final pinRepositoryProvider = Provider<PinRepository>((ref) {
  return PinRepository();
});
