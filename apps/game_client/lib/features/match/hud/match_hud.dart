import 'package:flutter/material.dart';
import 'package:game_client/features/match/hud/hud_ticker.dart';
import 'package:game_client/features/match/input/touch_input.dart';
import 'package:game_client/features/match/render/palette.dart';
import 'package:game_client/features/match/session/local_match.dart';
import 'package:game_core/game_core.dart';

/// Flutter overlay on top of the Flame canvas. Reads match state, owns none.
class MatchHud extends StatelessWidget {
  const MatchHud({
    required this.match,
    required this.ticker,
    required this.touch,
    required this.onExit,
    super.key,
  });

  final LocalMatch match;
  final HudTicker ticker;
  final TouchInput touch;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListenableBuilder(
          listenable: ticker,
          builder: (context, _) {
            final me = match.curr.players[LocalMatch.localId];
            if (me == null) return const SizedBox.shrink();
            final cls = match.config.classOf(me.classId);
            return Stack(
              children: [
                Positioned(
                  left: 8,
                  top: 8,
                  child: _VitalsPanel(
                    me: me,
                    cls: cls,
                    onExit: onExit,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _SidePanel(match: match),
                ),
                if (!me.alive)
                  Center(
                    child: Text(
                      'Respawning in '
                      '${((me.respawnTick - match.curr.tick) / kSimHz).ceil()}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _AbilityButtons(me: me, cls: cls, touch: touch),
                ),
              ],
            );
          },
        ),
      );
}

class _VitalsPanel extends StatelessWidget {
  const _VitalsPanel({
    required this.me,
    required this.cls,
    required this.onExit,
  });

  final PlayerState me;
  final ClassDef cls;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final frac = (me.hp / cls.maxHp).clamp(0.0, 1.0);
    final shield = me.statusMag[EffectType.shield.index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onExit,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to menu',
            ),
            Text(
              cls.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: classAccent(cls.id),
              ),
            ),
          ],
        ),
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 12,
              backgroundColor: Colors.black54,
              color: Color.lerp(Colors.redAccent, Colors.greenAccent, frac),
            ),
          ),
        ),
        Text(
          '${me.hp}/${cls.maxHp}'
          '${shield > 0 ? '  +$shield shield' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.match});

  final LocalMatch match;

  @override
  Widget build(BuildContext context) {
    final me = match.curr.players[LocalMatch.localId]!;
    final training = match.mode == MatchMode.training;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Kills ${me.kills}   Deaths ${me.deaths}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final k in match.killFeed.reversed.take(4))
          Text(
            '${match.nameOf(k.killerId)} defeated ${match.nameOf(k.victimId)}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        if (training) ...[
          const SizedBox(height: 8),
          Text(
            'DPS ${match.dps.dps(match.curr.tick).toStringAsFixed(1)}   '
            'total ${match.dps.total}',
            style: const TextStyle(
              color: Color(0xFFFFEE58),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: match.spawnDummy,
                child: const Text('Spawn dummy'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: match.clearDummies,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AbilityButtons extends StatelessWidget {
  const _AbilityButtons({
    required this.me,
    required this.cls,
    required this.touch,
  });

  final PlayerState me;
  final ClassDef cls;
  final TouchInput touch;

  @override
  Widget build(BuildContext context) {
    AbilityButton button(int bit, String label, int cooldown, int total,
        {double size = 56}) {
      return AbilityButton(
        label: label,
        fraction: total <= 0 ? 0 : (cooldown / total).clamp(0.0, 1.0),
        size: size,
        color: classAccent(cls.id),
        onDown: () {
          touch
            ..press(bit)
            ..setHeld(bit, down: true);
        },
        onUp: () => touch.setHeld(bit, down: false),
      );
    }

    int total(int slot) =>
        slot < cls.abilities.length ? cls.abilities[slot].cooldownTicks : 0;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        button(
          kBtnDash,
          'Dash',
          me.cooldowns[kDashSlot],
          cls.dashCooldownTicks,
        ),
        button(kBtnAbility1, 'Q', me.cooldowns[1], total(1)),
        button(kBtnAbility2, 'E', me.cooldowns[2], total(2)),
        button(kBtnAttack, 'Atk', me.cooldowns[0], total(0), size: 76),
      ],
    );
  }
}

/// Round button with a cooldown sweep. Reports press and release so channels
/// can be held.
class AbilityButton extends StatelessWidget {
  const AbilityButton({
    required this.label,
    required this.fraction,
    required this.size,
    required this.color,
    required this.onDown,
    required this.onUp,
    super.key,
  });

  final String label;

  /// 1 = just used, 0 = ready.
  final double fraction;
  final double size;
  final Color color;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fraction > 0
                      ? Colors.black54
                      : color.withValues(alpha: 0.35),
                  border: Border.all(color: color, width: 2),
                ),
              ),
              if (fraction > 0)
                SizedBox(
                  width: size - 6,
                  height: size - 6,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 4,
                    color: Colors.white54,
                  ),
                ),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
}
