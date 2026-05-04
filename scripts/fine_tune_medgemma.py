#!/usr/bin/env python3
"""
MedGemma / Gemma 4 Fine-tuning with Unsloth
LoRA fine-tuning for medical and education domain adaptation
"""

import argparse
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="Fine-tune MedGemma/Gemma4 with Unsloth LoRA")
    parser.add_argument("--model", default="unsloth/gemma-4-4b-it", help="Base model ID")
    parser.add_argument("--dataset", required=True, help="Dataset path or HF dataset ID")
    parser.add_argument("--task", choices=["medical", "education"], default="medical")
    parser.add_argument("--output-dir", default="./checkpoints/finetuned", help="Output directory")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=2)
    parser.add_argument("--lr", type=float, default=2e-4)
    parser.add_argument("--max-seq-len", type=int, default=2048)
    parser.add_argument("--lora-r", type=int, default=16, help="LoRA rank")
    parser.add_argument("--lora-alpha", type=int, default=16)
    parser.add_argument("--export-gguf", action="store_true", help="Export to GGUF after training")
    parser.add_argument("--push-to-hub", action="store_true", help="Push to Hugging Face Hub")
    args = parser.parse_args()

    print("🚀 Cyborg AGI — Gemma 4 Fine-tuning with Unsloth")
    print(f"   Model:    {args.model}")
    print(f"   Task:     {args.task}")
    print(f"   Dataset:  {args.dataset}")
    print(f"   Output:   {args.output_dir}")
    print(f"   Epochs:   {args.epochs}, LR: {args.lr}, Batch: {args.batch_size}")

    # Check Unsloth
    try:
        from unsloth import FastLanguageModel
    except ImportError:
        print("\n❌ Unsloth not installed. Install with:")
        print("   pip install 'unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git'")
        sys.exit(1)

    import torch

    # 1. Load model with Unsloth (2-5x faster than HF)
    print("\n📥 Loading base model...")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=args.model,
        max_seq_length=args.max_seq_len,
        dtype=torch.bfloat16,
        load_in_4bit=True,  # QLoRA
    )

    # 2. Add LoRA adapters
    model = FastLanguageModel.get_peft_model(
        model,
        r=args.lora_r,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                        "gate_proj", "up_proj", "down_proj"],
        lora_alpha=args.lora_alpha,
        lora_dropout=0.05,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=42,
    )

    # 3. Load dataset
    print(f"\n📚 Loading dataset: {args.dataset}")
    try:
        from datasets import load_dataset
        if os.path.exists(args.dataset):
            dataset = load_dataset("json", data_files=args.dataset, split="train")
        else:
            dataset = load_dataset(args.dataset, split="train")
        print(f"   Dataset size: {len(dataset)} examples")
    except Exception as e:
        print(f"❌ Dataset load failed: {e}")
        sys.exit(1)

    # 4. Prepare prompt format
    def format_prompt(example):
        if args.task == "medical":
            return {"text": f"[MEDICAL]\nInput: {example.get('input', '')}\nOutput: {example.get('output', '')}</s>"}
        else:
            return {"text": f"[EDUCATION]\nQuestion: {example.get('question', '')}\nAnswer: {example.get('answer', '')}</s>"}

    dataset = dataset.map(format_prompt, remove_columns=dataset.column_names)

    # 5. Train
    print("\n🏋️  Starting fine-tuning...")
    from trl import SFTTrainer
    from transformers import TrainingArguments

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset,
        dataset_text_field="text",
        max_seq_length=args.max_seq_len,
        args=TrainingArguments(
            output_dir=args.output_dir,
            num_train_epochs=args.epochs,
            per_device_train_batch_size=args.batch_size,
            gradient_accumulation_steps=4,
            learning_rate=args.lr,
            fp16=not torch.cuda.is_bf16_supported(),
            bf16=torch.cuda.is_bf16_supported(),
            logging_steps=10,
            save_steps=100,
            warmup_steps=50,
            lr_scheduler_type="cosine",
            optim="adamw_8bit",
            report_to="none",
        ),
    )
    trainer.train()

    # 6. Save
    print(f"\n💾 Saving to {args.output_dir}...")
    model.save_pretrained(args.output_dir)
    tokenizer.save_pretrained(args.output_dir)

    # 7. Export GGUF
    if args.export_gguf:
        print("\n🔄 Exporting to GGUF (Q4_K_M)...")
        model.save_pretrained_gguf(args.output_dir, tokenizer, quantization_method="q4_k_m")
        print(f"   GGUF saved to {args.output_dir}/*.gguf")

    # 8. Push to Hub
    if args.push_to_hub:
        hub_id = f"cyborg-ai/{args.task}-gemma4-lora"
        print(f"\n🚀 Pushing to HF Hub: {hub_id}")
        model.push_to_hub_gguf(hub_id, tokenizer, quantization_method="q4_k_m")

    print("\n✅ Fine-tuning complete!")
    print(f"   Model saved: {args.output_dir}")
    if args.export_gguf:
        print(f"   Run with Ollama: ollama create {args.task}-gemma4 -f Modelfile")


if __name__ == "__main__":
    main()
