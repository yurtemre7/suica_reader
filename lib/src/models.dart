import 'package:meta/meta.dart';

/// All data read from a single Suica/FeliCa card scan.
@immutable
class SuicaCardData {
  /// IDm — 8-byte card identifier in uppercase hex (e.g. "0123456789ABCDEF").
  final String idm;

  /// System code in uppercase hex — "0003" for Suica/PASMO.
  final String? systemCode;

  /// Balance in Japanese Yen (JPY), or null if the service was unreadable.
  final int? balance;

  /// UTC timestamp of this scan.
  final DateTime scannedAt;

  /// Recent trip history, newest first. Empty if the service was unreadable.
  final List<SuicaHistoryEntry> history;

  const SuicaCardData({
    required this.idm,
    required this.scannedAt,
    this.systemCode,
    this.balance,
    this.history = const [],
  });

  @override
  String toString() =>
      'SuicaCardData('
      'idm: $idm, '
      'systemCode: $systemCode, '
      'balance: $balance JPY, '
      'trips: ${history.length}'
      ')';
}

/// Terminal type codes decoded from history block byte 0.
enum TerminalType {
  gate('Gate'),
  bus('Bus'),
  charger('Charger'),
  vendingMachine('Vending machine'),
  unknown('Unknown');

  const TerminalType(this.label);
  final String label;
}

/// Process type codes decoded from history block byte 1.
enum ProcessType {
  entry('Entry'),
  exit('Exit'),
  busEntry('Bus entry'),
  busExit('Bus exit'),
  fareAdjust('Fare adjustment'),
  purchase('Purchase'),
  charge('Charge'),
  unknown('Unknown');

  const ProcessType(this.label);
  final String label;
}

/// A single trip/transaction entry (16 raw bytes per block on the card).
@immutable
class SuicaHistoryEntry {
  /// Date of this transaction, or null if bytes were unreadable.
  final DateTime? date;

  /// Decoded terminal type.
  final TerminalType terminalType;

  /// Decoded process type.
  final ProcessType processType;

  /// Balance remaining after this transaction, in JPY.
  final int? balanceAfter;

  /// The raw 16-byte block from the card, for advanced parsing.
  final List<int> raw;

  const SuicaHistoryEntry({
    this.date,
    this.terminalType = TerminalType.unknown,
    this.processType = ProcessType.unknown,
    this.balanceAfter,
    required this.raw,
  });

  @override
  String toString() =>
      'SuicaHistoryEntry('
      'date: $date, '
      'terminal: ${terminalType.label}, '
      'process: ${processType.label}, '
      'balanceAfter: $balanceAfter JPY'
      ')';
}
