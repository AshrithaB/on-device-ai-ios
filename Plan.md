# On-Device AI Productivity Assistant — Project Design

## 📌 Overview
Build an **on-device AI productivity assistant** with two phases:
1. **Phase 1 — Core Engine**: text ingestion, embeddings, vector search, and on-device generation.
2. **Phase 2 — iOS App**: SwiftUI interface accessing the core engine.

**Core goals:**  
✔ Fully on-device (no network)  
✔ On-device Core ML models for embeddings + generation  
✔ Semantic search with citations  
✔ Clean architecture supporting expansion

---

## 🚀 Tech Stack

### Target Hardware
- **Primary:** Mac M3 Air (8–16 GB unified memory)  
- **Future:** iPhone 13 / 13 Pro (4 GB RAM)

### Core Engine
- **Language:** Swift (pure — no C++ or Objective-C++ needed)  
- **Vector Search:** Brute-force cosine similarity via Apple Accelerate (`vDSP`)  
- **Database:** SQLite  
- **Models:**  
  - **Embeddings:** `all-MiniLM-L6-v2` converted to Core ML (~80 MB, 384-dim vectors)  
  - **LLM:** `Llama 3.2 1B` 4-bit quantized via Core ML (~1 GB on disk)  
- **Tools:** Xcode, Swift Package Manager, `coremltools` (for model conversion)  
- **Data Storage:** File system for raw sources + SQLite for metadata

### iOS App (Phase 2)
- **UI:** SwiftUI  
- **Concurrency:** `async/await`, background tasks  
- **Architecture:** MVVM (View → ViewModel → CoreEngine API)  
- **Integration:** CoreEngine as a Swift Package

---

## 📌 Phase 1 — Core Engine (Headless)

### Goals
- Ingest local text
- Embed text into vectors
- Build a fast semantic search index
- Support queries with on-device LLM
- Provide a reusable API that Phase 2 will consume

---

## 📍 Phase 1 — Requirements

### 1) Document Ingestion
- Accept raw text (TXT, MD, copied text)
- Normalize and chunk text
  - Chunk size: ~400–800 tokens
  - Overlap: ~10–15%
- Store chunks + metadata in SQLite

---

### 2) Embedding + Indexing
- Use **`all-MiniLM-L6-v2`** converted to Core ML (384-dim embeddings)
- Generate vector for each chunk
- Store vectors in SQLite (`embeddings` table, binary blob)
- Vector search: brute-force cosine similarity via Apple **Accelerate** (`vDSP`)
  - Sufficient for on-device personal corpus (< 50K vectors)
  - Upgrade path: swap in **USearch** library if scale demands it
- Provide:
  ```swift
  func embed(text: String) -> [Float]
  func search(vector: [Float], topK: Int) -> [(id: Int, score: Float)]
  ```

---

### 3) LLM Integration
- Use **`Llama 3.2 1B`** (4-bit quantized) converted to Core ML
- RAG prompt pattern:
  1. Embed user query
  2. Retrieve topK chunks
  3. Build prompt including citation markers
  4. Generate answer as a token stream
- Streaming API:
  ```swift
  func ask(query: String) -> AsyncStream<String>
  ```

---

### 4) Data Store
- **SQLite** tables:
  - `documents(id, title, created_at)`
  - `chunks(id, doc_id, text, start, end)`
  - `embeddings(chunk_id, vector_blob)`
- Incremental ingestion:
  - Avoid re-embedding duplicates via hashing

---

## 📌 Phase 1 — Core APIs (Surface)

| API | Description |
|-----|-------------|
| `ingest(text: String, source: String) -> DocID` | Add text to DB |
| `search(query: String, k: Int) -> [ResultChunk]` | Semantic search |
| `ask(query: String) -> AsyncStream<String>` | AI answer stream |
| `citations(answerID) -> [Citation]` | Sources used |

---

## 🛠 Phase 1 — Implementation TODOs

> Each TODO produces an output that becomes the input for the next TODO.

- [ ] **TODO 1: Create SQLite schema**
  - Define `documents`, `chunks`, and `embeddings` tables
  - **Output →** Empty database with schema ready to accept ingested text

