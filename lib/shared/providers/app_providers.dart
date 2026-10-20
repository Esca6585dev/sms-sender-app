import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sms_sender_app/database.dart' as database;

/// Single backend client shared by every screen.
final apiServiceProvider = Provider<database.ApiService>(
  (ref) => database.ApiService(),
);

/// One message draft shared between the home screen and the groups screen,
/// so the operator types the text once and sends it from either place.
final messageControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});
