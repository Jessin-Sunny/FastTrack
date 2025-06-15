import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qrdata.dart';

class PacketPage extends StatefulWidget {
  final String personId; // Receiving the personnel ID instead of email

  const PacketPage({
    super.key,
    required this.personId,
  });

  @override
  _PacketPageState createState() => _PacketPageState();
}

class _PacketPageState extends State<PacketPage> {
  List<Map<String, dynamic>> packets = [];
  bool isLoading = true;
  List<bool> isPicked = [];
  bool checkallPackages = true;
  int packlen = 0;
  String? assignedDay;
  bool routeGenerated = false;
  DateTime? selectedDate;
  String formattedDate = ""; // Store the date as a string

  @override
  void initState() {
    super.initState();
    _loadSavedDate();
    _fetchPackets();
    //print(widget.personId);
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      String newDate =
          "${picked.toLocal()}".split(' ')[0]; // Extract YYYY-MM-DD

      setState(() {
        formattedDate = newDate;
        isLoading = true;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedDate', newDate); // Save date

      await _fetchPackets(); // Fetch packets for the selected date
    }
  }

  Future<void> _loadSavedDate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedDate = prefs.getString('selectedDate');

    setState(() {
      formattedDate = savedDate ??
          "${DateTime.now().toLocal()}"
              .split(' ')[0]; // Use saved or today's date
    });

    await _fetchPackets(); // Fetch packets for the loaded date
  }

