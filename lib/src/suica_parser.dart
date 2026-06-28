import 'models.dart';
import 'suica_constants.dart';

/// Decodes raw FeliCa block bytes into Dart models.
abstract final class SuicaParser {
  /// Balance is stored at bytes 11–12 of the balance service block (0x008B),
  /// little-endian (LSB first).
  static int? parseBalance(List<int> block) {
    if (block.length < 13) return null;
    return block[11] | (block[12] << 8);
  }

  /// Decodes a list of 16-byte history blocks into [SuicaHistoryEntry]s.
  /// The card stores history newest-first; this preserves that order.
  static List<SuicaHistoryEntry> parseHistory(List<List<int>> blocks) {
    final entries = <SuicaHistoryEntry>[];
    for (final block in blocks) {
      if (block.length < SuicaConstants.blockSize) continue;
      if (_isEmptyBlock(block)) continue;
      entries.add(_parseHistoryBlock(block));
    }
    return entries;
  }

  static bool _isEmptyBlock(List<int> block) {
    // All zeros — unfilled slot
    if (block.every((b) => b == 0x00)) return true;
    // All 0xFF — erased slot
    if (block.every((b) => b == 0xFF)) return true;
    // Real card empty pattern: byte[0]==0x00 && byte[1]==0x00 && date bytes[4,5]==0x00
    // A valid entry always has a non-zero terminal byte[0] and a non-zero date.
    if (block[0] == 0x00 && block[4] == 0x00 && block[5] == 0x00) return true;
    return false;
  }

  static SuicaHistoryEntry _parseHistoryBlock(List<int> b) {
    // Byte 0: terminal type
    final terminalType = _decodeTerminal(b[0]);

    // Byte 1: process type
    final processType = _decodeProcess(b[1]);

    // Bytes 4–5: date packed as 2 bytes.
    // Bits [15:9] = year offset from 2000, bits [8:5] = month, bits [4:0] = day.
    final date = _decodeDate(b[4], b[5]);

    // Bytes 10–11: balance after this transaction, little-endian.
    // (History service 0x090F uses offset 10–11, different from balance service 0x008B)
    final balanceAfter = b.length > 11 ? (b[10] | (b[11] << 8)) : null;

    return SuicaHistoryEntry(
      date: date,
      terminalType: terminalType,
      processType: processType,
      balanceAfter: balanceAfter,
      raw: List<int>.unmodifiable(b),
    );
  }

  static DateTime? _decodeDate(int high, int low) {
    try {
      final raw = (high << 8) | low;
      final year = 2000 + (raw >> 9);
      final month = (raw >> 5) & 0x0F;
      final day = raw & 0x1F;
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static TerminalType _decodeTerminal(int byte) {
    return switch (byte) {
      0x03 => TerminalType.gate,
      0x05 => TerminalType.bus,
      0x07 => TerminalType.gate,
      0x08 => TerminalType.gate,
      0x09 => TerminalType.gate,
      0x12 => TerminalType.vendingMachine, // confirmed from your card
      0x13 => TerminalType.vendingMachine,
      0x14 => TerminalType.charger,
      0x15 => TerminalType.charger,
      0x16 => TerminalType.charger,
      0xC7 => TerminalType.bus,
      0xC8 => TerminalType.bus,
      _ => TerminalType.unknown,
    };
  }

  static ProcessType _decodeProcess(int byte) {
    return switch (byte) {
      0x01 => ProcessType.fareAdjust,
      0x02 => ProcessType.fareAdjust,
      0x03 => ProcessType.exit,
      0x05 => ProcessType.entry,
      0x07 => ProcessType.entry, // confirmed from your card — train entry
      0x08 => ProcessType.exit,
      0x0F => ProcessType.busEntry,
      0x10 => ProcessType.busExit,
      0x46 => ProcessType.purchase,
      0x47 => ProcessType.purchase,
      0x48 => ProcessType.purchase,
      0x84 => ProcessType.charge,
      0x85 => ProcessType.charge,
      _ => ProcessType.unknown,
    };
  }
}
