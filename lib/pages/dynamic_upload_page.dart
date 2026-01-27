import 'package:flutter/material.dart';
import '../widgets/forms/form_renderer.dart';
import '../models/forms/form_context.dart';
import '../repositories/visit_repository.dart';
import '../models/visit_data.dart';
import '../services/auth_service.dart';

class DynamicUploadPage extends StatelessWidget {
  final String slug;

  const DynamicUploadPage({Key? key, required this.slug}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormRenderer(
      slug: slug,
      onSave: (formContext) => _handleSave(context, formContext),
    );
  }

  Future<void> _handleSave(BuildContext context, FormContext formContext) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final summary = formContext.trackingSummary;
      if (summary == null) {
        throw Exception('Chybí data o trase. Nahrajte prosím GPX soubor.');
      }

      final currentUser = AuthService.currentUser;
      final visitToSave = VisitData(
        id: '',
        userId: currentUser?.id,
        user: currentUser != null ? {'name': currentUser.name, 'email': currentUser.email, 'image': currentUser.image} : null,
        year: DateTime.now().year,
        visitDate: formContext.visitDate,
        createdAt: DateTime.now(),
        state: VisitState.PENDING_REVIEW,
        points: 0, // In a real app, calculate points based on summary and places
        routeTitle: formContext.routeTitle ?? 'Nová trasa',
        routeDescription: formContext.routeDescription,
        visitedPlaces: formContext.places.map((p) => p.name).join(', '),
        dogName: null, // This would normally come from extraData if mapped
        dogNotAllowed: formContext.dogNotAllowed ? 'true' : null,
        extraData: formContext.extraData,
        photos: formContext.selectedImages.map((f) => {'url': f.path, 'local': true}).toList(),
        route: {
          'duration': summary.duration.inSeconds,
          'totalDistance': summary.totalDistance,
          'trackPoints': summary.trackPoints.map((p) => p.toJson()).toList(),
        },
        places: formContext.places,
        extraPoints: {},
      );

      final success = await VisitRepository().saveVisit(visitToSave);

      // Close loading dialog
      Navigator.pop(context);

      if (success) {
        _showSuccessDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba při ukládání návštěvy.')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba: ${e.toString()}')),
      );
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Úspěch!'),
        content: const Text('Vaše návštěva byla úspěšně uložena k revizi.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
