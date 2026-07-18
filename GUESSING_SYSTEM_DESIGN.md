# Guessing System Design

## Overview

This document describes the design for the Guessing System integration into FriendSlop. The system consists of three core concepts: **Topics**, **Guessing Lists**, and **Guessing Packs**.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Data extraction | Pre-extract to JSON | Ship with game, faster load times |
| Custom topics | Fully customizable | Players can create new topics |
| Initial data | Sample lists for now | Extract proper lists later |
| Storage location | `res://data/` for defaults | Ship with build, read-only |
| Lobby UI | Show selections + host button | Clean separation, host-only editing |

---

## Core Concepts

### Topics

Topics are categories that group related content. They are shown to the audience and limit what can be guessed.

**Default Topics:**
1. **Movies** - Movie titles
2. **TV** - TV show titles (one entry per show, not per season)
3. **Anime** - Anime titles

**Custom Topics:** Players can create new topics (e.g., "Video Games", "Books", "Music")

**Properties:**
```gdscript
class Topic:
    var id: String           # Unique identifier (e.g., "movies", "tv", "anime")
    var name: String         # Display name (e.g., "Movies")
    var is_default: bool     # True for built-in topics (not editable)
    var created_by: String   # Steam ID of creator (empty for defaults)
```

---

### Guessing Lists

Guessing Lists are the **full list of valid answers** an audience member can guess from. These are comprehensive lists.

**Default Guessing Lists (initially sample data):**
1. **Movies** - Sample movie titles (expandable to full IMDB later)
2. **TV** - Sample TV show titles
3. **Anime** - Sample anime titles

**Properties:**
```gdscript
class GuessingList:
    var id: String           # Unique identifier
    var name: String         # Display name (e.g., "Sample Movies")
    var topic_id: String     # Associated topic
    var is_default: bool     # True for built-in lists (not editable)
    var is_enabled: bool     # Whether this list is active for guessing
    var created_by: String   # Steam ID of creator
    var file_path: String    # Path to data file
```

**Behavior:**
- Default lists are **read-only** - cannot be edited
- Users can **copy** a default list to create their own editable version
- Users can **create** custom lists from scratch
- Lists can be **enabled/disabled** in lobby settings
- When loading into game, enabled lists are loaded and **deduplicated**
- Guessing only searches the **relevant topic's** enabled lists

---

### Guessing Packs

Guessing Packs are **curated, limited word lists** that performers choose from when acting. They are typically themed.

**Examples:**
- "Top 100 Movies All Time"
- "90s Sitcoms"
- "Shonen Anime Classics"

**Properties:**
```gdscript
class GuessingPack:
    var id: String           # Unique identifier
    var name: String         # Display name
    var topic_id: String     # Associated topic
    var is_default: bool     # True for built-in packs
    var is_enabled: bool     # Whether this pack is active
    var created_by: String   # Steam ID of creator
    var file_path: String    # Path to data file
    var entries: Array[String]  # The words/prompts in this pack
```

**Behavior:**
- Default packs are **read-only** - cannot be edited
- Users can **copy** a default pack to create their own
- Users can **create** custom packs from scratch
- Players in lobby are **not told** which pack a guess is from
- If **multiple packs** are selected, they are **deduped and combined**
- If a pack contains entries **not in the enabled guessing lists**, those entries are **automatically added** to the guessing list for that topic

---

## Data Storage

### File Format: JSON

**Rationale:**
1. **Godot native support** - `JSON.parse_string()` and `JSON.stringify()` built-in
2. **Human-readable** - Easy to inspect and debug
3. **Flexible** - Supports nested structures
4. **No external dependencies** - Works on all platforms

### File Structure

