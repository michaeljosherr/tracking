import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Focus management system for better keyboard navigation
class FocusManager {
  static final FocusManager _instance = FocusManager._internal();

  factory FocusManager() {
    return _instance;
  }

  FocusManager._internal();

  /// Move focus to next node
  static void moveToNext(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  /// Move focus to previous node
  static void moveToPrevious(BuildContext context) {
    FocusScope.of(context).previousFocus();
  }

  /// Unfocus current focus node
  static void unfocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Request focus for a specific node
  static void requestFocus(BuildContext context, FocusNode node) {
    FocusScope.of(context).requestFocus(node);
  }
}

/// Focus-aware text field with visual indicators
class AccessibleTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool required;
  final int? minLength;
  final bool obscureText;

  const AccessibleTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.required = false,
    this.minLength,
    this.obscureText = false,
  });

  @override
  State<AccessibleTextField> createState() => _AccessibleTextFieldState();
}

class _AccessibleTextFieldState extends State<AccessibleTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  String _buildSemanticLabel() {
    String label = widget.label ?? '';
    if (widget.required) label += ' (required)';
    if (widget.minLength != null) {
      label += ' (minimum ${widget.minLength} characters)';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _buildSemanticLabel(),
      enabled: true,
      textField: true,
      hint: widget.hint,
      child: Focus(
        onKey: (node, event) {
          // Handle Shift+Tab for previous focus, Tab for next focus
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          obscureText: widget.obscureText,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isFocused
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFCBD5E1),
                width: _isFocused ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 2,
              ),
            ),
            suffixText: widget.required ? '*' : null,
          ),
        ),
      ),
    );
  }
}

/// Focus-aware button with visual indicators
class AccessibleButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final bool enabled;
  final FocusNode? focusNode;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<AccessibleButton> createState() => _AccessibleButtonState();
}

class _AccessibleButtonState extends State<AccessibleButton> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? widget.onPressed : null,
      label: widget.label,
      child: Focus(
        focusNode: _focusNode,
        onKey: (node, event) {
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            border: _isFocused
                ? Border.all(
                    color: const Color(0xFF2563EB),
                    width: 3,
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ElevatedButton(
            onPressed: widget.enabled ? widget.onPressed : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Focus management widget that automatically manages focus order
class FocusOrderWidget extends StatelessWidget {
  final List<FocusableItem> items;
  final Widget Function(
    BuildContext context,
    List<FocusableItem> items,
  ) builder;

  const FocusOrderWidget({
    super.key,
    required this.items,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: builder(context, items),
    );
  }
}

/// Data class for focusable items
class FocusableItem {
  final String label;
  final FocusNode focusNode;
  final VoidCallback? onActivate;

  FocusableItem({
    required this.label,
    required this.focusNode,
    this.onActivate,
  });
}

/// Intent-based keyboard shortcuts helper
class KeyboardShortcutsHelper {
  /// Create action for keyboard shortcut
  static Action<ActivateIntent> createActivateAction(
    VoidCallback callback,
  ) {
    return CallbackAction<ActivateIntent>(
      onInvoke: (intent) {
        callback();
        return null;
      },
    );
  }

  /// Bind keyboard shortcut to widget
  static Widget bindShortcut({
    required Widget child,
    required LogicalKeyboardKey key,
    required VoidCallback onPressed,
    bool ctrlRequired = false,
    bool altRequired = false,
    bool shiftRequired = false,
  }) {
    return Focus(
      onKey: (node, event) {
        final isCtrlPressed = event.isControlPressed;
        final isAltPressed = event.isAltPressed;
        final isShiftPressed = event.isShiftPressed;

        final ctrlMatch = !ctrlRequired || isCtrlPressed;
        final altMatch = !altRequired || isAltPressed;
        final shiftMatch = !shiftRequired || isShiftPressed;

        if (ctrlMatch && altMatch && shiftMatch) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