- [ ] **TODO 2: Build text normalization + chunking**
  - Accept raw text (TXT, MD, copied text), normalize, and split into ~400–800 token chunks with ~10–15% overlap
  - **Input ←** Schema from TODO 1
  - **Output →** Chunking pipeline that produces structured text segments

- [ ] **TODO 3: Store chunks + metadata in SQLite**
  - Persist chunks with doc references, positions, and dedup hashes into the database
  - **Input ←** Chunked text segments from TODO 2
  - **Output →** Populated `documents` and `chunks` tables queryable by ID

- [ ] **TODO 4: Integrate `all-MiniLM-L6-v2` Core ML embedding model**
  - Convert model via `coremltools`, load and validate in Swift; expose `func embed(text: String) -> [Float]`
  - **Input ←** Stored chunk text from TODO 3
  - **Output →** Working embedding function that converts any string to a 384-dim vector

- [ ] **TODO 5: Generate embeddings for all chunks**
  - Iterate over stored chunks, embed each one, and persist vectors to the `embeddings` table
  - **Input ←** Embedding function from TODO 4 + stored chunks from TODO 3
  - **Output →** Every chunk has an associated 384-dim vector in the database

- [ ] **TODO 6: Implement brute-force cosine similarity search via Accelerate**
  - Use `vDSP` to compute cosine similarity of a query vector against all stored vectors; return topK results
  - **Input ←** Embedded vectors from TODO 5
  - **Output →** Working `search(vector:topK:)` returning ranked `(id, score)` pairs

- [ ] **TODO 7: Add `Llama 3.2 1B` (4-bit) Core ML LLM**
  - Convert model via `coremltools`, load in Swift, and verify token generation
  - **Input ←** Xcode project with Core ML already integrated (TODO 4)
  - **Output →** Working LLM inference that produces tokens from a prompt

- [ ] **TODO 8: Build RAG prompt builder**
  - Embed a user query, retrieve topK chunks via search, and assemble a prompt with citation markers
  - **Input ←** Search API from TODO 6 + embedding function from TODO 4
  - **Output →** Formatted prompt string ready for the LLM

- [ ] **TODO 9: Implement streaming engine (AsyncStream)**
  - Feed the RAG prompt into the LLM and expose results as `func ask(query: String) -> AsyncStream<String>`
  - **Input ←** RAG prompt from TODO 8 + LLM from TODO 7
  - **Output →** End-to-end streaming answer pipeline with citations

- [ ] **TODO 10: Add timing metrics + benchmarks**
  - Instrument ingestion, embedding, search, and generation with timing logs
  - **Input ←** Full pipeline from TODO 9
  - **Output →** Performance baseline numbers for each stage

- [ ] **TODO 11: Optimize performance**
  - Profile bottlenecks, batch embeddings, optimize memory usage on M3 Air
  - **Input ←** Benchmark data from TODO 10
  - **Output →** Measurably faster pipeline meeting target latency

- [ ] **TODO 12: Clean README + usage examples**
  - Document API, setup instructions, and example CLI usage
  - **Input ←** Polished, benchmarked core engine from TODO 11
  - **Output →** Ship-ready Phase 1 package that Phase 2 will consume

---

## 📌 Phase 2 — iOS Interface

### Goals
- Build a SwiftUI app
- Wrap Phase 1 core engine
- Provide:
  - Capture screen
  - Search screen
  - Chat screen with streaming
  - Source viewer

---

## 🛠 Phase 2 — Requirements

### UI Screens

#### ✍️ Capture
- Paste text
- Import files (future)
- Show ingestion progress

#### 🔍 Search
- Query text
- Show result chunks with titles

#### 💬 Chat
- Ask question
- Stream tokens
- Show citations
- Click citation → open chunk text

#### 📚 Library
- List ingested sources
- Delete / re-index functions

---

## 📌 Phase 2 — Implementation TODOs

> Each TODO produces an output that becomes the input for the next TODO.

- [ ] **TODO 13: Create SwiftUI app foundation**
  - Set up Xcode project, configure targets, and establish MVVM folder structure
  - **Input ←** Phase 1 core engine package from TODO 12
  - **Output →** Skeleton app that compiles with CoreEngine dependency resolved

