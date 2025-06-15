import 'package:fasttrack/screens/personnel_optimiztion.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_speed_test_plus/flutter_speed_test_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // Import the geolocator package
import 'dart:async'; // Import the dart:async library
import 'dart:convert'; // Import the dart:convert library for json decoding
import 'package:http/http.dart' as http; // Import the http package
import '../main.dart'; // Import the main.dart file to navigate back to the login page
import 'edit_profile.dart'; // Import the edit_profile.dart file
import 'support.dart'; // Import the support.dart file
// Import the google_fonts package
import 'packet.dart';
import 'package:intl/intl.dart';
import 'notifications.dart';
import 'settings.dart';
import '../../../lib/screens/secrets.dart';

class PersonnelPage extends StatefulWidget {
  final String password;
  const PersonnelPage({super.key, required this.password});

  @override
  _PersonnelPageState createState() => _PersonnelPageState();
}

class _PersonnelPageState extends State<PersonnelPage> {
  bool isConfirmed = false;
  List<Map<String, dynamic>> packets = [];
  String email = '';
  String vehicleNo = '';
  String capacity = '';
  String name = '';
  String phoneno = '';
  late String password;
  String docid = '';
  String profileurl = '';
  String connectionStatus = 'Unknown';
  double downloadSpeed = 0.0;
  double uploadSpeed = 0.0;
  String speedTestStatus = 'Idle';
  String networkQuality = '';
  late StreamSubscription _subscription;
  DateTime? _lastPressedAt; // Track the last time the back button was pressed
  String temperature = '';
  String climate = '';
  String locname = '';
  String forecastTemperature = '';
  String forecastClimate = '';
  int _currentIndex = 0;
  bool routeGenerated = false;
  bool isNight = false;
  LatLng currentlocation = LatLng(9.579380, 76.622051);

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      // Handle connectivity changes
    });
    //_fetchNetworkDetails();
    _fetchUserData();
    _fetchWeatherData();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  void listenToFirestoreNotifications(String docid) {
    String notificationId =
        "Vwhs2MsdW9ZCJYE4ooqz"; // Change this dynamically if needed

    FirebaseFirestore.instance
        .collection("Notification")
        .doc(notificationId)
        .collection("DeliveryPersonnels")
        .doc(docid)
        .collection("Assignment")
        .where("read", isEqualTo: false) // Fetch only unread notifications
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          var data = doc.data();
          String title = data['title'] ?? 'New Assignment';
          String body = data['body'] ?? 'You have a new delivery task!';

          // Show local notification
          showLocalNotification(title, body);
        }
      }
    });
  }

