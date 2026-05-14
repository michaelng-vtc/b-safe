/// Nordic UART Service UUIDs used by the PG4.9 BLE module.
///
/// Service:  6e400001-b5a3-f393-e0a9-e50e24dcca9e
/// RX char:  6e400002-b5a3-f393-e0a9-e50e24dcca9e  (write to device)
/// TX char:  6e400003-b5a3-f393-e0a9-e50e24dcca9e  (notify from device)
class PgServiceUuids {
  PgServiceUuids._();

  static const String nordicUartService =
      '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// RX characteristic – used to WRITE data to the device.
  static const String nordicUartRx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// TX characteristic – used to receive NOTIFY data from the device.
  static const String nordicUartTx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
}
