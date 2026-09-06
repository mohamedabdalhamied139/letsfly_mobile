import 'package:flutter_test/flutter_test.dart';
import 'package:letsfly_mobile/presentation/table_framework/client_game_adapter.dart';

void main() {
  test('Windows authoritative game registry is complete', () {
    expect(ClientGameRegistry.games.keys, containsAll(<String>[
      'UNO', 'NINETY_NINE', 'THIEF_HUNT', 'FARKLE', 'DOMINO',
      'AMERICAN_DOMINO', 'SCOPA', 'SNAKES_LADDERS', 'TENNIS',
    ]));
    expect(ClientGameRegistry.games.length, 9);
  });

  test('Tennis exposes only the Windows-compatible game actions', () {
    final tennis = ClientGameRegistry.get('TENNIS');
    expect(tennis.actions.map((a) => a.id), containsAll(<String>[
      'position:-1', 'position:1', 'serve',
    ]));
  });
}
