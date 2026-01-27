import 'package:flutter/material.dart';
import '../../models/forms/form_config.dart';
import '../../models/forms/form_context.dart';
import '../../services/form_service.dart';
import '../ui/app_button.dart';
import 'form_widget_factory.dart';
import 'package:provider/provider.dart';

class FormRenderer extends StatefulWidget {
  final String slug;
  final Function(FormContext) onSave;

  const FormRenderer({
    Key? key,
    required this.slug,
    required this.onSave,
  }) : super(key: key);

  @override
  State<FormRenderer> createState() => _FormRendererState();
}

class _FormRendererState extends State<FormRenderer> {
  late FormContext _formContext;
  FormConfig? _config;
  int _currentStepIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _formContext = FormContext();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await FormService().getFormBySlug(widget.slug);
    if (mounted) {
      setState(() {
        _config = config;
        _isLoading = false;
      });
    }
  }

  void _nextStep() {
    if (_config == null) return;
    if (_currentStepIndex < _config!.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      widget.onSave(_formContext);
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_config == null) {
      return const Center(child: Text('Nepodařilo se načíst konfiguraci formuláře.'));
    }

    final currentStep = _config!.steps[_currentStepIndex];

    return ChangeNotifierProvider<FormContext>.value(
      value: _formContext,
      child: Scaffold(
        appBar: AppBar(
          title: Text(currentStep.label),
          leading: _currentStepIndex > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _previousStep,
                )
              : null,
        ),
        body: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: currentStep.fields.length,
                itemBuilder: (context, index) {
                  final field = currentStep.fields[index];
                  return FormWidgetFactory.build(field);
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_config == null) return const SizedBox.shrink();
    
    return LinearProgressIndicator(
      value: (_currentStepIndex + 1) / _config!.steps.length,
      backgroundColor: Colors.grey[200],
      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
    );
  }

  Widget _buildBottomNav() {
    final isLastStep = _currentStepIndex == _config!.steps.length - 1;
    
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: AppButton(
        onPressed: _nextStep,
        text: isLastStep ? 'Dokončit' : 'Pokračovat',
        type: AppButtonType.primary,
        size: AppButtonSize.large,
        expand: true,
      ),
    );
  }
}
