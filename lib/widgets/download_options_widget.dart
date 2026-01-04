import 'package:flutter/material.dart';
import '../services/download_options_service.dart';
import '../services/mapy_cz_download_service.dart';
import '../widgets/ui/app_toast.dart';

/// Widget for choosing download options
class DownloadOptionsWidget extends StatefulWidget {
  const DownloadOptionsWidget({super.key});

  @override
  State<DownloadOptionsWidget> createState() => _DownloadOptionsWidgetState();
}

class _DownloadOptionsWidgetState extends State<DownloadOptionsWidget> {
  String _selectedOption = DownloadOptionsService.optionSmall;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentOption();
  }

  Future<void> _loadCurrentOption() async {
    final option = await DownloadOptionsService.getCurrentOption();
    setState(() {
      _selectedOption = option;
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = DownloadOptionsService.getAllOptions();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.download,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vyberte možnost stahování',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Zvolte preferovanou úroveň detailu mapy',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Download options
          ...options.map((option) => _buildOptionCard(option)).toList(),
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Zrušit',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Spustit stahování',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(Map<String, dynamic> option) {
    final isSelected = _selectedOption == _getOptionKey(option);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.05) : Colors.grey.shade50,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedOption = _getOptionKey(option)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Radio button
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4CAF50),
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // Option details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF4CAF50) : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Details grid
                    Row(
                      children: [
                        _buildDetailItem('🗺️', 'Zoom ${option['minZoom']}-${option['maxZoom']}'),
                        const SizedBox(width: 16),
                        _buildDetailItem('⚡', option['estimatedTime']),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildDetailItem('💾', option['estimatedSize']),
                        const SizedBox(width: 16),
                        _buildDetailItem('📊', option['tileCount']),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  String _getOptionKey(Map<String, dynamic> option) {
    if (option['maxZoom'] == 13) return DownloadOptionsService.optionSmall;
    if (option['maxZoom'] == 17) return DownloadOptionsService.optionLarge;
    return DownloadOptionsService.optionSmall;
  }

  Future<void> _startDownload() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await DownloadOptionsService.setDownloadOption(_selectedOption);
      await MapyCzDownloadService.downloadCzechRepublic();
      
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.showSuccess(context, 'Spuštěno ${DownloadOptionsService.getDownloadConfig(_selectedOption)['name']}');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Nepodařilo se spustit stahování: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 