import '../entities/zone.dart';
import '../repositories/parking_repository.dart';

class GetZonesUseCase {
  final ParkingRepository repository;

  GetZonesUseCase(this.repository);

  Future<List<Zone>> call() {
    return repository.getZones();
  }
}

