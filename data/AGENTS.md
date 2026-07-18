# data/

This folder contains game data files for the guessing system. Default data ships with the game build in `res://data/`. User-created data lives in `user://guessing/`.

## Structure

```
data/
├── AGENTS.md
├── topics.json              # Topic definitions (Movies, TV, Anime, custom)
├── lists/                   # Guessing lists (valid answers per topic)
│   ├── movies_sample.json   # Sample movie titles
│   ├── tv_sample.json       # Sample TV show titles
│   └── anime_sample.json    # Sample anime titles
└── packs/                   # Guessing packs (curated word lists for performers)
    ├── top_100_movies.json
    ├── classic_sitcoms.json
    └── shonen_anime.json
```

## File Formats

### topics.json

```json
{
  "version": 1,
  "topics": [
    {
      "id": "movies",
      "name": "Movies",
      "is_default": true,
      "created_by": ""
    }
  ]
}
```

### lists/*.json

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
  "entries": ["Title 1", "Title 2"]
}
```

### packs/*.json

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
  "entries": ["Title 1", "Title 2"]
}
```

## Conventions

- Default data files are **read-only** - never modify at runtime
- User-created data is saved to `user://guessing/`
- All data files use JSON format
- Each file has a `version` field for future migrations
- Metadata includes `is_default` flag and `created_by` Steam ID
