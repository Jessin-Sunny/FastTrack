import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:fasttrack/screens/personnel_navigation.dart';
import '../../../lib/screens/secrets.dart';
class PersonnelOptimization extends StatefulWidget {
  final List<Map<String, dynamic>> packets;
  final LatLng currentlocation;

  const PersonnelOptimization(
      {super.key, required this.packets, required this.currentlocation});

  @override
  _PersonnelOptimization createState() => _PersonnelOptimization();
}

class _PersonnelOptimization extends State<PersonnelOptimization> {
  final String apiKey =
      googleMapsApiKey; // Replace with your API Key
  List<LatLng> optimizedLocations = [];
  List<String> optimizednames = [];
  late LatLng _currentLocation;
  GoogleMapController? _mapController;
  Set<Marker> markers = {};
  bool isLoading = true;
  Set<Polyline> polylines = {};
  List<Map<String, dynamic>> estimates = [];
  List<String> locationnames = [];
  List<LatLng> locationArray = [];
  late LatLng pickup;
  List<String> packetid = [];
  List<String> pickedid = [];

  @override
  void initState() {
    super.initState();
    extractLocations();
    _currentLocation = widget.currentlocation; // Initialize
    polylines = {};
    optimizeDestinations("driving-car");
  }

  void extractLocations() {
    setState(() {
      List<Map<String, dynamic>> pickedPackets = widget.packets
          .where((packet) => packet['status'] == 'Picked')
          .toList();
      locationnames = pickedPackets
          .map<String>(
              (packet) => packet['dlocation_name']?.toString() ?? 'Unknown')
          .where((name) => name != 'Unknown') // Filter out unknown locations
          .toList();

      locationArray = pickedPackets
          .where((packet) => packet['delivery_location'] != null)
          .map<LatLng>((packet) => LatLng(
                packet['delivery_location']['latitude'],
                packet['delivery_location']['longitude'],
              ))
          .toList();
      pickedid = pickedPackets
          .map<String>((packet) => packet['id']?.toString() ?? 'Unknown')
          .where((id) => id != 'Unknown') // Filter out unknown id
          .toList();
      pickup = LatLng(widget.packets[0]['pickup_location']['latitude'],
          pickedPackets[0]['pickup_location']['longitude']);
      //print(pickup);
      locationArray.insert(0, pickup);
      locationnames.insert(0, widget.packets[0]['plocation_name']);
      //packetid.add('');
    });

    //print("Location Names: $locationnames");
    //print("Location Array: $locationArray");
  }

