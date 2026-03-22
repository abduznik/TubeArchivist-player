import 'package:flutter/material.dart';
import '../../../models/channel.dart';

class ChannelChip extends StatelessWidget {
  final Channel? channel; // Null for "All"
  final bool isSelected;
  final VoidCallback onTap;

  const ChannelChip({
    super.key,
    this.channel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          channel?.name ?? 'All',
          overflow: TextOverflow.visible,
          softWrap: false,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: isSelected ? Colors.white : const Color(0xFF272727),
        side: isSelected 
              ? BorderSide.none 
              : BorderSide(color: Colors.white.withOpacity(0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
