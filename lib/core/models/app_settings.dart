// ════════════════════════════════════════════════════════════════════════════
// app_settings.dart — Application settings model
// ════════════════════════════════════════════════════════════════════════════

class AppSettings {
  final String appName, businessName, ownerName, phone, address;
  final String gstin, themeMode, accentColor, currency, dateFormat, invoicePrefix;
  final bool gstEnabled, paymentAutoSync, auditLogEnabled;
  final double coolPrice, petPrice, transportFee, damageChargePerJar;
  final int lowStockThreshold, overdueDays;
  /// Dynamic logo: URL (Firebase Storage / HTTPS) — takes priority over local path + default asset
  final String logoUrl;
  /// Dynamic logo: local device file path (picked via image_picker)
  final String logoLocalPath;

  const AppSettings({
    this.appName = 'MrWater', this.businessName = 'Water Supply Co.',
    this.ownerName = 'Owner', this.phone = '',
    this.address = '', this.gstin = '',
    this.gstEnabled = false, this.coolPrice = 60.0, this.petPrice = 40.0,
    this.transportFee = 500.0, this.damageChargePerJar = 200.0,
    this.lowStockThreshold = 10, this.overdueDays = 7,
    this.themeMode = 'system', this.accentColor = '1A6BFF',
    this.paymentAutoSync = true, this.auditLogEnabled = true,
    this.currency = '₹', this.dateFormat = 'dd MMM yyyy', this.invoicePrefix = 'MRW',
    this.logoUrl = '', this.logoLocalPath = '',
  });

  Map<String, dynamic> toJson() => {
    'appName': appName, 'businessName': businessName, 'ownerName': ownerName,
    'phone': phone, 'address': address, 'gstin': gstin, 'gstEnabled': gstEnabled,
    'coolPrice': coolPrice, 'petPrice': petPrice, 'transportFee': transportFee,
    'damageChargePerJar': damageChargePerJar, 'lowStockThreshold': lowStockThreshold,
    'overdueDays': overdueDays, 'themeMode': themeMode, 'accentColor': accentColor,
    'paymentAutoSync': paymentAutoSync, 'auditLogEnabled': auditLogEnabled,
    'currency': currency, 'dateFormat': dateFormat, 'invoicePrefix': invoicePrefix,
    'logoUrl': logoUrl, 'logoLocalPath': logoLocalPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    appName: j['appName'] ?? 'MrWater', businessName: j['businessName'] ?? '',
    ownerName: j['ownerName'] ?? '', phone: j['phone'] ?? '',
    address: j['address'] ?? '', gstin: j['gstin'] ?? '',
    gstEnabled: j['gstEnabled'] ?? false, coolPrice: (j['coolPrice'] ?? 60.0).toDouble(),
    petPrice: (j['petPrice'] ?? 40.0).toDouble(), transportFee: (j['transportFee'] ?? 0.0).toDouble(),
    damageChargePerJar: (j['damageChargePerJar'] ?? 200.0).toDouble(),
    lowStockThreshold: j['lowStockThreshold'] ?? 10, overdueDays: j['overdueDays'] ?? 7,
    themeMode: j['themeMode'] ?? 'system', accentColor: j['accentColor'] ?? '1A6BFF',
    paymentAutoSync: j['paymentAutoSync'] ?? true, auditLogEnabled: j['auditLogEnabled'] ?? true,
    currency: j['currency'] ?? '₹', dateFormat: j['dateFormat'] ?? 'dd MMM yyyy',
    invoicePrefix: j['invoicePrefix'] ?? 'MRW',
    logoUrl: j['logoUrl'] ?? '', logoLocalPath: j['logoLocalPath'] ?? '',
  );

  AppSettings copyWith({
    String? appName, String? businessName, String? ownerName, String? phone,
    String? address, String? gstin, bool? gstEnabled, double? coolPrice,
    double? petPrice, double? transportFee, double? damageChargePerJar,
    int? lowStockThreshold, int? overdueDays, String? themeMode,
    String? accentColor, bool? paymentAutoSync, bool? auditLogEnabled,
    String? currency, String? dateFormat, String? invoicePrefix,
    String? logoUrl, String? logoLocalPath,
  }) => AppSettings(
    appName: appName ?? this.appName, businessName: businessName ?? this.businessName,
    ownerName: ownerName ?? this.ownerName, phone: phone ?? this.phone,
    address: address ?? this.address, gstin: gstin ?? this.gstin,
    gstEnabled: gstEnabled ?? this.gstEnabled, coolPrice: coolPrice ?? this.coolPrice,
    petPrice: petPrice ?? this.petPrice, transportFee: transportFee ?? this.transportFee,
    damageChargePerJar: damageChargePerJar ?? this.damageChargePerJar,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    overdueDays: overdueDays ?? this.overdueDays, themeMode: themeMode ?? this.themeMode,
    accentColor: accentColor ?? this.accentColor, paymentAutoSync: paymentAutoSync ?? this.paymentAutoSync,
    auditLogEnabled: auditLogEnabled ?? this.auditLogEnabled, currency: currency ?? this.currency,
    dateFormat: dateFormat ?? this.dateFormat, invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    logoUrl: logoUrl ?? this.logoUrl, logoLocalPath: logoLocalPath ?? this.logoLocalPath,
  );
}