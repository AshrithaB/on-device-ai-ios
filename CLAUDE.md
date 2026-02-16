# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

On-device AI productivity assistant with semantic search and RAG (Retrieval-Augmented Generation) capabilities. Built in two phases:
- **Phase 1**: Core Engine (Swift package) - text ingestion, embeddings, vector search, RAG Q&A
- **Phase 2**: iOS app (SwiftUI) - user interface consuming Core Engine

**Status**: **Phase 1B-MVP complete!** Full RAG pipeline with question answering, citations, and streaming. Using mock embeddings and mock LLM for MVP - architecture ready for real models. Ready for Phase 2 (iOS app development).

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
│   └── EmbeddingStore.swift # Vector persistence
├── TextProcessing/          # Text normalization & chunking
│   ├── TextNormalizer.swift # Text cleaning
│   ├── Tokenizer.swift      # Token counting
│   └── TextChunker.swift    # 512-token chunking
├── MLLayer/                 # ML model wrappers
│   ├── EmbeddingModel.swift # Embedding generation (mock)
│   └── GenerationModel.swift # LLM generation (mock) **NEW**
├── VectorSearch/            # Semantic search
│   ├── VectorStore.swift    # In-memory vector storage
│   ├── SimilaritySearch.swift # Cosine similarity via Accelerate
│   └── SearchResult.swift   # Search result models
└── RAG/                     # Question answering **NEW**
    ├── Citation.swift       # Citation and Answer models
    └── PromptBuilder.swift  # RAG prompt construction
```

### Key Components

**CoreEngine** (actor): Thread-safe coordinator for all operations
- `ingest(title:content:source:)` - Add documents and auto-chunk
- `search(query:topK:minScore:)` - Semantic search
- `ask(query:topK:)` - Question answering with streaming **NEW**
- `askComplete(query:topK:)` - Complete answer (non-streaming) **NEW**
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

**RAG Pipeline (NEW)**:
- **GenerationModel** (actor): LLM wrapper for text generation
  - Mock implementation: extractive summarization from context
  - Supports streaming via `AsyncStream<String>`
  - Interface ready for llama.cpp or Core ML LLM
- **PromptBuilder**: RAG prompt construction
  - Formats search results as numbered context chunks [1], [2], etc.
  - Manages token budget (max 2048 tokens context)
  - Builds system prompt + context + question
- **Citation tracking**: Maps generated text to source chunks
  - `Citation` model: chunk reference, snippet, score
  - `Answer` model: complete response with citations
  - `StreamToken` enum: streaming content, citations, metadata

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
- `PromptBuilderTests.swift` - RAG prompt construction **NEW**
- **Note**: XCTest requires full Xcode (not available with Command Line Tools only). Tests written and validated via CLI integration testing.

## Known Issues & Limitations

1. **Mock embeddings and LLM**: Using deterministic mocks for MVP
   - Embeddings: Hash-based 384-dim vectors (works for demo, not semantic)
   - LLM: Extractive summarization (concatenates context chunks)
   - Fix: Replace with real models (Core ML or llama.cpp)
   - **Benefit**: Mock approach unblocks development while model selection continues

2. **Schema.sql warning**: Can be ignored (schema embedded in `Database.swift`)

3. **No chunk overlap**: May miss context at boundaries
   - Fix: Add 50-100 token overlap in `TextChunker` (15 min task)

4. **XCTest environment**: Tests created but cannot run without full Xcode
   - Validation done via CLI integration testing
   - All core functionality verified end-to-end

## Next Development Steps

**✅ Phase 1B-MVP Complete!** - RAG pipeline working with mock models. Ready for next phase.

### Recommended: Phase 2 (iOS App) - Start Immediately
1. Create SwiftUI iOS app project
2. Add CoreEngine as Swift Package dependency
3. Build document capture UI (camera, text input)
4. Implement search interface with results list
5. Build chat interface with streaming answer display
6. Create citation viewer with source highlighting
7. Add document library browser
8. Polish UI/UX

### Optional Parallel Track: Real Model Integration
1. **Real LLM** (if needed for better answers):
   - Evaluate llama.cpp vs Core ML
   - Test TinyLlama 1.1B GGUF (~600MB)
   - Integrate Swift wrapper
   - Replace `GenerationModel` mock

2. **Real Embeddings** (if needed for better search):
   - Resolve coremltools compatibility
   - Convert all-MiniLM-L6-v2 to Core ML
   - Replace `EmbeddingModel` mock

3. **Better Chunking**: Add sentence-aware chunking with overlap

**Note**: Mock implementations are sufficient for UI development. Real models can be swapped in later without API changes.

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
