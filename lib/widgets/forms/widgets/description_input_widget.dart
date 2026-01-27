import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/forms/form_config.dart';
import '../../../models/forms/form_context.dart';

class DescriptionInputWidget extends StatelessWidget {
  final FormFieldWidget field;

  const DescriptionInputWidget({Key? key, required this.field}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formContext = Provider.of<FormContext>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: formContext.routeDescription,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => formContext.updateField('routeDescription', value),
        validator: field.required ? (value) => (value == null || value.isEmpty) ? 'Povinné pole' : null : null,
      ),
    );
  }
}