  Future<void> _fetchPackets() async {
    try {
      setState(() {
        isLoading = true; // Show loading indicator
      });

      // Fetch assigned packets for the selected date and personnel
      QuerySnapshot packetSnapshot = await FirebaseFirestore.instance
          .collection('AssignedPackages')
          .doc(formattedDate) // Use the selected date
          .collection('DeliveryPersonnels')
          .doc(widget.personId) // Use delivery personnel ID
          .collection('Packages')
          .get();

      if (packetSnapshot.docs.isEmpty) {
        setState(() {
          packets.clear(); // Clear previous packets if none are found
          isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> loadedPackets = packetSnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;

        GeoPoint? geoPoint = data['Delivery_Location'];
        GeoPoint? pickPoint = data['Pickup_Location'];

        return {
          'id': doc.id,
          'qrcode': data['QR_ID']?.toString() ?? 'Unknown',
          'status': data['Status']?.toString() ?? 'Pending',
          'dlocation_name': data['Dlocation_Name']?.toString() ?? 'Unknown',
          'delivery_location': geoPoint != null
              ? {'latitude': geoPoint.latitude, 'longitude': geoPoint.longitude}
              : null,
          'pickup_location': pickPoint != null
              ? {
                  'latitude': pickPoint.latitude,
                  'longitude': pickPoint.longitude
                }
              : null,
          'plocation_name': data['Plocation_Name']?.toString() ?? 'Unknown',
        };
      }).toList();

      setState(() {
        packets = loadedPackets;
        isPicked = List<bool>.filled(packets.length, false);
        isLoading = false; // Hide loading indicator
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateScannedPackets() async {
    try {
      for (var packet in packets) {
        await FirebaseFirestore.instance
            .collection('AssignedPackages')
            .doc(formattedDate)
            .collection('DeliveryPersonnels')
            .doc(widget.personId)
            .collection('Packages')
            .doc(packet['id']) // Updating the specific document
            .update({
          'Status': packet['status'], // Update status after scanning
          'Reason': packet['reason'], // Any reason if applicable
        });
      }
      print('All scanned packages updated successfully.');
    } catch (error) {
      print('Error updating scanned packages: $error');
    }
  }

  void _showRejectDialog(BuildContext context, int index) {
    TextEditingController reasonController = TextEditingController();
    String? selectedReason;
    bool showTextField = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Reject Packet'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please specify the reason'),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedReason == "Damaged"
                              ? Colors.blue
                              : Colors.grey[300],
                        ),
                        onPressed: () {
                          setState(() {
                            selectedReason = "Damaged";
                            showTextField = false;
                          });
                        },
                        child: Text('Damaged',
                            style: TextStyle(color: Colors.black)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedReason == "Oversized"
                              ? Colors.blue
                              : Colors.grey[300],
                        ),
                        onPressed: () {
                          setState(() {
                            selectedReason = "Oversized";
                            showTextField = false;
                          });
                        },
                        child: Text('Oversized',
                            style: TextStyle(color: Colors.black)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedReason == "Overweight"
                              ? Colors.blue
                              : Colors.grey[300],
                        ),
                        onPressed: () {
                          setState(() {
                            selectedReason = "Overweight";
                            showTextField = false;
                          });
                        },
                        child: Text('Overweight',
                            style: TextStyle(color: Colors.black)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedReason == "Other"
                              ? Colors.blue
                              : Colors.grey[300],
                        ),
                        onPressed: () {
                          setState(() {
                            selectedReason = "Other";
                            showTextField = true;
                          });
                        },
                        child: Text('Other',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                  if (showTextField) ...[
                    SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      decoration:
                          InputDecoration(hintText: "Enter reason here"),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedReason != null) {
                      String reasonToSubmit = selectedReason == "Other" &&
                              reasonController.text.isNotEmpty
                          ? reasonController.text
                          : selectedReason!;

                      _submitReason(index, reasonToSubmit);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please Select a Reason'),
                          duration: Duration(milliseconds: 1500),
                        ),
                      );
                    }
                  },
                  child: Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitReason(int index, String reason) {
    setState(() {
      packets[index]['status'] = 'Rejected [$reason]';
      packets[index]['reason'] = reason;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Packet ${packets[index]['id']} Rejected for: $reason'),
        duration: Duration(milliseconds: 2000),
      ),
    );
  }

  void _acceptPacket(int index) {
    setState(() {
      packets[index]['status'] = 'Pending';
      packets[index]['reason'] = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Packet ${packets[index]['id']} Assigned'),
        duration: Duration(milliseconds: 2000),
      ),
    );
  }

  Future<void> writeAllPackagesScannedNotification() async {
    try {
      // Extract companyId from personnelId (First two characters + 2nd to 4th character)
      String companyId = "FC${widget.personId.substring(2, 5)}";

      // Firestore batch write
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var packet in packets) {
        String packageId = packet['id'];
        bool isPicked = packet['status'] == 'Picked';

        // Firestore reference
        DocumentReference notificationRef = FirebaseFirestore.instance
            .collection('Notification')
            .doc('Vwhs2MsdW9ZCJYE4ooqz') // Personnel ID as document
            .collection('Company')
            .doc(companyId) // Company ID as document
            .collection('Pickup')
            .doc(); // Auto-generate notification document

        // Notification message
        String message = isPicked
            ? "Package $packageId has been scanned by ${widget.personId}"
            : "Package $packageId has been rejected by ${widget.personId}";

        String title = isPicked ? "Package Scanned" : "Package Rejected";

        // Notification data
        Map<String, dynamic> notificationData = {
          "body": message,
          "read": false,
          "time": FieldValue.serverTimestamp(),
          "title": title
        };

        // Add to batch
        batch.set(notificationRef, notificationData);
      }

      // Commit batch write
      await batch.commit();
      print("All package notifications added successfully");
    } catch (e) {
      print("Error writing notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FastTrack'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.blue,
            padding: EdgeInsets.all(20),
            width: double.infinity,
            height: 80,
            child: Column(
              children: [
                Text(
                  'Assigned Packets List',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Date Picker
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Select Date",
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  formattedDate.isNotEmpty ? formattedDate : "Pick a Date",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          // Loading Indicator
          if (isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Loading packages...",
                      style: TextStyle(fontSize: 18, color: Colors.black)),
                ],
              ),
            )
          else if (packets.isEmpty)
            // No packets assigned
            Center(
              child: Text(
                "No packets assigned.",
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            )
          else
            // List of Assigned Packets
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 10,
                radius: Radius.circular(20),
                child: ListView.builder(
                  itemCount: packets.length + 1, // Extra item for buttons
                  itemBuilder: (context, index) {
                    if (index == packets.length) {
                      // Show buttons after last packet
                      return Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FloatingActionButton.extended(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  backgroundColor: Colors.red,
                                  label: Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                SizedBox(width: 20),
                                FloatingActionButton.extended(
                                  onPressed: () async {
                                    checkallPackages = true;
                                    for (var i in packets) {
                                      if (i['status'] == 'Pending') {
                                        checkallPackages = false;
                                      }
                                    }
                                    if (checkallPackages == true) {
                                      if (routeGenerated == false) {
                                        await updateScannedPackets();
                                        await writeAllPackagesScannedNotification();
                                        routeGenerated = true;
                                      }
                                      var j;
                                      for (var i in packets) {
                                        if (i['status'] == 'Rejected') {
                                          j = j + 1;
                                        }
                                        if (j == packets.length) {
                                          checkallPackages = false;
                                        }
                                      }
                                      Navigator.pop(context, {
                                        "confirmed": checkallPackages,
                                        "packages": packets
                                      });
                                    } else {
                                      print(packets);
                                      print(checkallPackages);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(
                                            'Packages are left. Scan them and Try again'),
                                        duration: Duration(seconds: 2),
                                      ));
                                    }
                                  },
                                  backgroundColor: Colors.blue,
                                  label: Text('  Next  ',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    final packet = packets[index];
                    bool isRejected = packet['status']!.contains("Rejected");

                    return Container(
                      color: Colors.grey[200],
                      padding: EdgeInsets.all(20),
                      margin:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Packet ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  )),
                              SizedBox(height: 10),
                              Text('Packet ID: ${packet['id']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  )),
                              /*
                            SizedBox(height: 10),
                            Text('Assigned Date: ${packet['date']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                )),
                                */
                              SizedBox(height: 10),
                              Text('Status: ${packet['status']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isRejected
                                        ? Colors.red
                                        : packet['status'] == 'Picked'
                                            ? Colors.green
                                            : Colors.black,
                                  )),
                            ],
                          ),
                          Spacer(),
                          if (!isRejected)
                            if (packet['status'] ==
                                'Pending') // Hide QR button if rejected
                              IconButton(
                                onPressed: () async {
                                  isPicked[index] = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QRViewExample(
                                        qrcode: packets[index]['qrcode'] ??
                                            'Unknown',
                                      ),
                                    ),
                                  );
                                  if (isPicked[index] == true) {
                                    setState(() {
                                      packets[index]['status'] = 'Picked';
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Package ${index + 1} Scanned Successfully'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(Icons.qr_code_scanner, size: 40),
                                color: Colors.black,
                              ),
                          SizedBox(width: 10),
                          IconButton(
                            onPressed: () async {
                              if (isRejected) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Assign Packet'),
                                      content: Text(
                                          'Do you want to reassign the packet?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            _acceptPacket(
                                                index); // Reassign packet
                                            Navigator.pop(
                                                context); // Close dialog
                                          },
                                          child: Text('Yes'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(
                                                context); // Close dialog without action
                                          },
                                          child: Text('No'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else {
                                if (packet['status'] != 'Picked') {
                                  _showRejectDialog(context, index);
                                }
                              }
                            },
                            icon: Icon(
                              isRejected
                                  ? Icons.block
                                  : packet['status'] == 'Picked'
                                      ? Icons.check_circle
                                      : Icons.cancel,
                              size: 30,
                              color: isRejected
                                  ? Colors.red
                                  : packet['status'] == 'Picked'
                                      ? Colors.green
                                      : Colors.red, // This can be simplified
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
