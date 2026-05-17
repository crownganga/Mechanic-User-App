import 'package:flutter/material.dart';

Map<String, dynamic> getServiceStatus(int daysLeft) {
  if (daysLeft <= 4) {
    return {'text': 'Overdue', 'color': Colors.red};
  } else if (daysLeft <= 7) {
    return {'text': 'Service Soon', 'color': Colors.orange};
  } else {
    return {'text': 'Good', 'color': Colors.green};
  }
}
