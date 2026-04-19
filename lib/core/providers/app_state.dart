// ════════════════════════════════════════════════════════════════════════════
// app_state.dart — Core providers
// FIX v2 changes:
//
//   1. AppSettings class REMOVED — canonical definition is in app_settings.dart.
//      Importing app_state.dart no longer shadows app_settings.dart.
//
//   2. AuditNotifier now reads sessionUserProvider to record the REAL performer
//      instead of always writing 'Admin'. Requires a Ref — same pattern as
//      TransactionsNotifier.
//
//   3. CustomersNotifier.applyTx / revertTx / applyTxEdit: when the customer
//      is not found, throw StateError instead of silently returning state.first.
//      Previously a missing customer would corrupt the FIRST customer's ledger.
//
//   4. PaymentRecord is now keyed by txId (stable) instead of a new UUID on
//      every call. This prevents duplicate payment rows accumulating on edits.
//
//   5. TripEntry.expectedCoolDelivered no longer subtracts emptyReturned.
//      Empty shells confirm delivery — they are NOT undelivered jars.
//      Fix: expectedDelivered = loaded - filledReturned (only unfulfilled jars).
//
//   6. DayLogNotifier and LoadUnloadNotifier now watch SEPARATE RTDB nodes:
//      trips    → nodeLoadUnload  (TripEntry records keyed by UUID)
//      day logs → nodeDayLogs    (DayLog records keyed by date string)
//      Previously both watched nodeLoadUnload and silently corrupted each other.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/company_session.dart';
import '../services/firebase_service.dart';
import '../services/firebase_config.dart';
// FIX: import staff_provider so sessionUserProvider is accessible within this file
import 'staff_provider.dart';
export '../models/user_role.dart';
export '../models/staff_member.dart';
export 'staff_provider.dart';
// FIX 1: export app_settings.dart instead of re-defining AppSettings here
export '../models/app_settings.dart';
// FIX: export settings_provider so all screens get settingsProvider via this barrel
export 'settings_provider.dart';
// FIX: import AND export customer model — import makes Customer usable within this
// file (CustomersNotifier etc); export makes it available to all importing screens.
import '../models/customer.dart';
export '../models/customer.dart';

const _uuid = Uuid();
String _now() => DateTime.now().toIso8601String();

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

// ignore: unused_element
int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

// ignore: unused_element
bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

Map<String, dynamic> _deepCast(dynamic data) {
  if (data is Map) {
    return Map<String, dynamic>.fromEntries(
      data.entries
          .map((e) => MapEntry(e.key.toString(), _deepCastValue(e.value))),
    );
  }
  return {};
}

dynamic _deepCastValue(dynamic v) {
  if (v is Map) return _deepCast(v);
  if (v is List) return v.map(_deepCastValue).toList();
  return v;
}

Map<String, dynamic> _castMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _castMapValue(v)));
  }
  return {};
}

dynamic _castMapValue(dynamic v) {
  if (v is Map) return _castMap(v);
  if (v is List) return v.map(_castMapValue).toList();
  return v;
}

// ══════════════════════════════════════════════════════════════════════════════
// JAR TRANSACTION MODEL
// ══════════════════════════════════════════════════════════════════════════════

class JarTransaction {
  final String id,
      customerId,
      customerName,
      date,
      createdAt,
      paymentMode,
      note,
      createdBy;
  final int coolDelivered,
      petDelivered,
      coolReturned,
      petReturned,
      coolDamaged,
      petDamaged;
  final double coolPrice,
      petPrice,
      billedAmount,
      amountCollected,
      damageCharge;
  final double transportFee;
  final String? updatedAt;
  final String? deliveryType;
  final String? eventName;
  final String? eventStatus;
  // ── Multi-day event fields ────────────────────────────────────────────────
  /// Shared UUID linking all daily transactions of the same multi-day event.
  /// null = single-day event (legacy) or not an event.
  final String? eventId;
  /// 'yyyy-MM-dd' — the overall event start date (same across all days).
  final String? eventStartDate;
  /// 'yyyy-MM-dd' — the overall event end date (same across all days).
  final String? eventEndDate;
  /// 1-based day number within the event (1 = first day, 2 = second day…).
  final int? eventDay;
  final List<TxEditHistory> editHistory;

