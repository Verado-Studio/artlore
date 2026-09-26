import 'auth_service.dart';

/// One message in a painting's Q&A conversation.
class ChatTurn {
  const ChatTurn(this.text, this.fromUser);
  final String text;
  final bool fromUser;
}

/// In-memory conversation history keyed by (account, painting title), shared
/// by every [AskPage] instance — the one pushed from a result page and the
/// persistent bottom-nav tab. Without this, each pushed route got its own
/// throwaway state, so asking about a painting from its result page and
/// later checking the Ask tab showed nothing.
///
/// Keyed per signed-in account (falling back to a single shared "guest"
/// bucket, same as the rest of the app's local-only guest data) so one
/// account never sees another account's conversations within the same app
/// session — e.g. after signing out and a different account signing in.
class PaintingChatStore {
  PaintingChatStore._();

  static final Map<String, List<ChatTurn>> _history = {};
  static final Map<String, String> _lastInteractionId = {};

  static String get _scope => AuthService.currentUser?.uid ?? 'guest';

  static String _key(String title) => '$_scope::$title';

  static List<ChatTurn> historyFor(String title) => List.unmodifiable(_history[_key(title)] ?? const []);

  static String? interactionIdFor(String title) => _lastInteractionId[_key(title)];

  static void append(String title, ChatTurn turn) {
    _history.putIfAbsent(_key(title), () => []).add(turn);
  }

  static void setInteractionId(String title, String id) {
    _lastInteractionId[_key(title)] = id;
  }
}
