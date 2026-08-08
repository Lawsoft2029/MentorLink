import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double starSize;

  const StarRatingWidget({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.starSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Renders 5 star icons based on rating value
        Row(
          children: List.generate(5, (index) {
            IconData iconData = Icons.star;
            Color color = Colors.amber;

            if (index >= rating) {
              if (index < rating + 0.5 && index > rating) {
                iconData = Icons.star_half;
              } else {
                iconData = Icons.star_border;
                color = Colors.grey.shade400;
              }
            }
            return Icon(iconData, size: starSize, color: color);
          }),
        ),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: starSize * 0.9),
        ),
        const SizedBox(width: 4),
        Text(
          "($reviewCount)",
          style: TextStyle(color: Colors.grey.shade600, fontSize: starSize * 0.8),
        ),
      ],
    );
  }
}