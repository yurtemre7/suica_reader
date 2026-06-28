/// Base exception for all suica_reader errors.
class SuicaReaderException implements Exception {
  final String message;
  final Object? cause;

  const SuicaReaderException(this.message, {this.cause});

  @override
  String toString() =>
      'SuicaReaderException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// NFC hardware is not available or is disabled on this device.
class NfcUnavailableException extends SuicaReaderException {
  const NfcUnavailableException()
    : super('NFC is not available or is disabled on this device.');
}

/// The scanned NFC tag is not a Suica/FeliCa card.
class UnsupportedTagException extends SuicaReaderException {
  const UnsupportedTagException()
    : super('The scanned tag is not a supported Suica/FeliCa card.');
}

/// The card was detected but a required service/block read failed.
class SuicaReadException extends SuicaReaderException {
  const SuicaReadException(super.message, {super.cause});
}

/// The raw bytes from the card could not be parsed into a known format.
class SuicaParseException extends SuicaReaderException {
  const SuicaParseException(super.message, {super.cause});
}
