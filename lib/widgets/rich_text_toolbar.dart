import 'package:flutter/material.dart';
import 'dart:ui';

class RichTextToolbar extends StatelessWidget {
  final Function(String) onAction;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const RichTextToolbar({
    super.key,
    required this.onAction,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ToolbarButton(label: 'H1', onTap: () => onAction('# ')),
                      _ToolbarButton(label: 'H2', onTap: () => onAction('## ')),
                      _ToolbarButton(
                        label: 'Normal',
                        onTap: () => onAction(''),
                      ),
                      const VerticalDivider(width: 1),
                      _ToolbarAction(
                        icon: Icons.format_bold,
                        onTap: () => onAction('**'),
                      ),
                      _ToolbarAction(
                        icon: Icons.format_italic,
                        onTap: () => onAction('*'),
                      ),
                      _ToolbarAction(
                        icon: Icons.format_underlined,
                        onTap: () => onAction('__'),
                      ),
                      _ToolbarAction(
                        icon: Icons.format_strikethrough,
                        onTap: () => onAction('~~'),
                      ),
                      const VerticalDivider(width: 1),
                      _ToolbarAction(icon: Icons.undo, onTap: onUndo),
                      _ToolbarAction(icon: Icons.redo, onTap: onRedo),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ToolbarAction(
                        icon: Icons.format_align_left,
                        onTap: () => onAction('[:left:]'),
                      ),
                      _ToolbarAction(
                        icon: Icons.format_align_center,
                        onTap: () => onAction('[:center:]'),
                      ),
                      _ToolbarAction(
                        icon: Icons.format_align_right,
                        onTap: () => onAction('[:right:]'),
                      ),
                      const VerticalDivider(width: 1),
                      _ToolbarAction(
                        icon: Icons.link,
                        onTap: () => onAction('[link text](url)'),
                      ),
                      _ToolbarAction(
                        icon: Icons.image_outlined,
                        onTap: () => onAction('![alt](url)'),
                      ),
                      _ToolbarAction(
                        icon: Icons.subscript,
                        onTap: () => onAction('~sub~'),
                      ),
                      _ToolbarAction(
                        icon: Icons.superscript,
                        onTap: () => onAction('^sup^'),
                      ),
                      const VerticalDivider(width: 1),
                      _ToolbarAction(
                        icon: Icons.palette_outlined,
                        onTap: () {},
                      ),
                      _ToolbarAction(
                        icon: Icons.format_color_fill,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ToolbarAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: canRequestFocus: false prevents the button from
    // stealing focus from the TextField, keeping the keyboard open.
    return IconButton(
      icon: Icon(icon, color: Colors.indigo.shade700, size: 20),
      onPressed: onTap,
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
      focusNode: FocusNode(canRequestFocus: false),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      focusNode: FocusNode(canRequestFocus: false),
      style: TextButton.styleFrom(
        foregroundColor: Colors.indigo.shade700,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        minimumSize: const Size(45, 40),
      ),
      child: Text(label),
    );
  }
}
