import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:io';
import '../models/visit_data.dart';
import '../services/visit_data_service.dart';
import '../models/tracking_summary.dart';
import '../services/auth_service.dart';
import '../services/scoring_config_service.dart';
import '../services/form_field_service.dart' hide FormField;
import '../services/form_field_service.dart' as form_service;
import '../models/place_type_config.dart';
import '../services/cloudinary_service.dart';
import '../widgets/image_picker_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/error_recovery_service.dart';
import 'package:image_picker/image_picker.dart';

class VisitDataFormPage extends StatefulWidget {
  final TrackingSummary trackingSummary;
  
  const VisitDataFormPage({
    Key? key,
    required this.trackingSummary,
    this.existingVisit,
  }) : super(key: key);

  final VisitData? existingVisit;

  @override
  State<VisitDataFormPage> createState() => _VisitDataFormPageState();
}

class _VisitDataFormPageState extends State<VisitDataFormPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _dogNameController = TextEditingController(); // Keep for pre-filling
  // Scoring config and dynamic place typing
  ScoringConfig? _scoringConfig;
  bool _loadingScoring = true;
  
  // Dynamic form fields from database
  List<form_service.FormField> _dynamicFormFields = [];
  bool _loadingFormFields = true;
  final Map<String, TextEditingController> _dynamicFieldControllers = {};
  
  // Place type configuration from database
  List<PlaceTypeConfig> _placeTypeConfigs = [];
  bool _loadingPlaceTypes = true;
  
  bool _isSubmitting = false;
  bool _dogNamePreFilled = false;
  List<File> _selectedImages = [];
  final List<_PlaceItem> _places = [];
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    if (widget.existingVisit != null) {
      _dogNameController.text = widget.existingVisit!.dogName ?? '';
      _dogNamePreFilled = true;
    } else {
      _preFillDogName();
    }
    _addDogNameListener();
    _addDogNameListener();
    _loadScoringConfig();
    _loadFormFields();
    
    // Load place types from database
    print('🚀 Initializing place types from database...');
    _loadPlaceTypeConfigs();
  }

  Future<void> _loadScoringConfig() async {
    try {
      final cfg = await ScoringConfigService().getConfig();
      if (mounted) {
        setState(() {
          _scoringConfig = cfg;
          _loadingScoring = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingScoring = false);
    }
  }

  Future<void> _loadFormFields() async {
    try {
      final formFieldService = FormFieldService();
      final fields = await formFieldService.getFormFields();
      if (mounted) {
        setState(() {
          _dynamicFormFields = fields;
          _loadingFormFields = false;
        });
      }
    } catch (e) {
      print('❌ Error loading form fields: $e');
      if (mounted) setState(() => _loadingFormFields = false);
    }
  }

  Future<void> _loadPlaceTypeConfigs() async {
    try {
      print('🔍 Loading place type configs from database...');
      final placeTypeService = PlaceTypeConfigService();
      final configs = await placeTypeService.getPlaceTypeConfigs();
      print('🔍 Successfully loaded ${configs.length} place type configs');
      
      if (mounted) {
        setState(() {
          _placeTypeConfigs = configs;
          _loadingPlaceTypes = false;
          
          if (widget.existingVisit != null && _places.isEmpty) {
             for (final p in widget.existingVisit!.places) {
                final item = _PlaceItem();
                item.nameController.text = p.name;
                item.type = p.type;
                if (p.photos != null) {
                   for (final ph in p.photos!) {
                      if (ph.url.isNotEmpty) {
                         item.existingPhotoUrls.add(ph.url);
                      }
                   }
                }
                _places.add(item);
             }
          }
        });
        print('✅ Place type configs loaded into state: ${configs.length} configs');
      }
    } catch (e) {
      print('❌ Error loading place type configs: $e');
      if (mounted) {
        setState(() {
          _placeTypeConfigs = [];
          _loadingPlaceTypes = false;
        });
        print('❌ Place type configs failed to load - empty list set');
      }
    }
  }

  List<Widget> _buildDynamicFormFields() {
    return _dynamicFormFields.map((field) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildDynamicFormField(field),
      );
    }).toList();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideController.forward();
    _fadeController.forward();
  }

  void _preFillDogName() {
    final user = AuthService.currentUser;
    if (user != null && user.dogName != null && user.dogName!.isNotEmpty) {
      // Pre-fill the dynamic dog_name field when it becomes available
      Future.delayed(const Duration(milliseconds: 100), () {
        final dogNameController = _getControllerForField('dog_name');
        if (dogNameController.text.isEmpty) {
          dogNameController.text = user.dogName!;
          _dogNamePreFilled = true;
          print('🐕 Pre-filled dog name: ${user.dogName}');
        }
      });
    }
  }

  void _addDogNameListener() {
    // Add listener to dynamic dog_name field when it becomes available
    Future.delayed(const Duration(milliseconds: 200), () {
      final dogNameController = _getControllerForField('dog_name');
      dogNameController.addListener(() {
        if (dogNameController.text.isNotEmpty && _dogNamePreFilled) {
          _dogNamePreFilled = false;
          print('🐕 Dog name pre-filled indicator cleared.');
        }
      });
    });
  }

  LatLng _getMapCenter() {
    if (widget.trackingSummary.trackPoints.isEmpty) {
      return const LatLng(49.8175, 15.4730); // Default to Czech Republic center
    }
    
    final points = widget.trackingSummary.trackPoints;
    double totalLat = 0;
    double totalLon = 0;
    
    for (final point in points) {
      totalLat += point.latitude;
      totalLon += point.longitude;
    }
    
    return LatLng(totalLat / points.length, totalLon / points.length);
  }

  double _getMapZoom() {
    if (widget.trackingSummary.trackPoints.length < 2) {
      return 13.0; // Default zoom
    }
    
    // Calculate bounds to determine appropriate zoom
    final points = widget.trackingSummary.trackPoints;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;
    
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLon = min(minLon, point.longitude);
      maxLon = max(maxLon, point.longitude);
    }
    
    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = max(latDiff, lonDiff);
    
    // Adjust zoom based on the extent of the route
    if (maxDiff > 0.1) return 10.0;
    if (maxDiff > 0.05) return 11.0;
    if (maxDiff > 0.01) return 12.0;
    if (maxDiff > 0.005) return 13.0;
    return 14.0;
  }

  @override
  void dispose() {
    _dogNameController.dispose();
    // Dispose dynamic form controllers
    for (final controller in _dynamicFieldControllers.values) {
      controller.dispose();
    }
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showCustomToast(String message, bool isSuccess) {
    // Toast UI disabled per user request.
    return;
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chyba připojení'),
          content: const Text(
            'Nepodařilo se odeslat data o návštěvě. '
            'Zkuste to znovu nebo pokračujte bez ukládání.'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Zrušit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _submitVisitData();
              },
              child: const Text('Zkusit znovu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitVisitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
                  // Upload images first if any are selected
            List<Map<String, dynamic>>? photos;
            if (_selectedImages.isNotEmpty) {
              _showCustomToast('📤 Nahrávám fotografie...', true);

              try {
                final List<String> uploadedUrls = await CloudinaryService.uploadMultipleImages(_selectedImages);

                if (uploadedUrls.isNotEmpty) {
                  photos = uploadedUrls.map((url) => {
                    'url': url,
                    'uploadedAt': DateTime.now().toIso8601String(),
                  }).toList();

                  _showCustomToast('✅ Fotografie úspěšně nahrány!', true);
                } else {
                  _showCustomToast('⚠️ Nepodařilo se nahrát fotografie - pokračuji bez nich', false);
                }
              } catch (e) {
                print('❌ Cloudinary upload failed: $e');
                _showCustomToast('⚠️ Nahrávání fotek selhalo - pokračuji bez nich', false);
                // Continue without photos - the visit data will be saved without photos
                
                // For debugging, you can uncomment this to save local file paths
                // photos = _selectedImages.map((file) => {
                //   return {
                //     'url': 'file://${file.path}',
                //     'uploadedAt': DateTime.now().toIso8601String(),
                //   };
                // }).toList();
                
                // Temporary: Save local file paths for testing
                photos = _selectedImages.map((file) => {
                  'url': 'file://${file.path}',
                  'uploadedAt': DateTime.now().toIso8601String(),
                  'local': true, // Mark as local file
                }).toList();
              }
            }

      final visitDataService = VisitDataService();

      // Get places from places editor only
      final placesFromEditor = _places
          .map((p) => p.nameController.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final combinedPlaces = placesFromEditor.join(', ');

      // Collect dynamic form data - use field.name as key
      final Map<String, dynamic> dynamicFormData = {};
      for (final field in _dynamicFormFields) {
        final controller = _getControllerForField(field.name);
        if (controller.text.isNotEmpty) {
          dynamicFormData[field.name] = controller.text;
        }
      }

      // Use default title and description since these are not in dynamic form anymore
      final routeTitle = 'Trasa ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}';
      final routeDescription = 'GPS trasa';

      // Convert _PlaceItem to Place objects
      final List<Place> finalPlaces = _places.map((placeItem) {
        final newPhotos = placeItem.photos.asMap().entries.map((entry) {
          final index = entry.key;
          final photo = entry.value;
          final description = placeItem.descriptions.length > index 
              ? placeItem.descriptions[index].text 
              : '';
          
          return PlacePhoto(
            id: '${DateTime.now().millisecondsSinceEpoch}_$index',
            url: photo.path, // For now, use local path
            description: description.isNotEmpty ? description : null,
            uploadedAt: DateTime.now(),
            isLocal: true,
          );
        }).toList();

        final existingPhotos = placeItem.existingPhotoUrls.map((url) {
           return PlacePhoto(
             id: '${DateTime.now().millisecondsSinceEpoch}_existing_${url.hashCode}',
             url: url,
             uploadedAt: DateTime.now(),
             isLocal: false,
           );
        }).toList();

        final allPhotos = [...existingPhotos, ...newPhotos];

        return Place(
          id: '${DateTime.now().millisecondsSinceEpoch}_${placeItem.nameController.text}',
          name: placeItem.nameController.text.trim(),
          type: placeItem.type,
          photos: allPhotos,
          description: null,
          createdAt: DateTime.now(),
        );
      }).where((place) => place.name.isNotEmpty).toList();

      bool success = false;

      if (widget.existingVisit != null) {
          // Re-calculate everything to ensure consistency (points, etc.)
          final calculatedVisit = await visitDataService.createVisitDataFromTracking(
            routeTitle: routeTitle,
            routeDescription: routeDescription,
            visitedPlaces: combinedPlaces,
            trackPoints: widget.trackingSummary.trackPoints,
            totalDistance: widget.trackingSummary.totalDistance,
            duration: widget.trackingSummary.duration,
            dogName: dynamicFormData['dog_name'] ?? null,
            dogNotAllowed: dynamicFormData['dog_not_allowed'] ?? null,
            photos: photos,
            places: finalPlaces,
            peaksCount: _places.where((p) => p.type == PlaceType.PEAK).length,
            towersCount: _places.where((p) => p.type == PlaceType.TOWER).length,
            treesCount: _places.where((p) => p.type == PlaceType.TREE).length,
            extraData: dynamicFormData,
          );

          // Merge with existing ID and metadata
          final updatedVisit = calculatedVisit.copyWith(
             id: widget.existingVisit!.id,
             state: widget.existingVisit!.state, // Preserve state
             createdAt: widget.existingVisit!.createdAt,
             userId: widget.existingVisit!.userId,
             user: widget.existingVisit!.user,
             seasonId: widget.existingVisit!.seasonId,
             displayName: widget.existingVisit!.displayName,
          );
          
          success = await visitDataService.updateVisitData(updatedVisit);
      } else {
          // Create new visit
          final visitData = await visitDataService.createVisitDataFromTracking(
            routeTitle: routeTitle,
            routeDescription: routeDescription,
            visitedPlaces: combinedPlaces,
            trackPoints: widget.trackingSummary.trackPoints,
            totalDistance: widget.trackingSummary.totalDistance,
            duration: widget.trackingSummary.duration,
            dogName: dynamicFormData['dog_name'] ?? null,
            dogNotAllowed: dynamicFormData['dog_not_allowed'] ?? null,
            photos: photos,
            places: finalPlaces,
            peaksCount: _places.where((p) => p.type == PlaceType.PEAK).length,
            towersCount: _places.where((p) => p.type == PlaceType.TOWER).length,
            treesCount: _places.where((p) => p.type == PlaceType.TREE).length,
            extraData: dynamicFormData,
          );
          success = await visitDataService.saveVisitData(visitData);
      }

      if (success) {
        if (mounted) {
          _showCustomToast('✅ Data o návštěvě úspěšně uložena!', true);
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          });
        }
      } else {
        if (mounted) {
          _showCustomToast('❌ Nepodařilo se uložit data o návštěvě', false);
          _showRetryDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomToast('❌ Chyba: $e', false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Only show summary if it has some meaningful data (e.g. non-zero duration or distance)
    // or if it was passed from a real tracking session.
    final hasSummary = widget.trackingSummary.totalDistance > 0 || widget.trackingSummary.duration.inMinutes > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Modern light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detaily návštěvy',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _loadingScoring || _loadingFormFields || _loadingPlaceTypes
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100), // Bottom padding for fab/button
                children: [
                  if (hasSummary) ...[
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                  ],

                  _buildSectionHeader(Icons.info_outline, 'Informace o trase'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _cardDecoration(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildDynamicFormFields(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionHeader(Icons.place_outlined, 'Místa a fotky'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: _cardDecoration(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (_places.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(Icons.add_location_alt_outlined, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'Zatím zde nejsou žádná místa',
                                  style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ..._buildPlacesEditor(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitVisitData, // Updated to use the correct method name
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    'Uložit návštěvu',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  Icons.straighten,
                  'Vzdálenost',
                  '${widget.trackingSummary.totalDistance.toStringAsFixed(2)} km',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(
                child: _buildSummaryItem(
                  Icons.timer_outlined,
                  'Doba trvání',
                  _formatDuration(widget.trackingSummary.duration),
                ),
              ),
            ],
          ),
          
          if (_scoringConfig != null) ...[
             const SizedBox(height: 20),
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: const Color(0xFFF1F8E9), // Very light green
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: const Color(0xFFDCEDC8)),
               ),
               child: Column(
                 children: [
                   _buildScoreRow('Body za vzdálenost', _calculateDistancePoints()),
                   const SizedBox(height: 8),
                   _buildScoreRow('Místa (${_formatPlacesCount()})', _calculatePlacesPoints()),
                   const Padding(
                     padding: EdgeInsets.symmetric(vertical: 8),
                     child: Divider(height: 1, color: Color(0xFFAED581)),
                   ),
                   _buildScoreRow('Celkem body', _calculateTotalPoints(), isTotal: true),
                 ],
               ),
             ),
             const SizedBox(height: 12),
             Text(
              'Pro získání bodů je nutné přidat alespoň jedno navštívené místo.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[800],
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreRow(String label, double points, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal ? const Color(0xFF1B5E20) : const Color(0xFF33691E),
          ),
        ),
        Text(
          points.toStringAsFixed(1),
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.w800,
            color: isTotal ? const Color(0xFF1B5E20) : const Color(0xFF33691E),
          ),
        ),
      ],
    );
  }
  
  // Helpers
  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  double _calculateDistancePoints() {
    if (_scoringConfig == null) return 0;
    return (widget.trackingSummary.totalDistance / 1000) * _scoringConfig!.pointsPerKm;
  }
  
  String _formatPlacesCount() {
    return _places.length.toString();
  }
  
  double _calculatePlacesPoints() {
    double total = 0;
    for (var p in _places) {
       final cfg = _placeTypeConfigs.firstWhere((c) => c.name == p.type.name, orElse: () => PlaceTypeConfig(id: '', name: '', label: '', icon: Icons.place, color: Colors.grey, points: 0, isActive: true, order: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
       total += cfg.points;
    }
    return total;
  }
  
  double _calculateTotalPoints() {
    return _calculateDistancePoints() + _calculatePlacesPoints();
  }

  Widget _buildDynamicFormField(form_service.FormField field) {
    if (field.type == 'places') return _buildPlacesFieldInfo(field);

    switch (field.type) {
      case 'text':
      case 'email':
      case 'number':
        return _buildModernTextField(field);
      case 'textarea':
        return _buildModernTextField(field, maxLines: 3);
      case 'select':
        return _buildModernDropdown(field);
      case 'checkbox':
        return _buildModernCheckbox(field);
      case 'date':
        return _buildModernDatePicker(field);
      default:
        return _buildModernTextField(field);
    }
  }

  Widget _buildModernTextField(form_service.FormField field, {int maxLines = 1}) {
    final controller = _getControllerForField(field.name);
    final isNumber = field.type == 'number';
    final isEmail = field.type == 'email';
    
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber 
          ? TextInputType.number 
          : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: field.label,
        labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
        alignLabelWithHint: maxLines > 1,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Icon(_getIconForFieldType(field.type), color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: field.required 
          ? (v) => (v == null || v.trim().isEmpty) ? 'Toto pole je povinné' : null 
          : null,
    );
  }

  Widget _buildModernDropdown(form_service.FormField field) {
    return DropdownButtonFormField<String>(
      value: _getControllerForField(field.name).text.isEmpty 
          ? null 
          : _getControllerForField(field.name).text,
      icon: const Icon(Icons.arrow_drop_down_rounded),
      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827), fontSize: 16),
      decoration: InputDecoration(
        labelText: field.label,
        labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
        prefixIcon: Icon(_getIconForFieldType(field.type), color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
      ),
      items: field.options.map((option) => DropdownMenuItem(
        value: option,
        child: Text(option),
      )).toList(),
      onChanged: (value) {
        if (value != null) _getControllerForField(field.name).text = value;
      },
      validator: field.required ? (v) => v == null ? 'Vyberte hodnotu' : null : null,
    );
  }

  Widget _buildModernCheckbox(form_service.FormField field) {
    final controller = _getControllerForField(field.name);
    final isChecked = controller.text == 'true';
    
    return InkWell(
      onTap: () {
        setState(() {
          controller.text = isChecked ? 'false' : 'true';
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isChecked ? const Color(0xFFF1F8E9) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChecked ? const Color(0xFF2E7D32) : const Color(0xFFF3F4F6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFF2E7D32) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? const Color(0xFF2E7D32) : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isChecked 
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                field.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isChecked ? const Color(0xFF1B5E20) : const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDatePicker(form_service.FormField field) {
    final controller = _getControllerForField(field.name);
    final hasValue = controller.text.isNotEmpty;

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF2E7D32),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF111827),
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          controller.text = date.toIso8601String().split('T')[0];
          setState(() {}); // refresh UI
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: IgnorePointer( // Ignore pointer on TextField so InkWell handles tap
        child: TextFormField(
          controller: controller,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          decoration: InputDecoration(
            labelText: field.label,
            labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
            prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF2E7D32)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF3F4F6), width: 1.5),
            ),
          ),
          validator: field.required ? (v) => (v == null || v.isEmpty) ? 'Zadejte datum' : null : null,
        ),
      ),
    );
  }

  Widget _buildPlacesFieldInfo(form_service.FormField field) {
    // Just an info block saying places are below
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Místa a fotky přidávejte v sekci "Místa a fotky" níže.',
              style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlacesEditor() {
    return [
      ..._places.asMap().entries.map((entry) {
        final idx = entry.key;
        final place = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Delete Button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Místo #${idx + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _removePlace(idx),
                      splashRadius: 20,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Type Chips
                     if (_loadingPlaceTypes)
                        const LinearProgressIndicator(minHeight: 2, color: Color(0xFF2E7D32))
                     else if (_placeTypeConfigs.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _placeTypeConfigs
                              .where((c) => c.isActive)
                              .map((c) => _typeChipFromConfig(idx, c))
                              .toList(),
                        )
                     else
                        const Text('Žádné typy míst k dispozici', style: TextStyle(color: Colors.orange)),
                    
                    const SizedBox(height: 16),
                    
                    // Name Input
                    TextFormField(
                      controller: place.nameController,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Název místa',
                        hintText: 'Např. Vyhlídka Máj',
                        prefixIcon: const Icon(Icons.place_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF3F4F6))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photos
                    InkWell(
                      onTap: () => _addPhotosToPlace(idx),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             const Icon(Icons.add_a_photo_outlined, color: Color(0xFF4B5563)),
                             const SizedBox(width: 8),
                             Text(
                               'Přidat fotky (${place.photos.length + place.existingPhotoUrls.length})',
                               style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                             ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (place.photos.isNotEmpty || place.existingPhotoUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: place.existingPhotoUrls.length + place.photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            Widget imageWidget;
                            if (i < place.existingPhotoUrls.length) {
                              imageWidget = Image.network(place.existingPhotoUrls[i], width: 100, height: 100, fit: BoxFit.cover);
                            } else {
                              imageWidget = Image.file(place.photos[i - place.existingPhotoUrls.length], width: 100, height: 100, fit: BoxFit.cover);
                            }
                            
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  imageWidget,
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          // Optional: Show full screen or edit description
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      
      // Add Place Button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _addPlace,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Přidat další místo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
            foregroundColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
    ];
  }

  void _addPhotosToPlace(int index) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
    if (images.isNotEmpty) {
      setState(() {
         // Create description controllers for new photos
         final newControllers = List.generate(
           images.length, 
           (_) => TextEditingController()
         );
         
         _places[index].photos.addAll(images.map((x) => File(x.path)));
         _places[index].descriptions.addAll(newControllers);
      });
    }
  }

  void _removePlace(int index) {
    if (_places.length > index) {
      setState(() {
        _places.removeAt(index);
      });
    }
  }

  void _addPlace() {
    setState(() {
      _places.add(_PlaceItem());
    });
  }

  Widget _typeChipFromConfig(int idx, PlaceTypeConfig config) {
    final selected = _places[idx].type.name == config.name;
    return ChoiceChip(
      selected: selected,
      onSelected: (val) {
        setState(() {
          _places[idx].type = PlaceType.values.firstWhere(
            (e) => e.name == config.name,
            orElse: () => PlaceType.OTHER,
          );
        });
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 16, color: selected ? Colors.white : Colors.green[700]!),
          const SizedBox(width: 6),
          Text(
            '${config.label}${config.points > 0 ? ' +${config.points.toString()}' : ''}',
            style: TextStyle(
              color: selected ? Colors.white : Colors.green[700]!, 
              fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
      selectedColor: Colors.green[600]!,
      backgroundColor: Colors.green[50]!,
      shape: StadiumBorder(side: BorderSide(color: selected ? Colors.green[600]! : Colors.green[200]!)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  IconData _getIconForFieldType(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'textarea':
        return Icons.description;
      case 'number':
        return Icons.numbers;
      case 'email':
        return Icons.email;
      case 'select':
        return Icons.list;
      case 'checkbox':
        return Icons.check_box;
      case 'date':
        return Icons.calendar_today;
      case 'places':
        return Icons.place;
      default:
        return Icons.input;
    }
  }

  TextEditingController _getControllerForField(String fieldName) {
    if (!_dynamicFieldControllers.containsKey(fieldName)) {
      _dynamicFieldControllers[fieldName] = TextEditingController();
    }
    return _dynamicFieldControllers[fieldName]!;
  }
}

class _PlaceItem {
  final TextEditingController nameController = TextEditingController();
  final List<File> photos = [];
  final List<String> existingPhotoUrls = [];
  final List<TextEditingController> descriptions = [];
  PlaceType type = PlaceType.OTHER;
}
