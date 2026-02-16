#!/usr/bin/env python3
"""
Convert sentence-transformers/all-MiniLM-L6-v2 to Core ML format.

This script downloads the HuggingFace model and converts it to Core ML
for on-device inference on iOS/macOS.
"""

import coremltools as ct
import torch
from transformers import AutoTokenizer, AutoModel
from sentence_transformers import SentenceTransformer
import os
import shutil

def mean_pooling(model_output, attention_mask):
    """Mean pooling - take attention mask into account for correct averaging."""
    token_embeddings = model_output[0]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

class EmbeddingModelWrapper(torch.nn.Module):
    """Wrapper for the embedding model that includes mean pooling."""

    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask):
        """Forward pass with mean pooling."""
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
        embeddings = mean_pooling(outputs, attention_mask)
        # Normalize embeddings
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        return embeddings

def convert_embedding_model():
    """Convert all-MiniLM-L6-v2 to Core ML."""

    print("Loading all-MiniLM-L6-v2 from HuggingFace...")
    model_name = "sentence-transformers/all-MiniLM-L6-v2"

    # Load tokenizer and model
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    base_model = AutoModel.from_pretrained(model_name)

    # Wrap the model with pooling
    model = EmbeddingModelWrapper(base_model)
    model.eval()

    print("Creating example inputs...")
    # Create example inputs (max sequence length = 128)
    max_seq_length = 128
    example_text = "This is an example sentence for embedding."

    # Tokenize
    encoded = tokenizer(
        example_text,
        padding='max_length',
        truncation=True,
        max_length=max_seq_length,
        return_tensors='pt'
    )

    example_input_ids = encoded['input_ids']
    example_attention_mask = encoded['attention_mask']

    print(f"Input shape: {example_input_ids.shape}")

    # Trace the model
    print("Tracing PyTorch model...")
    with torch.no_grad():
        traced_model = torch.jit.trace(
            model,
            (example_input_ids, example_attention_mask)
        )

        # Verify traced model works
        example_output = traced_model(example_input_ids, example_attention_mask)
        print(f"Output shape: {example_output.shape}")  # Should be [1, 384]
        print(f"Output norm: {torch.norm(example_output, dim=1)}")  # Should be ~1.0

    print("Converting to Core ML...")
    # Convert to Core ML
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(
                name="input_ids",
                shape=example_input_ids.shape,
                dtype=int
            ),
            ct.TensorType(
                name="attention_mask",
                shape=example_attention_mask.shape,
                dtype=int
            )
        ],
        outputs=[
            ct.TensorType(
                name="embeddings",
                dtype=float
            )
        ],
        minimum_deployment_target=ct.target.iOS16,
    )

    # Set model metadata
    mlmodel.short_description = "all-MiniLM-L6-v2 sentence embedding model"
    mlmodel.author = "sentence-transformers"
    mlmodel.license = "Apache License 2.0"
    mlmodel.version = "1.0.0"

    # Add input descriptions
    mlmodel.input_description["input_ids"] = "Tokenized input text (max 128 tokens)"
    mlmodel.input_description["attention_mask"] = "Attention mask for input tokens"

    # Add output description
    mlmodel.output_description["embeddings"] = "384-dimensional normalized embedding vector"

    # Create output directory
    output_dir = "/workspace/output"
    os.makedirs(output_dir, exist_ok=True)

    # Save the model
    output_path = os.path.join(output_dir, "MiniLM_L6_v2.mlpackage")

    # Remove existing model if present
    if os.path.exists(output_path):
        shutil.rmtree(output_path)

    print(f"Saving Core ML model to {output_path}...")
    mlmodel.save(output_path)

    print("✅ Conversion complete!")
    print(f"Model saved to: {output_path}")
    print(f"Input shape: [1, {max_seq_length}] (input_ids and attention_mask)")
    print(f"Output shape: [1, 384] (normalized embeddings)")

    # Save tokenizer vocab for reference
    vocab_path = os.path.join(output_dir, "vocab.txt")
    tokenizer.save_vocabulary(output_dir)
    print(f"Tokenizer vocabulary saved to: {output_dir}")

    return output_path

if __name__ == "__main__":
    convert_embedding_model()
