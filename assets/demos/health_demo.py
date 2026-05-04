"""
Health Track Gradio Demo
MedGemma 4B X-ray Analysis Assistant
Interactive demo for competition judges
"""

import gradio as gr
import sys
import os

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from lib.health.medgemma.inference import MedGemmaPipeline


# Initialize pipeline (cached on first load)
def get_pipeline():
    """Lazy initialization of MedGemma pipeline"""
    if not hasattr(get_pipeline, 'pipeline'):
        get_pipeline.pipeline = MedGemmaPipeline.get_instance()
    return get_pipeline.pipeline


def analyze_xray(image, patient_age, patient_symptoms, language="en"):
    """
    Gradio interface for X-ray analysis
    
    Args:
        image: Uploaded chest X-ray image
        patient_age: Patient age
        patient_symptoms: Comma-separated symptoms
        language: Explanation language
        
    Returns:
        Formatted markdown response
    """
    if image is None:
        return "⚠️ Please upload a chest X-ray image"
    
    try:
        # Save uploaded image temporarily
        import tempfile
        from PIL import Image
        
        # Convert to PIL Image if needed
        if isinstance(image, dict):  # Gradio image format
            img_pil = Image.fromarray(image["composite"])
        else:
            img_pil = Image.fromarray(image)
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            img_pil.save(tmp.name)
            temp_path = tmp.name
        
        # Prepare patient context
        context = {
            "age": int(patient_age) if patient_age else None,
            "symptoms": patient_symptoms.split(",") if patient_symptoms else [],
            "language": language
        }
        
        # Run inference
        pipeline = get_pipeline()
        result = pipeline.analyze_xray(temp_path, patient_context=context)
        
        # Clean up temp file
        os.unlink(temp_path)
        
        # Format response for display
        response = f"""
### 🔍 Analysis Results

**Possible Findings**: {result.get('diagnosis_suggestion', 'N/A')}  
**Confidence**: {result.get('confidence', 0)}%

---

### 💬 Plain-Language Explanation ({language})

{result.get('plain_language_explanation', 'Analysis in progress...')}

---

### 📋 Key Points

"""
        
        # Add risk factors if available
        if result.get('risk_factors'):
            response += "**Risk Factors:**\n"
            for factor in result['risk_factors']:
                response += f"- {factor}\n"
            response += "\n"
        
        # Add recommendations
        if result.get('recommendations'):
            response += "**Recommendations:**\n"
            for rec in result['recommendations']:
                response += f"- {rec}\n"
            response += "\n"
        
        # Always include disclaimer
        response += """
---

### ⚠️ Important Medical Disclaimer

This AI assistance provides information and suggestions only. It is **NOT** a substitute for professional medical advice, diagnosis, or treatment. 

**Always consult a qualified healthcare provider** for any questions regarding a medical condition. If you think you may have a medical emergency, call your doctor or emergency services immediately.
"""
        
        return response
        
    except Exception as e:
        return f"""
### ❌ Error

An error occurred during analysis:

```
{str(e)}
```

Please try again with a different image or check that the model is properly loaded.

*Note: First run may take longer while loading the model.*
"""


# Build Gradio interface
with gr.Blocks(
    title="🏥 MedGemma 4B: Offline X-ray Analysis",
    theme=gr.themes.Soft(primary_hue="sky")
) as demo:
    
    gr.Markdown("""
    # 🏥 MedGemma 4B: Offline Chest X-ray Analysis Assistant
    
    Upload a chest X-ray to receive AI-assisted analysis with plain-language explanations. 
    **Runs entirely offline** on edge devices - no cloud dependency.
    
    ### How to Use:
    1. Upload a chest X-ray image (PNG, JPG, or DICOM)
    2. (Optional) Enter patient age and symptoms for context
    3. Select explanation language
    4. Click "Analyze X-ray"
    
    ⚠️ **This tool is for educational purposes only and does not provide medical diagnoses.**
    """)
    
    with gr.Row():
        with gr.Column(scale=1):
            gr.Markdown("### 📤 Upload X-ray")
            image_input = gr.Image(
                type="numpy",
                label="Chest X-ray Image",
                sources=["upload", "clipboard"],
                height=300
            )
            
            gr.Markdown("### 📝 Patient Context (Optional)")
            age_input = gr.Number(
                label="Patient Age",
                minimum=0,
                maximum=120,
                value=45
            )
            
            symptoms_input = gr.Textbox(
                label="Symptoms (comma-separated)",
                placeholder="e.g., fever, cough, shortness of breath",
                lines=2
            )
            
            language_input = gr.Dropdown(
                choices=[
                    ("English", "en"),
                    ("Español", "es"),
                    ("हिन्दी", "hi"),
                    ("Swahili", "sw"),
                    ("Français", "fr")
                ],
                label="Explanation Language",
                value="en"
            )
            
            analyze_btn = gr.Button(
                "🔍 Analyze X-ray",
                variant="primary",
                size="lg"
            )
        
        with gr.Column(scale=2):
            gr.Markdown("### 📊 Analysis Results")
            output_display = gr.Markdown(
                label="Results",
                elem_classes=["analysis-output"]
            )
    
    # Examples
    gr.Markdown("### 📚 Example Cases")
    gr.Examples(
        examples=[
            ["Normal chest X-ray - healthy adult", 35, "none", "en"],
            ["Pneumonia case - elderly patient", 72, "fever, cough, difficulty breathing", "en"],
            ["TB screening - persistent cough", 45, "chronic cough, weight loss, night sweats", "hi"],
        ],
        inputs=[image_input, age_input, symptoms_input, language_input],
        label="Try these example scenarios (images would be added in production)"
    )
    
    # Footer
    gr.Markdown("""
    ---
    
    ### ℹ️ Technical Details
    
    - **Model**: MedGemma 4B (quantized Q4_K_M for edge deployment)
    - **Vision Encoder**: SigLIP-So400m
    - **Runtime**: Ollama / llama.cpp (GGUF format)
    - **Edge Optimized**: Runs on Raspberry Pi 4, Jetson Nano, Android devices
    - **Offline**: No internet required after initial setup
    
    **Built with ❤️ for digital equity in healthcare**
    
    [GitHub Repository](https://github.com/ankit-sengupta05/test) | [Documentation](README.md)
    """)
    
    # Set up event handlers
    analyze_btn.click(
        fn=analyze_xray,
        inputs=[image_input, age_input, symptoms_input, language_input],
        outputs=output_display
    )


if __name__ == "__main__":
    print("🚀 Starting MedGemma 4B Health Demo...")
    print("📍 Access at: http://localhost:7860")
    print("💡 Tip: First run will download/load models (~3GB)")
    
    demo.launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=False,  # Set True for public link
        show_error=True
    )
