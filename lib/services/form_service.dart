import '../models/forms/form_config.dart';
import 'database/database_service.dart';

class FormService {
  static final FormService _instance = FormService._internal();
  factory FormService() => _instance;
  FormService._internal();

  static const String _collection = 'forms';
  final DatabaseService _dbService = DatabaseService();

  Future<List<FormConfig>> getForms() async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final docs = await collection.find().toList();
      return docs.map((doc) => FormConfig.fromJson(doc)).toList();
    }).catchError((e) {
      print('❌ Error getting forms: $e');
      return <FormConfig>[];
    });
  }

  Future<FormConfig?> getFormBySlug(String slug) async {
    return _dbService.execute((db) async {
      final collection = db.collection(_collection);
      final doc = await collection.findOne({'slug': slug});
      if (doc != null) {
        return FormConfig.fromJson(doc);
      }
      return _getDefaultForm(slug);
    }).catchError((e) {
      print('❌ Error getting form by slug ($slug): $e');
      return _getDefaultForm(slug);
    });
  }

  FormConfig _getDefaultForm(String slug) {
    List<FormStep> steps = [];

    if (slug == 'gpx-upload') {
      steps.add(FormStep(
        id: 'upload',
        label: 'Nahrát trasu',
        order: 0,
        fields: [
          FormFieldWidget(id: 'gpx_picker', type: 'gpx_upload', label: 'GPX soubor', order: 0, required: true),
        ],
      ));
    } else if (slug == 'screenshot-upload') {
       steps.add(FormStep(
        id: 'upload',
        label: 'Nahrát screenshot',
        order: 0,
        fields: [
          FormFieldWidget(id: 'screenshot_picker', type: 'image_upload', label: 'Screenshot trasy', order: 0, required: true),
        ],
      ));
    }

    // Common Edit Step
    steps.add(FormStep(
      id: 'edit',
      label: 'Detaily návštěvy',
      order: steps.length,
      fields: [
        if (slug != 'screenshot-upload')
          FormFieldWidget(id: 'map_preview', type: 'map_preview', label: 'Mapa trasy', order: 0),
        FormFieldWidget(id: 'title_input', type: 'title_input', label: 'Název trasy', order: 1, required: true),
        FormFieldWidget(id: 'description_input', type: 'description_input', label: 'Popis', order: 2),
        FormFieldWidget(id: 'calendar_input', type: 'calendar', label: 'Datum návštěvy', order: 3, required: true),
        FormFieldWidget(id: 'image_uploader', type: 'image_upload', label: 'Fotografie z cesty', order: 4),
        FormFieldWidget(id: 'places_manager', type: 'places_manager', label: 'Navštívená místa', order: 5),
        FormFieldWidget(id: 'dog_switch', type: 'dog_switch', label: 'Vstup se psem zakázán', order: 6),
      ],
    ));

    // Common Finish Step
    steps.add(FormStep(
      id: 'finish',
      label: 'Shrnutí',
      order: steps.length,
      fields: [
        FormFieldWidget(id: 'stats', type: 'route_summary', label: 'Statistiky', order: 0),
      ],
    ));

    return FormConfig(
      slug: slug,
      name: slug == 'gpx-upload' ? 'Nahrát GPX' : (slug == 'screenshot-upload' ? 'Nahrát Screenshot' : 'Uložit trasu'),
      steps: steps,
    );
  }
}