```
FriendSlop/
├── data/                              # Default data (ships with game)
│   ├── AGENTS.md
│   ├── topics.json                    # Topic definitions
│   ├── lists/                         # Guessing lists (sample data)
│   │   ├── movies_sample.json
│   │   ├── tv_sample.json
│   │   └── anime_sample.json
│   └── packs/                         # Default packs
│       ├── top_100_movies.json
│       ├── classic_sitcoms.json
│       └── shonen_anime.json

user://guessing/                       # User data (runtime)
├── topics.json                        # Custom topics
├── lists/                             # Custom lists
└── packs/                             # Custom packs
```

### Topics File Format (`data/topics.json`)

```json
{
  "version": 1,
  "topics": [
    {
      "id": "movies",
      "name": "Movies",
      "is_default": true,
      "created_by": ""
    },
    {
      "id": "tv",
      "name": "TV Shows",
      "is_default": true,
      "created_by": ""
    },
    {
      "id": "anime",
      "name": "Anime",
      "is_default": true,
      "created_by": ""
    }
  ]
}
```

### Guessing List File Format

```json
{
  "version": 1,
  "metadata": {
    "id": "movies_sample",
    "name": "Sample Movies",
    "topic_id": "movies",
    "is_default": true,
    "created_by": ""
  },
  "entries": [
    "The Shawshank Redemption",
    "The Godfather",
    "The Dark Knight"
  ]
}
```

### Guessing Pack File Format

```json
{
  "version": 1,
  "metadata": {
    "id": "top_100_movies",
    "name": "Top 100 Movies All Time",
    "topic_id": "movies",
    "is_default": true,
    "created_by": ""
  },
  "entries": [
    "The Shawshank Redemption",
    "The Godfather",
    "The Dark Knight"
  ]
}
```

---

## Lobby Integration

### Lobby Display (All Players)

The lobby shows current selections and allows the host to access settings:

```
┌─────────────────────────────────────────────────────────┐
│ [Username]'s Lobby                                      │
├─────────────────────────────────────────────────────────┤
│ Players:                                                │
│   • Player1 (Host)                                      │
│   • Player2                                             │
│   • Player3                                             │
│                                                         │
│ Current Settings:                                       │
│   Topics: Movies, TV Shows, Anime                       │
│   Lists: 3 enabled (Sample Movies, TV, Anime)           │
│   Packs: 2 enabled (Top 100 Movies, Shonen Anime)      │
│                                                         │
│ [Game Settings]  ← Host only button                    │
│                                                         │
│ [Chat]                                                  │
│ [Invite]  [Leave]  [Start]                              │
└─────────────────────────────────────────────────────────┘
```

### Game Settings Panel (Host Only)

Clicking "Game Settings" opens an interactive panel:

```
┌─────────────────────────────────────────────────────────┐
│ Game Settings                                    [X]    │
├─────────────────────────────────────────────────────────┤
│ Topics                                                  │
│ ☑ Movies    ☑ TV Shows    ☑ Anime    [+ Add Topic]     │
│                                                         │
│ Guessing Lists                                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Movies                                              │ │
│ │   ☑ Sample Movies (50 entries)                      │ │
│ │   [Copy] [Edit] [Create New]                        │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ TV Shows                                            │ │
│ │   ☑ Sample TV Shows (40 entries)                    │ │
│ │   [Copy] [Edit] [Create New]                        │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ Anime                                               │ │
│ │   ☑ Sample Anime (30 entries)                       │ │
│ │   [Copy] [Edit] [Create New]                        │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ Guessing Packs                                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ☑ Top 100 Movies All Time (Movies)                 │ │
│ │ ☑ Shonen Anime Classics (Anime)                    │ │
│ │ ☐ Classic Sitcoms (TV Shows)                       │ │
│ │ [Copy] [Edit] [Create New]                         │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ [Save Settings]  [Cancel]                               │
└─────────────────────────────────────────────────────────┘
```

---

## Game Flow Integration

### 1. Lobby Phase (Before Game Start)

