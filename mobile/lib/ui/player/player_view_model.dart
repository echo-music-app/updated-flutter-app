import 'package:flutter/foundation.dart';
import 'package:mobile/ui/player/player_controller.dart';
import 'package:mobile/domain/repositories/queue_repository_interface.dart';
import 'package:mobile/utils/command.dart';
import 'package:mobile/utils/result.dart';

class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel({required QueueRepository queueRepository})
    : _queueRepository = queueRepository {
    _loadCmd = Command0<void>(_loadFn);
    _loadCmd.addListener(notifyListeners);
    _loadCmd.execute();
  }

  final QueueRepository _queueRepository;
  late final Command0<void> _loadCmd;
  PlayerController? _controller;

  PlayerController? get controller => _controller;
  bool get isLoading => _loadCmd.running;
  String? get error =>
      _loadCmd.hasError ? (_loadCmd.result as Err).error.toString() : null;

  Future<Result<void>> _loadFn() async {
    try {
      final queue = await _queueRepository.buildQueue();
      _controller = PlayerController(
        stream: const Stream.empty(),
        queue: queue,
      );
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  void dispose() {
    _loadCmd.removeListener(notifyListeners);
    _controller?.dispose();
    super.dispose();
  }
}
