import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  for (var format in BarcodeFormat.values) {
    print(format.name);
  }
}
