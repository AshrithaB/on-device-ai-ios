#!/usr/bin/env python3
"""
Test and validate converted Core ML models.

Compares Core ML output with original HuggingFace model to ensure
conversion accuracy.
"""

import coremltools as ct
import torch
from transformers import AutoTokenizer, AutoModel
from sentence_transformers import SentenceTransformer
import numpy as np
import os

def mean_pooling(model_output, attention_mask):
    """Mean pooling - take attention mask into account for correct averaging."""
    token_embeddings = model_output[0]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

def test_embedding_model():
    """Test the converted embedding model."""

    print("Testing MiniLM_L6_v2.mlpackage...")

    # Check if model exists
    model_path = "/workspace/output/MiniLM_L6_v2.mlpackage"
    if not os.path.exists(model_path):
        print(f"❌ Model not found at {model_path}")
        print("Run convert_embedding.py first!")
        return False

    # Load Core ML model
    print("Loading Core ML model...")
    mlmodel = ct.models.MLModel(model_path)

    # Load original model for comparison
    print("Loading original HuggingFace model...")
    model_name = "sentence-transformers/all-MiniLM-L6-v2"
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    hf_model = AutoModel.from_pretrained(model_name)
    hf_model.eval()

    # Test sentences
    test_sentences = [
        "This is a test sentence.",
        "Machine learning is fascinating.",
        "The quick brown fox jumps over the lazy dog.",
    ]

    max_seq_length = 128
    print(f"\nTesting {len(test_sentences)} sentences...\n")

    all_passed = True

    for i, sentence in enumerate(test_sentences, 1):
        print(f"Test {i}: '{sentence}'")

        # Tokenize
        encoded = tokenizer(
            sentence,
            padding='max_length',
            truncation=True,
            max_length=max_seq_length,
            return_tensors='pt'
        )

        input_ids = encoded['input_ids']
        attention_mask = encoded['attention_mask']

        # Get HuggingFace embedding
        with torch.no_grad():
            hf_output = hf_model(input_ids=input_ids, attention_mask=attention_mask)
            hf_embedding = mean_pooling(hf_output, attention_mask)
            hf_embedding = torch.nn.functional.normalize(hf_embedding, p=2, dim=1)
            hf_embedding = hf_embedding.numpy()

        # Get Core ML embedding
        coreml_input = {
            'input_ids': input_ids.numpy().astype(np.int32),
            'attention_mask': attention_mask.numpy().astype(np.int32)
        }
        coreml_output = mlmodel.predict(coreml_input)
        coreml_embedding = coreml_output['embeddings']

        # Compare embeddings
        diff = np.abs(hf_embedding - coreml_embedding)
        max_diff = np.max(diff)
        mean_diff = np.mean(diff)

        # Check if embeddings are close enough (tolerance: 1e-5)
        tolerance = 1e-5
        passed = max_diff < tolerance

        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  HuggingFace embedding shape: {hf_embedding.shape}")
        print(f"  Core ML embedding shape: {coreml_embedding.shape}")
        print(f"  Max difference: {max_diff:.2e}")
        print(f"  Mean difference: {mean_diff:.2e}")
        print(f"  {status}\n")

        if not passed:
            all_passed = False

    if all_passed:
        print("=" * 50)
        print("🎉 All tests passed! Model conversion successful.")
        print("=" * 50)
    else:
        print("=" * 50)
        print("⚠️  Some tests failed. Check conversion process.")
        print("=" * 50)

    return all_passed

def verify_model_properties():
    """Verify model metadata and properties."""

    model_path = "/workspace/output/MiniLM_L6_v2.mlpackage"
    if not os.path.exists(model_path):
        print(f"❌ Model not found at {model_path}")
        return False

    print("\nModel Properties:")
    print("=" * 50)

    mlmodel = ct.models.MLModel(model_path)

    spec = mlmodel.get_spec()
    print(f"Description: {spec.description.metadata.shortDescription}")
    print(f"Author: {spec.description.metadata.author}")
    print(f"License: {spec.description.metadata.license}")
    print(f"Version: {spec.description.metadata.versionString}")

    print("\nInputs:")
    for input_spec in spec.description.input:
        print(f"  - {input_spec.name}: {input_spec.shortDescription}")

    print("\nOutputs:")
    for output_spec in spec.description.output:
        print(f"  - {output_spec.name}: {output_spec.shortDescription}")

    print("=" * 50)

    return True

if __name__ == "__main__":
    print("Starting model validation...\n")

    # Verify model properties
    verify_model_properties()

    # Test embedding accuracy
    print()
    success = test_embedding_model()

    exit(0 if success else 1)
