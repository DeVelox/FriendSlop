# Design

Gameplay design document for FriendSlop. This file describes *what the game does* and *why*. For implementation details, read the code directly.

## Lobby Flow

1. Player launches game -> `Steamworks` autoload initializes Steam
2. Player sees lobby manager with Host / Join / Exit buttons
3. **Host:** Clicks Host -> `lobby_host` creates a Steam lobby (visibility, max players)
4. **Client:** Clicks Join -> `lobby_join` browses lobby list (distance filter, search, open slots), picks one to join
5. Both see lobby scene: player list, Invite button (Steam overlay), chat, Leave
6. **Host configures round settings** (e.g. round time)
7. Host presses Start -> `SteamMultiplayerPeer.host_with_lobby(lobby_id)` -> scene changes to `main_stage.tscn`
8. Client connects via `SteamMultiplayerPeer.connect_to_lobby(lobby_id)` -> waits for `connected_to_server` signal -> same scene change
9. Host can invite friends anytime via Steam overlay (`activateGameOverlayInviteDialog`)
10. Supports `+connect_lobby <id>` command-line arg for Steam overlay join invites

## Player Controller

The controller is a **third/second person hybrid** designed around emote-based gameplay, not free-roaming movement. It is an enabler for the emote system.

- **Actor:** Can move freely within the stage area. Cannot leave the stage. Primary interaction is triggering emotes to act out words.
- **Audience:** Seated in fixed positions between the camera and stage. Cannot move. Primary interaction is triggering reaction emotes (clapping, throwing tomatoes, etc.).

The current prototype is based on a first-person prototyping controller (Brackeys' ProtoController) and needs to be reworked to match the intended third/second person hybrid design with restricted movement.

## Emotes

The core gameplay mechanic. Both actor and audience use emotes.

- **Actor:** Full range of emotes — gestures, poses, movements for acting out words. The actor cycles through emotes to convey the prompt.
- **Audience:** Limited reaction emotes — clapping, throwing tomatoes, facepalms, etc. Cosmetic/social only, no gameplay impact.

**Current implementation:** Placeholder emotes using the AnimatedHuman model's built-in animations. Walk and jump animations are used automatically during movement. The remaining animations are bound to number row keys (1-4) as emotes. These will be replaced with proper emote animations when provided.

Movement animations (automatic):
- **Walk** — plays when the actor is moving on the ground
- **Jump** — plays when any player jumps

## Round System

- **Turn selection:** Exhaustive pool. All players take a turn as the actor. Once everyone has acted, the pool resets. Server picks the next actor randomly from the remaining pool.
- **Round duration:** Timed. The round time is **configurable by the host during lobby setup**. Server-authoritative countdown.
- **Prompt source:** Built-in word bank (see Word Bank below). Random selection, no repeats within a session.
- **Input gating:** Player inputs (emotes, movement) are locked during ACTOR_READY (prep time) and ROUND_END states, and unlocked during IN_ROUND. This prevents actors from starting early and ensures clean transitions. Animations are reset to Idle at the start of each round.

## Word Bank

Built-in list of charade prompts. Randomly selected for each round, no repeats within a session. Shown only to the actor (not the audience). See `scripts/round_manager.gd` for the full prompt list.

**Categories:**
- Gaming (10 prompts): Mario, Link, Pac-Man, Angry Birds, Minecraft, Tetris, Sonic, Street Fighter, Portal, Guitar Hero
- Movies / TV Shows (10 prompts): The Matrix, Jurassic Park, Titanic, Lord of the Rings, Star Wars, Friends, The Office, Breaking Bad, The Lion King, Harry Potter

## Voice Chat & Guessing

Voice chat uses **Steam Voice** (`Steam` singleton voice APIs). The actor cannot speak during their turn — their mic is muted server-side. Audience members guess by speaking; a **speaking indicator** shows who is currently talking. The actor clicks on a player's avatar to declare the winner.

Key Steam Voice APIs (reference: https://godotsteam.com/tutorials/voice/):
- `Steam.startVoiceRecording()` / `Steam.stopVoiceRecording()` — toggle mic capture
- `Steam.getVoice()` — grab compressed voice buffer
- `Steam.decompressVoice(buffer, sample_rate)` — decode for playback
- `Steam.getVoiceOptimalSampleRate()` — get Steam's recommended sample rate
- `Steam.setInGameVoiceSpeaking(steam_id, is_speaking)` — suppress Steam client audio while in-game
- Voice data is sent to other peers via RPCs (`process_voice_data.rpc(buffer)`)
- Playback uses `AudioStreamGenerator` + `AudioStreamGeneratorPlayback` with a buffer of `PackedVector2Array` frames

GodotSteamKit also provides a voice custom node that may contain reusable functionality.

## Stage Layout

- **Actor:** Spawns under the spotlight on the stage platform at `(0, 1, 30)`, facing the fixed camera.
- **Audience:** Spawns evenly distributed between the camera and the stage (z=15 to z=25, 11 slots with sinusoidal x-spread).

## Camera

Single fixed camera for the entire game. Located on `CameraMount` at position `(-20, 18, 10)`, FOV ~35 degrees, pointed at the spotlight/stage area. The audience is visible in the lower portion of the frame.

## Scoring

Not yet implemented. Current approach: the actor declares the winner each round. A simple rounds-won tally tracks overall standings. Team-based scoring is a future possibility.
