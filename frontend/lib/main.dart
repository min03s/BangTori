import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/room_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(BangToriApp());
}

class BangToriApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoomProvider(),
      child: MaterialApp(
        title: '방토리',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: HomeScreen(),
      ),
    );
  }
}