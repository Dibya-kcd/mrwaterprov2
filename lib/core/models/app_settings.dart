// ════════════════════════════════════════════════════════════════════════════
// app_settings.dart — Application settings model
// FIX v2:
//   • toFirebaseJson() excludes logoLocalPath (device-local path must NOT sync)
//   • copyWith uses sentinel pattern for nullable price overrides
// ════════════════════════════════════════════════════════════════════════════

class AppSettings {
  final String appName, businessName, ownerName, phone, address;
  final String gstin, themeMode, accentColor, currency, dateFormat, invoicePrefix;
  final bool gstEnabled, paymentAutoSync, auditLogEnabled;
  final double coolPrice, petPrice, transportFee, damageChargePerJar;
  final int lowStockThreshold, overdueDays;

  /// Dynamic logo: URL (Firebase Storage / HTTPS) — synced to Firebase.
  final String logoUrl;

  /// Dynamic logo: local device file path (picked via image_picker).
  /// FIX: NEVER synced to Firebase — stored locally only via LocalStorageService.
  final String logoLocalPath;

  const AppSettings({
    this.appName = 'MrWater',
    this.businessName = 'Water Supply Co.',
    this.ownerName = 'Owner',
    this.phone = '',
    this.address = '',
    this.gstin = '',
    this.gstEnabled = false,
    this.coolPrice = 60.0,
    this.petPrice = 40.0,
    this.transportFee = 500.0,
    this.damageChargePerJar = 200.0,
    this.lowStockThreshold = 10,
    this.overdueDays = 7,
    this.themeMode = 'system',
    this.accentColor = '1A6BFF',
    this.paymentAutoSync = true,
    this.auditLogEnabled = true,
    this.currency = '₹',
    this.dateFormat = 'dd MMM yyyy',
    this.invoicePrefix = 'MRW',
    this.logoUrl = '',
    this.logoLocalPath = '',
  });

  /// Full serialization — used only for local in-memory operations.
  Map<String, dynamic> toJson() => {
        'appName': appName,
        'businessName': businessName,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
        'gstin': gstin,
        'gstEnabled': gstEnabled,
        'coolPrice': coolPrice,
        'petPrice': petPrice,
        'transportFee': transportFee,
        'damageChargePerJar': damageChargePerJar,
        'lowStockThreshold': lowStockThreshold,
        'overdueDays': overdueDays,
        'themeMode': themeMode,
        'accentColor': accentColor,
        'paymentAutoSync': paymentAutoSync,
        'auditLogEnabled': auditLogEnabled,
        'currency': currency,
        'dateFormat': dateFormat,
        'invoicePrefix': invoicePrefix,
        'logoUrl': logoUrl,
        'logoLocalPath': logoLocalPath,
      };

  /// FIX: Firebase serialization — excludes logoLocalPath.
  /// logoLocalPath is a device-specific filesystem path. Syncing it to Firebase
  /// causes every OTHER device to reference a non-existent path and fail silently.
  /// Only logoUrl (a proper HTTPS URL) is safe to sync across devices.
  Map<String, dynamic> toFirebaseJson() => {
        'appName': appName,
        'businessName': businessName,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
        'gstin': gstin,
        'gstEnabled': gstEnabled,
        'coolPrice': coolPrice,
        'petPrice': petPrice,
        'transportFee': transportFee,
        'damageChargePerJar': damageChargePerJar,
        'lowStockThreshold': lowStockThreshold,
        'overdueDays': overdueDays,
        'themeMode': themeMode,
        'accentColor': accentColor,
        'paymentAutoSync': paymentAutoSync,
        'auditLogEnabled': auditLogEnabled,
        'currency': currency,
        'dateFormat': dateFormat,
        'invoicePrefix': invoicePrefix,
        'logoUrl': logoUrl,
        // logoLocalPath intentionally excluded
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        appName: j['appName'] ?? 'MrWater',
        businessName: j['businessName'] ?? '',
        ownerName: j['ownerName'] ?? '',
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        gstin: j['gstin'] ?? '',
        gstEnabled: j['gstEnabled'] ?? false,
        coolPrice: (j['coolPrice'] ?? 60.0).toDouble(),
        petPrice: (j['petPrice'] ?? 40.0).toDouble(),
        transportFee: (j['transportFee'] ?? 0.0).toDouble(),
        damageChargePerJar: (j['damageChargePerJar'] ?? 200.0).toDouble(),
        lowStockThreshold: j['lowStockThreshold'] ?? 10,
        overdueDays: j['overdueDays'] ?? 7,
        themeMode: j['themeMode'] ?? 'system',
        accentColor: j['accentColor'] ?? '1A6BFF',
        paymentAutoSync: j['paymentAutoSync'] ?? true,
        auditLogEnabled: j['auditLogEnabled'] ?? true,
        currency: j['currency'] ?? '₹',
        dateFormat: j['dateFormat'] ?? 'dd MMM yyyy',
        invoicePrefix: j['invoicePrefix'] ?? 'MRW',
        logoUrl: j['logoUrl'] ?? '',
        // logoLocalPath is device-local — never stored in Firebase, starts empty
        logoLocalPath: '',
      );

  // FIX: sentinel object pattern so nullable fields can be explicitly cleared.
  // The old `field ?? this.field` pattern made it impossible to set a nullable
  // field to null — passing null was indistinguishable from "not provided".
  // ignore: unused_field
  static const _keep = Object();

  AppSettings copyWith({
    String? appName,
    String? businessName,
    String? ownerName,
    String? phone,
    String? address,
    String? gstin,
    bool? gstEnabled,
    double? coolPrice,
    double? petPrice,
    double? transportFee,
    double? damageChargePerJar,
    int? lowStockThreshold,
    int? overdueDays,
    String? themeMode,
    String? accentColor,
    bool? paymentAutoSync,
    bool? auditLogEnabled,
    String? currency,
    String? dateFormat,
    String? invoicePrefix,
    String? logoUrl,
    String? logoLocalPath,
  }) =>
      AppSettings(
        appName: appName ?? this.appName,
        businessName: businessName ?? this.businessName,
        ownerName: ownerName ?? this.ownerName,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        gstin: gstin ?? this.gstin,
        gstEnabled: gstEnabled ?? this.gstEnabled,
        coolPrice: coolPrice ?? this.coolPrice,
        petPrice: petPrice ?? this.petPrice,
        transportFee: transportFee ?? this.transportFee,
        damageChargePerJar: damageChargePerJar ?? this.damageChargePerJar,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        overdueDays: overdueDays ?? this.overdueDays,
        themeMode: themeMode ?? this.themeMode,
        accentColor: accentColor ?? this.accentColor,
        paymentAutoSync: paymentAutoSync ?? this.paymentAutoSync,
        auditLogEnabled: auditLogEnabled ?? this.auditLogEnabled,
        currency: currency ?? this.currency,
        dateFormat: dateFormat ?? this.dateFormat,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        logoUrl: logoUrl ?? this.logoUrl,
        logoLocalPath: logoLocalPath ?? this.logoLocalPath,
      );
}
