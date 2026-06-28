## 0.1.0

- Initial release.
- Read Suica/PASMO/ICOCA card balance via FeliCa service 0x008B.
- Read up to 20 transaction history entries via FeliCa service 0x090F.
- Supports Android (NfcF) and iOS (FeliCa Core NFC).
- Typed exceptions: NfcUnavailableException, UnsupportedTagException, SuicaReadException.