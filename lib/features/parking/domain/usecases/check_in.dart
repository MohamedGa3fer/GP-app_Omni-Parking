import '../repositories/parking_repository.dart';

class CheckInUseCase {
  final ParkingRepository repository;

  CheckInUseCase(this.repository);

  Future<CheckInResult> call(String licensePlate, String zoneId) {
    return repository.checkIn(licensePlate, zoneId);
  }
}

