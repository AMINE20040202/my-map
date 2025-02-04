import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/cache_service.dart';

// Events
abstract class MapEvent {}
class UpdateLocationEvent extends MapEvent {
  final LatLng location;
  UpdateLocationEvent(this.location);
}
class RequestRouteEvent extends MapEvent {
  final LatLng destination;
  RequestRouteEvent(this.destination);
}

// State
class MapState {
  final LatLng? currentLocation;
  final List<LatLng> routePoints;
  final String error;
  final bool isLoading;
  final double distance;
  final String duration;

  MapState({
    this.currentLocation,
    this.routePoints = const [],
    this.error = '',
    this.isLoading = false,
    this.distance = 0,
    this.duration = '',
  });
}

// BLoC
class MapBloc extends Bloc<MapEvent, MapState> {
  final CacheService cacheService;
  final String apiKey;

  MapBloc({required this.cacheService, required this.apiKey}) : super(MapState()) {
    on<UpdateLocationEvent>(_onUpdateLocation);
    on<RequestRouteEvent>(_onRequestRoute);
  }

  void _onUpdateLocation(UpdateLocationEvent event, Emitter<MapState> emit) {
    emit(MapState(
      currentLocation: event.location,
      routePoints: state.routePoints,
      distance: state.distance,
      duration: state.duration,
      isLoading: state.isLoading,
    ));
  }

  Future<void> _onRequestRoute(RequestRouteEvent event, Emitter<MapState> emit) async {
    if (state.currentLocation == null) {
      emit(MapState(
        currentLocation: state.currentLocation,
        error: 'Current location not available'
      ));
      return;
    }

    emit(MapState(
      currentLocation: state.currentLocation,
      isLoading: true,
      routePoints: state.routePoints, // Preserve existing route while loading
      distance: state.distance,
      duration: state.duration,
    ));

    try {
      final cachedRoute = cacheService.getCachedRoute(state.currentLocation!, event.destination);
      if (cachedRoute != null) {
        _processRouteData(cachedRoute, emit);
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car'
          '?api_key=$apiKey'
          '&start=${state.currentLocation!.longitude},${state.currentLocation!.latitude}'
          '&end=${event.destination.longitude},${event.destination.latitude}'
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await cacheService.cacheRoute(state.currentLocation!, event.destination, data);
        _processRouteData(data, emit);
      } else {
        _handleError('Failed to fetch route: ${response.statusCode}', emit);
      }
    } catch (e) {
      _handleError(e is TimeoutException ? 'Request timed out' : e.toString(), emit);
    }
  }

  void _handleError(String message, Emitter<MapState> emit) {
    emit(MapState(
      currentLocation: state.currentLocation,
      error: message,
      routePoints: state.routePoints, // Preserve existing route on error
      distance: state.distance,
      duration: state.duration,
    ));
  }

  void _processRouteData(Map<String, dynamic> data, Emitter<MapState> emit) {
    try {
      final features = data['features'] as List;
      if (features.isEmpty) {
        throw Exception('No route found');
      }

      final geometry = features[0]['geometry'];
      final properties = features[0]['properties'];

      if (geometry == null || properties == null) {
        throw Exception('Invalid route data');
      }

      final List<dynamic> coords = geometry['coordinates'];
      final routePoints = coords
          .map((coord) => LatLng(coord[1] as double, coord[0] as double))
          .toList();

      final summary = properties['summary'];
      final distance = (summary['distance'] as num).toDouble() / 1000;
      final duration = _formatDuration((summary['duration'] as num).toDouble());

      emit(MapState(
        currentLocation: state.currentLocation,
        routePoints: routePoints,
        distance: distance,
        duration: duration,
        isLoading: false,
      ));
    } catch (e) {
      emit(MapState(
        currentLocation: state.currentLocation,
        error: 'Error processing route data: ${e.toString()}',
      ));
    }
  }

  String _formatDuration(double seconds) {
    Duration duration = Duration(seconds: seconds.round());
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
}
