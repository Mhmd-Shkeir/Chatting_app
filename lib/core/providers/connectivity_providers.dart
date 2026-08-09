import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the device has *some* network interface up (wifi/mobile/
/// ethernet/etc.) — not a guarantee the internet is actually reachable
/// end to end, just enough signal to decide whether to show the "No
/// internet connection" banner and whether a failed upload should
/// auto-retry. Seeds from a one-off [Connectivity.checkConnectivity] call
/// so the UI doesn't show a loading flash before the first change event.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield !initial.contains(ConnectivityResult.none);
  yield* connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
});
