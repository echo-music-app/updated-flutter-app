import 'package:flutter/foundation.dart';
import 'package:mobile/domain/models/queue.dart';
import 'package:mobile/domain/models/track.dart';
import 'package:mobile/domain/repositories/queue_repository_interface.dart';
import 'package:mobile/domain/repositories/track_repository.dart';
import 'package:mobile/utils/command.dart';
import 'package:mobile/utils/result.dart';

enum WebViewScreenState { loading, data, error }

class PlayerWebViewViewModel extends ChangeNotifier {
  PlayerWebViewViewModel({
    required QueueRepository queueRepository,
    required TrackRepository trackRepository,
  }) : _queueRepository = queueRepository,
       _trackRepository = trackRepository,
       _simulateLoaded = false,
       _simulateError = false {
    _loadCmd = Command0<void>(_loadFn);
    _loadCmd.addListener(notifyListeners);
    _loadCmd.execute();
  }

  // testable constructor (preserves simulation flags from old .testable factory)
  PlayerWebViewViewModel.testable({
    required QueueRepository queueRepository,
    required TrackRepository trackRepository,
    bool simulateIframeLoaded = false,
    bool simulateIframeError = false,
  }) : _queueRepository = queueRepository,
       _trackRepository = trackRepository,
       _simulateLoaded = simulateIframeLoaded,
       _simulateError = simulateIframeError {
    _loadCmd = Command0<void>(_loadFn);
    _loadCmd.addListener(notifyListeners);
    _loadCmd.execute();
  }

  final QueueRepository _queueRepository;
  final TrackRepository _trackRepository;
  final bool _simulateLoaded;
  final bool _simulateError;

  late final Command0<void> _loadCmd;
  Queue? _queue;
  Track? _currentTrack;
  bool _iframeLoaded = false;
  bool _iframeError = false;

  WebViewScreenState get screenState {
    if (_loadCmd.running) return WebViewScreenState.loading;
    if (_loadCmd.hasError) return WebViewScreenState.error;
    // Load succeeded
    if (_iframeError || _simulateError) return WebViewScreenState.error;
    if (_iframeLoaded || _simulateLoaded) return WebViewScreenState.data;
    return WebViewScreenState.loading; // waiting for iframe
  }

  Track? get currentTrack => _currentTrack;
  bool get hasPrevious => _queue?.hasPrevious ?? false;
  bool get hasNext => _queue?.hasNext ?? false;

  void onIframeLoaded() {
    _iframeLoaded = true;
    notifyListeners();
  }

  void onIframeError() {
    _iframeError = true;
    notifyListeners();
  }

  Future<void> retry() {
    _iframeLoaded = false;
    _iframeError = false;
    return _loadCmd.execute();
  }

  Future<void> skipNext() async {
    if (_queue == null || !_queue!.hasNext) return;
    _queue!.skipNext();
    _currentTrack = await _trackRepository.getTrack(_queue!.currentTrack.id);
    notifyListeners();
  }

  Future<void> skipPrevious() async {
    if (_queue == null || !_queue!.hasPrevious) return;
    _queue!.skipPrevious();
    _currentTrack = await _trackRepository.getTrack(_queue!.currentTrack.id);
    notifyListeners();
  }

  Future<Result<void>> _loadFn() async {
    try {
      _queue = await _queueRepository.buildQueue();
      _currentTrack = await _trackRepository.getTrack(_queue!.currentTrack.id);
      return Result.ok(null);
    } on Exception catch (e) {
      _queue = null;
      _currentTrack = null;
      return Result.error(e);
    }
  }

  @override
  void dispose() {
    _loadCmd.removeListener(notifyListeners);
    super.dispose();
  }
}
