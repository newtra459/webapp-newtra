// Dummy data mock — swap back to HomeRepositoryImpl in home_provider.dart
// when the backend /stations/nearby endpoint is live.

import '../models/station_model.dart';
import 'home_repository.dart';

class HomeRepositoryMock implements HomeRepository {
  static const List<StationModel> _stations = [
    StationModel(
      id: 'st-01',
      name: 'Main Gate',
      distance: 0.2,
      walkMin: 3,
      capacity: 15,
      currentCapacity: 8,
      lat: 17.4577,
      lng: 78.2753,
    ),
    StationModel(
      id: 'st-02',
      name: 'Library Hub',
      distance: 0.5,
      walkMin: 6,
      capacity: 17,
      currentCapacity: 10,
      lat: 17.4590,
      lng: 78.2770,
    ),
    StationModel(
      id: 'st-03',
      name: 'Hostel Block C',
      distance: 0.8,
      walkMin: 10,
      capacity: 9,
      currentCapacity: 6,
      lat: 17.4555,
      lng: 78.2740,
    ),
    StationModel(
      id: 'st-04',
      name: 'Sports Complex',
      distance: 1.1,
      walkMin: 13,
      capacity: 21,
      currentCapacity: 12,
      lat: 17.4563,
      lng: 78.2790,
    ),
    StationModel(
      id: 'st-05',
      name: 'Admin Block',
      distance: 1.4,
      walkMin: 17,
      capacity: 6,
      currentCapacity: 5,
      lat: 17.4601,
      lng: 78.2760,
    ),
    StationModel(
      id: 'st-06',
      name: 'Research Park',
      distance: 1.8,
      walkMin: 22,
      capacity: 14,
      currentCapacity: 8,
      lat: 17.4615,
      lng: 78.2745,
    ),
  ];

  @override
  Future<List<StationModel>> getNearbyStations(double lat, double lng) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _stations;
  }
}
