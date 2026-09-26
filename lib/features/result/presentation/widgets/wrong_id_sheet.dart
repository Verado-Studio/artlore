import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/painting.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

void showWrongIdSheet(BuildContext context, Painting painting) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 20),
          Text("Does this look wrong?", style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            "Tell us the correct title and we'll use it to improve future scans.",
            style: Theme.of(sheetContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g. Sunflowers, Vincent van Gogh'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final correction = controller.text.trim();
                if (correction.isEmpty) return;
                Navigator.of(sheetContext).pop();
                try {
                  await FirebaseFirestore.instance.collection('wrongIdReports').add({
                    'paintingTitle': painting.title,
                    'paintingArtist': painting.artist,
                    'suggestedCorrection': correction,
                    'userId': AuthService.currentUser?.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thanks — we logged your correction.')),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Couldn't submit — please try again.")),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
