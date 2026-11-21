# SwitchYard

A real-time railway switching game for DOS. Trains enter the yard through two entrances, and the player must set the track switches so each train reaches the station matching its letter.

## Overview

SwitchYard is a text-mode puzzle game with four switches, lettered stations (A, B, C, D) and multiple trains on the track at once. Movement is driven by a shared timer-tick interval, and collisions are prevented by a strict cell-claiming rule. The game supports single-player and two-player co-op modes.

## Features

- Fixed track with two entrances, four numbered switches and lettered stations
- Visible indication of each switch's selected route, updated on toggle
- Five or more simultaneous trains, each labelled with its destination
- Collision-free movement using a shared movement interval
- Live score, mistake count and elapsed time
- One-time speed increase at a score threshold
- Single-player and two-player co-op modes
- Win, lose and replay flow with full state reset

## Gameplay

- A train that reaches its matching station scores one point.
- A train that reaches a wrong station counts as one mistake.
- Waiting for another train to clear the track carries no penalty.
- The movement interval is halved once when the score reaches 6 (single-player) or 12 (co-op).
- Win at 10 correct deliveries (single-player) or 20 (co-op). Lose after 5 mistakes.

## Controls

| Mode | Player | Keys | Switches |
|------|--------|------|----------|
| Single-player | Player 1 | 1, 2, 3, 4 | 1 to 4 |
| Co-op | Player 1 | 1, 2 | 1 and 2 |
| Co-op | Player 2 | J, K | 3 and 4 |

In co-op mode, both players share the score and mistake count.

## Build and Run

```
Build and run instructions to be added.
```

## Team

| Name | Role |
|------|------|
| M. Shoaib Ul Hassan | Developer |
| Abdul Ahad | Developer |

## License

Released under the MIT License.
