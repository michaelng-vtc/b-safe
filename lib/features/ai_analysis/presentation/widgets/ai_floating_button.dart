import 'package:flutter/material.dart';

class AiFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const AiFloatingButton({
    super.key,
    required this.onPressed,
    this.label = 'AI Analysis',
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.auto_awesome),
      label: Text(label),
    );
  }
}