```
┌─────────────────────────────────────────────────────────┐
│ LOBBY STATE                                             │
├─────────────────────────────────────────────────────────┤
│ 1. Host configures:                                     │
│    - Which topics are enabled                           │
│    - Which guessing lists are enabled per topic         │
│    - Which guessing packs are enabled                   │
│                                                         │
│ 2. Host can:                                            │
│    - Create/edit custom packs                           │
│    - Copy default packs/lists                           │
│    - Enable/disable lists and packs                     │
│                                                         │
│ 3. When host clicks "Start Game":                       │
│    - Load enabled guessing lists                        │
│    - Load enabled guessing packs                        │
│    - Combine and deduplicate                            │
│    - Auto-add pack entries not in lists                 │
│    - Sync final configuration to all clients            │
└─────────────────────────────────────────────────────────┘
```

### 2. Game Start (Server Loads Data)

```gdscript
# server-side initialization
func _initialize_guessing_data() -> void:
    # 1. Load enabled topics
    var topics: Array[Dictionary] = _load_enabled_topics()
    
    # 2. For each topic, load enabled guessing lists
    for topic in topics:
        var list_entries: Array[String] = _load_guessing_lists(topic.id)
        
        # 3. Load enabled packs for this topic
        var pack_entries: Array[String] = _load_guessing_packs(topic.id)
        
        # 4. Auto-add pack entries not in lists
        for entry in pack_entries:
            if entry not in list_entries:
                list_entries.append(entry)
        
        # 5. Store combined list for this topic
        _guessing_lists[topic.id] = list_entries
    
    # 6. Load all pack entries (for actor selection)
    for pack in enabled_packs:
        _word_bank.append_array(pack.entries)
    
    # 7. Deduplicate word bank
    _word_bank = _deduplicate(_word_bank)
```

### 3. Round Start (Actor Selection)

```
┌─────────────────────────────────────────────────────────┐
│ ROUND FLOW                                              │
├─────────────────────────────────────────────────────────┤
│ 1. Pick 3 random words from combined word bank          │
│ 2. Send 3 options to acting team                        │
│ 3. Acting team picks 1 word                             │
│ 4. Show prep phase (choose background)                  │
│ 5. Round begins - actor performs                        │
│ 6. Audience sees search box filtered to topic           │
│ 7. Audience types to search guessing list               │
│ 8. Submit guess → server validates                      │
└─────────────────────────────────────────────────────────┘
```

### 4. Guessing UI Integration

**Current State:**
- Searches 20 hardcoded `WORD_BANK` entries
- Shows up to 3 fuzzy matches

**New State:**
- Searches the **topic-specific guessing list**
- Shows up to 5 fuzzy matches
- Only shows entries from the **current topic's** enabled lists
- Still allows typing full answer and submitting

---

## New Scripts

### `scripts/guessing_data_manager.gd`

**Purpose:** Central manager for all guessing data operations.

**Responsibilities:**
- Load/save topics, lists, and packs from `res://data/` and `user://guessing/`
- Create default packs/lists
- Validate data integrity
- Provide API for other systems

**Key Methods:**
```gdscript
func load_all_topics() -> Array[Dictionary]
func load_enabled_topics() -> Array[Dictionary]
func save_custom_topics(topics: Array[Dictionary]) -> void
func load_guessing_list(list_id: String) -> Array[String]
func load_guessing_pack(pack_id: String) -> Array[String]
func get_enabled_lists_for_topic(topic_id: String) -> Array[Dictionary]
func get_enabled_packs_for_topic(topic_id: String) -> Array[Dictionary]
func create_custom_pack(name: String, topic_id: String, entries: Array[String]) -> Dictionary
func copy_pack(source_pack_id: String, new_name: String) -> Dictionary
func deduplicate_entries(entries: Array[String]) -> Array[String]
func combine_lists(lists: Array[Array]) -> Array[String]
```

### `scripts/lobby_settings.gd`

**Purpose:** UI controller for the host's game settings panel.

**Responsibilities:**
- Display topic selection checkboxes
- Display list enable/disable toggles
- Display pack enable/disable toggles
- Handle create/edit/copy operations
- Save settings to host's local storage
- Sync settings to other players via RPC/Steam Lobby Data

