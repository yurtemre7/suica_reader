# suica_reader

A Flutter package for reading **Suica**, **PASMO**, **ICOCA**, and other FeliCa-based Japanese IC transit cards on NFC-enabled Android and iOS devices.

***

## Features

- ✅ Read **card balance** in JPY
- ✅ Read **transaction history** (up to 20 entries)
- ✅ Decode terminal type, process type, date, and balance-after per trip
- ✅ Works on **Android** (NfcF / ISO 18092) and **iOS** (FeliCa / Core NFC)
- ✅ Typed exceptions for clean error handling
- ✅ Testable — inject a fake transport for unit tests without hardware

***

## Installation

```yaml
dependencies:
  suica_reader: ^0.1.0
```

Or via the command line:

```bash
flutter pub add suica_reader
```

***

## Android setup

### Add NFC permission to `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.NFC" />
    <uses-feature android:name="android.hardware.nfc" android:required="false" />

    <application ...>
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            ...>

            <!-- Launcher intent -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
```

***

## iOS setup

### 1. Add NFC usage description to `ios/Runner/Info.plist`

```xml
<key>NFCReaderUsageDescription</key>
<string>This app reads your Suica card balance and history.</string>
```

### 2. Add the Near Field Communication entitlement

In Xcode: **Signing & Capabilities → + Capability → Near Field Communication Tag Reading**

This adds the following to your `.entitlements` file automatically:

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>TAG</string>
</array>
```

### 3. iOS deployment target

iOS 13.0 or later is required for FeliCa reading. Set this in `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

***

## Usage

### Basic — balance and history in one call

```dart
import 'package:suica_reader/suica_reader.dart';

final reader = SuicaReader();

// Check NFC availability first
final available = await reader.isAvailable();
if (!available) {
  print('NFC is not available on this device.');
  return;
}

// Scan the card — resolves when the user taps their card
final card = await reader.readCard();

print('IDm:        ${card.idm}');
print('SystemCode: ${card.systemCode}');
print('Balance:    ¥${card.balance}');

for (final trip in card.history) {
  print('${trip.date} | ${trip.terminalType.label} | '
        '${trip.processType.label} | ¥${trip.balanceAfter}');
}
```

### Balance only

```dart
final balance = await reader.readBalance();
print('Balance: ¥$balance');
```

### Latest N trips

```dart
final trips = await reader.readLatestTrips(limit: 5);
for (final trip in trips) {
  print('${trip.date} — ¥${trip.balanceAfter}');
}
```

### Error handling

```dart
try {
  final card = await reader.readCard();
} on NfcUnavailableException {
  // NFC is off or not supported on this device
} on UnsupportedTagException {
  // Tag detected but it is not a FeliCa card
} on SuicaReadException catch (e) {
  // FeliCa command failed during reading
  print('Read error: $e');
}
```

### Auto-scan on app launch (recommended for Android)

Starting the NFC session immediately on launch activates Android's reader mode,
which prevents the OS from spawning a new app instance when a card is tapped.

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
}
```

### Debug logging

```dart
// Prints verbose per-step NFC logs to the console
final reader = SuicaReader(printDebug: true);
```

***

## Supported cards

Any card using the FeliCa IC platform with the standard JR East service layout:

| Card | Region |
|------|--------|
| Suica | JR East (nationwide) |
| PASMO | Tokyo metro / buses |
| ICOCA | JR West |
| TOICA | JR Central |
| PiTaPa | Kansai |
| Kitaca | JR Hokkaido |
| SUGOCA | JR Kyushu |

***

## Data model

### `SuicaCardData`

| Field | Type | Description |
|-------|------|-------------|
| `idm` | `String` | Card unique ID (8 bytes, hex) |
| `systemCode` | `String` | FeliCa system code (e.g. `0003` for Suica) |
| `balance` | `int?` | Current balance in JPY |
| `history` | `List<SuicaHistoryEntry>` | Transaction history, newest first |

### `SuicaHistoryEntry`

| Field | Type | Description |
|-------|------|-------------|
| `date` | `DateTime?` | Transaction date |
| `terminalType` | `TerminalType` | Gate, bus, vending machine, charger… |
| `processType` | `ProcessType` | Entry, exit, purchase, charge… |
| `balanceAfter` | `int?` | Balance after this transaction in JPY |
| `raw` | `List<int>` | Raw 16-byte block for custom parsing |

***

## Testing without hardware

Inject a `FakeSuicaTransport` to unit test your app logic without a physical card:

```dart
class FakeSuicaTransport implements SuicaNfcTransport {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, dynamic>> scanFelica({String iosAlertMessage = ''}) async {
    return {
      'idm': [0x01, 0x01, 0x02, 0x14, 0xD6, 0x21, 0xBC, 0x01],
      'systemCode': [0x00, 0x03],
      'balanceBlock': [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x20, 0x00, 0x00, 0xF4, 0x01, 0x00, 0x00, 0x01,
      ],
    };
  }
}

final reader = SuicaReader(transport: FakeSuicaTransport());
expect(await reader.readBalance(), 500);
```

***

## FeliCa service codes

| Service | Code | Description |
|---------|------|-------------|
| Balance | `0x008B` | Current stored value |
| History | `0x090F` | Up to 20 transaction records |

***

## License

MIT