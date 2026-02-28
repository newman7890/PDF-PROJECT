import 'package:flutter/material.dart';

class RichTextToolbar extends StatelessWidget {
  final VoidCallback onBoldToggle;
  final VoidCallback onItalicToggle;
  final Function(double) onFontSizeChange;
  final Function(Color) onColorChange;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const RichTextToolbar({
    super.key,
    required this.onBoldToggle,
    required this.onItalicToggle,
    required this.onFontSizeChange,
    required this.onColorChange,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ColorFilter.mode(Colors.white.withValues(alpha: 0.8), BlendMode.lighten),
        child: Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ToolbarAction(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            onTap: onBoldToggle,
          ),
          _ToolbarAction(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            onTap: onItalicToggle,
          ),
          _ToolbarAction(
            icon: Icons.format_size,
            tooltip: 'Font Size',
            onTap: () {
              // Quick font size picker shim
              onFontSizeChange(20.0);
            },
          ),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12),
          _ToolbarAction(
            icon: Icons.palette_outlined,
            tooltip: 'Text Color',
            onTap: () => onColorChange(Colors.red),
          ),
          _ToolbarAction(
            icon: Icons.format_align_left,
            tooltip: 'Align Left',
            onTap: () {},
          ),
          _ToolbarAction(
            icon: Icons.format_align_center,
            tooltip: 'Align Center',
            onTap: () {},
          ),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12),
          _ToolbarAction(icon: Icons.undo, tooltip: 'Undo', onTap: onUndo),
          _ToolbarAction(icon: Icons.redo, tooltip: 'Redo', onTap: onRedo),
          _ToolbarAction(
            icon: Icons.image_outlined,
            tooltip: 'Insert Image',
            onTap: () {},
          ),
        ],
        ),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.indigo.shade700, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}