// Show local notification
  void showLocalNotification(String title, String body) async {
    int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    var android = const AndroidNotificationDetails(
      'channel_id',
      'Channel Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    var ios = const DarwinNotificationDetails();
    var platform = NotificationDetails(android: android, iOS: ios);

    await flutterLocalNotificationsPlugin.show(
        notificationId, title, body, platform);
  }

  Future<void> _fetchNetworkDetails() async {
    if (!mounted) return;
    setState(() {
      speedTestStatus = 'Testing...';
      networkQuality = '';
    });

    List<ConnectivityResult> result = await Connectivity().checkConnectivity();

    if (!result.contains(ConnectivityResult.none)) {
      try {
        final speedTest = FlutterInternetSpeedTest()..enableLog();
        await speedTest.startTesting(
          useFastApi: true,
          onCompleted: (TestResult download, TestResult upload) {
            if (!mounted) return;
            setState(() {
              downloadSpeed = download.transferRate;
              uploadSpeed = upload.transferRate;
              speedTestStatus = 'Completed';

              if (downloadSpeed > 20 && uploadSpeed > 5) {
                networkQuality = 'Your network is Excellent';
              } else if (downloadSpeed > 10 && uploadSpeed > 2) {
                networkQuality = 'Your network is Very Good';
              } else if (downloadSpeed > 5 && uploadSpeed > 1) {
                networkQuality = 'Your network is Good';
              } else if (downloadSpeed > 2 && uploadSpeed > 1) {
                networkQuality = 'Your network is Fair';
              } else {
                networkQuality = 'Your network is Poor';
              }
            });
          },
          onError: (String errorMessage, String speedTestError) {
            if (!mounted) return;
            setState(() {
              downloadSpeed = 0.0;
              uploadSpeed = 0.0;
              speedTestStatus = 'Error: $errorMessage';
            });
          },
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          downloadSpeed = 0.0;
          uploadSpeed = 0.0;
          speedTestStatus = 'Error: $e';
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        downloadSpeed = 0.0;
        uploadSpeed = 0.0;
        speedTestStatus = 'No Internet Connection';
      });
    }
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userEmail = user.email!;
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('DeliveryPersonnel')
          .where('D_Email', isEqualTo: userEmail)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        docid = userDoc.id;
        bool passwordReset = userDoc['Password_Reset'];

        if (passwordReset) {
          await userDoc.reference.update({
            'D_Password': widget.password,
            'Password_Reset': false, // Reset the flag
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Password updated')),
          );
        }

        if (!mounted) return;
        setState(() {
          name = userDoc['D_Name'];
          email = userDoc['D_Email'];
          vehicleNo = userDoc['VehicleNo'];
          capacity = userDoc['Capacity'].toString();
          phoneno = userDoc['D_PhoneNo'];
          password = userDoc['D_Password'];
          profileurl = userDoc['D_Profileurl'];
        });
        // ✅ Call notification listener only after docid is set
        listenToFirestoreNotifications(docid);
      }
    }
  }

  Future<void> _fetchWeatherData() async {
    String? timeString;
    final apiKey =
        weatherApiKey; // Replace with your actual API key
    try {
      // Get the current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latitude = position.latitude;
      final longitude = position.longitude;
      currentlocation = LatLng(latitude, longitude);

      // Fetch current weather data using the current location
      final currentWeatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric';
      final currentWeatherResponse =
          await http.get(Uri.parse(currentWeatherUrl));

      if (currentWeatherResponse.statusCode == 200) {
        final currentWeatherData = json.decode(currentWeatherResponse.body);
        if (!mounted) return;
        setState(() {
          temperature = '${currentWeatherData['main']['temp']}°C';
          climate = currentWeatherData['weather'][0]['description'];
          locname = currentWeatherData['name'];
          //print(currentWeatherData);
        });
      } else {
        if (!mounted) return;
        setState(() {
          temperature = 'Could not fetch data';
          climate = 'Could not fetch data';
        });
      }

      // Fetch weather forecast data for the next 2 hours
      final forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric';
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      if (forecastResponse.statusCode == 200) {
        final forecastData = json.decode(forecastResponse.body);
        final nextTwoHoursForecast = forecastData['list'].take(2).map((item) {
          return {
            'time': item['dt_txt'],
            'temperature': '${item['main']['temp']}°C',
            'climate': item['weather'][0]['description'],
          };
        }).toList();
        print(nextTwoHoursForecast);
        timeString = nextTwoHoursForecast[1]['time'];
        DateTime dateTime =
            DateFormat("yyyy-MM-dd HH:mm:ss").parse(timeString!);

        // Extract hour
        int hour = dateTime.hour;

        // Determine if it's day or night
        isNight = hour >= 18 || hour < 6; // Night if between 18:00 - 06:00
        // Extract time string from API

        // Store the forecast data in state variables
        if (!mounted) return;
        setState(() {
          forecastTemperature = nextTwoHoursForecast[1]['temperature'];
          forecastClimate = nextTwoHoursForecast[1]['climate'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        //print(e);
        temperature = 'No data available';
        climate = 'No data available';
        forecastTemperature = 'No data available';
        forecastClimate = 'No data available';
        locname = 'Unknown';
      });
    }
  }

  void _showMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            foregroundColor: Colors.white,
            title: const Text("FastTrack"),
            backgroundColor: Colors.blue,
            leading: IconButton(
              icon: Icon(Icons.menu),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          body: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              Center(
                child: Container(
                  width: 300,
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.person),
                        title: Text('Profile'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfilePage(
                                name: name,
                                email: email,
                                vehicleNo: vehicleNo,
                                capacity: capacity,
                                phoneNo: phoneno,
                                password: password,
                                profileurl: profileurl,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.notifications),
                        title: Text('Notifications'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationsPage(
                                personnelId: docid,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.support_agent),
                        title: Text('Support'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Support(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Settings'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingsPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Logout'),
                        onTap: () async {
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          prefs.setBool('isLoggedIn', false);
                          Navigator.of(context).pop();
                          FirebaseAuth.instance.signOut();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FirstPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) > Duration(seconds: 2)) {
      // Show a message when the back button is pressed for the first time
      _lastPressedAt = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Press again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return false; // Prevent the app from exiting
    }
    return true; // Exit the app
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: Colors.white,
          title: const Text("FastTrack"),
          backgroundColor: Colors.blue,
          leading: IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              _showMenu(context);
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(
                              name: name,
                              email: email,
                              vehicleNo: vehicleNo,
                              capacity: capacity,
                              phoneNo: phoneno,
                              password: password,
                              profileurl: profileurl,
                            ),
                          ),
                        );
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: InteractiveViewer(
                                  child: profileurl.isNotEmpty
                                      ? Image.network(
                                          profileurl,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                ),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: profileurl.isNotEmpty
                                    ? NetworkImage(
                                        profileurl) // Correct way to use network image
                                    : null, // No background image if profile URL is empty
                                child: profileurl.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey,
                                      )
                                    : null, // Avoid overlapping the image when profile exists
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            phoneno,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final result =
                              await Navigator.push<Map<String, dynamic>>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PacketPage(personId: docid),
                            ),
                          );

                          // Check if result is valid and confirmed
                          if (result != null && result['confirmed'] == true) {
                            isConfirmed = result['confirmed'];
                            packets = List<Map<String, dynamic>>.from(
                                result['packages'] ?? []);
                            routeGenerated = true;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PersonnelOptimization(
                                  packets: packets,
                                  currentlocation: currentlocation,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          print(e);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                        minimumSize: Size(double.infinity, 50), // Full width
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // Keep button content compact
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Center content
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 20,
                          ), // Package icon
                          SizedBox(width: 8), // Space between icon and text
                          Text('View Packages',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    SizedBox(height: 20), // Add vertical space between buttons
                    ElevatedButton(
                      onPressed: () {
                        if (!isConfirmed) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Please PickUp the Packages'),
                            duration: Duration(seconds: 2),
                          ));
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PersonnelOptimization(
                                      packets: packets,
                                      currentlocation: currentlocation,
                                    )),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Background color
                        minimumSize: Size(double.infinity, 50), // Full width
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // Keep button content compact
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Center content
                        children: [
                          Icon(
                            Icons.pin_drop,
                            color: Colors.white,
                            size: 20,
                          ), // Package icon
                          SizedBox(width: 8), // Space between icon and text
                          Text('Map', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 300,
                child: PageView(
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  children: [
                    _buildLocationContainer(),
                    _buildSpeedTestContainer(),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBubbleIndicator(0),
                  _buildBubbleIndicator(1),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationContainer() {
    IconData getWeatherIcon(String climate) {
      if (climate.contains('rain')) {
        return Icons.beach_access;
      } else if (climate.contains('cloud')) {
        return isNight ? Icons.nights_stay : Icons.cloud;
      } else if (climate.contains('clear')) {
        return isNight ? Icons.dark_mode : Icons.wb_sunny;
      } else if (climate.contains('snow')) {
        return Icons.ac_unit;
      } else if (climate.contains('thunderstorm') || climate.contains('rain')) {
        return Icons.thunderstorm;
      } else {
        return Icons.wb_cloudy;
      }
    }

    return Container(
      padding: EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                getWeatherIcon(climate),
                color: Colors.white,
                size: 50,
              ),
              SizedBox(width: 10),
              Text(
                temperature,
                style: TextStyle(color: Colors.white, fontSize: 24),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          SizedBox(height: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                climate,
                style: TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          SizedBox(height: 5),
          Text(
            locname,
            style: TextStyle(color: Colors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 20),
          Text(
            '$forecastClimate expected \nin the next few hours, with a \ntemperature of $forecastTemperature',
            style: TextStyle(color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
              if (!serviceEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please turn on location services'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                if (!mounted) return;
                setState(() {
                  temperature = 'Loading...';
                  climate = 'Loading...';
                  forecastClimate = 'Loading...';
                  forecastTemperature = 'Loading...';
                  locname = 'Loading...';
                });
                await _fetchWeatherData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedTestContainer() {
    return Container(
      padding: EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.speed,
            color: Colors.white,
            size: 50,
          ),
          SizedBox(height: 20),
          Text('Download: ${downloadSpeed.toStringAsFixed(2)} Mbps',
              style: TextStyle(color: Colors.white)),
          SizedBox(height: 10),
          Text('Upload: ${uploadSpeed.toStringAsFixed(2)} Mbps',
              style: TextStyle(color: Colors.white)),
          SizedBox(height: 10),
          Text(speedTestStatus, style: TextStyle(color: Colors.white)),
          SizedBox(height: 10),
          Text(networkQuality, style: TextStyle(color: Colors.white)),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _fetchNetworkDetails();
              uploadSpeed = 0.0;
              downloadSpeed = 0.0;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, // Background color
            ),
            child: Text('Test Speed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleIndicator(int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.0),
      width: 12.0,
      height: 12.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentIndex == index ? Colors.blue : Colors.grey,
      ),
    );
  }
}
