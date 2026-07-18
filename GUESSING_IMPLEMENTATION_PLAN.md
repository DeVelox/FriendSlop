# Implementation Plan: Guessing System Integration

## Overview

This document outlines the step-by-step implementation plan for integrating the Guessing System into FriendSlop. The system introduces Topics, Guessing Lists, and Guessing Packs.

**Design Document:** `GUESSING_SYSTEM_DESIGN.md`

---

## Phase 1: Data Layer (Foundation)

### Step 1.1: Create Folder Structure

Create the following folders:
```
data/
data/lists/
data/packs/
```

**Files to create:**
- `data/AGENTS.md` - Folder documentation

### Step 1.2: Create Default Topics

Create `data/topics.json` with the 3 default topics:
- Movies
- TV Shows
- Anime

### Step 1.3: Create Sample Guessing Lists

Create sample data files (expandable later):

**`data/lists/movies_sample.json`**
- ~50 popular movie titles
- Examples: "The Shawshank Redemption", "The Godfather", "The Dark Knight"

**`data/lists/tv_sample.json`**
- ~40 popular TV show titles
- One entry per show (not per season)
- Examples: "Breaking Bad", "Friends", "The Office"

**`data/lists/anime_sample.json`**
- ~30 popular anime titles
- Examples: "Attack on Titan", "Death Note", "Naruto"

### Step 1.4: Create Sample Guessing Packs

**`data/packs/top_100_movies.json`**
- Curated list of top-rated movies
- ~50 entries for now

**`data/packs/classic_sitcoms.json`**
- Classic TV sitcoms
- ~30 entries

**`data/packs/shonen_anime.json`**
- Popular shonen anime
- ~25 entries

### Step 1.5: Implement Guessing Data Manager

Create `scripts/guessing_data_manager.gd`:

```gdscript
extends Node
## Central manager for all guessing data operations.
## Handles loading/saving topics, lists, and packs from res:// and user://.

# Core data structures
var _topics: Array[Dictionary] = []
var _all_lists: Array[Dictionary] = []
var _all_packs: Array[Dictionary] = []

# Game session data
var _enabled_topics: Array[Dictionary] = []
var _guessing_lists: Dictionary = {}  # topic_id -> Array[String]
var _word_bank: Array[String] = []

# Signals
signal topics_loaded(topics: Array[Dictionary])
signal lists_loaded(lists: Array[Dictionary])
signal packs_loaded(packs: Array[Dictionary])
signal data_initialized()
```

**Key Methods:**

1. **Loading:**
   - `load_all_topics() -> Array[Dictionary]`
   - `load_guessing_list(list_id: String) -> Array[String]`
   - `load_guessing_pack(pack_id: String) -> Array[String]`

2. **Saving:**
   - `save_custom_topic(topic: Dictionary) -> void`
   - `save_custom_list(list: Dictionary) -> void`
   - `save_custom_pack(pack: Dictionary) -> void`

3. **Game Initialization:**
   - `initialize_game_data(enabled_topic_ids: Array[String], enabled_list_ids: Array[String], enabled_pack_ids: Array[String]) -> void`
   - `_build_guessing_lists() -> void`
   - `_build_word_bank() -> void`

4. **Utilities:**
   - `deduplicate_entries(entries: Array[String]) -> Array[String]`
   - `combine_lists(lists: Array[Array]) -> Array[String]`
   - `get_word_bank() -> Array[String]`
   - `get_guessing_list_for_topic(topic_id: String) -> Array[String]`

### Step 1.6: Test Data Loading

- Verify JSON parsing works
- Test loading from `res://data/`
- Test saving to `user://guessing/`
- Test deduplication logic

---

## Phase 2: Lobby Integration

### Step 2.1: Create Lobby Settings Script

Create `scripts/lobby_settings.gd`:

```gdscript
extends Control
## UI controller for the host's game settings panel.
## Displays topic selection, list/pack toggles, and create/edit options.
```

**Components:**
- Topic checkboxes (Movies, TV, Anime + custom)
- List enable/disable toggles per topic
- Pack enable/disable toggles
- "Create New Pack" button
- "Copy Pack" button
- "Edit Pack" button (for custom packs)

### Step 2.2: Modify Lobby Scene

Update `addons/godotsteamkit/starters/lobbies/lobby.gd`:

1. Add settings display area (shows current selections)
2. Add host-only "Game Settings" button
3. Button opens the settings panel

**New Nodes to Add:**
- `SettingsDisplay` - VBoxContainer showing current config
- `GameSettingsButton` - Button (host only)
- `GameSettingsPanel` - instanced from settings scene

### Step 2.3: Implement Settings Sync

**For Steam Lobbies:**
- Store settings in Steam Lobby metadata
- Host sets → `Steam.setLobbyData()`
- Clients receive via `lobby_data_update` callback
- On join, read current settings

**For Local Lobbies:**
- Host sets → RPC to all clients
- Clients apply settings locally

### Step 2.4: Add Pack Creation UI

