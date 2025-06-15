import 'dart:async';
import 'dart:convert';
import 'package:fasttrack/screens/secrets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../lib/screens/secrets.dart';

class NavigationSample extends StatefulWidget {
  final List<LatLng> optimizedLocations;
  final List<String> optimizednames;
  final LatLng currentLocation;
  const NavigationSample({
    super.key,
    required this.optimizedLocations,
    required this.optimizednames,
    required this.currentLocation,
  });

  @override
  State<NavigationSample> createState() => _NavigationSampleState();
}

class _NavigationSampleState extends State<NavigationSample> {
  late GoogleMapController mapController;
  Set<Marker> stopmarker = {};
  Set<Marker> currentlocmarker = {};
  List<LatLng> locations = [];
  List<String> locnames = [];
  late int length;
  late String finaldestination;
  Set<Polyline> polylines = {};
  late LatLng currentLocation;
  Map<String, dynamic> result = {
    'destination': 'loading ...',
    'distance_km': 'loading ...',
    'duration_min': 'loading ...'
  };
  final String apiKey =
      googleMapsApiKey; // Replace with your API Key

  final LatLng _initialPosition =
      LatLng(9.5916, 76.5222); // Example coordinates
  Timer? _locationTimer; // Timer for continuous updates

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  void initState() {
    locations = widget.optimizedLocations;
    locnames = widget.optimizednames;
    currentLocation = widget.currentLocation;
    length = locnames.length;
    finaldestination = locnames[length - 1];
    _generateMarkers();
  }

  @override
  void dispose() {
    _locationTimer?.cancel(); // Cancel the timer when widget is disposed
    super.dispose();
  }

  Future<void> _generateMarkers() async {
    Set<Marker> newMarkers = {};
    Set<Polyline> newPolylines = {};
    int i = 0;

    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      LatLng newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        currentLocation = newLocation;
      });
      _updateCurrentLocationMarker(newLocation);

      if (i < length && !isWithin100Meters(currentLocation, locations[i])) {
        // Only process the next stop when the previous is reached
        newMarkers.add(
          Marker(
            markerId: MarkerId("marker_$i"),
            position: locations[i],
            infoWindow: InfoWindow(title: "Stop ${i + 1}"),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );

        try {
          Set<Polyline> polylines = await getRoutePolyline(
            currentLocation,
            locations[i],
          );
          setState(() {
            newPolylines.addAll(polylines);
            stopmarker = newMarkers;
            this.polylines = newPolylines;
          });
        } catch (e) {
          print("Error loading route: $e");
        }

        try {
          result = await getDistanceAndTime(
              currentLocation, locations[i], i, "driving");
        } catch (e) {
          print('Error Calculating distance and time');
        }
      } else if (i < length) {
        // Move to the next stop when the current stop is reached
        i++;
      }
    });
  }

  /// Updates the current location marker on the map
  void _updateCurrentLocationMarker(LatLng newLocation) {
    setState(() {
      currentlocmarker = {
        Marker(
          markerId: MarkerId("current_location"),
          position: newLocation,
          infoWindow: InfoWindow(title: "Current Location"),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      };
    });
  }

//to find whether target location reached
  bool isWithin100Meters(LatLng currentLocation, LatLng targetLocation) {
    double distance = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      targetLocation.latitude,
      targetLocation.longitude,
    );

    return distance <= 2500; // Check if within 2500 meters
  }

  /// Fetches route coordinates using Google Maps Directions API.
  Future<Set<Polyline>> getRoutePolyline(
      LatLng origin, LatLng destination) async {
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving"
        "&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data["status"] == "OK" && data["routes"].isNotEmpty) {
        String encodedPolyline =
            data["routes"][0]["overview_polyline"]["points"];
        List<LatLng> polylinePoints = decodePolyline(encodedPolyline);

        return {
          Polyline(
            polylineId: PolylineId("route"),
            color: Colors.blue,
            width: 5,
            points: polylinePoints,
          ),
        };
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

  /// Fetches estimated distance and time between two points using Google Maps Directions API.
  Future<Map<String, dynamic>> getDistanceAndTime(
      LatLng origin, LatLng destination, int i, String vehicle) async {
    final url = Uri.parse("https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=$vehicle"
        "&key=$apiKey");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["status"] == "OK" && data["routes"].isNotEmpty) {
        final leg =
            data["routes"][0]["legs"][0]; // Get the first leg of the journey

        double distanceKm =
            leg["distance"]["value"] / 1000; // Convert meters to km
        double durationMin =
            leg["duration"]["value"] / 60; // Convert seconds to minutes

        return {
          "destination": locnames[i],
          "distance_km": distanceKm.toStringAsFixed(2),
          "duration_min": durationMin.toStringAsFixed(2),
        };
      } else {
        throw Exception("Invalid response from Google: ${data["status"]}");
      }
    } else {
      throw Exception(
          "Failed to fetch distance and time: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving Mode'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          /// Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: currentLocation,
              zoom: 12.0,
            ),
            markers: {
              ...stopmarker,
              ...currentlocmarker
            }, // Include both markers
            polylines: polylines,
          ),
          Positioned(
            height: 150,
            width: 280,
            bottom: 1,
            left: 50,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3.0,
                children: [
                  Flexible(
                    child: Text("📍 To: ${result['destination']}",
                        style: TextStyle(color: Colors.black, fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Flexible(
                    child: Text("🛣️ Distance: ${result['distance_km']} km",
                        style: TextStyle(color: Colors.black, fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Flexible(
                    child: Text("🕒 Time: ${result['duration_min']} min",
                        style: TextStyle(color: Colors.black, fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
