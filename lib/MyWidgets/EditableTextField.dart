import 'package:flutter/material.dart';

class EditableTextField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool>? onEditingChanged; // 👈 callback added

  const EditableTextField({
    super.key,
    required this.controller,
    this.onEditingChanged,
  });

  @override
  State<EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<EditableTextField> {
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      // Notify parent about the change
      widget.onEditingChanged?.call(_isEditing);
      // When entering edit mode, select all text
      if (_isEditing) {
        // Delay selection until after build completes
        Future.delayed(Duration(milliseconds: 50), () {
          widget.controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.controller.text.length,
          );
        });
      } else {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _isEditing
            ? SizedBox(
                width: 165, // adjust as needed
                child: TextField(
                  controller: widget.controller,
                  style: TextStyle(fontSize: 16, fontFamily: 'Mulish-Bold'),
                  autofocus: true,
                  onSubmitted: (_) => _toggleEdit(),
                ),
              )
            : Text(
                widget.controller.text,
                style: TextStyle(fontSize: 16, fontFamily: 'Mulish-Bold'),
              ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_isEditing ? Icons.check : Icons.edit),
          onPressed: _toggleEdit,
        ),
      ],
    );
  }
}
