import '../entities/parking_session.dart';
import '../repositories/parking_repository.dart';

class GetActiveSessionsUseCase {
  final ParkingRepository repository;

  GetActiveSessionsUseCase(this.repository);

  Future<List<ParkingSession>> call() {
    return repository.getActiveSessions();
  }
}