  /// Get the device's current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation));
    });
  }

  /// Show dialog to enable location services
  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enable Location"),
        content: Text("Please enable location services for better experience."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Fetches distance between two locations using Google Maps Distance Matrix API
  Future<double> getDistance(LatLng coord1, LatLng coord2, String mode) async {
    final url =
        Uri.parse("https://maps.googleapis.com/maps/api/distancematrix/json"
            "?origins=${coord1.latitude},${coord1.longitude}"
            "&destinations=${coord2.latitude},${coord2.longitude}"
            "&mode=$mode"
            "&key=$apiKey");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["rows"].isNotEmpty &&
          data["rows"][0]["elements"].isNotEmpty &&
          data["rows"][0]["elements"][0]["distance"] != null) {
        return data["rows"][0]["elements"][0]["distance"]["value"]
            .toDouble(); // Distance in meters
      } else {
        //print(data);
        throw Exception("No distance data available");
      }
    } else {
      throw Exception("Failed to fetch distance");
    }
  }

  /// Optimizes the given locations using Nearest Neighbor algorithm
  Future<void> optimizeDestinations(String vehicle) async {
    int n = locationArray.length;
    List<double> distances = List.filled(n, double.infinity);
    List<LatLng> optimizedRoute = [];
    List<bool> visited = List.filled(n, false);

    // Start from the first location
    optimizedRoute.add(locationArray[0]);
    optimizednames.add(locationnames[0]);
    packetid.add('');
    visited[0] = true;
    int currentIndex = 0;

    for (int i = 1; i < n; i++) {
      int nextIndex = -1;
      double minDistance = double.infinity;

      for (int j = 0; j < n; j++) {
        if (!visited[j]) {
          double distance = await getDistance(
              locationArray[currentIndex], locationArray[j], vehicle);
          if (distance < minDistance) {
            minDistance = distance;
            nextIndex = j;
          }
        }
      }

      if (nextIndex != -1) {
        optimizedRoute.add(locationArray[nextIndex]);
        optimizednames.add(locationnames[nextIndex]);
        //print(nextIndex);
        packetid.add(pickedid[nextIndex - 1]);

        visited[nextIndex] = true;
        currentIndex = nextIndex;
      }
    }
    optimizedRoute.add(locationArray[0]);
    optimizednames.add(locationnames[0]);
    packetid.add('');

    setState(() {
      optimizedLocations = optimizedRoute;
      isLoading = false;
      _generateMarkers();
      getEstimatedDistanceAndTime(vehicle);
    });
  }

  /// Fetches estimated distance and time from the first stop to all other stops.
  Future<void> getEstimatedDistanceAndTime(String mode) async {
    List<Map<String, dynamic>> results = [];

    for (int i = 1; i < optimizedLocations.length; i++) {
      String origin =
          "${optimizedLocations[0].latitude},${optimizedLocations[0].longitude}";
      String destination =
          "${optimizedLocations[i].latitude},${optimizedLocations[i].longitude}";

      List<String> waypoints = [];
      for (int j = 1; j < i; j++) {
        waypoints.add(
            "${optimizedLocations[j].latitude},${optimizedLocations[j].longitude}");
      }

      final url =
          Uri.parse("https://maps.googleapis.com/maps/api/directions/json"
              "?origin=$origin"
              "&destination=$destination"
              "&mode=$mode"
              "&waypoints=${waypoints.isNotEmpty ? waypoints.join('|') : ''}"
              "&key=$apiKey");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["routes"].isNotEmpty) {
          double totalDistance = data["routes"][0]["legs"].fold(
              0.0, (sum, leg) => sum + leg["distance"]["value"]); // meters

          double totalDuration = data["routes"][0]["legs"].fold(
              0.0, (sum, leg) => sum + leg["duration"]["value"]); // seconds

          results.add({
            "stop": i, // Stop index (1-based)
            "distance_km":
                (totalDistance / 1000).toStringAsFixed(2), // Convert to km
            "duration_min":
                (totalDuration / 60).toStringAsFixed(2), // Convert to min
          });
        } else {
          throw Exception("No route found");
        }
      } else {
        throw Exception("Failed to fetch distance and time");
      }
    }

    // Update state once after all calculations
    setState(() {
      estimates = results;
    });
  }

  void _generateMarkers() {
    Set<Marker> newMarkers = {};
    Set<Polyline> newPolylines = {};

    // Add markers for optimized locations
    for (int i = 0; i < optimizedLocations.length; i++) {
      newMarkers.add(
        Marker(
          markerId: MarkerId("marker_$i"),
          position: optimizedLocations[i],
          infoWindow: InfoWindow(title: "Stop ${i + 1}"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Draw optimized route using Google Maps Directions API
    if (optimizedLocations.length > 1) {
      getRouteCoordinates(optimizedLocations).then((routePoints) {
        if (routePoints.isNotEmpty) {
          setState(() {
            newPolylines.add(
              Polyline(
                polylineId: PolylineId("optimized_route"),
                color: Colors.blue,
                width: 5,
                points: routePoints,
              ),
            );
            polylines = newPolylines;
          });
        }
      }).catchError((error) {
        print("Error fetching route: $error");
      });
    }

    // Add marker for current location
    newMarkers.add(
      Marker(
        markerId: MarkerId("current_location"),
        position: widget.currentlocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: "Current Location"),
      ),
    );

    // Update markers in the state
    setState(() {
      markers = newMarkers;
    });
  }

  /// Fetches route coordinates using Google Maps Directions API
  Future<List<LatLng>> getRouteCoordinates(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return [];

    String origin = "${waypoints.first.latitude},${waypoints.first.longitude}";
    String destination =
        "${waypoints.last.latitude},${waypoints.last.longitude}";

    List<String> waypointStrings = waypoints
        .sublist(1, waypoints.length - 1)
        .map((point) => "${point.latitude},${point.longitude}")
        .toList();

    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json"
      "?origin=$origin"
      "&destination=$destination"
      "&mode=driving"
      "&waypoints=${waypointStrings.isNotEmpty ? waypointStrings.join('|') : ''}"
      "&key=$apiKey",
    );

    final response = await http.get(url);
    print("API Response: ${response.body}"); // Debugging response

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data.containsKey('routes') && data['routes'].isNotEmpty) {
        String encodedPolyline =
            data['routes'][0]['overview_polyline']['points'];
        return decodePolyline(encodedPolyline);
      } else {
        throw Exception("Invalid API response: No route found.");
      }
    } else {
      throw Exception(
          "Failed to load route. Status Code: ${response.statusCode}, Response: ${response.body}");
    }
  }

  /// Decodes polyline from Google Maps API response
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// Show Bottom Sheet with Numbered Stop List
  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16), // Spacing between loader and text
                    Text(
                      "Loading Route Information... Please wait.",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : Container(
                padding: EdgeInsets.all(16),
                height:
                    350, // Adjusted height to accommodate additional details
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Route Information",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Divider(),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: optimizedLocations.length,
                        itemBuilder: (context, index) {
                          String details;
                          // Ensure estimates list is not empty before accessing
                          if (index == 0) {
                            details = "Start Point";
                          } else if (estimates.isNotEmpty &&
                              index - 1 < estimates.length) {
                            details =
                                "🛣️ Estimated Distance : ${estimates[index - 1]['distance_km']} km \n"
                                "🕒 Estimated Time : ${estimates[index - 1]['duration_min']} min";
                          } else {
                            details = "Loading...";
                          }

                          return Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text("${index + 1}",
                                      style: TextStyle(color: Colors.white)),
                                ),
                                title: Text("Stop ${index + 1}"),
                                subtitle: Text(
                                  "📌 ${optimizednames[index]}\n"
                                  "${index == 0 ? '' : "📦 ${packetid[index]}\n"}"
                                  "📍 Latitude: ${optimizedLocations[index].latitude}\n"
                                  "📍 Longitude: ${optimizedLocations[index].longitude}\n"
                                  "$details",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  softWrap:
                                      true, // Allows text to wrap to the next line
                                  overflow: TextOverflow
                                      .visible, // Ensures all text is shown
                                ),
                                onTap: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                        optimizedLocations[index], 15),
                                  );
                                  Navigator.pop(
                                      context); // Close the bottom sheet
                                },
                              ),
                              Divider(),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FastTrack'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              Icons.expand_circle_down,
              size: 40,
            ),
            onPressed: _showBottomSheet, // Open Bottom Sheet
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16), // Spacing between loader and text
                  Text(
                    "Calculating Optimized route... Please wait.",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          :

          /// Google Map Section
          Expanded(
              flex: 2,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: optimizedLocations[0],
                      zoom: 12,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    markers: markers,
                    polylines: polylines,
                  ),

                  /// GPS Button to Get Current Location
                  Positioned(
                    bottom: 100,
                    right: 10,
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      onPressed: _getCurrentLocation,
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),

                  // Navigate Button
                  Positioned(
                    bottom: 180,
                    right: 10,
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PersonnelNavigation(
                              currentLocation: _currentLocation,
                              optimizedLocations:
                                  optimizedLocations, // Your optimized route stops
                              optimizednames: optimizednames,
                            ),
                          ),
                        );
                      },
                      backgroundColor: Colors.green.withOpacity(0.9),
                      child: Icon(Icons.navigation, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
