import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/pin_repository.dart';
import '../services/company_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final companyId = CompanySession.companyId;
  return AuthRepository(companyId: companyId);
});

final pinRepositoryProvider = Provider<PinRepository>((ref) {
  final companyId = CompanySession.companyId;
  return PinRepository(companyId: companyId);
});
