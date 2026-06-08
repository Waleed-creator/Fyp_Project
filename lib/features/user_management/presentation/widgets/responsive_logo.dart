import 'package:flutter/material.dart';
import 'package:parental_control_app/core/constants/app_assets.dart';
// import 'package:parental_control_app/core/utils/media_query_helpers.dart';

class ResponsiveLogo extends StatelessWidget {
  final double sizeFactor; // fraction of screen width, e.g. 0.2

  const ResponsiveLogo({super.key, this.sizeFactor = 1});

  @override
  Widget build(BuildContext context) {
    // final mq = MQ(context);
    // final logoSize = mq.w(sizeFactor);
    return Column(
      children: [
        // Crop the bottom portion to remove "SafeNest" text
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1, // Show top 80% (complete shield visible, text hidden)
            child: Image.asset(
              AppAssets.logo,
              width: 180,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
