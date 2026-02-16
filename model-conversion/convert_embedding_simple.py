#!/usr/bin/env python3
"""
Simplified Core ML conversion for all-MiniLM-L6-v2.
Uses a more compatible approach with latest coremltools.
"""

import coremltools as ct
import torch
import torch.nn as nn
from sentence_transformers import SentenceTransformer
import os
import shutil

class SimplifiedEmbeddingModel(nn.Module):
    """Simplified wrapper that avoids complex operations."""

    def __init__(self, model_name="sentence-transformers/all-MiniLM-L6-v2"):
        super().__init__()
        self.model = SentenceTransformer(model_name)
        self.bert = self.model[0].auto_model

    def forward(self, input_ids, attention_mask):
        # Get token embeddings
        outputs = self.bert(input_ids=input_ids, attention_mask=attention_mask)
        token_embeddings = outputs[0]

        # Mean pooling
        input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
        sum_embeddings = torch.sum(token_embeddings * input_mask_expanded, 1)
        sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)
        embeddings = sum_embeddings / sum_mask

        # L2 normalization
        norm = torch.norm(embeddings, p=2, dim=1, keepdim=True)
        embeddings = embeddings / norm

        return embeddings

def convert_embedding_model():
    """Convert all-MiniLM-L6-v2 to Core ML using simplified approach."""

    # Force CPU execution to avoid MPS issues
    torch.set_default_device('cpu')

    print("Loading all-MiniLM-L6-v2 from HuggingFace...")
    model = SimplifiedEmbeddingModel()
    model.eval()
    model.to('cpu')  # Ensure model is on CPU

    print("Creating example inputs...")
    # Batch size 1, sequence length 128
    max_seq_length = 128
    example_input_ids = torch.randint(0, 30522, (1, max_seq_length), dtype=torch.int32, device='cpu')
    example_attention_mask = torch.ones(1, max_seq_length, dtype=torch.int32, device='cpu')

    print(f"Input shapes: input_ids={example_input_ids.shape}, attention_mask={example_attention_mask.shape}")

    # Test the model
    print("Testing model...")
    with torch.no_grad():
        example_output = model(example_input_ids.long(), example_attention_mask.long())
        print(f"Output shape: {example_output.shape}")
        print(f"Output norm: {torch.norm(example_output, dim=1)}")

    print("Tracing PyTorch model...")
    with torch.no_grad():
        traced_model = torch.jit.trace(
            model,
            (example_input_ids.long(), example_attention_mask.long()),
            strict=False
        )

    print("Converting to Core ML (this may take a few minutes)...")
    try:
        mlmodel = ct.convert(
            traced_model,
            inputs=[
                ct.TensorType(
                    name="input_ids",
                    shape=(1, max_seq_length),
                    dtype=int
                ),
                ct.TensorType(
                    name="attention_mask",
                    shape=(1, max_seq_length),
                    dtype=int
                )
            ],
            outputs=[
                ct.TensorType(
                    name="embeddings"
                )
            ],
            minimum_deployment_target=ct.target.iOS16,
            compute_precision=ct.precision.FLOAT32
        )

        # Set metadata
        mlmodel.short_description = "all-MiniLM-L6-v2 sentence embedding model"
        mlmodel.author = "sentence-transformers"
        mlmodel.license = "Apache License 2.0"
        mlmodel.version = "1.0.0"

        mlmodel.input_description["input_ids"] = "Tokenized input text (max 128 tokens)"
        mlmodel.input_description["attention_mask"] = "Attention mask for input tokens"
        mlmodel.output_description["embeddings"] = "384-dimensional normalized embedding vector"

        # Save
        output_dir = "/workspace/output" if os.path.exists("/workspace/output") else "Models"
        os.makedirs(output_dir, exist_ok=True)

        output_path = os.path.join(output_dir, "MiniLM_L6_v2.mlpackage")
        if os.path.exists(output_path):
            shutil.rmtree(output_path)

        print(f"Saving Core ML model to {output_path}...")
        mlmodel.save(output_path)

        print("✅ Conversion complete!")
        print(f"Model saved to: {output_path}")
        print(f"Input shape: [1, {max_seq_length}] (input_ids and attention_mask)")
        print(f"Output shape: [1, 384] (normalized embeddings)")

        return output_path

    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        print("\nTrying fallback method without strict tracing...")

        # Fallback: Just convert without strict=False
        mlmodel = ct.convert(
            traced_model,
            inputs=[
                ct.TensorType(name="input_ids", shape=(1, max_seq_length)),
                ct.TensorType(name="attention_mask", shape=(1, max_seq_length))
            ],
            convert_to="mlprogram",
            minimum_deployment_target=ct.target.iOS16
        )

        output_dir = "Models"
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, "MiniLM_L6_v2.mlpackage")
        if os.path.exists(output_path):
            shutil.rmtree(output_path)

        mlmodel.save(output_path)
        print(f"✅ Conversion complete (fallback method)!")
        print(f"Model saved to: {output_path}")

        return output_path

if __name__ == "__main__":
    convert_embedding_model()
