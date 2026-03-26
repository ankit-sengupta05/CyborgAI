import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'android/home_screen.dart';
import 'windows/home_screen.dart';

class HomeRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return HomeMobile();
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return HomeDesktop();
    } else {
      return Scaffold(
        body: Center(child: Text("Unsupported Platform")),
      );
    }
  }
}