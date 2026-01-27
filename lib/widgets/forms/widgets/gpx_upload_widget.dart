import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';
import '../../../models/tracking_summary.dart';

class GpxUploadWidget extends StatefulWidget {
  final FormFieldWidget field;

  const GpxUploadWidget({Key? key, required this.field}) : super(key: key);

  @override
  State<GpxUploadWidget> createState() => _GpxUploadWidgetState();
}

class _GpxUploadWidgetState extends State<GpxUploadWidget> {
  bool _isFileselected = false;
  String? _fileName;

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.upload_file, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            widget.field.label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isFileselected ? 'Vybráno: $_fileName' : 'Vyberte GPX soubor s vaší trasou',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _pickGpxFile(formContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(_isFileselected ? 'Změnit soubor' : 'Vybrat soubor'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickGpxFile(FormContext formContext) async {
    // In a real app, use file_picker package:
    // FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gpx']);
    
    // Mock parsing for demonstration
    setState(() {
      _isFileselected = true;
      _fileName = 'moje_trasa.gpx';
    });

    // Create a mock tracking summary
    final mockPoints = [
      TrackPoint(latitude: 50.0755, longitude: 14.4378, timestamp: DateTime.now(), speed: 5.0, accuracy: 10.0),
      TrackPoint(latitude: 50.0760, longitude: 14.4385, timestamp: DateTime.now(), speed: 5.2, accuracy: 10.0),
      TrackPoint(latitude: 50.0765, longitude: 14.4390, timestamp: DateTime.now(), speed: 4.8, accuracy: 10.0),
    ];

    final summary = TrackingSummary(
      isTracking: false,
      startTime: DateTime.now().subtract(const Duration(hours: 2)),
      duration: const Duration(hours: 2),
      totalDistance: 5.4,
      averageSpeed: 2.7,
      maxSpeed: 6.0,
      totalElevationGain: 120,
      totalElevationLoss: 110,
      minAltitude: 200,
      maxAltitude: 320,
      trackPoints: mockPoints,
    );

    formContext.setTrackingSummary(summary);
    formContext.updateField('routeTitle', 'Trasa z ${_fileName}');
  }
}