Add to the settings panel:
- Text input for pack name
- Topic dropdown selection
- Text area for entries (one per line)
- Save/Cancel buttons

---

## Phase 3: Game Integration

### Step 3.1: Update Round Manager

Modify `scripts/round_manager.gd`:

1. **Remove** hardcoded `WORD_BANK` constant
2. **Add** reference to `guessing_data_manager`
3. **Update** `_pick_prompt()` to use word bank from manager
4. **Add** 3-word selection for actors:

```gdscript
func _choose_next_actor() -> void:
    # ... existing code ...
    
    # Pick 3 random words
    var options: Array[String] = _pick_three_prompts()
    current_options = options
    
    # Send options to actor
    _sync_actor_options.rpc(current_actor_peer_id, options)

func _pick_three_prompts() -> Array[String]:
    var options: Array[String] = []
    for i in range(3):
        options.append(_pick_prompt())
    return options
```

5. **Add** topic tracking for current round

### Step 3.2: Update Game HUD

Modify `scripts/game_hud.gd`:

1. **Replace** `_fuzzy_search()` to use topic-specific lists:

```gdscript
func _fuzzy_search(query: String) -> Array[String]:
    if query.is_empty():
        return []
    
    var lower_query: String = query.to_lower()
    var topic_id: String = _round_manager.current_topic_id
    var search_list: Array[String] = _get_guessing_list_for_topic(topic_id)
    
    var results: Array[String] = []
    for entry: String in search_list:
        if _fuzzy_match(lower_query, entry.to_lower()):
            results.append(entry)
            if results.size() >= 5:  # Show up to 5 results
                break
    return results
```

2. **Add** topic label display
3. **Update** search box placeholder to show topic

### Step 3.3: Add Topic Filtering

- Store current topic in `round_manager.gd`
- Pass topic to HUD when round starts
- Filter search results by topic

### Step 3.4: Implement Auto-Add Logic

When game starts:
```gdscript
func _auto_add_pack_entries(topic_id: String, pack_entries: Array[String], list_entries: Array[String]) -> Array[String]:
    var combined: Array[String] = list_entries.duplicate()
    for entry in pack_entries:
        if entry not in combined:
            combined.append(entry)
    return combined
```

---

## Phase 4: Polish & Testing

### Step 4.1: Performance Optimization

- Add search debouncing (100ms delay)
- Cache loaded lists
- Lazy load disabled lists

### Step 4.2: Error Handling

- Handle missing files gracefully
- Validate JSON structure
- Show user-friendly error messages

### Step 4.3: UI Polish

- Loading indicators
- Visual feedback for enabled/disabled items
- Confirmation dialogs for destructive actions

### Step 4.4: Update Documentation

Update the following files:
- `ARCHITECTURE.md` - Add data folder
- `scripts/AGENTS.md` - Add new scripts
- `data/AGENTS.md` - Create folder documentation
- `DESIGN.md` - Reference guessing system

### Step 4.5: Test Edge Cases

- No lists enabled
- No packs enabled
- Empty pack
- Duplicate entries
- Custom topic with no lists
- Very large lists

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
| `scripts/guessing_data_manager.gd` | Data management |
| `scripts/lobby_settings.gd` | Settings UI |

### Modified Files

| File | Changes |
|------|---------|
| `ARCHITECTURE.md` | Add data folder |
| `scripts/AGENTS.md` | Add new scripts |
| `scripts/round_manager.gd` | Remove WORD_BANK, add 3-word selection |
| `scripts/game_hud.gd` | Update search to use topic lists |
| `addons/godotsteamkit/starters/lobbies/lobby.gd` | Add settings display and button |

---

## Dependencies

### External Data

- IMDB dataset (`assets/title.basics.tsv.gz`) - For future full extraction
- No new Godot addons required

### Godot APIs Used

- `JSON.parse_string()` / `JSON.stringify()`
- `FileAccess.open()` / `FileAccess.get_as_text()`
- `File.open()` for user:// access

---

## Timeline Estimate

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Data Layer | 2-3 hours | Data manager, sample data files |
| Phase 2: Lobby Integration | 3-4 hours | Settings UI, sync |
| Phase 3: Game Integration | 2-3 hours | Updated round manager, HUD |
| Phase 4: Polish | 2-3 hours | Error handling, docs, testing |
| **Total** | **9-13 hours** | Complete guessing system |

---

## Success Criteria

1. ✅ Topics, lists, and packs load from JSON files
2. ✅ Host can configure settings in lobby
3. ✅ Settings sync to all players
4. ✅ Actor sees 3 word options to choose from
5. ✅ Audience searches topic-specific list
6. ✅ Deduplication works correctly
7. ✅ Pack entries auto-add to lists
8. ✅ Custom packs can be created
9. ✅ No hardcoded word bank

---

## Future Enhancements (Out of Scope)

1. Full IMDB data extraction
2. Trie-based search for 750K+ entries
3. Pack sharing/export
4. Community pack ratings
5. Image prompts (movie posters)
6. Seasonal/event packs
