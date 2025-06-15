import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'guest_navigation.dart';
import '../../../lib/screens/secrets.dart';

class OptimizeRoutePage extends StatefulWidget {
  final List<LatLng> locationArray;
  final LatLng currentLocation;
  final List<String> locationnames;

  const OptimizeRoutePage(
      {super.key,
      required this.locationArray,
      required this.locationnames,
      required this.currentLocation});

  @override
  _OptimizeRoutePageState createState() => _OptimizeRoutePageState();
}

class _OptimizeRoutePageState extends State<OptimizeRoutePage> {
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

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.currentLocation; // Initialize
    polylines = {};
    optimizeDestinations("driving-car");
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDialog();
        return;
      }

      // Get the user's current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng newLocation = LatLng(position.latitude, position.longitude);

      // Get address from coordinates using Google Geocoding API
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String address = placemarks.isNotEmpty
          ? "${placemarks[0].street}, ${placemarks[0].locality}"
          : "Unknown Location";

      // Update the state with the new location
      setState(() {
        _currentLocation = newLocation;
      });

      // Animate the camera to the new position
      _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));

      debugPrint("Current Location: $newLocation");
      debugPrint("Address: $address");
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Location Permission Required"),
        content: Text("Please enable location permission in settings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: Text("Open Settings"),
          ),
        ],
      ),
    );
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

  /// Fetches distance between two locations using Google Maps API
  Future<double> getDistance(
      LatLng coord1, LatLng coord2, String apiKey) async {
    final url =
        Uri.parse("https://maps.googleapis.com/maps/api/distancematrix/json"
            "?origins=${coord1.latitude},${coord1.longitude}"
            "&destinations=${coord2.latitude},${coord2.longitude}"
            "&key=$apiKey");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["status"] == "OK" &&
          data["rows"].isNotEmpty &&
          data["rows"][0]["elements"].isNotEmpty &&
          data["rows"][0]["elements"][0]["status"] == "OK") {
        return data["rows"][0]["elements"][0]["distance"]["value"]
            .toDouble(); // Distance in meters
      } else {
        throw Exception("Invalid response: ${data["status"]}");
      }
    } else {
      throw Exception("Failed to fetch distance: ${response.statusCode}");
    }
  }

  /// Optimizes the given locations using Nearest Neighbor algorithm with Google API
  Future<void> optimizeDestinations(String vehicle) async {
    int n = widget.locationArray.length;
    if (n < 2) return;

    List<LatLng> optimizedRoute = [];
    List<bool> visited = List.filled(n, false);

    // Start from the first location
    optimizedRoute.add(widget.locationArray[0]);
    optimizednames.add(widget.locationnames[0]);
    visited[0] = true;
    int currentIndex = 0;

    for (int i = 1; i < n; i++) {
      int nextIndex = -1;
      double minDistance = double.infinity;

      for (int j = 0; j < n; j++) {
        if (!visited[j]) {
          double distance = await getDistance(
              widget.locationArray[currentIndex],
              widget.locationArray[j],
              apiKey);

          if (distance < minDistance) {
            minDistance = distance;
            nextIndex = j;
          }
        }
      }

      if (nextIndex != -1) {
        optimizedRoute.add(widget.locationArray[nextIndex]);
        optimizednames.add(widget.locationnames[nextIndex]);
        visited[nextIndex] = true;
        currentIndex = nextIndex;
      }
    }

    setState(() {
      optimizedLocations = optimizedRoute;
      isLoading = false;
      _generateMarkers();
      getEstimatedDistanceAndTime(vehicle);
    });
  }

  //// Fetches estimated distance and time from the first stop to all other stops using Google Maps Directions API.
  Future<void> getEstimatedDistanceAndTime(String vehicle) async {
    List<Map<String, dynamic>> results = [];

    for (int i = 1; i < optimizedLocations.length; i++) {
      String waypoints = "";

      // Construct waypoints string (excluding the last destination)
      for (int j = 1; j < i; j++) {
        waypoints +=
            "${optimizedLocations[j].latitude},${optimizedLocations[j].longitude}|";
      }

      final origin =
          "${optimizedLocations[0].latitude},${optimizedLocations[0].longitude}";
      final destination =
          "${optimizedLocations[i].latitude},${optimizedLocations[i].longitude}";

      final url =
          Uri.parse("https://maps.googleapis.com/maps/api/directions/json"
              "?origin=$origin"
              "&destination=$destination"
              "${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}"
              "&mode=$vehicle"
              "&key=$apiKey");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" && data["routes"].isNotEmpty) {
          final route = data["routes"][0]["legs"];

          double totalDistance = 0.0;
          double totalDuration = 0.0;

          for (var leg in route) {
            totalDistance += leg["distance"]["value"]; // meters
            totalDuration += leg["duration"]["value"]; // seconds
          }

          results.add({
            "stop": i, // Stop index (1-based)
            "distance_km": (totalDistance / 1000).toStringAsFixed(2),
            "duration_min": (totalDuration / 60).toStringAsFixed(2),
          });
        } else {
          throw Exception("Invalid response from Google: ${data["status"]}");
        }
      } else {
        throw Exception(
            "Failed to fetch distance and time: ${response.statusCode}");
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

    // Draw polyline for optimized route
    if (optimizedLocations.length > 1) {
      getRouteCoordinates(optimizedLocations).then((routePoints) {
        setState(() {
          newPolylines.add(
            Polyline(
              polylineId: PolylineId("optimized_route"),
              color: Colors.blue,
              width: 5,
              points: routePoints,
            ),
          );
          markers = newMarkers;
          polylines.addAll(newPolylines);
        });
      });
    }
    // Add marker for current location
    newMarkers.add(
      Marker(
        markerId: MarkerId("current_location"),
        position: widget.currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: "Current Location"),
      ),
    );
    setState(() {
      markers = newMarkers;
    });
  }

  /// Fetches route coordinates using Google Maps Directions API.
  Future<List<LatLng>> getRouteCoordinates(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return [];

    final origin = "${waypoints.first.latitude},${waypoints.first.longitude}";
    final destination =
        "${waypoints.last.latitude},${waypoints.last.longitude}";

    // Format waypoints for the API (excluding first and last points)
    String waypointString = waypoints.length > 2
        ? "&waypoints=${waypoints.sublist(1, waypoints.length - 1).map((point) => "${point.latitude},${point.longitude}").join("|")}"
        : "";

    final url = Uri.parse("https://maps.googleapis.com/maps/api/directions/json"
        "?origin=$origin"
        "&destination=$destination"
        "$waypointString"
        "&mode=driving"
        "&key=$apiKey");

    final response = await http.get(url);

    print("API Response: ${response.body}"); // Debugging response

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data["status"] == "OK" && data["routes"].isNotEmpty) {
        String encodedPolyline =
            data["routes"][0]["overview_polyline"]["points"];
        return decodePolyline(encodedPolyline);
      } else {
        throw Exception("Invalid API response: ${data["status"]}");
      }
    } else {
      throw Exception(
          "Failed to load route. Status Code: ${response.statusCode}, Response: ${response.body}");
    }
  }

  /// Decodes a Google Maps encoded polyline into a list of LatLng coordinates.
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polylineCoordinates = [];
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
      int deltaLat = ((result & 1) == 1 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLng = ((result & 1) == 1 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      polylineCoordinates
          .add(LatLng(lat / 1E5, lng / 1E5)); // Convert to proper coordinates
    }

    return polylineCoordinates;
  }

  /// Show Bottom Sheet with Numbered Stop List
  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 350, // Adjusted height to accommodate additional details
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Route Information",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            "📌 ${optimizednames[index]}\n📍Latitude: ${optimizedLocations[index].latitude}\n📍Longitude: ${optimizedLocations[index].longitude}\n$details",
                            style: TextStyle(fontWeight: FontWeight.bold),
                            softWrap:
                                true, // Allows text to wrap to the next line
                            overflow: TextOverflow
                                .ellipsis, // Adds "..." if text is too long
                          ),
                          onTap: () {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                  optimizedLocations[index], 15),
                            );
                            Navigator.pop(context); // Close the bottom sheet
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

                  /// Navigation Button to start Navigation

                  Positioned(
                    bottom: 170,
                    right: 10,
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NavigationSample(
                              optimizedLocations: optimizedLocations,
                              optimizednames: optimizednames,
                              currentLocation: _currentLocation,
                            ),
                          ),
                        );
                      },
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: Icon(Icons.navigation, color: Colors.blue),
                    ),
                  ),

                  /// GPS Button to Get Current Location
                  Positioned(
                    bottom: 105,
                    right: 10,
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      onPressed: _getCurrentLocation,
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
