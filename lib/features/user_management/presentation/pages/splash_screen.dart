// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:parental_control_app/core/constants/app_colors.dart';
// import 'package:parental_control_app/core/design_system/app_design_system.dart';
// import '../widgets/responsive_logo.dart';
// import 'user_type_selection_screen.dart';
// import 'home_screen.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     );

//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
//       ),
//     );

//     _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _animationController,
//         curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
//       ),
//     );

//     _animationController.forward();

//     // Check authentication state and navigate accordingly
//     _checkAuthState();
//   }

//   /// Check if user is already logged in
//   Future<void> _checkAuthState() async {
//     // Wait for animation to complete
//     await Future.delayed(const Duration(milliseconds: 2000));

//     if (!mounted) return;

//     try {
//       final auth = FirebaseAuth.instance;
//       final currentUser = auth.currentUser;

//       // Check if user is logged in
//       if (currentUser != null) {
//         // Check user type from SharedPreferences
//         final prefs = await SharedPreferences.getInstance();
//         final userType = prefs.getString('user_type');

//         debugPrint('✅ User already logged in: ${currentUser.email}');
//         debugPrint('   User type: $userType');

//         // If parent, navigate to home screen
//         if (userType == 'parent') {
//           if (mounted) {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => const ParentHomeScreen()),
//             );
//             return;
//           }
//         }
//         // For child, you can add child home screen navigation here
//       }

//       // If not logged in, navigate to user type selection
//       if (mounted) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen()),
//         );
//       }
//     } catch (e) {
//       debugPrint('❌ Error checking auth state: $e');
//       // On error, navigate to user type selection
//       if (mounted) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen()),
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.lightCyan,
//       body: SafeArea(
//         child: Center(
//           child: FadeTransition(
//             opacity: _fadeAnimation,
//             child: ScaleTransition(
//               scale: _scaleAnimation,
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   ResponsiveLogo(sizeFactor: 0.25),
//                   const SizedBox(height: AppDesignSystem.spacingXL),
//                   Text(
//                     'SafeNest',
//                     style: AppDesignSystem.headline1.copyWith(
//                       color: AppColors.textDark,
//                     ),
//                   ),
//                   const SizedBox(height: AppDesignSystem.spacingS),
//                   Text(
//                     'Family digital safety made simple',
//                     style: AppDesignSystem.bodyMedium.copyWith(
//                       color: AppColors.deepTeal,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parental_control_app/features/user_management/presentation/pages/user_type_selection_screen.dart';
import 'package:parental_control_app/features/user_management/presentation/pages/home_screen.dart';
import 'package:parental_control_app/features/messaging/presentation/pages/child_app_main_screen.dart'; // ✅ add

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final userType = prefs.getString('user_type');

        debugPrint('✅ Logged in user: ${currentUser.email}');
        debugPrint('👤 User type: $userType');

        if (!mounted) return;

        if (userType == 'parent') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ParentHomeScreen()),
          );
          return;
        }

        // ✅ Child navigation uncomment kiya
        if (userType == 'child') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChildAppMainScreen()),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen()),
      );

    } catch (e) {
      debugPrint('❌ Splash auth error: $e');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserTypeSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox());
  }
}