---

## Integration Points

### Existing Scripts to Modify

| Script | Changes |
|--------|---------|
| `round_manager.gd` | Remove hardcoded `WORD_BANK`, load from packs, support 3-word selection |
| `game_hud.gd` | Update fuzzy search to use topic-specific guessing lists |
| `lobby.gd` | Add settings display and host-only button |
| `lobby_manager.gd` | Add settings panel for local host |

### New Scripts to Create

| Script | Purpose |
|--------|---------|
| `guessing_data_manager.gd` | Central data management |
| `lobby_settings.gd` | Settings UI controller |

---

## Implementation Phases

### Phase 1: Data Layer
1. Create folder structure (`data/`, `data/lists/`, `data/packs/`)
2. Create `data/topics.json` with default topics
3. Create sample guessing lists (50 movies, 40 TV shows, 30 anime)
4. Create sample packs (Top 100 Movies, Shonen Anime, Classic Sitcoms)
5. Implement `guessing_data_manager.gd` with load/save functionality
6. Test data loading/saving

### Phase 2: Lobby Integration
1. Create `lobby_settings.gd` with UI
2. Add settings display to `lobby.gd`
3. Add host-only "Game Settings" button
4. Implement settings sync (Steam Lobby Data for online, RPC for local)
5. Add pack/list creation UI

### Phase 3: Game Integration
1. Update `round_manager.gd` to load from `guessing_data_manager`
2. Implement 3-word selection for actors
3. Update `game_hud.gd` fuzzy search to use topic-specific lists
4. Add topic filtering to search
5. Implement deduplication and auto-add logic

### Phase 4: Polish
1. Add loading indicators
2. Implement search debouncing
3. Add error handling
4. Update documentation (AGENTS.md files)
5. Test edge cases

---

## Edge Cases & Considerations

### Empty States
- **No lists enabled:** Only pack entries available for guessing
- **No packs enabled:** Game cannot start (warn user)
- **Empty pack:** Skip when picking words

### Deduplication
- Across lists: Same title in multiple lists → keep one
- Across packs: Same word in multiple packs → keep one
- Pack entries not in lists → auto-add to relevant topic's list

### Custom Topics
- Custom topics need custom lists
- No default list for custom topics
- User must provide list or pack entries

### Validation
- Prevent duplicate topic IDs
- Prevent empty list/pack names
- Validate JSON structure on load
- Graceful fallback on corrupted data

---

## File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `data/AGENTS.md` | Folder documentation |
| `data/topics.json` | Default topic definitions |
| `data/lists/movies_sample.json` | Sample movie list |
| `data/lists/tv_sample.json` | Sample TV show list |
| `data/lists/anime_sample.json` | Sample anime list |
| `data/packs/top_100_movies.json` | Top 100 movies pack |
| `data/packs/classic_sitcoms.json` | Classic sitcoms pack |
| `data/packs/shonen_anime.json` | Shonen anime pack |
| `scripts/guessing_data_manager.gd` | Data management script |
| `scripts/lobby_settings.gd` | Settings UI script |

### Modified Files

| File | Changes |
|------|---------|
| `ARCHITECTURE.md` | Add data folder documentation |
| `scripts/round_manager.gd` | Remove WORD_BANK, load from manager |
| `scripts/game_hud.gd` | Update search to use topic lists |
| `scripts/AGENTS.md` | Add new scripts |
| `scenes/lobby.tscn` | Add settings display area (if scene exists) |

---

## Summary

This design provides a flexible, user-extensible system for managing guessing content. Key features:

- **Separation of concerns:** Topics, Lists, and Packs are independent but related
- **User customization:** Players can create new topics, copy lists/packs, create custom content
- **Performance:** Pre-extracted JSON, deduplication, efficient search
- **Cross-platform:** JSON format, Godot native support
- **Clean integration:** Minimal changes to existing code, new scripts for new functionality

The system integrates cleanly with the existing lobby and game flow while providing the foundation for future content expansion.
