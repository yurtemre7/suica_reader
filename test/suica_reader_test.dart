import 'package:flutter_test/flutter_test.dart';
import 'package:suica_reader/src/suica_parser.dart';
import 'package:suica_reader/suica_reader.dart';

// ─── Real card data captured from IDm: 01010214D621BC01 ──────────────────────
//
// Captured: 2026-06-28
// Card:     Suica (systemCode: 0003)
// Balance:  500 JPY

/// Real balance service block (0x008B) as read from the card.
/// Bytes 11–12 little-endian = 0xF4, 0x01 = 500 yen.
const _realBalanceBlock = [
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x20, 0x00, 0x00, 0xF4, 0x01, 0x00, 0x00, 0x01,
];

/// Real history block 0 (0x090F) as read from the card.
/// Terminal: 0x12 (vendingMachine), Process: 0x07 (entry)
/// Date bytes [4,5] = 0x31, 0x51 → 2024-10-17
/// Balance after bytes [10,11] = 0xF4, 0x01 = 500 yen
const _realHistoryBlock0 = [
  0x12, 0x07, 0x00, 0x00, 0x31, 0x51, 0x18, 0x11,
  0x00, 0x00, 0xF4, 0x01, 0x00, 0x00, 0x01, 0x00,
];

/// Real empty/unfilled history slot from this card.
/// byte[3]=0x80 makes the all-zeros check insufficient.
const _emptyHistoryBlock = [
  0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
];

/// Full payload as returned by the transport layer for this card.
Map<String, dynamic> realCardPayload() => {
  'idm': [0x01, 0x01, 0x02, 0x14, 0xD6, 0x21, 0xBC, 0x01],
  'systemCode': [0x00, 0x03],
  'balanceBlock': List<int>.from(_realBalanceBlock),
  'historyBlocks': [
    List<int>.from(_realHistoryBlock0),
    // Remaining 19 slots are empty on this card.
    ...List.generate(19, (_) => List<int>.from(_emptyHistoryBlock)),
  ],
};

// ─── Fake transport ───────────────────────────────────────────────────────────

class FakeSuicaTransport implements SuicaNfcTransport {
  FakeSuicaTransport({
    required this.available,
    this.payload,
    this.error,
  });

  final bool available;
  final Map<String, dynamic>? payload;
  final Object? error;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, dynamic>> scanFelica({String iosAlertMessage = ''}) async {
    if (error != null) throw error!;
    return payload!;
  }
}

FakeSuicaTransport realCardTransport() => FakeSuicaTransport(
  available: true,
  payload: realCardPayload(),
);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('SuicaReader (real card data)', () {
    test('isAvailable returns true', () async {
      final reader = SuicaReader(transport: realCardTransport());
      expect(await reader.isAvailable(), isTrue);
    });

    test('readCard returns correct IDm', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final card = await reader.readCard();
      expect(card.idm, '01010214D621BC01');
    });

    test('readCard returns correct systemCode', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final card = await reader.readCard();
      expect(card.systemCode, '0003');
    });

    test('readBalance returns 500 yen', () async {
      final reader = SuicaReader(transport: realCardTransport());
      expect(await reader.readBalance(), 500);
    });

    test('readCard returns 1 non-empty history entry', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final card = await reader.readCard();
      expect(card.history.length, 1);
    });

    test('history entry has correct date (2024-10-17)', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final card = await reader.readCard();
      expect(card.history.first.date, DateTime(2024, 10, 17));
    });

    test('history entry has correct balanceAfter (500 yen)', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final card = await reader.readCard();
      expect(card.history.first.balanceAfter, 500);
    });

    test('history entry has correct terminalType (vendingMachine)', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final card = await reader.readCard();
      expect(card.history.first.terminalType, TerminalType.vendingMachine);
    });

    test('history entry has correct processType (entry)', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final card = await reader.readCard();
      expect(card.history.first.processType, ProcessType.entry);
    });
  });

  group('SuicaReader (edge cases)', () {
    test('isAvailable returns false when NFC off', () async {
      final reader = SuicaReader(
        transport: FakeSuicaTransport(available: false),
      );
      expect(await reader.isAvailable(), isFalse);
    });

    test('readCard throws NfcUnavailableException when NFC off', () async {
      final reader = SuicaReader(
        transport: FakeSuicaTransport(available: false),
      );
      await expectLater(reader.readCard(), throwsA(isA<NfcUnavailableException>()));
    });

    test('readBalance returns null when balanceBlock absent', () async {
      final payload = Map<String, dynamic>.from(realCardPayload())
        ..remove('balanceBlock');
      final reader = SuicaReader(
        transport: FakeSuicaTransport(available: true, payload: payload),
      );
      expect(await reader.readBalance(), isNull);
    });

    test('readLatestTrips respects limit', () async {
      final reader = SuicaReader(transport: realCardTransport());
      final trips = await reader.readLatestTrips(limit: 0);
      expect(trips, isEmpty);
    });

    test('readLatestTrips returns empty when no historyBlocks', () async {
      final payload = Map<String, dynamic>.from(realCardPayload())
        ..remove('historyBlocks');
      final reader = SuicaReader(
        transport: FakeSuicaTransport(available: true, payload: payload),
      );
      expect(await reader.readLatestTrips(), isEmpty);
    });
  });

  group('SuicaParser (real card bytes)', () {
    test('parseBalance decodes real balance block to 500 yen', () {
      expect(
        SuicaParser.parseBalance(List<int>.from(_realBalanceBlock)),
        500,
      );
    });

    test('parseBalance returns null for short block', () {
      expect(SuicaParser.parseBalance(List.filled(12, 0)), isNull);
    });

    test('parseHistory skips all empty blocks', () {
      final blocks = List.generate(20, (_) => List<int>.from(_emptyHistoryBlock));
      expect(SuicaParser.parseHistory(blocks), isEmpty);
    });

    test('parseHistory decodes 1 real entry from 20-block list', () {
      final blocks = [
        List<int>.from(_realHistoryBlock0),
        ...List.generate(19, (_) => List<int>.from(_emptyHistoryBlock)),
      ];
      expect(SuicaParser.parseHistory(blocks).length, 1);
    });

    test('parseHistory real entry date is 2024-10-17', () {
      final entries = SuicaParser.parseHistory([
        List<int>.from(_realHistoryBlock0),
      ]);
      expect(entries.first.date, DateTime(2024, 10, 17));
    });

    test('parseHistory real entry balanceAfter is 500 yen', () {
      final entries = SuicaParser.parseHistory([
        List<int>.from(_realHistoryBlock0),
      ]);
      expect(entries.first.balanceAfter, 500);
    });

    test('parseHistory real entry terminal is vendingMachine', () {
      final entries = SuicaParser.parseHistory([
        List<int>.from(_realHistoryBlock0),
      ]);
      expect(entries.first.terminalType, TerminalType.vendingMachine);
    });

    test('parseHistory real entry process is entry', () {
      final entries = SuicaParser.parseHistory([
        List<int>.from(_realHistoryBlock0),
      ]);
      expect(entries.first.processType, ProcessType.entry);
    });
  });
}