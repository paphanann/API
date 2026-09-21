import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/models.dart';

class ChannelDot extends StatelessWidget {
  const ChannelDot({super.key, required this.channel, this.size = 22});

  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = channel == Channel.tiktok ? Pal.tiktokHi : Colors.white;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: channel.color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        channel.mark,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.48, height: 1),
      ),
    );
  }
}

class ChannelLabel extends StatelessWidget {
  const ChannelLabel({super.key, required this.channel, this.maxLabelWidth = 110});

  final Channel channel;
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChannelDot(channel: channel, size: 20),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxLabelWidth),
          child: Text(
            channel.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: channel.color),
          ),
        ),
      ],
    );
  }
}