- [ ] **TODO 14: Add tab-based navigation**
  - Implement `TabView` with Capture, Search, Chat, and Library tabs
  - **Input ←** App skeleton from TODO 13
  - **Output →** Navigable app shell with placeholder screens

- [ ] **TODO 15: Integrate CoreEngine as Swift Package**
  - Import the CoreEngine module, initialize it on launch, and verify API access from ViewModels
  - **Input ←** Navigation shell from TODO 14 + CoreEngine package from TODO 12
  - **Output →** ViewModels can call `ingest`, `search`, and `ask` APIs

- [ ] **TODO 16: Build Capture screen**
  - Paste/import text, show ingestion progress, call `ingest()` in the background
  - **Input ←** CoreEngine integration from TODO 15
  - **Output →** Users can add documents; data flows into SQLite + vector index

- [ ] **TODO 17: Build Search screen**
  - Search bar + results list displaying chunk titles and previews via `search()` API
  - **Input ←** Ingested documents from TODO 16 + search API from TODO 15
  - **Output →** Users can semantically search their documents

- [ ] **TODO 18: Build Chat screen with streaming**
  - Chat interface that calls `ask()`, streams tokens in real time, and displays citation markers
  - **Input ←** Search results context from TODO 17 + streaming API from TODO 15
  - **Output →** Interactive AI chat with live token display and tappable citations

- [ ] **TODO 19: Build citation panel + source viewer**
  - Tapping a citation opens the original chunk text with highlight
  - **Input ←** Citation data from TODO 18
  - **Output →** Full answer-to-source traceability in the UI

- [ ] **TODO 20: Build Library screen**
  - List all ingested sources with delete and re-index actions
  - **Input ←** Document metadata from TODO 16
  - **Output →** Users can manage their document collection

- [ ] **TODO 21: UX polish, accessibility + dark mode**
  - Refine animations, add VoiceOver labels, support dark/light appearance
  - **Input ←** All screens from TODOs 16–20
  - **Output →** Production-quality UI ready for demo

- [ ] **TODO 22: Record demo + update README with screenshots**
  - Capture a walkthrough video, add screenshots and setup instructions to README
  - **Input ←** Polished app from TODO 21
  - **Output →** Portfolio-ready project with documentation and demo

---

## 🚩 Constraints (keep scope realistic)
✔ No audio → text only (for now)  
✔ No cloud/SDK dependencies (cloud model fallback planned later)  
✔ No sync between devices  
✔ Focus on clarity & performance  
✔ Target: Mac M3 Air first, iPhone 13/13 Pro later

---

## 📝 Resume-Ready Highlights

- Built a **core on-device retrieval engine** using `all-MiniLM-L6-v2` embeddings + `Llama 3.2 1B` via Core ML
- Implemented **brute-force semantic search** with Apple Accelerate (`vDSP`) — pure Swift, zero C++
- Shipped a **SwiftUI iOS app** with token-streaming chat and source citations
- Designed a reusable **Swift Package** for the AI core

---

## 🎯 Success Criteria

- Phase 1: CLI tool can ingest + search + answer with citations
- Phase 2: iOS app with smooth UI + fast response + offline operation

---

## 🔮 Future Improvements (deferred)

| Area | What to add |
|------|-------------|
| **Cloud model fallback** | Add API-based LLM (e.g. GPT-4, Claude) for higher-quality answers when online |
| **Better chunking** | Sentence/paragraph-aware splitting, proper tokenizer alignment |
| **Citation reliability** | Structured output parsing, post-processing to map citations back to chunks |
| **Error handling** | Graceful degradation for model load failures, OOM, corrupt DB, partial ingestion |
| **Testing** | Unit tests for chunking/embedding/search, integration tests for the full pipeline |
| **HNSW upgrade** | Swap brute-force for **USearch** library if corpus exceeds ~50K vectors |
| **Richer input** | PDF support (`PDFKit`), web clips, images via OCR |
| **Delete / re-index** | Handle vector store cleanup when documents are removed from Library |
| **iPhone optimization** | Memory profiling and model tuning for 4 GB RAM devices |

---

