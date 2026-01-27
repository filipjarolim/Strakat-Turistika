import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';

class DogSwitchWidget extends StatelessWidget {
  final FormFieldWidget field;

  const DogSwitchWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SwitchListTile(
        title: Text(field.label),
        value: formContext.dogNotAllowed,
        onChanged: (value) => formContext.updateField('dogNotAllowed', value),
      ),
    );
  }
}
