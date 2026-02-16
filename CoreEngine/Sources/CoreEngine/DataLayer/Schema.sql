-- On-Device AI Core Engine Database Schema
-- SQLite database for storing documents, chunks, and embeddings

-- Documents table: stores source documents
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    source TEXT,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_documents_created ON documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_source ON documents(source);

-- Chunks table: stores text chunks from documents
CREATE TABLE IF NOT EXISTS chunks (
    id TEXT PRIMARY KEY,
    document_id TEXT NOT NULL,
    content TEXT NOT NULL,
    token_count INTEGER NOT NULL,
    chunk_index INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_chunks_document ON chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_chunks_index ON chunks(document_id, chunk_index);

-- Embeddings table: stores vector embeddings (deferred to Phase 1B for persistence)
-- For MVP, embeddings will be stored in-memory
-- CREATE TABLE IF NOT EXISTS embeddings (
--     chunk_id TEXT PRIMARY KEY,
--     embedding BLOB NOT NULL,
--     model_version TEXT NOT NULL,
--     created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
--     FOREIGN KEY (chunk_id) REFERENCES chunks(id) ON DELETE CASCADE
-- );
