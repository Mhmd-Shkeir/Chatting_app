import 'package:flutter/material.dart';

/// Lets code outside the widget tree (router redirects, provider listeners)
/// show a SnackBar without needing a BuildContext.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
