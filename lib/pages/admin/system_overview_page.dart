import 'package:flutter/material.dart';
import '../../services/mongodb_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_toast.dart';
import '../../config/app_colors.dart';

class SystemOverviewPage extends StatefulWidget {
  const SystemOverviewPage({super.key});

  @override
  State<SystemOverviewPage> createState() => _SystemOverviewPageState();
}

class _SystemOverviewPageState extends State<SystemOverviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  Color _connectionColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing...';
      _connectionColor = Colors.orange;
    });

    final isConnected = await MongoDBService.testConnection();

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = isConnected ? 'Connected' : 'Disconnected';
        _connectionColor = isConnected ? Colors.green : Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'System Overview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Database Data'), // Renamed to "Database Data" to imply schema/structure
            Tab(text: 'Endpoints'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildDatabaseSchemaTab(), 
          _buildEndpointsTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Connection Status'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, color: _connectionColor, size: 16),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MongoDB',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]),
                    ),
                    Text(
                      _connectionStatus ?? 'Unknown',
                      style: TextStyle(color: _connectionColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                AppButton(
                  onPressed: _testConnection,
                  text: 'Test',
                  type: AppButtonType.outline,
                  size: AppButtonSize.small,
                  isLoading: _isTestingConnection,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Environment'),
          _buildInfoCard([
            _buildInfoRow('App ID', 'com.strakataturistika.app'),
            _buildInfoRow('Auth User', AuthService.currentUser?.email ?? 'Not Logged In'),
            _buildInfoRow('Role', AuthService.currentUser?.role ?? 'N/A'),
            _buildInfoRow('Dart Version', '3.x'),
          ]),
        ],
      ),
    );
  }

  Widget _buildDatabaseSchemaTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Collections'),
        _buildSchemaCard(
          'User', 
          'Stores user profiles and roles',
          [
            'email (String, Unique)',
            'name (String)',
            'role (Enum: ADMIN, UZIVATEL)',
            'provider (String)',
            'dogName (String?)',
          ],
        ),
        const SizedBox(height: 16),
        _buildSchemaCard(
          'VisitData', 
          'Stores trips and routes',
          [
            'userId (Ref -> User)',
            'state (Enum: APPROVED, PENDING...)',
            'points (Double)',
            'geoJson (Object)',
            'photos (Array)',
            'seasonYear (Int)',
          ],
        ),
        const SizedBox(height: 16),
        _buildSchemaCard(
          'Account', 
          'Stores OAuth links',
          [
            'userId (Ref -> User)',
            'provider (String)',
            'providerAccountId (String)',
          ],
        ),
      ],
    );
  }

  Widget _buildEndpointsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Active Services'),
        _buildEndpointCard('MongoDBService', 'Singleton', 'Direct DB Connection (Atlas)'),
        const SizedBox(height: 12),
        _buildEndpointCard('AuthService', 'Static', 'Google Sign-In, Session Management'),
        const SizedBox(height: 12),
        _buildEndpointCard('VisitDataService', 'Singleton', 'CRUD, Aggregation Pipelines'),
        const SizedBox(height: 12),
        _buildEndpointCard('GpsServices', 'Singleton', 'Location, Sensors, GPX Recording'),
        const SizedBox(height: 12),
        _buildEndpointCard('CloudinaryService', 'Static', 'Image Hosting (Cloudinary API)'),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSchemaCard(String title, String subtitle, List<String> fields) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dataset_rounded, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Fields:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 8),
          ...fields.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.grey),
                const SizedBox(width: 8),
                Text(f, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEndpointCard(String name, String type, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.api_rounded, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}
