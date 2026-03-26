import 'package:flutter/material.dart';
import 'screens/home_router.dart'; // ✅ correct

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeRouter(), // ✅ no const
    );
  }
}