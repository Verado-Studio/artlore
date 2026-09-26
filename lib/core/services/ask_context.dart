import 'package:flutter/foundation.dart';

import '../mock/mock_paintings.dart';
import '../models/painting.dart';

/// Tracks which painting the persistent bottom-nav "Ask" tab is about.
/// Updated whenever a result page is opened, so that tab reflects whatever
/// painting the user most recently looked at instead of a fixed default.
class AskContext {
  AskContext._();

  static final ValueNotifier<Painting> current = ValueNotifier(MockPaintings.starryNight);
}
