/// Suica/PASMO system and service codes.
/// Source: public reverse-engineering documentation and the
/// SuicaNFCReader reference project.
abstract final class SuicaConstants {
  /// FeliCa system code for Suica, PASMO, ICOCA, TOICA, PiTaPa.
  static const int systemCode = 0x0003;

  /// Service code: card balance block (1 block, 16 bytes).
  /// Balance is stored at bytes 10–11, little-endian.
  static const int balanceServiceCode = 0x008B;

  /// Number of blocks to read for balance.
  static const int balanceBlockCount = 1;

  /// Service code: transaction history (up to 20 blocks, 16 bytes each).
  static const int historyServiceCode = 0x090F;

  /// Maximum number of history blocks available on the card.
  static const int historyMaxBlocks = 20;

  /// Every FeliCa block is exactly 16 bytes.
  static const int blockSize = 16;

  /// Balance bytes index in the balance block (little-endian 2-byte value).
  static const int balanceByteOffset = 10;

  /// FeliCa ReadWithoutEncryption command code.
  static const int readWithoutEncryptionCommand = 0x06;
}
