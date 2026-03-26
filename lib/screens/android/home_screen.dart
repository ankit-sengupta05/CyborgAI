import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class HomeMobile extends StatefulWidget{
  _HomeMobile createState() => _HomeMobile();
}

class _HomeMobile extends State<HomeMobile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Screen'),
      ),
      body: Center(
        child: Text('Welcome to the Home Mobile Screen!'),
      ),
    );
  }
}