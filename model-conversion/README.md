# Model Conversion Scripts

This directory contains Docker-based scripts for converting ML models to Core ML format for on-device inference.

## Prerequisites

- Docker installed and running
- Docker Compose installed

## Quick Start

### 1. Build the Docker Image

```bash
cd model-conversion
docker-compose build
```

This creates a Python 3.11 environment with all required dependencies (coremltools, transformers, PyTorch, etc.).

### 2. Convert Embedding Model

Convert `sentence-transformers/all-MiniLM-L6-v2` to Core ML:

```bash
docker-compose run model-converter python convert_embedding.py
```

**Output:** `../Models/MiniLM_L6_v2.mlpackage`

This downloads the model from HuggingFace, traces it with PyTorch JIT, and converts it to Core ML format.

**Expected Output:**
- Model package saved to `Models/MiniLM_L6_v2.mlpackage`
- Input: `input_ids` and `attention_mask` (shape: [1, 128])
- Output: `embeddings` (shape: [1, 384], normalized)

### 3. Validate Conversion

Test the converted model and compare outputs with the original:

```bash
docker-compose run model-converter python test_models.py
```

This runs the Core ML model and HuggingFace model side-by-side on test sentences and verifies that outputs match within tolerance (1e-5).

**Expected Output:**
```
Test 1: 'This is a test sentence.'
  Max difference: 1.23e-06
  Mean difference: 4.56e-07
  ✅ PASS

🎉 All tests passed! Model conversion successful.
```

## Files

- **Dockerfile** - Python environment with ML dependencies
- **docker-compose.yml** - Service configuration and volume mounts
- **requirements.txt** - Python package dependencies
- **convert_embedding.py** - Converts all-MiniLM-L6-v2 to Core ML
- **test_models.py** - Validates converted model accuracy
- **convert_llm.py** - (Phase 1B) Converts Llama 3.2 1B to Core ML

## Model Details

### all-MiniLM-L6-v2

- **Purpose:** Sentence embeddings for semantic search
- **Input:** Tokenized text (max 128 tokens)
  - `input_ids`: [1, 128] int32
  - `attention_mask`: [1, 128] int32
- **Output:** 384-dimensional normalized embedding vector
  - `embeddings`: [1, 384] float32
- **Size:** ~23 MB
- **Source:** https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2

### Usage in Swift

```swift
import CoreML

let model = try MiniLM_L6_v2(configuration: MLModelConfiguration())

// input_ids and attention_mask are MLMultiArray with shape [1, 128]
let prediction = try model.prediction(
    input_ids: inputIds,
    attention_mask: attentionMask
)

let embeddings = prediction.embeddings // MLMultiArray [1, 384]
```

## Troubleshooting

### Docker Build Fails

- Ensure Docker Desktop is running
- Check internet connection (downloads PyTorch ~2GB)
- Try `docker-compose build --no-cache`

### Conversion Fails

- Check HuggingFace Hub availability
- Verify sufficient disk space (~5GB for cache)
- Check Docker volume mounts in docker-compose.yml

### Test Fails (High Difference)

- Acceptable tolerance: < 1e-5
- If difference is 1e-3 to 1e-4, model may still work but verify manually
- If difference > 1e-2, conversion likely failed - check conversion logs

## Next Steps (Phase 1B)

To convert Llama 3.2 1B (deferred for MVP):

```bash
docker-compose run model-converter python convert_llm.py
```

This is more complex and may require:
- Quantization to int8 or int4
- Custom tokenizer integration
- Memory optimization for mobile deployment
