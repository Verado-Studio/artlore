import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/services/auth_service.dart';
import 'core/services/purchases.dart';
import 'core/services/scanned_image_store.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'features/splash/presentation/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.ensureSignedIn();
  await RevenueCatService.configure();
  await ScannedImageStore.init();
  runApp(const ArtfulApp());
}

class ArtfulApp extends StatelessWidget {
  const ArtfulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashPage(),
    );
  }
}
