import '../entities/parking_session.dart';
import '../repositories/parking_repository.dart';

class CheckOutUseCase {
  final ParkingRepository repository;

  CheckOutUseCase(this.repository);

  Future<ParkingSession?> call(int sessionId) {
    return repository.checkOut(sessionId);
  }
}

