import 'package:flutter/material.dart';

import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/phone_login_screen.dart';
import 'features/auth/screens/otp_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bizora',
      debugShowCheckedModeBanner: false,

      /// First screen
      home: const SplashScreen(),

      /// Named routes
      routes: {
        "/login": (context) => LoginScreen(),
        "/phone": (context) => const PhoneLoginScreen(),
      },

      /// OTP route with arguments
      onGenerateRoute: (settings) {
        if (settings.name == "/otp") {
          final verificationId = settings.arguments as String;

          return MaterialPageRoute(
            builder: (_) => OtpScreen(verificationId: verificationId),
          );
        }

        return null;
      },
    );
  }
}
