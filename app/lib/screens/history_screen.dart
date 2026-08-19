import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spacingLarge),
          child: Text('Your past scans will appear here.'),
        ),
      ),
    );
  }
}
