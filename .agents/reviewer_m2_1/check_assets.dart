import 'dart:io';

void main() {
  final files = [
    // Common
    'assets/audio/player_joined.wav',
    'assets/audio/player_left.wav',
    'assets/audio/turn_start.wav',
    'assets/audio/round_start.wav',
    'assets/audio/round_end.wav',
    'assets/audio/match_win.wav',
    'assets/audio/match_loss.wav',
    'assets/audio/invalid_action.wav',
    'assets/audio/game_stopped.wav',
    'assets/audio/win.wav',
    // Uno
    'assets/audio/uno/draw.wav',
    'assets/audio/uno/draw_two.wav',
    'assets/audio/uno/wild_color.wav',
    'assets/audio/uno/wild_draw_four.wav',
    'assets/audio/uno/skip.wav',
    'assets/audio/uno/reverse.wav',
    'assets/audio/uno/deal.wav',
    'assets/audio/uno/place.wav',
    'assets/audio/uno/place_special.wav',
    'assets/audio/uno/uno_call.wav',
    'assets/audio/uno/uno_penalty.wav',
    'assets/audio/uno/bluff_challenge.wav',
    'assets/audio/uno/wild_color_prompt.wav',
    'assets/audio/uno/shuffle.wav',
    // Farkle
    'assets/audio/farkle/farkle_roll.wav',
    'assets/audio/farkle/farkle_score.wav',
    'assets/audio/farkle/farkle_bank.wav',
    'assets/audio/farkle/farkle_bust.wav',
    'assets/audio/farkle/farkle_hot_dice.wav',
    // Thief
    'assets/audio/thief_hunt/thief_game_start.wav',
    'assets/audio/thief_hunt/thief_escape.wav',
    'assets/audio/thief_hunt/thief_answer_start.wav',
    'assets/audio/thief_hunt/thief_round_end.wav',
    'assets/audio/thief_hunt/thief_caught.wav',
    'assets/audio/thief_hunt/thief_round_winner.wav',
    // Domino
    'assets/audio/domino/domino_place.wav',
    'assets/audio/domino/domino_draw.wav',
    'assets/audio/domino/domino_pass.wav',
    'assets/audio/domino/domino_blocked.wav',
    'assets/audio/domino/domino_win.wav',
    'assets/audio/domino/domino_shuffle.wav',
    'assets/audio/domino/domino_setup.wav',
    'assets/audio/domino/domino_pre_round.wav',
    'assets/audio/domino/domino_round_start.wav',
    'assets/audio/domino/domino_place_original.wav',
    'assets/audio/domino/domino_draw_original.wav',
    // Snakes & Ladders
    'assets/audio/snakes_and_ladders/DICE_ROLL.wav',
    'assets/audio/snakes_and_ladders/LADDER_CLIMB.wav',
    'assets/audio/snakes_and_ladders/SNAKE_BITE.wav',
    'assets/audio/snakes_and_ladders/MYSTERY_BOX.wav',
    'assets/audio/snakes_and_ladders/PLAYER_BUMP.wav',
    'assets/audio/snakes_and_ladders/MATCH_WIN.wav',
    'assets/audio/snakes_and_ladders/FREEZE_TRAP.wav',
    'assets/audio/snakes_and_ladders/BONUS_ROLL.wav',
    'assets/audio/snakes_and_ladders/STEP_MOVE.wav',
    // Scopa
    'assets/audio/scopa/scopa_sweep.wav',
    'assets/audio/scopa/scopa_play.wav',
    'assets/audio/scopa/scopa_deal.wav',
    'assets/audio/scopa/scopa_shuffle.wav',
    'assets/audio/scopa/scopa_capture.wav',
    'assets/audio/scopa/scopa_round_start.wav',
    'assets/audio/scopa/scopa_deal_batch.wav',
    'assets/audio/scopa/scopa_deal_single.wav',
    'assets/audio/scopa/scopa_card_throw.wav',
    'assets/audio/scopa/scopa_eat_cards.wav',
    'assets/audio/scopa/scopa_announcement.wav',
    // Ninety Nine
    'assets/audio/ninety_nine/ninety_nine_draw.wav',
    'assets/audio/ninety_nine/ninety_nine_exceed.wav',
    'assets/audio/ninety_nine/ninety_nine_reach.wav',
    // Tennis SFX
    'assets/audio/tennis/air_left.wav',
    'assets/audio/tennis/air_center.wav',
    'assets/audio/tennis/air_right.wav',
    'assets/audio/tennis/bounce_left.wav',
    'assets/audio/tennis/bounce_center.wav',
    'assets/audio/tennis/bounce_right.wav',
    'assets/audio/tennis/claps_1.wav',
    'assets/audio/tennis/claps_2.wav',
    'assets/audio/tennis/hit_1_left.wav',
    'assets/audio/tennis/hit_1_center.wav',
    'assets/audio/tennis/hit_1_right.wav',
    'assets/audio/tennis/hit_2_left.wav',
    'assets/audio/tennis/hit_2_center.wav',
    'assets/audio/tennis/hit_2_right.wav',
    'assets/audio/tennis/jm_left.wav',
    'assets/audio/tennis/jm_center.wav',
    'assets/audio/tennis/jm_right.wav',
    // Tennis Umpire
    'assets/audio/tennis/arabic_umpire/advantage_receiver.wav',
    'assets/audio/tennis/arabic_umpire/advantage_server.wav',
    'assets/audio/tennis/arabic_umpire/deuce.wav',
    'assets/audio/tennis/arabic_umpire/fault.wav',
    'assets/audio/tennis/arabic_umpire/game_won.wav',
    'assets/audio/tennis/arabic_umpire/match_won.wav',
    'assets/audio/tennis/arabic_umpire/set_won.wav',
    'assets/audio/tennis/arabic_umpire/score_0_15.wav',
    'assets/audio/tennis/arabic_umpire/score_0_30.wav',
    'assets/audio/tennis/arabic_umpire/score_0_40.wav',
    'assets/audio/tennis/arabic_umpire/score_15_0.wav',
    'assets/audio/tennis/arabic_umpire/score_15_30.wav',
    'assets/audio/tennis/arabic_umpire/score_15_40.wav',
    'assets/audio/tennis/arabic_umpire/score_15_all.wav',
    'assets/audio/tennis/arabic_umpire/score_30_0.wav',
    'assets/audio/tennis/arabic_umpire/score_30_15.wav',
    'assets/audio/tennis/arabic_umpire/score_30_40.wav',
    'assets/audio/tennis/arabic_umpire/score_30_all.wav',
    'assets/audio/tennis/arabic_umpire/score_40_0.wav',
    'assets/audio/tennis/arabic_umpire/score_40_15.wav',
    'assets/audio/tennis/arabic_umpire/score_40_30.wav',
  ];

  int missing = 0;
  for (final path in files) {
    final f = File(path);
    if (!f.existsSync()) {
      print('MISSING: $path');
      missing++;
    } else if (f.lengthSync() == 0) {
      print('EMPTY: $path');
      missing++;
    }
  }

  print('Checked ${files.length} assets. Missing/empty: $missing');
  if (missing > 0) exit(1);
}
