import 'errors.dart';
import 'models.dart';
import 'nfc_transport.dart';
import 'suica_parser.dart';

/// Primary entry point for reading Suica/FeliCa transit cards.
///
/// Inject a custom [SuicaNfcTransport] in tests:
/// ```dart
/// final reader = SuicaReader(transport: FakeSuicaTransport(...));
/// ```
class SuicaReader {
  final SuicaNfcTransport _transport;

  SuicaReader({SuicaNfcTransport? transport, bool printDebug = false})
    : _transport =
          transport ?? NfcManagerSuicaTransport(printDebug: printDebug);

  /// Returns true if NFC hardware is available and enabled on this device.
  Future<bool> isAvailable() => _transport.isAvailable();

  /// Scans a card and returns all available data: balance, history, identity.
  ///
  /// Throws [NfcUnavailableException] if NFC is off or not supported.
  /// Throws [UnsupportedTagException] if the tag is not a Suica/FeliCa card.
  /// Throws [SuicaReadException] if the NFC session fails.
  Future<SuicaCardData> readCard({
    String iosAlertMessage =
        'Hold your Suica card near the top of your iPhone.',
  }) async {
    final available = await _transport.isAvailable();
    if (!available) throw const NfcUnavailableException();

    final raw = await _transport.scanFelica(iosAlertMessage: iosAlertMessage);

    return _build(raw);
  }

  /// Convenience: reads only the balance in JPY.
  Future<int?> readBalance() async {
    final card = await readCard();
    return card.balance;
  }

  /// Convenience: reads only the latest [limit] trip history entries.
  Future<List<SuicaHistoryEntry>> readLatestTrips({int limit = 10}) async {
    final card = await readCard();
    return card.history.take(limit).toList();
  }

  // ─── Internal ────────────────────────────────────────────────────────────

  SuicaCardData _build(Map<String, dynamic> raw) {
    final idmBytes = raw['idm'] as List<int>?;
    if (idmBytes == null || idmBytes.isEmpty) {
      throw const SuicaReadException('Card IDm was missing from NFC response.');
    }

    final systemCodeBytes = raw['systemCode'] as List<int>?;
    final balanceBlock = raw['balanceBlock'] as List<int>?;
    final historyBlockList = raw['historyBlocks'] as List<dynamic>?;

    final balance = balanceBlock != null
        ? SuicaParser.parseBalance(balanceBlock)
        : null;

    final history = historyBlockList != null
        ? SuicaParser.parseHistory(
            historyBlockList.map((b) => List<int>.from(b as List)).toList(),
          )
        : const <SuicaHistoryEntry>[];

    return SuicaCardData(
      idm: _hex(idmBytes),
      systemCode: systemCodeBytes != null ? _hex(systemCodeBytes) : null,
      balance: balance,
      scannedAt: DateTime.now(),
      history: history,
    );
  }

  String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toUpperCase();
  }
}
