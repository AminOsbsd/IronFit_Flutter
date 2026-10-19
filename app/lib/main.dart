import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const IronFitApp());
}
