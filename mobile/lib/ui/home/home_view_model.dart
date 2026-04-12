import 'package:flutter/foundation.dart';

enum HomeScreenState { loading, empty, error, data }

class HomeViewModel extends ChangeNotifier {
  HomeScreenState get state => HomeScreenState.data; // PoC: always data
}