  const JarTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.createdAt,
    this.coolDelivered = 0,
    this.petDelivered = 0,
    this.coolReturned = 0,
    this.petReturned = 0,
    this.coolDamaged = 0,
    this.petDamaged = 0,
    this.coolPrice = 0.0,
    this.petPrice = 0.0,
    required this.billedAmount,
    this.amountCollected = 0,
    this.damageCharge = 0,
    this.transportFee = 0,
    this.paymentMode = 'cash',
    this.note = '',
    this.createdBy = 'Admin',
    this.updatedAt,
    this.deliveryType = 'daily',
    this.eventName,
    this.eventStatus,
    this.eventId,
    this.eventStartDate,
    this.eventEndDate,
    this.eventDay,
    this.editHistory = const [],
  });

  // ── Multi-day helpers ─────────────────────────────────────────────────────
  /// True when this transaction is part of a multi-day event group.
  bool get isMultiDayEvent =>
      eventId != null && eventStartDate != null && eventEndDate != null;

  /// Total number of days in the event (computed from start/end dates).
  int get eventTotalDays {
    if (eventStartDate == null || eventEndDate == null) return 1;
    try {
      final s = DateTime.parse(eventStartDate!);
      final e = DateTime.parse(eventEndDate!);
      return e.difference(s).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  double get balance => billedAmount - amountCollected;
  bool get hasCool => coolDelivered > 0 || coolReturned > 0;
  bool get hasPet => petDelivered > 0 || petReturned > 0;
  bool get isReturn =>
      coolDelivered == 0 &&
      petDelivered == 0 &&
      (coolReturned > 0 || petReturned > 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'date': date,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'note': note,
        'createdBy': createdBy,
        'coolDelivered': coolDelivered,
        'petDelivered': petDelivered,
        'coolReturned': coolReturned,
        'petReturned': petReturned,
        'coolDamaged': coolDamaged,
        'petDamaged': petDamaged,
        'coolPrice': coolPrice,
        'petPrice': petPrice,
        'billedAmount': billedAmount,
        'amountCollected': amountCollected,
        'damageCharge': damageCharge,
        'transportFee': transportFee,
        'paymentMode': paymentMode,
        'deliveryType': deliveryType,
        'eventName': eventName,
        'eventStatus': eventStatus,
        'eventId': eventId,
        'eventStartDate': eventStartDate,
        'eventEndDate': eventEndDate,
        'eventDay': eventDay,
        'editHistory': editHistory.map((e) => e.toJson()).toList(),
      };

  factory JarTransaction.fromJson(Map<String, dynamic> j) => JarTransaction(
        id: j['id']?.toString() ?? '',
        customerId: j['customerId']?.toString() ?? '',
        customerName: j['customerName']?.toString() ?? 'Unknown',
        date: j['date']?.toString() ?? '',
        createdAt:
            j['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        updatedAt: j['updatedAt']?.toString(),
        note: j['note'] ?? '',
        createdBy: j['createdBy'] ?? 'Admin',
        coolDelivered: j['coolDelivered'] ?? 0,
        petDelivered: j['petDelivered'] ?? 0,
        coolReturned: j['coolReturned'] ?? 0,
        petReturned: j['petReturned'] ?? 0,
        coolDamaged: j['coolDamaged'] ?? 0,
        petDamaged: j['petDamaged'] ?? 0,
        coolPrice: (j['coolPrice'] ?? 0.0).toDouble(),
        petPrice: (j['petPrice'] ?? 0.0).toDouble(),
        billedAmount: (j['billedAmount'] ?? 0.0).toDouble(),
        amountCollected: (j['amountCollected'] ?? 0.0).toDouble(),
        damageCharge: (j['damageCharge'] ?? 0.0).toDouble(),
        transportFee: (j['transportFee'] ?? 0.0).toDouble(),
        paymentMode: j['paymentMode'] ?? 'cash',
        deliveryType: j['deliveryType'] ?? 'daily',
        eventName: j['eventName'],
        eventStatus: j['eventStatus'],
        eventId: j['eventId']?.toString(),
        eventStartDate: j['eventStartDate']?.toString(),
        eventEndDate: j['eventEndDate']?.toString(),
        eventDay: j['eventDay'] is int
            ? j['eventDay'] as int
            : int.tryParse('${j['eventDay'] ?? ''}'),
        editHistory: (j['editHistory'] as List?)
                ?.map((e) => TxEditHistory.fromJson(e))
                .toList() ??
            [],
      );

  JarTransaction copyWith({
    int? coolDelivered,
    int? petDelivered,
    int? coolReturned,
    int? petReturned,
    int? coolDamaged,
    int? petDamaged,
    double? coolPrice,
    double? petPrice,
    double? billedAmount,
    double? amountCollected,
    double? damageCharge,
    String? paymentMode,
    String? note,
    String? updatedAt,
    String? deliveryType,
    String? eventName,
    double? transportFee,
    String? eventStatus,
    String? eventId,
    String? eventStartDate,
    String? eventEndDate,
    int? eventDay,
    List<TxEditHistory>? editHistory,
  }) =>
      JarTransaction(
        id: id,
        customerId: customerId,
        customerName: customerName,
        date: date,
        createdAt: createdAt,
        coolDelivered: coolDelivered ?? this.coolDelivered,
        petDelivered: petDelivered ?? this.petDelivered,
        coolReturned: coolReturned ?? this.coolReturned,
        petReturned: petReturned ?? this.petReturned,
        coolDamaged: coolDamaged ?? this.coolDamaged,
        petDamaged: petDamaged ?? this.petDamaged,
        coolPrice: coolPrice ?? this.coolPrice,
        petPrice: petPrice ?? this.petPrice,
        billedAmount: billedAmount ?? this.billedAmount,
        amountCollected: amountCollected ?? this.amountCollected,
        damageCharge: damageCharge ?? this.damageCharge,
        transportFee: transportFee ?? this.transportFee,
        paymentMode: paymentMode ?? this.paymentMode,
        note: note ?? this.note,
        createdBy: createdBy,
        updatedAt: updatedAt ?? this.updatedAt,
        deliveryType: deliveryType ?? this.deliveryType,
        eventName: eventName ?? this.eventName,
        eventStatus: eventStatus ?? this.eventStatus,
        eventId: eventId ?? this.eventId,
        eventStartDate: eventStartDate ?? this.eventStartDate,
        eventEndDate: eventEndDate ?? this.eventEndDate,
        eventDay: eventDay ?? this.eventDay,
        editHistory: editHistory ?? this.editHistory,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// INVENTORY STATE
// ══════════════════════════════════════════════════════════════════════════════

class InventoryState {
  final int coolTotal, coolStock, petTotal, petStock;
  const InventoryState(
      {this.coolTotal = 0,
      this.coolStock = 0,
      this.petTotal = 0,
      this.petStock = 0});

  int get coolOut => coolTotal - coolStock;
  int get petOut => petTotal - petStock;
  double get coolPct => coolTotal > 0 ? coolStock / coolTotal : 0;
  double get petPct => petTotal > 0 ? petStock / petTotal : 0;

  InventoryState copyWith(
          {int? coolTotal, int? coolStock, int? petTotal, int? petStock}) =>
      InventoryState(
        coolTotal: coolTotal ?? this.coolTotal,
        coolStock: coolStock ?? this.coolStock,
        petTotal: petTotal ?? this.petTotal,
        petStock: petStock ?? this.petStock,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// AUDIT ENTRY MODEL
// ══════════════════════════════════════════════════════════════════════════════

class AuditEntry {
  final String id,
      type,
      description,
      entityId,
      before,
      after,
      performedBy,
      createdAt;

  const AuditEntry({
    required this.id,
    required this.type,
    required this.description,
    required this.entityId,
    this.before = '',
    this.after = '',
    required this.performedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'description': description,
        'entityId': entityId,
        'before': before,
        'after': after,
        'performedBy': performedBy,
        'createdAt': createdAt,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: _asString(j['id'], fallback: _uuid.v4()),
        type: _asString(j['type'], fallback: 'unknown'),
        description: _asString(j['description'], fallback: ''),
        entityId: _asString(j['entityId'], fallback: ''),
        before: _asString(j['before']),
        after: _asString(j['after']),
        performedBy: _asString(j['performedBy'], fallback: 'Admin'),
        createdAt: _asString(j['createdAt'], fallback: _now()),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// LEDGER ENTRY MODEL
// ══════════════════════════════════════════════════════════════════════════════

class LedgerEntry {
  final String id;
  final String customerId;
  final String txId;
  final String date;
  final String createdAt;
  final String? updatedAt;
  final String type;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String paymentMode;
  final String createdBy;

  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.txId,
    required this.date,
    required this.createdAt,
    this.updatedAt,
    required this.type,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.paymentMode,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'txId': txId,
        'date': date,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'type': type,
        'description': description,
        'debit': debit,
        'credit': credit,
        'balance': balance,
        'paymentMode': paymentMode,
        'createdBy': createdBy,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: _asString(j['id'], fallback: _uuid.v4()),
        customerId: _asString(j['customerId'], fallback: ''),
        txId: _asString(j['txId'], fallback: ''),
        date: _asString(j['date'], fallback: ''),
        createdAt: _asString(j['createdAt'], fallback: _now()),
        updatedAt: j['updatedAt']?.toString(),
        type: _asString(j['type'], fallback: 'delivery'),
        description: _asString(j['description'], fallback: ''),
        debit: _asDouble(j['debit']),
        credit: _asDouble(j['credit']),
        balance: _asDouble(j['balance']),
        paymentMode: _asString(j['paymentMode'], fallback: 'cash'),
        createdBy: _asString(j['createdBy'], fallback: 'Admin'),
      );

  factory LedgerEntry.fromTransaction(
      JarTransaction tx, double customerBalanceAfter) {
    final isPaymentOnly = tx.billedAmount == 0 &&
        tx.amountCollected > 0 &&
        tx.coolDelivered == 0 &&
        tx.petDelivered == 0 &&
        tx.coolReturned == 0 &&
        tx.petReturned == 0;
    final isReturn = tx.coolDelivered == 0 &&
        tx.petDelivered == 0 &&
        (tx.coolReturned > 0 || tx.petReturned > 0);
    final hasDamage = tx.coolDamaged > 0 || tx.petDamaged > 0;

    String type;
    String desc;

    if (isPaymentOnly) {
      type = 'payment';
      desc = 'Payment received ₹${tx.amountCollected.toInt()}';
    } else if (isReturn) {
      type = 'return';
      final parts = <String>[];
      if (tx.coolReturned > 0) parts.add('${tx.coolReturned} Cool');
      if (tx.petReturned > 0) parts.add('${tx.petReturned} PET');
      desc = '${parts.join(' + ')} returned';
    } else if (hasDamage && tx.coolDelivered == 0 && tx.petDelivered == 0) {
      type = 'damage';
      desc = 'Damage charge – ${tx.coolDamaged + tx.petDamaged} jar(s)';
    } else {
      type = tx.deliveryType == 'event' ? 'event' : 'delivery';
      final parts = <String>[];
      if (tx.coolDelivered > 0) parts.add('${tx.coolDelivered} Cool');
      if (tx.petDelivered > 0) parts.add('${tx.petDelivered} PET');
      if (tx.coolReturned > 0) parts.add('${tx.coolReturned} Cool returned');
      if (tx.petReturned > 0) parts.add('${tx.petReturned} PET returned');
      desc = parts.isNotEmpty ? parts.join(', ') : 'Transaction';
      if (tx.deliveryType == 'event' &&
          tx.eventName != null &&
          tx.eventName!.isNotEmpty) {
        desc = '${tx.eventName}: $desc';
      }
    }

    if (tx.amountCollected > 0 && !isPaymentOnly) {
      if (tx.amountCollected >= tx.billedAmount) {
        desc += ' – fully paid';
      } else {
        desc += ' – partial ₹${tx.amountCollected.toInt()} paid';
      }
    }

    return LedgerEntry(
      id: 'le_${tx.id}',
      customerId: tx.customerId,
      txId: tx.id,
      date: tx.date,
      createdAt: tx.createdAt,
      updatedAt: tx.updatedAt,
      type: type,
      description: desc,
      debit: tx.billedAmount,
      credit: tx.amountCollected,
      balance: customerBalanceAfter,
      paymentMode: tx.paymentMode,
      createdBy: tx.createdBy,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TRANSACTION REVISION MODEL
// ══════════════════════════════════════════════════════════════════════════════

class TransactionRevision {
  final String revId;
  final String txId;
  final int revNumber;
  final bool isLatest;
  final String createdAt;
  final String editedBy;
  final String editNote;
  final int coolDelivered,
      petDelivered,
      coolReturned,
      petReturned,
      coolDamaged,
      petDamaged;
  final double coolPrice,
      petPrice,
      billedAmount,
      amountCollected,
      damageCharge,
      transportFee;
  final String paymentMode;
  final String? eventStatus, eventName;
  final String deliveryType;

  const TransactionRevision({
    required this.revId,
    required this.txId,
    required this.revNumber,
    required this.isLatest,
    required this.createdAt,
    required this.editedBy,
    this.editNote = '',
    required this.coolDelivered,
    required this.petDelivered,
    required this.coolReturned,
    required this.petReturned,
    required this.coolDamaged,
    required this.petDamaged,
    required this.coolPrice,
    required this.petPrice,
    required this.billedAmount,
    required this.amountCollected,
    required this.damageCharge,
    required this.transportFee,
    required this.paymentMode,
    required this.deliveryType,
    this.eventStatus,
    this.eventName,
  });

  factory TransactionRevision.fromTransaction(
    JarTransaction tx, {
    required int revNumber,
    required bool isLatest,
    String editedBy = 'Admin',
    String editNote = '',
  }) =>
      TransactionRevision(
        revId: _uuid.v4(),
        txId: tx.id,
        revNumber: revNumber,
        isLatest: isLatest,
        createdAt: _now(),
        editedBy: editedBy,
        editNote: editNote,
        coolDelivered: tx.coolDelivered,
        petDelivered: tx.petDelivered,
        coolReturned: tx.coolReturned,
        petReturned: tx.petReturned,
        coolDamaged: tx.coolDamaged,
        petDamaged: tx.petDamaged,
        coolPrice: tx.coolPrice,
        petPrice: tx.petPrice,
        billedAmount: tx.billedAmount,
        amountCollected: tx.amountCollected,
        damageCharge: tx.damageCharge,
        transportFee: tx.transportFee,
        paymentMode: tx.paymentMode,
        deliveryType: tx.deliveryType ?? 'daily',
        eventStatus: tx.eventStatus,
        eventName: tx.eventName,
      );

  Map<String, dynamic> toJson() => {
        'revId': revId,
        'txId': txId,
        'revNumber': revNumber,
        'isLatest': isLatest,
        'createdAt': createdAt,
        'editedBy': editedBy,
        'editNote': editNote,
        'coolDelivered': coolDelivered,
        'petDelivered': petDelivered,
        'coolReturned': coolReturned,
        'petReturned': petReturned,
        'coolDamaged': coolDamaged,
        'petDamaged': petDamaged,
        'coolPrice': coolPrice,
        'petPrice': petPrice,
        'billedAmount': billedAmount,
        'amountCollected': amountCollected,
        'damageCharge': damageCharge,
        'transportFee': transportFee,
        'paymentMode': paymentMode,
        'deliveryType': deliveryType,
        'eventStatus': eventStatus,
        'eventName': eventName,
      };

  factory TransactionRevision.fromJson(Map<String, dynamic> j) =>
      TransactionRevision(
        revId: j['revId'] ?? '',
        txId: j['txId'] ?? '',
        revNumber: j['revNumber'] ?? 1,
        isLatest: j['isLatest'] ?? true,
        createdAt: j['createdAt'] ?? _now(),
        editedBy: j['editedBy'] ?? 'Admin',
        editNote: j['editNote'] ?? '',
        coolDelivered: j['coolDelivered'] ?? 0,
        petDelivered: j['petDelivered'] ?? 0,
        coolReturned: j['coolReturned'] ?? 0,
        petReturned: j['petReturned'] ?? 0,
        coolDamaged: j['coolDamaged'] ?? 0,
        petDamaged: j['petDamaged'] ?? 0,
        coolPrice: (j['coolPrice'] ?? 0.0).toDouble(),
        petPrice: (j['petPrice'] ?? 0.0).toDouble(),
        billedAmount: (j['billedAmount'] ?? 0.0).toDouble(),
        amountCollected: (j['amountCollected'] ?? 0.0).toDouble(),
        damageCharge: (j['damageCharge'] ?? 0.0).toDouble(),
        transportFee: (j['transportFee'] ?? 0.0).toDouble(),
        paymentMode: j['paymentMode'] ?? 'cash',
        deliveryType: j['deliveryType'] ?? 'daily',
        eventStatus: j['eventStatus'],
        eventName: j['eventName'],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// INVENTORY MOVEMENT MODEL
// ══════════════════════════════════════════════════════════════════════════════

class InventoryMovement {
  final String invId;
  final String? txId;
  final String? revId;
  final String type;
  final int coolDelta;
  final int petDelta;
  final int coolTotalDelta;
  final int petTotalDelta;
  final String createdAt;
  final String note;

  const InventoryMovement({
    required this.invId,
    this.txId,
    this.revId,
    required this.type,
    required this.coolDelta,
    required this.petDelta,
    required this.coolTotalDelta,
    required this.petTotalDelta,
    required this.createdAt,
    this.note = '',
  });

  factory InventoryMovement.fromApply(JarTransaction tx, {String? revId}) =>
      InventoryMovement(
        invId: _uuid.v4(),
        txId: tx.id,
        revId: revId,
        type: 'delivery',
        coolDelta:
            -tx.coolDelivered + tx.coolReturned - tx.coolDamaged,
        petDelta:
            -tx.petDelivered + tx.petReturned - tx.petDamaged,
        coolTotalDelta: -tx.coolDamaged,
        petTotalDelta: -tx.petDamaged,
        createdAt: _now(),
        note: 'Tx ${tx.id} applied',
      );

  factory InventoryMovement.fromRevert(JarTransaction tx,
          {String type = 'delete_revert'}) =>
      InventoryMovement(
        invId: _uuid.v4(),
        txId: tx.id,
        type: type,
        coolDelta:
            tx.coolDelivered - tx.coolReturned + tx.coolDamaged,
        petDelta:
            tx.petDelivered - tx.petReturned + tx.petDamaged,
        coolTotalDelta: tx.coolDamaged,
        petTotalDelta: tx.petDamaged,
        createdAt: _now(),
        note: 'Tx ${tx.id} reverted',
      );

  factory InventoryMovement.fromEditDelta(
      JarTransaction oldTx, JarTransaction newTx,
      {String? revId}) {
    final coolStockDelta =
        (-newTx.coolDelivered + newTx.coolReturned - newTx.coolDamaged) -
            (-oldTx.coolDelivered + oldTx.coolReturned - oldTx.coolDamaged);
    final petStockDelta =
        (-newTx.petDelivered + newTx.petReturned - newTx.petDamaged) -
            (-oldTx.petDelivered + oldTx.petReturned - oldTx.petDamaged);
    return InventoryMovement(
      invId: _uuid.v4(),
      txId: newTx.id,
      revId: revId,
      type: 'edit_delta',
      coolDelta: coolStockDelta,
      petDelta: petStockDelta,
      coolTotalDelta: oldTx.coolDamaged - newTx.coolDamaged,
      petTotalDelta: oldTx.petDamaged - newTx.petDamaged,
      createdAt: _now(),
      note: 'Edit delta for tx ${newTx.id}',
    );
  }

  Map<String, dynamic> toJson() => {
        'invId': invId,
        'txId': txId,
        'revId': revId,
        'type': type,
        'coolDelta': coolDelta,
        'petDelta': petDelta,
        'coolTotalDelta': coolTotalDelta,
        'petTotalDelta': petTotalDelta,
        'createdAt': createdAt,
        'note': note,
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// PAYMENT RECORD MODEL
// FIX 4: paymentId is now derived from txId (stable key) not a new UUID.
//        On every edit, the same paymentId is overwritten instead of creating
//        a duplicate row. Old pattern: _uuid.v4() on every call.
// ══════════════════════════════════════════════════════════════════════════════

class PaymentRecord {
  final String paymentId;
  final String txId;
  final String customerId;
  final String customerName;
  final double amount;
  final String mode;
  final String date;
  final String createdAt;
  final String note;
  final String type;
  final bool isActive;

  const PaymentRecord({
    required this.paymentId,
    required this.txId,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.mode,
    required this.date,
    required this.createdAt,
    this.note = '',
    required this.type,
    this.isActive = true,
  });

  factory PaymentRecord.fromTransaction(JarTransaction tx) {
    final bool isDelivery = tx.billedAmount > 0;
    final String type = tx.paymentMode == 'advance'
        ? 'advance'
        : isDelivery
            ? (tx.amountCollected >= tx.billedAmount
                ? 'with_delivery'
                : 'partial')
            : 'settlement';

    // FIX: stable paymentId = 'pmt_{txId}' so re-saving on edit overwrites
    // the existing row instead of inserting a duplicate.
    return PaymentRecord(
      paymentId: 'pmt_${tx.id}',
      txId: tx.id,
      customerId: tx.customerId,
      customerName: tx.customerName,
      amount: tx.amountCollected,
      mode: tx.paymentMode,
      date: tx.date,
      createdAt: _now(),
      note: tx.note,
      type: type,
    );
  }

  PaymentRecord copyWith({bool? isActive}) => PaymentRecord(
        paymentId: paymentId,
        txId: txId,
        customerId: customerId,
        customerName: customerName,
        amount: amount,
        mode: mode,
        date: date,
        createdAt: createdAt,
        note: note,
        type: type,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'paymentId': paymentId,
        'txId': txId,
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
        'mode': mode,
        'date': date,
        'createdAt': createdAt,
        'note': note,
        'type': type,
        'isActive': isActive,
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// TX EDIT HISTORY
// ══════════════════════════════════════════════════════════════════════════════

class TxEditHistory {
  final String editedAt;
  final String editedBy;
  final String note;
  final int coolDelivered,
      petDelivered,
      coolReturned,
      petReturned,
      coolDamaged,
      petDamaged;
  final double coolPrice,
      petPrice,
      billedAmount,
      amountCollected,
      damageCharge,
      transportFee;
  final String paymentMode;
  final String? eventStatus;

  const TxEditHistory({
    required this.editedAt,
    required this.editedBy,
    this.note = '',
    required this.coolDelivered,
    required this.petDelivered,
    required this.coolReturned,
    required this.petReturned,
    required this.coolDamaged,
    required this.petDamaged,
    required this.coolPrice,
    required this.petPrice,
    required this.billedAmount,
    required this.amountCollected,
    required this.damageCharge,
    required this.transportFee,
    required this.paymentMode,
    this.eventStatus,
  });

  Map<String, dynamic> toJson() => {
        'editedAt': editedAt,
        'editedBy': editedBy,
        'note': note,
        'coolDelivered': coolDelivered,
        'petDelivered': petDelivered,
        'coolReturned': coolReturned,
        'petReturned': petReturned,
        'coolDamaged': coolDamaged,
        'petDamaged': petDamaged,
        'coolPrice': coolPrice,
        'petPrice': petPrice,
        'billedAmount': billedAmount,
        'amountCollected': amountCollected,
        'damageCharge': damageCharge,
        'transportFee': transportFee,
        'paymentMode': paymentMode,
        'eventStatus': eventStatus,
      };

  factory TxEditHistory.fromJson(Map<String, dynamic> j) => TxEditHistory(
        editedAt: j['editedAt']?.toString() ?? _now(),
        editedBy: j['editedBy']?.toString() ?? 'Admin',
        note: j['note']?.toString() ?? '',
        coolDelivered: j['coolDelivered'] ?? 0,
        petDelivered: j['petDelivered'] ?? 0,
        coolReturned: j['coolReturned'] ?? 0,
        petReturned: j['petReturned'] ?? 0,
        coolDamaged: j['coolDamaged'] ?? 0,
        petDamaged: j['petDamaged'] ?? 0,
        coolPrice: (j['coolPrice'] ?? 0.0).toDouble(),
        petPrice: (j['petPrice'] ?? 0.0).toDouble(),
        billedAmount: (j['billedAmount'] ?? 0.0).toDouble(),
        amountCollected: (j['amountCollected'] ?? 0.0).toDouble(),
        damageCharge: (j['damageCharge'] ?? 0.0).toDouble(),
        transportFee: (j['transportFee'] ?? 0.0).toDouble(),
        paymentMode: j['paymentMode']?.toString() ?? 'cash',
        eventStatus: j['eventStatus']?.toString(),
      );

  factory TxEditHistory.from(JarTransaction tx,
          {String editedBy = 'Admin', String note = ''}) =>
      TxEditHistory(
        editedAt: _now(),
        editedBy: editedBy,
        note: note,
        coolDelivered: tx.coolDelivered,
        petDelivered: tx.petDelivered,
        coolReturned: tx.coolReturned,
        petReturned: tx.petReturned,
        coolDamaged: tx.coolDamaged,
        petDamaged: tx.petDamaged,
        coolPrice: tx.coolPrice,
        petPrice: tx.petPrice,
        billedAmount: tx.billedAmount,
        amountCollected: tx.amountCollected,
        damageCharge: tx.damageCharge,
        transportFee: tx.transportFee,
        paymentMode: tx.paymentMode,
        eventStatus: tx.eventStatus,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

// FIX 1: SettingsNotifier is REMOVED from app_state.dart.
//        Canonical definition lives in settings_provider.dart / app_settings.dart.
//        app_state.dart re-exports AppSettings via `export '../models/app_settings.dart'`.
//        All imports that used `app_state.dart` for AppSettings still work.

// FIX 2: AuditNotifier now reads sessionUserProvider (requires a Ref).
class AuditNotifier extends StateNotifier<List<AuditEntry>> {
  final Ref _ref;

  AuditNotifier(this._ref) : super([]) {
    Future.microtask(_init);
  }

  void _init() {
    FirebaseService.instance.watch('auditLog').listen((data) {
      if (data != null) {
        state = data.values
            .map((e) => AuditEntry.fromJson(_castMap(e)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        state = [];
      }
    });
  }

  void log({
    required String type,
    required String description,
    required String entityId,
    String before = '',
    String after = '',
  }) {
    // FIX 2: Read real performer from session, not hardcoded 'Admin'
    final sessionUser = _ref.read(sessionUserProvider);
    final performer = sessionUser?.name ?? 'Owner';

    final entry = AuditEntry(
      id: _uuid.v4(),
      type: type,
      description: description,
      entityId: entityId,
      before: before,
      after: after,
      performedBy: performer,
      createdAt: _now(),
    );
    FirebaseService.instance.setChild('auditLog', entry.id, entry.toJson());
  }

  void clear() => FirebaseService.instance.write('auditLog', {});
}

final auditProvider =
    StateNotifierProvider<AuditNotifier, List<AuditEntry>>(
        (ref) => AuditNotifier(ref));

// ── Inventory Notifier ────────────────────────────────────────────────────────
class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier() : super(const InventoryState()) {
    Future.microtask(_init);
  }

  void _init() {
    FirebaseService.instance.watchInventory().listen((data) {
      if (data != null) {
        final coolTotal = (data['coolTotal'] ?? 0).toInt();
        final petTotal  = (data['petTotal']  ?? 0).toInt();
        // SAFETY: clamp stock to [0, total] on every Firebase snapshot.
        // This prevents any race-condition or legacy bad data from letting
        // coolStock > coolTotal (the "stock exceeds 100" bug).
        final coolStock = ((data['coolStock'] ?? 0).toInt()).clamp(0, coolTotal);
        final petStock  = ((data['petStock']  ?? 0).toInt()).clamp(0, petTotal);
        state = InventoryState(
          coolTotal: coolTotal,
          coolStock: coolStock,
          petTotal:  petTotal,
          petStock:  petStock,
        );
        // If the clamped values differ from what Firebase stored, persist the
        // corrected values so the corruption does not persist.
        if (coolStock != (data['coolStock'] ?? 0).toInt() ||
            petStock  != (data['petStock']  ?? 0).toInt()) {
          debugPrint('[InventoryNotifier] ⚠ Stock exceeded total — auto-corrected '
              'cool: ${data['coolStock']} -> $coolStock, '
              'pet: ${data['petStock']} -> $petStock');
          _save();
        }
      }
    }, onError: (e) => debugPrint('[InventoryNotifier] error: $e'));
  }

  Future<void> _save() async {
    await FirebaseService.instance.writeInventory({
      'coolTotal': state.coolTotal,
      'coolStock': state.coolStock,
      'petTotal': state.petTotal,
      'petStock': state.petStock,
    });
  }

  void _apply(JarTransaction tx) {
    // The ceiling for coolStock after apply is the pre-damage total
    // (state.coolTotal), because damage is being removed from total simultaneously.
    // The net result must always satisfy: 0 <= coolStock <= newCoolTotal.
    final newCoolTotal = state.coolTotal - tx.coolDamaged;
    final newPetTotal  = state.petTotal  - tx.petDamaged;
    state = state.copyWith(
      coolStock: (state.coolStock -
              tx.coolDelivered +
              tx.coolReturned -
              tx.coolDamaged)
          .clamp(0, newCoolTotal),
      petStock: (state.petStock -
              tx.petDelivered +
              tx.petReturned -
              tx.petDamaged)
          .clamp(0, newPetTotal),
      coolTotal: newCoolTotal,
      petTotal:  newPetTotal,
    );
    _save();
  }

  void _revert(JarTransaction tx) {
    // Restore totals first so the clamp ceiling is accurate when restoring stock.
    // BUG FIX: the old ceiling was 9999, which allowed coolStock to exceed
    // coolTotal after a delete/revert — the root cause of "stock jumps above 100".
    // The correct ceiling is the post-restore total (i.e. total before the tx
    // was originally applied).
    final restoredCoolTotal = state.coolTotal + tx.coolDamaged;
    final restoredPetTotal  = state.petTotal  + tx.petDamaged;
    state = state.copyWith(
      coolStock: (state.coolStock +
              tx.coolDelivered -
              tx.coolReturned +
              tx.coolDamaged)
          .clamp(0, restoredCoolTotal),
      petStock: (state.petStock +
              tx.petDelivered -
              tx.petReturned +
              tx.petDamaged)
          .clamp(0, restoredPetTotal),
      coolTotal: restoredCoolTotal,
      petTotal:  restoredPetTotal,
    );
    _save();
  }

  void _writeMovement(InventoryMovement mov) {
    FirebaseService.instance.setChild(
        FirebaseConfig.nodeInventoryMovements, mov.invId, mov.toJson());
  }

  static bool _hasJarMovement(JarTransaction tx) =>
      tx.coolDelivered > 0 ||
      tx.petDelivered > 0 ||
      tx.coolReturned > 0 ||
      tx.petReturned > 0 ||
      tx.coolDamaged > 0 ||
      tx.petDamaged > 0;

  void apply(JarTransaction tx, {String? revId}) {
    if (!_hasJarMovement(tx)) return;
    _apply(tx);
    _writeMovement(InventoryMovement.fromApply(tx, revId: revId));
  }

  void revert(JarTransaction tx) {
    if (!_hasJarMovement(tx)) return;
    _revert(tx);
    _writeMovement(InventoryMovement.fromRevert(tx));
  }

  void edit(JarTransaction old, JarTransaction neu, {String? revId}) {
    if (!_hasJarMovement(old) && !_hasJarMovement(neu)) return;
    _revert(old);
    _apply(neu);
    _writeMovement(InventoryMovement.fromEditDelta(old, neu, revId: revId));
  }

  void addStock(int cool, int pet) {
    state = state.copyWith(
        coolStock: state.coolStock + cool,
        coolTotal: state.coolTotal + cool,
        petStock: state.petStock + pet,
        petTotal: state.petTotal + pet);
    _save();
    _writeMovement(InventoryMovement(
      invId: _uuid.v4(),
      type: 'add_stock',
      coolDelta: cool,
      petDelta: pet,
      coolTotalDelta: cool,
      petTotalDelta: pet,
      createdAt: _now(),
      note: 'Stock-in: $cool cool, $pet PET',
    ));
  }

  void recordLoss(int cool, int pet) {
    state = state.copyWith(
      coolStock: (state.coolStock - cool).clamp(0, state.coolTotal),
      coolTotal: (state.coolTotal - cool).clamp(0, 9999),
      petStock: (state.petStock - pet).clamp(0, state.petTotal),
      petTotal: (state.petTotal - pet).clamp(0, 9999),
    );
    _save();
    _writeMovement(InventoryMovement(
      invId: _uuid.v4(),
      type: 'record_loss',
      coolDelta: -cool,
      petDelta: -pet,
      coolTotalDelta: -cool,
      petTotalDelta: -pet,
      createdAt: _now(),
      note: 'Loss/damage write-off: $cool cool, $pet PET',
    ));
  }

  void syncStock(int totalCoolOut, int totalPetOut) {
    state = state.copyWith(
      coolStock:
          (state.coolTotal - totalCoolOut).clamp(0, state.coolTotal),
      petStock: (state.petTotal - totalPetOut).clamp(0, state.petTotal),
    );
    _save();
  }

  Future<void> refresh() async {
    final data = await FirebaseService.instance.readInventory();
    if (data != null) {
      final coolTotal = (data['coolTotal'] ?? 0).toInt();
      final petTotal  = (data['petTotal']  ?? 0).toInt();
      // SAFETY: same clamp as the live watcher — stock must never exceed total.
      final coolStock = ((data['coolStock'] ?? 0).toInt()).clamp(0, coolTotal);
      final petStock  = ((data['petStock']  ?? 0).toInt()).clamp(0, petTotal);
      state = InventoryState(
        coolTotal: coolTotal,
        coolStock: coolStock,
        petTotal:  petTotal,
        petStock:  petStock,
      );
      if (coolStock != (data['coolStock'] ?? 0).toInt() ||
          petStock  != (data['petStock']  ?? 0).toInt()) {
        debugPrint('[InventoryNotifier] refresh: stock exceeded total — auto-corrected');
        await _save();
      }
    }
  }

  void adjustForCustomerEdit(int coolDelta, int petDelta) {
    state = state.copyWith(
      coolStock:
          (state.coolStock - coolDelta).clamp(0, state.coolTotal),
      petStock:
          (state.petStock - petDelta).clamp(0, state.petTotal),
    );
    _save();
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>(
        (ref) => InventoryNotifier());

// ── Customers Notifier ────────────────────────────────────────────────────────
class CustomersNotifier extends StateNotifier<List<Customer>> {
  CustomersNotifier() : super([]) {
    Future.microtask(_init);
  }

  void _init() {
    FirebaseService.instance
        .watch(FirebaseConfig.nodeCustomers)
        .listen((data) {
      if (data != null) {
        final customers = <Customer>[];
        for (final entry in data.values) {
          try {
            customers.add(Customer.fromJson(_castMap(entry)));
          } catch (e) {
            debugPrint('[CustomersNotifier] parse error: $e');
          }
        }
        state = customers;
      } else {
        state = [];
      }
    }, onError: (e) => debugPrint('[CustomersNotifier] error: $e'));
  }

  void _assertAuth() {
    if (FirebaseAuth.instance.currentUser == null ||
        CompanySession.companyId.isEmpty) {
      throw StateError('Not authenticated — please sign in again.');
    }
  }

  Future<void> add(Customer c) async {
    _assertAuth();
    if (!state.any((x) => x.id == c.id)) {
      state = [...state, c];
    }
    await FirebaseService.instance
        .setChild(FirebaseConfig.nodeCustomers, c.id, c.toJson());
  }

  Future<void> update(Customer c) async {
    _assertAuth();
    state = [
      for (final x in state)
        if (x.id == c.id) c else x,
    ];
    await FirebaseService.instance
        .update('${FirebaseConfig.nodeCustomers}/${c.id}', c.toJson());
  }

  Future<void> remove(String id) async {
    _assertAuth();
    state = state.where((x) => x.id != id).toList();
    await FirebaseService.instance
        .removeChild(FirebaseConfig.nodeCustomers, id);
  }

  // FIX 3: throw instead of silently returning state.first on missing customer.
  // The old code returned state.first, causing the ledger entry to be written
  // with a completely wrong customer's balance.
  Customer _requireCustomer(String customerId) {
    final idx = state.indexWhere((c) => c.id == customerId);
    if (idx == -1) {
      throw StateError(
          'Customer $customerId not found in local state. '
          'The customer list may not have loaded yet — please refresh.');
    }
    return state[idx];
  }

  Customer applyTx(JarTransaction tx) {
    final c = _requireCustomer(tx.customerId);
    final neu = c.copyWith(
      coolOut: (c.coolOut + tx.coolDelivered - tx.coolReturned).clamp(0, 9999),
      petOut:
          (c.petOut + tx.petDelivered - tx.petReturned).clamp(0, 9999),
      balance: c.balance - (tx.billedAmount - tx.amountCollected),
    );
    update(neu);
    return neu;
  }

  Customer revertTx(JarTransaction tx) {
    final c = _requireCustomer(tx.customerId);
    final neu = c.copyWith(
      coolOut: (c.coolOut - tx.coolDelivered + tx.coolReturned).clamp(0, 9999),
      petOut:
          (c.petOut - tx.petDelivered + tx.petReturned).clamp(0, 9999),
      balance: c.balance + (tx.billedAmount - tx.amountCollected),
    );
    update(neu);
    return neu;
  }

  Future<void> refresh() async {
    final data = await FirebaseService.instance
        .readOnce(FirebaseConfig.nodeCustomers);
    if (data != null) {
      state = data.values
          .map((e) => Customer.fromJson(_castMap(e)))
          .toList();
    }
  }

  Customer applyTxEdit(JarTransaction oldTx, JarTransaction newTx) {
    final c = _requireCustomer(newTx.customerId);
    final oldNetJarCool = oldTx.coolDelivered - oldTx.coolReturned;
    final newNetJarCool = newTx.coolDelivered - newTx.coolReturned;
    final oldNetJarPet = oldTx.petDelivered - oldTx.petReturned;
    final newNetJarPet = newTx.petDelivered - newTx.petReturned;
    final oldNetBalance = oldTx.billedAmount - oldTx.amountCollected;
    final newNetBalance = newTx.billedAmount - newTx.amountCollected;
    final neu = c.copyWith(
      coolOut:
          (c.coolOut + (newNetJarCool - oldNetJarCool)).clamp(0, 9999),
      petOut:
          (c.petOut + (newNetJarPet - oldNetJarPet)).clamp(0, 9999),
      balance: c.balance - (newNetBalance - oldNetBalance),
    );
    update(neu);
    return neu;
  }
}

final customersProvider =
    StateNotifierProvider<CustomersNotifier, List<Customer>>(
        (ref) => CustomersNotifier());

// ── Ledger Notifier ───────────────────────────────────────────────────────────
class LedgerNotifier extends StateNotifier<List<LedgerEntry>> {
  LedgerNotifier() : super([]) {
    Future.microtask(_init);
  }

  void _init() {
    FirebaseService.instance
        .watch(FirebaseConfig.nodeLedgerEntries)
        .listen((data) {
      if (data != null) {
        state = (data as Map)
            .values
            .map((e) => LedgerEntry.fromJson(_castMap(e)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        state = [];
      }
    }, onError: (e) => debugPrint('[LedgerNotifier] error: $e'));
  }

  Future<void> refresh() async {
    final data = await FirebaseService.instance
        .readOnce(FirebaseConfig.nodeLedgerEntries);
    if (data != null) {
      state = (data as Map)
          .values
          .map((e) => LedgerEntry.fromJson(_castMap(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  List<LedgerEntry> forCustomer(String customerId) =>
      state.where((e) => e.customerId == customerId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

final ledgerProvider =
    StateNotifierProvider<LedgerNotifier, List<LedgerEntry>>(
        (ref) => LedgerNotifier());

// ── Transactions Notifier ─────────────────────────────────────────────────────
class TransactionsNotifier extends StateNotifier<List<JarTransaction>> {
  final Ref _ref;

  TransactionsNotifier(this._ref) : super([]) {
    Future.microtask(_init);
  }

  void _init() {
    FirebaseService.instance
        .watch(FirebaseConfig.nodeTransactions)
        .listen((data) {
      if (data == null) {
        state = [];
        return;
      }
      final parsed = <JarTransaction>[];
      for (final entry in data.values) {
        try {
          parsed.add(JarTransaction.fromJson(_castMap(entry)));
        } catch (e) {
          debugPrint('[TransactionsNotifier] skipped malformed record: $e');
        }
      }
      parsed.sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.createdAt.compareTo(a.createdAt);
      });
      state = parsed;
    }, onError: (e) => debugPrint('[TransactionsNotifier] error: $e'));
  }

  Future<void> refreshAll(WidgetRef ref) async {
    final txData = await FirebaseService.instance
        .readOnce(FirebaseConfig.nodeTransactions);
    if (txData != null) {
      final parsed = <JarTransaction>[];
      for (final entry in txData.values) {
        try {
          parsed.add(JarTransaction.fromJson(_castMap(entry)));
        } catch (_) {}
      }
      parsed.sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.createdAt.compareTo(a.createdAt);
      });
      state = parsed;
    }
    await ref.read(customersProvider.notifier).refresh();
    await ref.read(inventoryProvider.notifier).refresh();
    await ref.read(ledgerProvider.notifier).refresh();
  }

  Future<void> _writeLedger(JarTransaction tx, double balanceAfter) async {
    final entry = LedgerEntry.fromTransaction(tx, balanceAfter);
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLedgerEntries, entry.id, entry.toJson());
  }

  Map<String, int> reconcileWithTrips(LoadUnloadState trips, String date) {
    final txToday = state.where((t) => t.date == date).toList();
    final txCoolDel = txToday.fold(0, (s, t) => s + t.coolDelivered);
    final txPetDel = txToday.fold(0, (s, t) => s + t.petDelivered);
    final txCoolRet = txToday.fold(0, (s, t) => s + t.coolReturned);
    final txPetRet = txToday.fold(0, (s, t) => s + t.petReturned);
    return {
      'tripCoolLoaded': trips.totalCoolLoaded,
      'tripPetLoaded': trips.totalPetLoaded,
      'tripCoolUnloaded': trips.totalCoolUnloaded,
      'tripPetUnloaded': trips.totalPetUnloaded,
      'txCoolDelivered': txCoolDel,
      'txPetDelivered': txPetDel,
      'txCoolReturned': txCoolRet,
      'txPetReturned': txPetRet,
      'coolMismatch': trips.expectedCoolDelivered - txCoolDel,
      'petMismatch': trips.expectedPetDelivered - txPetDel,
    };
  }

  Future<void> _deleteLedger(String txId) async {
    await FirebaseService.instance
        .removeChild(FirebaseConfig.nodeLedgerEntries, 'le_$txId');
  }

  void _assertAuth() {
    if (FirebaseAuth.instance.currentUser == null ||
        CompanySession.companyId.isEmpty) {
      throw StateError('Not authenticated — please sign in again.');
    }
  }

  // FIX 2 (audit performer): get real user name from sessionUserProvider
  String get _performer {
    final u = _ref.read(sessionUserProvider);
    return u?.name ?? 'Owner';
  }

  Future<void> add(JarTransaction tx) async {
    _assertAuth();
    await FirebaseService.instance
        .setChild(FirebaseConfig.nodeTransactions, tx.id, tx.toJson());
    final updatedCust =
        _ref.read(customersProvider.notifier).applyTx(tx);
    _ref.read(inventoryProvider.notifier).apply(tx);
    await _writeLedger(tx, updatedCust.balance);
    _ref.read(auditProvider.notifier).log(
          type: 'transaction_created',
          description: 'Transaction for ${tx.customerName}',
          entityId: tx.id,
          after:
              'C↓${tx.coolDelivered} C↑${tx.coolReturned} P↓${tx.petDelivered} P↑${tx.petReturned} ₹${tx.billedAmount} paid:${tx.amountCollected}',
        );
  }

  Future<void> edit(JarTransaction old, JarTransaction neu,
      {String editNote = ''}) async {
    _assertAuth();
    final history =
        TxEditHistory.from(old, editedBy: _performer, note: editNote);
    final neuWithHistory = neu.copyWith(
      editHistory: [history, ...old.editHistory],
      updatedAt: _now(),
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeTransactions, neu.id, neuWithHistory.toJson());

    final revNumber = old.editHistory.length + 2;
    final rev = TransactionRevision.fromTransaction(neuWithHistory,
        revNumber: revNumber,
        isLatest: true,
        editedBy: _performer,
        editNote: editNote);
    await FirebaseService.instance
        .setChild(FirebaseConfig.nodeRevisions, rev.revId, rev.toJson());

    final updatedCust = _ref
        .read(customersProvider.notifier)
        .applyTxEdit(old, neuWithHistory);
    _ref
        .read(inventoryProvider.notifier)
        .edit(old, neuWithHistory, revId: rev.revId);
    await _writeLedger(neuWithHistory, updatedCust.balance);

    // FIX 4: stable paymentId means this overwrites instead of duplicating
    if (neu.amountCollected > 0) {
      final pmt = PaymentRecord.fromTransaction(neuWithHistory);
      await FirebaseService.instance
          .setChild(FirebaseConfig.nodePayments, pmt.paymentId, pmt.toJson());
    }

    _ref.read(auditProvider.notifier).log(
          type: 'transaction_edited',
          description:
              'Ledger edited for ${neu.customerName}${editNote.isNotEmpty ? ": $editNote" : ""}',
          entityId: neu.id,
          before:
              'C↓${old.coolDelivered} C↑${old.coolReturned} ₹${old.billedAmount} coll:${old.amountCollected}',
          after:
              'C↓${neu.coolDelivered} C↑${neu.coolReturned} ₹${neu.billedAmount} coll:${neu.amountCollected}',
        );
  }

  Future<void> delete(JarTransaction tx) async {
    _assertAuth();
    await FirebaseService.instance
        .removeChild(FirebaseConfig.nodeTransactions, tx.id);
    _ref.read(customersProvider.notifier).revertTx(tx);
    _ref.read(inventoryProvider.notifier).revert(tx);
    await _deleteLedger(tx.id);
    _ref.read(auditProvider.notifier).log(
          type: 'transaction_deleted',
          description:
              'Deleted for ${tx.customerName} — revisions + movements retained',
          entityId: tx.id,
          before:
              'C↓${tx.coolDelivered} C↑${tx.coolReturned} ₹${tx.billedAmount} coll:${tx.amountCollected}',
        );
  }

  // ── Multi-day event helpers ───────────────────────────────────────────────

  /// Returns all transactions belonging to the same multi-day event group.
  List<JarTransaction> eventDays(String eventId) =>
      state.where((t) => t.eventId == eventId).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// Propagate event-level metadata (name / dates / status) to every day
  /// in the group without touching per-day jar counts or billing.
  Future<void> updateEventMeta({
    required String eventId,
    String? newEventName,
    String? newEventStartDate,
    String? newEventEndDate,
    String? newEventStatus,
  }) async {
    _assertAuth();
    final now = DateTime.now().toIso8601String();
    final updated = state.map((tx) {
      if (tx.eventId != eventId) return tx;
      return tx.copyWith(
        eventName: newEventName ?? tx.eventName,
        eventStartDate: newEventStartDate ?? tx.eventStartDate,
        eventEndDate: newEventEndDate ?? tx.eventEndDate,
        eventStatus: newEventStatus ?? tx.eventStatus,
        updatedAt: now,
      );
    }).toList();
    state = updated;
    // Persist every changed day to Firebase
    for (final tx in updated.where((t) => t.eventId == eventId)) {
      await FirebaseService.instance
          .setChild(FirebaseConfig.nodeTransactions, tx.id, tx.toJson());
    }
    _ref.read(auditProvider.notifier).log(
      type: 'event_meta_updated',
      description: 'Event "$newEventName" metadata updated across all days',
      entityId: eventId,
    );
  }

  /// Delete every transaction in a multi-day event group and revert all
  /// inventory / customer ledger impacts day-by-day.
  Future<void> deleteEvent(String eventId) async {
    _assertAuth();
    final days = eventDays(eventId);
    if (days.isEmpty) return;
    for (final tx in days) {
      await FirebaseService.instance
          .removeChild(FirebaseConfig.nodeTransactions, tx.id);
      _ref.read(customersProvider.notifier).revertTx(tx);
      _ref.read(inventoryProvider.notifier).revert(tx);
      await _deleteLedger(tx.id);
    }
    _ref.read(auditProvider.notifier).log(
      type: 'event_deleted',
      description:
          'Multi-day event deleted: ${days.first.eventName} (${days.length} days)',
      entityId: eventId,
      before: '${days.length} day(s) reverted',
    );
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, List<JarTransaction>>(
        (ref) => TransactionsNotifier(ref));

// ── Tab Management ────────────────────────────────────────────────────────────
final tabProvider = StateProvider<int>((ref) => 0);
final selectedCustomerForTxnProvider = StateProvider<Customer?>((ref) => null);

// ══════════════════════════════════════════════════════════════════════════════
// TRIP ENTRY MODEL
// FIX 5: expectedCoolDelivered no longer subtracts emptyReturned.
//   Old: coolLoaded - emptyReturned - filledReturned  ← WRONG (double subtraction)
//   New: coolLoaded - filledReturned                  ← CORRECT
//   Empty jars ARE confirmed deliveries (jars came back empty from customers).
//   Only filledReturned (undelivered full jars) should reduce expected delivery.
// ══════════════════════════════════════════════════════════════════════════════

class TripEntry {
  final String id;
  final int tripNumber;
  final String vehicleId;
  final String date;
  final int coolLoaded;
  final int petLoaded;
  final String loadTime;
  final int? coolEmptyReturned;
  final int? petEmptyReturned;
  final int? coolFilledReturned;
  final int? petFilledReturned;
  final String? unloadTime;
  final String? driverNote;
  final String status;

  const TripEntry({
    required this.id,
    required this.tripNumber,
    required this.vehicleId,
    required this.date,
    required this.coolLoaded,
    required this.petLoaded,
    required this.loadTime,
    this.coolEmptyReturned,
    this.petEmptyReturned,
    this.coolFilledReturned,
    this.petFilledReturned,
    this.unloadTime,
    this.driverNote,
    this.status = 'pending',
  });

  bool get isComplete => unloadTime != null;
  int get coolUnloaded => coolFilledReturned ?? 0;
  int get petUnloaded => petFilledReturned ?? 0;

  // FIX 5: correct delivery math — only subtract unfulfilled full jars.
  // Empty jars returned = jars that WERE delivered (customers sent empty shells back).
  // Full jars returned  = jars that were NOT delivered (returned to warehouse).
  int get coolExpectedDelivered => isComplete
      ? (coolLoaded - (coolFilledReturned ?? 0)).clamp(0, coolLoaded)
      : 0;
  int get petExpectedDelivered => isComplete
      ? (petLoaded - (petFilledReturned ?? 0)).clamp(0, petLoaded)
      : 0;

  int get coolDelivered => coolExpectedDelivered;
  int get petDelivered => petExpectedDelivered;
  bool get hasMismatch => status == 'discrepancy';

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripNumber': tripNumber,
        'vehicleId': vehicleId,
        'date': date,
        'coolLoaded': coolLoaded,
        'petLoaded': petLoaded,
        'loadTime': loadTime,
        'coolEmptyReturned': coolEmptyReturned,
        'petEmptyReturned': petEmptyReturned,
        'coolFilledReturned': coolFilledReturned,
        'petFilledReturned': petFilledReturned,
        'coolUnloaded': coolFilledReturned,
        'petUnloaded': petFilledReturned,
        'unloadTime': unloadTime,
        'driverNote': driverNote,
        'status': status,
      };

  factory TripEntry.fromJson(Map<String, dynamic> j) {
    final coolFilled = j['coolFilledReturned'] ?? j['coolUnloaded'];
    final petFilled = j['petFilledReturned'] ?? j['petUnloaded'];
    return TripEntry(
      id: j['id']?.toString() ?? '',
      tripNumber: j['tripNumber'] ?? 0,
      vehicleId: j['vehicleId']?.toString() ?? '',
      date: j['date']?.toString() ?? '',
      coolLoaded: j['coolLoaded'] ?? 0,
      petLoaded: j['petLoaded'] ?? 0,
      loadTime: j['loadTime']?.toString() ?? _now(),
      coolEmptyReturned: j['coolEmptyReturned'],
      petEmptyReturned: j['petEmptyReturned'],
      coolFilledReturned: coolFilled,
      petFilledReturned: petFilled,
      unloadTime: j['unloadTime']?.toString(),
      driverNote: j['driverNote']?.toString(),
      status: j['status']?.toString() ??
          (coolFilled != null ? 'complete' : 'pending'),
    );
  }

  TripEntry copyWithUnload({
    required int coolEmptyReturned,
    required int petEmptyReturned,
    required int coolFilledReturned,
    required int petFilledReturned,
    required String unloadTime,
    required String status,
    String? driverNote,
  }) =>
      TripEntry(
        id: id,
        tripNumber: tripNumber,
        vehicleId: vehicleId,
        date: date,
        coolLoaded: coolLoaded,
        petLoaded: petLoaded,
        loadTime: loadTime,
        coolEmptyReturned: coolEmptyReturned,
        petEmptyReturned: petEmptyReturned,
        coolFilledReturned: coolFilledReturned,
        petFilledReturned: petFilledReturned,
        unloadTime: unloadTime,
        driverNote: driverNote ?? this.driverNote,
        status: status,
      );
}

// ── Load/Unload State ─────────────────────────────────────────────────────────
class LoadUnloadState {
  final List<TripEntry> trips;
  final String vehicleId;
  final String sessionDate;

  const LoadUnloadState({
    this.trips = const [],
    this.vehicleId = 'VH-01',
    required this.sessionDate,
  });

  List<TripEntry> get todayTrips {
    final list = trips.where((t) => t.date == sessionDate).toList();
    list.sort((a, b) => a.loadTime.compareTo(b.loadTime));
    return list;
  }

  bool get hasActiveTrip => todayTrips.any((t) => !t.isComplete);
  TripEntry? get activeTrip =>
      todayTrips.where((t) => !t.isComplete).isNotEmpty
          ? todayTrips.where((t) => !t.isComplete).last
          : null;

  int get totalCoolLoaded =>
      todayTrips.fold(0, (s, t) => s + t.coolLoaded);
  int get totalPetLoaded =>
      todayTrips.fold(0, (s, t) => s + t.petLoaded);
  int get totalCoolEmptyReturned =>
      todayTrips.fold(0, (s, t) => s + (t.coolEmptyReturned ?? 0));
  int get totalPetEmptyReturned =>
      todayTrips.fold(0, (s, t) => s + (t.petEmptyReturned ?? 0));
  int get totalCoolFilledReturned =>
      todayTrips.fold(0, (s, t) => s + (t.coolFilledReturned ?? 0));
  int get totalPetFilledReturned =>
      todayTrips.fold(0, (s, t) => s + (t.petFilledReturned ?? 0));
  int get totalCoolUnloaded => totalCoolFilledReturned;
  int get totalPetUnloaded => totalPetFilledReturned;
  int get totalCoolDelivered =>
      todayTrips.fold(0, (s, t) => s + t.coolExpectedDelivered);
  int get totalPetDelivered =>
      todayTrips.fold(0, (s, t) => s + t.petExpectedDelivered);
  bool get hasMismatch => todayTrips.any((t) => t.hasMismatch);
  int get pendingTripCount =>
      todayTrips.where((t) => t.status == 'pending').length;
  int get discrepancyCount =>
      todayTrips.where((t) => t.status == 'discrepancy').length;

  // FIX 5: expectedDelivered = loaded - filledReturned only
  int get expectedCoolDelivered => totalCoolLoaded - totalCoolUnloaded;
  int get expectedPetDelivered => totalPetLoaded - totalPetUnloaded;

  LoadUnloadState copyWith(
          {List<TripEntry>? trips, String? vehicleId}) =>
      LoadUnloadState(
        trips: trips ?? this.trips,
        vehicleId: vehicleId ?? this.vehicleId,
        sessionDate: sessionDate,
      );
}

// ── Load/Unload Notifier ──────────────────────────────────────────────────────
// FIX 6: Now watches nodeLoadUnload only (trip UUIDs).
//        DayLogNotifier has been moved to its own nodeDayLogs node.
class LoadUnloadNotifier extends StateNotifier<LoadUnloadState> {
  LoadUnloadNotifier()
      : super(LoadUnloadState(
          sessionDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        )) {
    Future.microtask(_init);
  }

  void _init() {
    FirebaseService.instance
        .watch(FirebaseConfig.nodeLoadUnload)
        .listen((data) {
      if (data != null) {
        final trips = (data as Map)
            .values
            .map((e) => TripEntry.fromJson(_castMap(e)))
            .toList();
        state = state.copyWith(trips: trips);
      } else {
        state = state.copyWith(trips: []);
      }
    });
  }

  void changeVehicle(String id) => state = state.copyWith(vehicleId: id);

  void _assertAuth() {
    if (FirebaseAuth.instance.currentUser == null ||
        CompanySession.companyId.isEmpty) {
      throw StateError('Not authenticated — cannot save trip data.');
    }
  }

  Future<void> recordLoad(
      {required int cool, required int pet, WidgetRef? ref}) async {
    _assertAuth();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final trip = TripEntry(
      id: _uuid.v4(),
      tripNumber: state.todayTrips.length + 1,
      coolLoaded: cool,
      petLoaded: pet,
      loadTime: _now(),
      vehicleId: state.vehicleId,
      date: today,
      status: 'pending',
    );
    await FirebaseService.instance
        .setChild(FirebaseConfig.nodeLoadUnload, trip.id, trip.toJson());
  }

  Future<void> recordUnload({
    required String tripId,
    required int coolEmptyReturned,
    required int petEmptyReturned,
    required int coolFilledReturned,
    required int petFilledReturned,
    String? driverNote,
    WidgetRef? ref,
    int txCoolDelivered = 0,
    int txPetDelivered = 0,
  }) async {
    final trip = state.trips.firstWhere((t) => t.id == tripId);
    // FIX 5: reconcile using fixed expectedDelivered math
    final expCool =
        (trip.coolLoaded - coolFilledReturned).clamp(0, trip.coolLoaded);
    final expPet =
        (trip.petLoaded - petFilledReturned).clamp(0, trip.petLoaded);
    final reconciled =
        expCool == txCoolDelivered && expPet == txPetDelivered;
    final status = reconciled ? 'complete' : 'discrepancy';
    final updated = trip.copyWithUnload(
      coolEmptyReturned: coolEmptyReturned,
      petEmptyReturned: petEmptyReturned,
      coolFilledReturned: coolFilledReturned,
      petFilledReturned: petFilledReturned,
      unloadTime: _now(),
      driverNote: driverNote,
      status: status,
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, trip.id, updated.toJson());
  }

  Future<void> editTrip({
    required String tripId,
    required int coolEmptyReturned,
    required int petEmptyReturned,
    required int coolFilledReturned,
    required int petFilledReturned,
    required TripEntry oldTrip,
    String? adminNote,
    WidgetRef? ref,
    int txCoolDelivered = 0,
    int txPetDelivered = 0,
  }) async {
    final expCool = (oldTrip.coolLoaded - coolFilledReturned)
        .clamp(0, oldTrip.coolLoaded);
    final expPet = (oldTrip.petLoaded - petFilledReturned)
        .clamp(0, oldTrip.petLoaded);
    final reconciled =
        expCool == txCoolDelivered && expPet == txPetDelivered;
    final status = reconciled ? 'complete' : 'discrepancy';
    final corrected = oldTrip.copyWithUnload(
      coolEmptyReturned: coolEmptyReturned,
      petEmptyReturned: petEmptyReturned,
      coolFilledReturned: coolFilledReturned,
      petFilledReturned: petFilledReturned,
      unloadTime: oldTrip.unloadTime ?? _now(),
      driverNote: adminNote ?? oldTrip.driverNote,
      status: status,
    );
    await FirebaseService.instance.setChild(
        FirebaseConfig.nodeLoadUnload, tripId, corrected.toJson());
  }

  Future<void> markDayReviewed() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final pending = state.trips
        .where((t) => t.date == today && t.status == 'pending')
        .toList();
    for (final trip in pending) {
      await FirebaseService.instance.update(
        '${FirebaseConfig.nodeLoadUnload}/${trip.id}',
        {'status': 'discrepancy', 'reviewedAt': _now()},
      );
    }
  }
}

final loadUnloadProvider =
    StateNotifierProvider<LoadUnloadNotifier, LoadUnloadState>(
        (ref) => LoadUnloadNotifier());

// ══════════════════════════════════════════════════════════════════════════════
// DAY LOG MODEL + PROVIDER
// FIX 6: Now uses nodeDayLogs — a separate RTDB node from nodeLoadUnload.
//        Old code had both LoadUnloadNotifier and DayLogNotifier watching
//        nodeLoadUnload, causing each to try to parse the other's records
//        (TripEntry vs DayLog schemas are incompatible).
// ══════════════════════════════════════════════════════════════════════════════

class DayLog {
  final String date;
  final int coolLoaded;
  final int petLoaded;
  final int coolEmptyReturned;
  final int petEmptyReturned;
  final int coolFilledReturned;
  final int petFilledReturned;
  final String? note;

  const DayLog({
    required this.date,
    this.coolLoaded = 0,
    this.petLoaded = 0,
    this.coolEmptyReturned = 0,
    this.petEmptyReturned = 0,
    this.coolFilledReturned = 0,
    this.petFilledReturned = 0,
    this.note,
  });

  int get coolNetDelivered =>
      (coolLoaded - coolEmptyReturned - coolFilledReturned)
          .clamp(0, coolLoaded);
  int get petNetDelivered =>
      (petLoaded - petEmptyReturned - petFilledReturned).clamp(0, petLoaded);

  Map<String, dynamic> toJson() => {
        'id': date,
        'date': date,
        'coolLoaded': coolLoaded,
        'petLoaded': petLoaded,
        'coolEmptyReturned': coolEmptyReturned,
        'petEmptyReturned': petEmptyReturned,
        'coolFilledReturned': coolFilledReturned,
        'petFilledReturned': petFilledReturned,
        'note': note,
        'updatedAt': _now(),
      };

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
        date: j['date']?.toString() ?? '',
        coolLoaded: j['coolLoaded'] ?? 0,
        petLoaded: j['petLoaded'] ?? 0,
        coolEmptyReturned: j['coolEmptyReturned'] ?? 0,
        petEmptyReturned: j['petEmptyReturned'] ?? 0,
        coolFilledReturned: j['coolFilledReturned'] ?? 0,
        petFilledReturned: j['petFilledReturned'] ?? 0,
        note: j['note']?.toString(),
      );

  DayLog copyWith({
    int? coolLoaded,
    int? petLoaded,
    int? coolEmptyReturned,
    int? petEmptyReturned,
    int? coolFilledReturned,
    int? petFilledReturned,
    String? note,
  }) =>
      DayLog(
        date: date,
        coolLoaded: coolLoaded ?? this.coolLoaded,
        petLoaded: petLoaded ?? this.petLoaded,
        coolEmptyReturned: coolEmptyReturned ?? this.coolEmptyReturned,
        petEmptyReturned: petEmptyReturned ?? this.petEmptyReturned,
        coolFilledReturned: coolFilledReturned ?? this.coolFilledReturned,
        petFilledReturned: petFilledReturned ?? this.petFilledReturned,
        note: note ?? this.note,
      );
}

class DayLogNotifier extends StateNotifier<List<DayLog>> {
  DayLogNotifier() : super([]) {
    Future.microtask(_init);
  }

  void _init() {
    // FIX 6: watch nodeDayLogs, NOT nodeLoadUnload
    FirebaseService.instance
        .watch(FirebaseConfig.nodeDayLogs)
        .listen((data) {
      if (data == null) {
        state = [];
        return;
      }
      final logs = <DayLog>[];
      for (final entry in data.values) {
        try {
          logs.add(DayLog.fromJson(_castMap(entry)));
        } catch (_) {}
      }
      logs.sort((a, b) => b.date.compareTo(a.date));
      state = logs;
    });
  }

  DayLog? get todayLog {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      return state.firstWhere((d) => d.date == today);
    } catch (_) {
      return null;
    }
  }

  void _assertAuth() {
    if (FirebaseAuth.instance.currentUser == null ||
        CompanySession.companyId.isEmpty) {
      throw StateError('Not authenticated — cannot save load/unload data.');
    }
  }

  Future<void> addLoad({required int cool, required int pet}) async {
    _assertAuth();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = todayLog ?? DayLog(date: today);
    final updated = existing.copyWith(
      coolLoaded: existing.coolLoaded + cool,
      petLoaded: existing.petLoaded + pet,
    );
    // FIX 6: write to nodeDayLogs
    await FirebaseService.instance
        .setChild(FirebaseConfig.nodeDayLogs, today, updated.toJson());
  }

  Future<void> addUnload({
    required int coolEmpty,
    required int petEmpty,
    required int coolFilled,
    required int petFilled,
  }) async {
    _assertAuth();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = todayLog ?? DayLog(date: today);
    final updated = existing.copyWith(
      coolEmptyReturned: existing.coolEmptyReturned + coolEmpty,
      petEmptyReturned: existing.petEmptyReturned + petEmpty,
      coolFilledReturned: existing.coolFilledReturned + coolFilled,
      petFilledReturned: existing.petFilledReturned + petFilled,
    );
    await FirebaseService.instance
        .setChild(FirebaseConfig.nodeDayLogs, today, updated.toJson());
  }

  Future<void> setExact({
    required int coolLoaded,
    required int petLoaded,
    required int coolEmpty,
    required int petEmpty,
    required int coolFilled,
    required int petFilled,
    String? note,
  }) async {
    _assertAuth();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final updated = DayLog(
      date: today,
      coolLoaded: coolLoaded,
      petLoaded: petLoaded,
      coolEmptyReturned: coolEmpty,
      petEmptyReturned: petEmpty,
      coolFilledReturned: coolFilled,
      petFilledReturned: petFilled,
      note: note,
    );
    await FirebaseService.instance
        .setChild(FirebaseConfig.nodeDayLogs, today, updated.toJson());
  }
}

final dayLogProvider =
    StateNotifierProvider<DayLogNotifier, List<DayLog>>(
        (ref) => DayLogNotifier());
