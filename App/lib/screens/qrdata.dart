import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QRViewExample extends StatefulWidget {
  final String qrcode;
  const QRViewExample({
    super.key,
    required this.qrcode,
  });
  @override
  _QRViewExampleState createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  String scanned_code = '';
  Barcode? result;
  QRViewController? controller;
  Future<bool>? flashStatus;
  bool isCameraPaused = false; // Track camera state
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  if (scanned_code == '')
                    const Text(
                      'Scan QR code placed on package',
                      style: TextStyle(fontSize: 20, color: Colors.blue),
                    )
                  else if (scanned_code != widget.qrcode)
                    Text(
                      'Wrong Package, Please Scan the Correct Package',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: IconButton(
                          onPressed: () async {
                            await controller?.toggleFlash();
                            setState(() {
                              flashStatus = controller?.getFlashStatus().then(
                                  (value) => value ?? false); // Update future
                            });
                          },
                          icon: FutureBuilder<bool>(
                            future:
                                flashStatus, // Directly use flashStatus future
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  snapshot.data == null) {
                                return const Icon(
                                  Icons.flash_off,
                                  size: 40,
                                ); // Default while loading
                              }
                              return Icon(
                                snapshot.data!
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                                size: 40,
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: IconButton(
                          onPressed: () async {
                            await controller?.flipCamera();
                            setState(() {});
                          },
                          icon: Icon(
                            Icons.cameraswitch,
                            size: 40,
                          ),
                        ),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: IconButton(
                          onPressed: () async {
                            if (isCameraPaused) {
                              await controller?.resumeCamera();
                            } else {
                              await controller?.pauseCamera();
                            }
                            setState(() {
                              isCameraPaused = !isCameraPaused; // Toggle state
                            });
                          },
                          icon: Icon(
                            isCameraPaused ? Icons.play_arrow : Icons.pause,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 200.0
        : 40.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.white,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      if (!mounted) return; // Prevents updates if the widget is disposed

      String newScannedCode = scanData.code ?? 'Error';

      // Prevent unnecessary setState calls
      if (scanned_code != newScannedCode) {
        setState(() {
          result = scanData;
          scanned_code = newScannedCode;
        });

        // Ensure Navigator.pop() is called only ONCE
        if (scanned_code == widget.qrcode) {
          controller.dispose(); // Stop the camera before exiting
          Future.microtask(() {
            if (mounted) Navigator.pop(context, true);
          });
        }
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Permission')),
      );
    }
  }
}
