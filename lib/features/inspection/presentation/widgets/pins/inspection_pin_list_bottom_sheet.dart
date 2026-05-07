import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartsurvey/features/inspection/domain/entities/inspection_model.dart';
import 'package:smartsurvey/features/inspection/presentation/providers/inspection_provider.dart';
import 'package:smartsurvey/core/theme/app_theme.dart';

class InspectionPinListBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final Widget Function(InspectionProvider inspection) buildPinSummary;
  final Widget Function() buildEmptyPinState;
  final Widget Function(
    InspectionPin pin,
    int index,
    InspectionProvider inspection,
  ) buildPinCard;

  const InspectionPinListBottomSheet({
    super.key,
    required this.scrollController,
    required this.buildPinSummary,
    required this.buildEmptyPinState,
    required this.buildPinCard,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, inspection, _) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Inspection Points',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    '${inspection.currentPins.length}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (inspection.currentPins.isNotEmpty) buildPinSummary(inspection),
            Expanded(
              child: inspection.currentPins.isEmpty
                  ? buildEmptyPinState()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: inspection.currentPins.length,
                      itemBuilder: (context, index) {
                        final pin = inspection.currentPins[index];
                        return buildPinCard(pin, index, inspection);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
