import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:suica_reader/suica_reader.dart';

void main() {
  runApp(const SuicaExampleApp());
}

class SuicaExampleApp extends StatelessWidget {
  const SuicaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suica Reader',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const SuicaHomePage(),
    );
  }
}

class SuicaHomePage extends StatefulWidget {
  const SuicaHomePage({super.key});

  @override
  State<SuicaHomePage> createState() => _SuicaHomePageState();
}

class _SuicaHomePageState extends State<SuicaHomePage> {
  final _reader = SuicaReader(printDebug: kDebugMode);

  bool _scanning = false;
  String _status = 'Press the button and hold your Suica card.';
  SuicaCardData? _card;

  @override
  void initState() {
    super.initState();
    // Start NFC session immediately so reader mode is active before
    // the user taps the card — prevents Android from spawning a new instance.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    if (_scanning) return;

    setState(() {
      _scanning = true;
      _status = 'Hold your Suica card near your phone…';
      _card = null;
    });

    try {
      print('[ExampleApp] Calling isAvailable()');
      final available = await _reader.isAvailable();
      print('[ExampleApp] isAvailable() = $available');

      if (!available) {
        setState(() => _status = 'NFC is not available on this device.');
        return;
      }

      print('[ExampleApp] Calling readCard()');
      final card = await _reader.readCard();
      print('[ExampleApp] readCard() returned: $card');

      setState(() {
        _card = card;
        _status = 'Card read successfully! Tap "Scan Again" to re-scan.';
      });
    } on NfcUnavailableException catch (e, st) {
      print('[ExampleApp] NfcUnavailableException: $e\n$st');
      setState(() => _status = 'NFC unavailable: $e');
    } on UnsupportedTagException catch (e, st) {
      print('[ExampleApp] UnsupportedTagException: $e\n$st');
      setState(() => _status = 'Unsupported tag — is this a Suica card?');
    } on SuicaReadException catch (e, st) {
      print('[ExampleApp] SuicaReadException: $e\n$st');
      setState(() => _status = 'Read error: $e');
    } catch (e, st) {
      print('[ExampleApp] UNEXPECTED: $e\n$st');
      setState(() => _status = 'Unexpected error: $e');
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suica Reader')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // ── Card data ────────────────────────────────────────────────
            if (_card != null) ...[
              _InfoTile(label: 'IDm', value: _card!.idm),
              _InfoTile(
                label: 'System Code',
                value: _card!.systemCode ?? 'systemCode not found',
              ),
              _InfoTile(
                label: 'Balance',
                value: _card!.balance != null
                    ? '¥${_card!.balance}'
                    : 'Not available',
              ),
              _InfoTile(
                label: 'History entries',
                value: '${_card!.history.length}',
              ),
              if (_card!.history.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Latest trips',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _card!.history.length,
                    itemBuilder: (context, index) {
                      var historyItem = _card!.history[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${historyItem.date?.toString().substring(0, 10) ?? '??'} '
                            '— ¥${historyItem.balanceAfter ?? '?'}',
                          ),
                          subtitle: Text(
                            'Terminal: ${historyItem.terminalType.name}  '
                            'Process: ${historyItem.processType.name}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],

            const Spacer(),

            // ── Scan button ──────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.nfc),
              label: Text(_scanning ? 'Waiting for card…' : 'Scan Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
