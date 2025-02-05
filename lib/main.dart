import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'package:device_preview/device_preview.dart';
import 'screens/splash_screen.dart';
import 'utils/app_strings.dart';

void main() {
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const SafeArea(
        child: SplashScreen(), // Changed from MapScreen to SplashScreen
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  LocationData? currentLocation;
  List<LatLng> routePoints = [];
  List<Marker> markers = [];
  final String orsApiKey =
      '5b3ce3597851110001cf62487e963e23239b4da28831def130544ae7'; // Replace with your OpenRouteService API key
  bool _isLoading = false;
  String _errorMessage = '';
  double _distance = 0;
  String _duration = '';
  final TextEditingController _searchController = TextEditingController();

  static const LatLng defaultLocation =
      LatLng(31.604495079489517, -2.2324191054772817); // JQ38+JWG, Béchar
  static const double defaultZoom = 16.5;

  @override
  void initState() {
    super.initState();
    // Initialize markers with default location marker
    markers = [
      Marker(
        width: 80.0,
        height: 80.0,
        point: defaultLocation,
        child: const Icon(Icons.location_on, color: Colors.blue, size: 40.0),
      ),
    ];
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _errorMessage = AppStrings.locationServicesDisabled);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _errorMessage = AppStrings.locationPermissionsDenied);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() =>
          _errorMessage = AppStrings.locationPermissionsPermanentlyDenied);
      return;
    }

    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    var location = Location();

    try {
      var userLocation = await location.getLocation();
      setState(() {
        currentLocation = userLocation;
        markers.add(
          Marker(
            width: 80.0,
            height: 80.0,
            point: LatLng(userLocation.latitude!, userLocation.longitude!),
            child:
                const Icon(Icons.my_location, color: Colors.blue, size: 40.0),
          ),
        );
      });
    } on Exception {
      currentLocation = null;
    }

    location.onLocationChanged.listen((LocationData newLocation) {
      setState(() {
        currentLocation = newLocation;
      });
    });
  }

  Future<void> _getRoute(LatLng destination) async {
    if (currentLocation == null) return;

    setState(() {
      _isLoading = true;
      // Add current location and destination as initial route points
      routePoints = [
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        destination
      ];
    });

    try {
      final start =
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
      final response = await http.get(
        Uri.parse(
            'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${start.longitude},${start.latitude}&end=${destination.longitude},${destination.latitude}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coords =
            data['features'][0]['geometry']['coordinates'];
        final routes = data['features'][0]['properties'];

        if (coords.isNotEmpty) {
          setState(() {
            routePoints =
                coords.map((coord) => LatLng(coord[1], coord[0])).toList();
            markers = [
              // Keep current location marker
              Marker(
                width: 80.0,
                height: 80.0,
                point: start,
                child: const Icon(Icons.my_location,
                    color: Colors.blue, size: 40.0),
              ),
              // Add destination marker
              Marker(
                width: 80.0,
                height: 80.0,
                point: destination,
                child: const Icon(Icons.location_on,
                    color: Colors.red, size: 40.0),
              ),
            ];
            _distance = routes['summary']['distance'] / 1000;
            _duration = _formatDuration(routes['summary']['duration']);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch route';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatDuration(double seconds) {
    Duration duration = Duration(seconds: seconds.round());
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }

  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.length < 3) return [];

    final response = await http.get(
      Uri.parse(
          'https://api.openrouteservice.org/geocode/search?api_key=$orsApiKey&text=$query'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['features'].map((feature) {
        final coordinates = feature['geometry']['coordinates'];
        return {
          'name': feature['properties']['label'],
          'location': LatLng(coordinates[1], coordinates[0]),
        };
      }));
    }
    return [];
  }

  void _addDestinationMarker(LatLng point) {
    setState(() {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: point,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
        ),
      );
    });
    _getRoute(point);
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: const AssetImage(
                      'assets/images/image.png'), // Replace 'profile.png' with your image name
                ),
                // const SizedBox(height: 10),
                const Text(
                  AppStrings.navigationApp,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  AppStrings.menuOptions,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // BLOCK Section
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 16.0),
            child: Text(
              'BLOCK',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...List.generate(8, (index) {
            final blockLetter = String.fromCharCode('A'.codeUnitAt(0) + index);
            return ListTile(
              leading: const Icon(Icons.block),
              title: Text('Block $blockLetter'),
              onTap: () {
                // Handle block selection
                Navigator.pop(context);
              },
            );
          }),

          const Divider(),

          // IMPHI Section
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 16.0),
            child: Text(
              'IMPHI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ...List.generate(9, (index) {
            final imphiLetter = String.fromCharCode('A'.codeUnitAt(0) + index);
            return ListTile(
              leading: const Icon(Icons.apartment),
              title: Text('IMPHI $imphiLetter'),
              onTap: () {
                // Handle IMPHI selection
                Navigator.pop(context);
              },
            );
          }),

          const Divider(),
          // Settings and About options
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text(AppStrings.settings),
            onTap: () {
              // TODO: Implement settings
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text(AppStrings.about),
            onTap: () {
              // TODO: Implement about page
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: defaultLocation,
        initialZoom: defaultZoom,
        onTap: (tapPosition, point) => _addDestinationMarker(point),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final mapSize = screenSize.width * 0.9; // Square size based on screen width

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.appName),
          elevation: 0,
        ),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            if (_errorMessage.isNotEmpty)
              Center(child: Text(_errorMessage))
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 16.0,
                    bottom: 160.0,
                  ),
                  child: Container(
                    height: mapSize, // Square height
                    width: mapSize, // Square width
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          spreadRadius: -3,
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          _buildMap(),
                          // Gradient overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 80,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (routePoints.isNotEmpty)
              Positioned(
                bottom: 24, // Increased from 16 to 24
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    // color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          '${AppStrings.distance}${_distance.toStringAsFixed(2)}${AppStrings.km}'),
                      Text('${AppStrings.duration}$_duration'),
                      ElevatedButton(
                        onPressed: () {
                          // Implement turn-by-turn navigation
                        },
                        child: const Text(AppStrings.startNavigation),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (currentLocation != null) {
              mapController.move(
                LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
                15.0,
              );
            }
          },
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}
