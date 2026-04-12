import 'package:mobile/domain/models/queue.dart';

abstract class QueueRepository {
  Future<Queue> buildQueue();
}
