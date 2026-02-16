# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

On-device AI productivity assistant with semantic search and RAG (Retrieval-Augmented Generation) capabilities. Built in two phases:
- **Phase 1**: Core Engine (Swift package) - text ingestion, embeddings, vector search
- **Phase 2**: iOS app (SwiftUI) - user interface consuming Core Engine

**Status**: Search MVP complete with mock embeddings and **vector persistence**. Vectors persist to SQLite and reload automatically. Real Core ML embeddings integration pending.

## Tech Stack

- **Language**: Swift 6.1+ (strict concurrency enabled)
- **Database**: SQLite via GRDB.swift
- **Vector Operations**: Apple Accelerate framework (vDSP)
- **ML Models**: Core ML (all-MiniLM-L6-v2 for embeddings, Llama 3.2 1B for generation - planned)
- **Platforms**: macOS 13+, iOS 16+
- **Model Conversion**: Python 3.11+ with coremltools, transformers, PyTorch

## Build & Development Commands

### Core Engine (Swift Package)

```bash
# Build the package
cd CoreEngine
swift build

# Run tests
swift test

# Clean build artifacts
swift package clean
```

### CLI Demo

```bash
# Run the demo (ingests sample documents and searches)
cd CoreEngineCLI
swift run CoreEngineCLI
```

### Model Conversion (Python)

The model conversion scripts use a Python virtual environment:

```bash
cd model-conversion

# First time setup: create and activate venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Convert embedding model
python convert_embedding.py

# Validate conversion
python test_models.py

# Deactivate venv when done
deactivate
```

**Note**: Docker-based conversion was planned but local venv is currently used.

## Architecture

### Directory Structure

```
CoreEngine/Sources/CoreEngine/
├── CoreEngine.swift          # Public API facade
├── DataLayer/               # SQLite persistence
│   ├── Database.swift       # GRDB wrapper
│   ├── Document.swift       # Document model
│   ├── Chunk.swift          # Chunk model
│   ├── DocumentStore.swift  # Document CRUD
│   ├── ChunkStore.swift     # Chunk CRUD
│   └── EmbeddingStore.swift # Vector persistence (NEW)
├── TextProcessing/          # Text normalization & chunking
│   ├── TextNormalizer.swift # Text cleaning
│   ├── Tokenizer.swift      # Token counting
│   └── TextChunker.swift    # 512-token chunking
├── MLLayer/                 # Embedding generation
│   └── EmbeddingModel.swift # Core ML wrapper (currently mock)
└── VectorSearch/            # Semantic search
    ├── VectorStore.swift    # In-memory vector storage
    ├── SimilaritySearch.swift # Cosine similarity via Accelerate
    └── SearchResult.swift   # Search result models
```

### Key Components

**CoreEngine** (actor): Thread-safe coordinator for all operations
- `ingest(title:content:source:)` - Add documents and auto-chunk
- `search(query:topK:minScore:)` - Semantic search
- `getStatistics()` - Document/chunk/vector counts

**Database Layer**: GRDB-backed SQLite with async/await
- Tables: `documents`, `chunks`, `embeddings` (vectors)
- Full persistence: vectors saved to database and loaded on startup

**Text Processing**:
- Fixed 512-token chunks (no overlap in MVP)
- Whitespace tokenizer (approximation)
- Basic text normalization

**Vector Search**:
- Dual storage: In-memory cache + SQLite persistence
- Brute-force cosine similarity via `vDSP_dotpr` (Accelerate)
- Sub-millisecond search for <10K vectors
- Vectors automatically loaded on startup

**EmbeddingModel**:
- Currently returns deterministic mock embeddings (384-dim)
- Interface ready for real Core ML model
- Uses Accelerate for L2 normalization

## Code Patterns & Conventions

### Concurrency
- Main coordinator (`CoreEngine`) is an `actor` for thread safety
- All database operations are `async`
- Use `async/await` throughout, no completion handlers
- All models conform to `Sendable`

### Error Handling
- Throw descriptive errors, don't silently fail
- Use `try await` for database and ML operations
- Validate inputs at API boundaries

### Database Operations
- All CRUD goes through stores (`DocumentStore`, `ChunkStore`)
- Use GRDB's async API: `write { db in ... }`, `read { db in ... }`
- Models implement `FetchableRecord` and `PersistableRecord`

### Vector Operations
- Use Accelerate framework for performance
- Example: `vDSP_dotpr` for dot product, `vDSP_normalize` for L2 norm
- Store embeddings as `[Float]` (384 dimensions)

## Key Architectural Decisions

1. **GRDB over raw SQLite**: Type-safe Swift API, better error handling
2. **Hybrid vector storage**: In-memory cache for speed + SQLite for persistence
3. **Brute-force search**: Sufficient for personal corpus (<50K vectors)
4. **Actor-based concurrency**: Thread-safe by design (Swift 6 strict mode)
5. **Mock embeddings**: Unblocks development while Core ML conversion is WIP
6. **No chunk overlap**: Simplifies MVP, can add 10-15% overlap later
7. **Binary blob storage**: Vectors stored as raw Float bytes (efficient)

## Testing

```bash
cd CoreEngine
swift test
```

Current tests:
- `ChunkerTests.swift` - Text chunking validation
- Unit tests for other components pending

## Known Issues & Limitations

1. **Mock embeddings**: Search works but relevance is not semantic
   - Fix: Replace `EmbeddingModel` with real Core ML implementation
   - Interface is ready, just swap implementation
   - Known blocker: coremltools 9.0 + torch 2.10.0 incompatibility

2. **Schema.sql warning**: Can be ignored (schema embedded in `Database.swift`)

3. **No chunk overlap**: May miss context at boundaries
   - Fix: Add 50-100 token overlap in `TextChunker` (15 min task)

## Next Development Steps

### High Priority
1. **Real Core ML embeddings**: Convert all-MiniLM-L6-v2 successfully or use alternative approach
   - Options: Downgrade dependencies, use ONNX, try MLX
2. **Better chunking**: Smart sentence boundaries with overlap

### Phase 1B (LLM Integration)
4. Convert Llama 3.2 1B to Core ML
5. Build RAG prompt builder
6. Implement streaming generation (`AsyncStream<String>`)
7. Citation extraction from LLM responses

### Phase 2 (iOS App)
8. SwiftUI interface
9. Tab navigation (Capture, Search, Chat, Library)
10. Token streaming UI
11. Citation viewer

## Model Files

Expected location: `Models/` directory at project root

- `MiniLM_L6_v2.mlpackage` - Embedding model (pending successful conversion)
- Future: Llama 3.2 1B quantized model

## Important Notes

- **Swift 6 strict concurrency**: All code must be thread-safe
- **No force unwraps**: Use optional binding or proper error handling
- **Accelerate framework**: Prefer Apple-optimized vector operations
- **GRDB best practices**: Use stores for CRUD, keep models simple
- **Target hardware**: Mac M3 Air (8-16GB), future: iPhone 13+ (4GB)
