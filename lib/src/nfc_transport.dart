import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_felica/nfc_manager_felica.dart';

import 'errors.dart';
import 'suica_constants.dart';

abstract class SuicaNfcTransport {
  Future<bool> isAvailable();

  Future<Map<String, dynamic>> scanFelica({String iosAlertMessage});
}

class NfcManagerSuicaTransport implements SuicaNfcTransport {
  NfcManagerSuicaTransport({this.printDebug = false});

  /// Set to true to print verbose NFC read logs to the console.
  final bool printDebug;

  static const int _maxBlocksPerRead = 10;

  void _log(String message) {
    if (printDebug) print('[SuicaReader] $message');
  }

  @override
  Future<bool> isAvailable() async {
    final availability = await NfcManager.instance.checkAvailability();
    return availability != NfcAvailability.unsupported;
  }

  @override
  Future<Map<String, dynamic>> scanFelica({
    String iosAlertMessage = 'Hold your Suica card near your phone.',
  }) async {
    final completer = Completer<Map<String, dynamic>>();

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso18092},
      alertMessageIos: iosAlertMessage,
      onDiscovered: (NfcTag tag) async {
        try {
          final felica = FeliCa.from(tag);
          if (felica == null) throw const UnsupportedTagException();

          final idm = List<int>.from(felica.idm);
          final systemCode = List<int>.from(felica.systemCode);
          _log(
            'FeliCa detected — IDm: ${_hex(idm)}, systemCode: ${_hex(systemCode)}',
          );

          // ── Balance ───────────────────────────────────────────────────
          List<int>? balanceBlock;
          try {
            final balanceResp = await felica.readWithoutEncryption(
              serviceCodeList: [
                Uint8List.fromList([
                  SuicaConstants.balanceServiceCode & 0xFF,
                  (SuicaConstants.balanceServiceCode >> 8) & 0xFF,
                ]),
              ],
              blockList: [
                Uint8List.fromList([0x80, 0x00]),
              ],
            );
            _log(
              'Balance — flag1: 0x${balanceResp.statusFlag1.toRadixString(16)}, '
              'flag2: 0x${balanceResp.statusFlag2.toRadixString(16)}, '
              'blocks: ${balanceResp.blockData.length}',
            );
            if (balanceResp.statusFlag1 == 0x00 &&
                balanceResp.blockData.isNotEmpty) {
              balanceBlock = List<int>.from(balanceResp.blockData.first);
              // Print every byte with its index so we can find the balance offset
              print(
                '[SuicaReader] Balance block (${balanceBlock.length} bytes):',
              );
              for (var i = 0; i < balanceBlock.length; i++) {
                print(
                  '[SuicaReader]   [$i] = 0x${balanceBlock[i].toRadixString(16).padLeft(2, '0')} (${balanceBlock[i]})',
                );
              }
            }
          } catch (e, st) {
            _log('Balance read EXCEPTION: $e\n$st');
          }

          // ── History (batched) ──────────────────────────────────────────
          final allHistoryBlocks = <List<int>>[];
          try {
            final serviceCode = Uint8List.fromList([
              SuicaConstants.historyServiceCode & 0xFF,
              (SuicaConstants.historyServiceCode >> 8) & 0xFF,
            ]);
            var blockIndex = 0;

            while (blockIndex < SuicaConstants.historyMaxBlocks) {
              final remaining = SuicaConstants.historyMaxBlocks - blockIndex;
              final batchSize = remaining < _maxBlocksPerRead
                  ? remaining
                  : _maxBlocksPerRead;

              final blockList = List.generate(
                batchSize,
                (i) => Uint8List.fromList([0x80, blockIndex + i]),
              );

              final histResp = await felica.readWithoutEncryption(
                serviceCodeList: [serviceCode],
                blockList: blockList,
              );

              _log(
                'History batch [$blockIndex–${blockIndex + batchSize - 1}] — '
                'flag1: 0x${histResp.statusFlag1.toRadixString(16)}, '
                'blocks: ${histResp.blockData.length}',
              );

              if (histResp.statusFlag1 != 0x00) {
                _log('Non-zero statusFlag1 — stopping history read.');
                break;
              }

              allHistoryBlocks.addAll(
                histResp.blockData.map((b) => List<int>.from(b)),
              );
              blockIndex += batchSize;
            }

            _log('Total history blocks read: ${allHistoryBlocks.length}');
          } catch (e, st) {
            _log('History read EXCEPTION: $e\n$st');
          }

          if (!completer.isCompleted) {
            completer.complete({
              'idm': idm,
              'systemCode': systemCode,
              'balanceBlock': ?balanceBlock,
              if (allHistoryBlocks.isNotEmpty)
                'historyBlocks': allHistoryBlocks,
            });
          }

          await NfcManager.instance.stopSession();
        } catch (e, st) {
          _log('NFC session EXCEPTION: $e\n$st');
          if (!completer.isCompleted) {
            completer.completeError(
              e is SuicaReaderException
                  ? e
                  : SuicaReadException('NFC read failed.', cause: e),
            );
          }
          await NfcManager.instance.stopSession(errorMessageIos: 'Read failed');
        }
      },
    );

    return completer.future;
  }

  String _hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}
