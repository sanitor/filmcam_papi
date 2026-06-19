import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/camera_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => CameraProvider()..initialize(),
      child: const FilmCamApp(),
    ),
  );
}

class FilmCamApp extends StatelessWidget {
  const FilmCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'FilmCam Assist',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
