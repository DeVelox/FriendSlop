# Design

This document describes the design goals, mechanics, and ideas behind FriendSlop. It explains *what the game is* and *why*, not how it's implemented. For implementation details, read the code.

## Game Overview

FriendSlop is an online multiplayer charades game. Designed for teams of 2-3 players taking turns on stage, acting out words through animations (mime) while opposing teams watch and guess. It also supports solo play (teams of 1) for smaller groups. The game is designed for parties and social play — low barrier to entry, high potential for funny moments.

The core loop is simple: a team acts, the other teams guess, points are scored, and the next team takes the stage.

## Core Loop

1. Players form teams in the lobby
2. A word is chosen (from packs added to the lobby)
3. The acting team picks a word from 3 random options
4. A short prep phase lets the acting team choose a stage background
5. The acting team performs — using poses and animations to convey the word
6. Guessing teams type their answer and select from a fuzzy-searched list on screen
7. Points are awarded based on the outcome
8. Once all teams have acted, the stage is complete and a new one begins

## Teams & Stages

The game is structured around **stages**. Each stage is a full cycle where every team takes a turn acting.

- Teams are ideally **2-3 players**, but teams of 1 (solo) are also supported
- During a stage, each team gets one turn on stage while the other teams guess
- A stage is complete once all teams have acted
- After a stage ends, a new stage begins with a fresh cycle

Team formation happens in the lobby before the game starts.

## Word System

### Packs

Words are organized into **packs**. Each pack is a curated list of words tied to a single topic. Examples:

- "Top 100 Movies of All Time"
- "Currently Airing Anime 2026"
- "Classic TV Sitcoms"

Packs are the primary way content is added to the game. The game ships with built-in packs, and players can also create custom packs.

### Selection

Before the game starts, players in the lobby select which packs to include. During a round, the acting team is presented with **3 randomly chosen words** from all selected packs. They pick one to act out.

## Guessing

Guessing is not based on the packs selected in the lobby. Instead, each topic has a **predefined master list** of valid answers — intentionally massive in scope:

- **Movies:** every title on IMDB
- **Anime:** every title on MAL
- **TV:** comprehensive show listings

If a pack contains a word that isn't already in the master list for its topic, it gets added automatically. This ensures custom packs never produce unguessable rounds.

Players guess by **typing the name**. As they type, a **fuzzy-searched list** appears on screen showing matching entries from the master list. The player can either type the full name and submit, or select from the suggestions. This keeps guessing fast while still requiring the guesser to know the answer.

## Scoring

Scoring is intentionally simple and low-numbered:

- **1-3 points** per round, fixed for now
- Totals stay small and easy to understand at a glance
- The exact point breakdown will be refined through playtesting

The goal is a scoring system that feels fair without being complicated. Detailed scoring mechanics are a future consideration.

## Voice & Communication

Voice chat is a key part of the social experience, but with intentional asymmetry:

- **Stage team:** Can talk to each other freely. They need to coordinate — pick the word, plan their act, and communicate during the performance. They can also hear the audience, but faintly — like ambient crowd noise in a theater.
- **Audience:** Can hear each other clearly (to discuss and guess). They **cannot** hear the stage team at all. This keeps the acting team's planning private and prevents the audience from picking up verbal cues.

This creates an interesting dynamic where the stage team has a private channel while the audience has their own.

## The Pose System

The pose system is the core mechanic that makes FriendSlop unique. It turns animation into a creative tool rather than a fixed set of emotes.

### How It Works

Every player has a set of **poses** they can cycle through. Each pose is tied to an animation — standing, walking, jumping, and various action animations.

The key innovation is **freeze**: at any point, a player can press a button (RMB) to freeze their current animation at whatever frame it's on. This lets them:

- Freeze mid-walk to create a stepping pose
- Freeze mid-jump for an airborne pose
- Freeze during an action animation to capture a specific gesture
- Combine frozen poses with movement to "hold" a pose while sliding across the stage

### Creative Freedom

This system gives players a large vocabulary of visual expressions from a relatively small set of animations:

- **Default stand** = neutral pose
- **Walk** = movement animation, but can be frozen at any frame for custom poses
- **Jump** = airborne animation, freezeable
- **Action animations** = gestures and movements, each with multiple usable frames

Players can switch poses at any time (pressing a pose key or unfreezing with RMB). The result is a system where creative players can craft surprisingly expressive performances from simple building blocks.

## Stage Prep

After choosing a word, the acting team gets a short preparation phase before the round begins:

- They can select a **background** from a predefined list
- Backgrounds are **cosmetic only** — they set the scene visually but don't affect gameplay
- This gives the team a moment to plan their approach before the timer starts

## Topics

The game focuses on three topic categories:

- **TV** — sitcoms, dramas, reality shows, iconic scenes
- **Movies** — blockbuster moments, famous scenes, character impressions
- **Anime** — popular series, memorable moments, character poses

These topics are not final. The pack system is designed to be easily expandable — new topics, niche categories, and seasonal content can all be added as new packs without changing the core game.
