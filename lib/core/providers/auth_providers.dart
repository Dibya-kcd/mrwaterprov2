// ════════════════════════════════════════════════════════════════════════════
// auth_providers.dart
// FIX v2:
//   • AuthRepository and PinRepository now receive a companyId GETTER instead
//     of a snapshot value captured at provider-creation time.
//
//   BUG: The old code ran `CompanySession.companyId` inside the Provider
//   factory. The factory executes ONCE — on cold start, before Firebase Auth
//   resolves, CompanySession.companyId is '' (empty). Both repositories were
//   then constructed with companyId == '' and every subsequent operation
//   silently wrote to / read from the wrong RTDB path ('companies//users/…').
//
//   FIX: Pass `() => CompanySession.companyId` (a getter closure) so each
//   method call reads the CURRENT companyId, not the value at startup time.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/pin_repository.dart';
import '../services/company_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // FIX: pass a getter so the repository always reads the live companyId.
  return AuthRepository(companyIdGetter: () => CompanySession.companyId);
});

final pinRepositoryProvider = Provider<PinRepository>((ref) {
  // FIX: same — lazy getter avoids capturing '' on cold start.
  return PinRepository(companyIdGetter: () => CompanySession.companyId);
});
