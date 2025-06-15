import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'guest_optimization.dart';
import 'guest_information.dart';

const String googleApiKey = "";

class GuestWelcomePage extends StatefulWidget {
  const GuestWelcomePage({super.key});

  @override
  State<GuestWelcomePage> createState() => _GuestWelcomePageState();
}

class _GuestWelcomePageState extends State<GuestWelcomePage> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = LatLng(9.579330, 76.622040); // Default center
  final List<LatLng> _selectedLocations = []; // Stores selected locations
  final List<String> _locationnames = [];
  final List<TextEditingController> _locationControllers = [
    TextEditingController()
  ];
  final List<FocusNode> _focusNodes = [
    FocusNode()
  ]; // Maintain a focus node for each field

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Get GPS location on start
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

  /// Function to search location and move map
  Future<void> _searchLocation(
      TextEditingController searchController, int index) async {
    String address = searchController.text.trim();
    if (address.isEmpty) return;

    try {
      if (address.toLowerCase() == "marker") {
        LatLng defaultPosition =
            LatLng(9.579330, 76.622040); // Default marker position

        for (var loc in _selectedLocations) {
          if (loc.latitude == defaultPosition.latitude &&
              loc.longitude == defaultPosition.longitude) {
            return; // Location already exists, do nothing
          }
        }

        setState(() {
          if (index < _selectedLocations.length) {
            _selectedLocations[index] = defaultPosition;
            _locationnames[index] = "Marker";
          } else {
            _selectedLocations.add(defaultPosition);
            _locationnames.add("Marker");
          }
        });

        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(defaultPosition, 14));
        return;
      }
      if (address.toLowerCase() == "current location") {
        for (var loc in _selectedLocations) {
          if (loc.latitude == _currentLocation.latitude &&
              loc.longitude == _currentLocation.longitude) {
            return; // Location already exists, do nothing
          }
        }
        setState(() {
          // Update existing location if already present
          if (index < _selectedLocations.length) {
            _selectedLocations[index] = _currentLocation;
            _locationnames[index] = address;
          } else {
            _selectedLocations.add(_currentLocation);
            _locationnames.add(address);
          }
        });
        return;
      }
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng newPosition = LatLng(loc.latitude, loc.longitude);

        // Move camera to searched location
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(newPosition, 14));

        for (var loc in _selectedLocations) {
          if (loc.latitude == newPosition.latitude &&
              loc.longitude == newPosition.longitude) {
            return; // Location already exists, do nothing
          }
        }

        setState(() {
          // Update existing location if already present
          if (index < _selectedLocations.length) {
            _selectedLocations[index] = newPosition;
            _locationnames[index] = address;
          } else {
            _selectedLocations.add(newPosition);
            _locationnames.add(address);
          }
        });
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location not found")),
      );
    }
  }

  /// Function to update marker position when dragged
  void _onMarkerDrag(LatLng newPosition, int index) {
    setState(() {
      _selectedLocations[index] = newPosition;
      _locationControllers[index].text =
          "Lat: ${newPosition.latitude}, Lng: ${newPosition.longitude}";
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

  /// Add a new location input field
  void _addLocationField() {
    setState(() {
      _locationControllers.add(TextEditingController());
      _focusNodes.add(FocusNode()); // Add a new focus node for the new field
    });
  }

  void _removeLocationField(int index) {
    if (_locationControllers.length > 1) {
      setState(() {
        _locationControllers[index].dispose();
        _focusNodes[index].dispose();
        _locationControllers.removeAt(index);
        _focusNodes.removeAt(index);

        // Remove the corresponding location safely
        if (index < _selectedLocations.length) {
          _selectedLocations.removeAt(index);
        }
        if (index < _locationnames.length) {
          _locationnames.removeAt(index);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _locationControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose(); // Dispose all focus nodes
    }
    super.dispose();
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
              Icons.assistant_direction,
              size: 30,
            ),
            onPressed: () {
              if (_selectedLocations.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please Select locations'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OptimizeRoutePage(
                      locationArray: _selectedLocations,
                      locationnames: _locationnames,
                      currentLocation: _currentLocation,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          /// Location Input Section
          Container(
            height: 150,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (int i = 0; i < _locationControllers.length; i++)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    focusNode: _focusNodes[i],
                                    controller: _locationControllers[i],
                                    //readOnly: true,
                                    textInputAction: TextInputAction
                                        .done, // Triggers 'Done' on keyboard
                                    onSubmitted: (value) => _searchLocation(
                                        _locationControllers[i], i),
                                    decoration: InputDecoration(
                                      labelText: "Enter Location ${i + 1}",
                                      labelStyle: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  ),
                                ),
                                if (i == _locationControllers.length - 1 &&
                                    _locationControllers.length > 1)
                                  IconButton(
                                    icon: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                        color: Colors.blue,
                                      ),
                                      child: Icon(Icons.remove_circle,
                                          color: Colors.white, size: 30),
                                    ),
                                    onPressed: () => _removeLocationField(i),
                                  )
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      color: Colors.blue,
                    ),
                    child:
                        Icon(Icons.add_circle, color: Colors.white, size: 30),
                  ),
                  onPressed: _addLocationField,
                )
              ],
            ),
          ),

          /// Google Map Section
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation,
                    zoom: 12,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  markers: {
                    /// Marker for Current Location
                    Marker(
                      markerId: MarkerId("current_location"),
                      position: _currentLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue),
                    ),

                    /// Markers for Selected Locations (Including Draggable)
                    for (int i = 0; i < _selectedLocations.length; i++)
                      Marker(
                        markerId: MarkerId(_selectedLocations[i].toString()),
                        position: _selectedLocations[i],
                        icon: _locationnames[i] == "Marker"
                            ? BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueAzure)
                            : BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed),
                        draggable: _locationnames[i] ==
                            "Marker", // Enable drag only for "Marker"
                        onDragEnd: (newPosition) =>
                            _onMarkerDrag(newPosition, i),
                      ),
                  },
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

                // Help button
                Positioned(
                  bottom: 40,
                  left: 10,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GuestInformation(),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Icon(
                          Icons.help,
                          size: 40,
                          color: Colors.blue,
                        ),
                        Text(
                          "Help",
                          style: TextStyle(color: Colors.blue, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
