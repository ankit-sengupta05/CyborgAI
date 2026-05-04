"""
Education Track Gradio Demo
Adaptive Homework Grading Assistant
Interactive demo for competition judges
"""

import gradio as gr
import sys
import os
import tempfile
from PIL import Image

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from lib.education.adaptive_tutor.grader import HomeworkGrader


def get_grader(language="en"):
    """Lazy initialization of homework grader"""
    if not hasattr(get_grader, 'graders'):
        get_grader.graders = {}
    
    if language not in get_graders.graders:
        get_graders.graders[language] = HomeworkGrader(language=language)
    
    return get_graders.graders[language]


def grade_homework(image, subject, grade_level, language="en"):
    """
    Gradio interface for homework grading
    
    Args:
        image: Uploaded homework photo
        subject: Subject area (math, science, literacy)
        grade_level: Grade level (1-12)
        language: Language for feedback
        
    Returns:
        Formatted markdown response with grade and feedback
    """
    if image is None:
        return "⚠️ Please upload a homework image"
    
    try:
        # Save uploaded image temporarily
        if isinstance(image, dict):
            img_pil = Image.fromarray(image["composite"])
        else:
            img_pil = Image.fromarray(image)
        
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            img_pil.save(tmp.name)
            temp_path = tmp.name
        
        # Run grading
        grader = get_grader(language)
        result = grader.grade_submission(
            image_path=temp_path,
            subject=subject.lower(),
            grade_level=int(grade_level),
            language=language
        )
        
        # Clean up
        os.unlink(temp_path)
        
        # Format response
        score = result.get('score', 0)
        
        # Color code the score
        if score >= 85:
            score_emoji = "🌟"
            score_color = "#10b981"  # Green
        elif score >= 70:
            score_emoji = "👍"
            score_color = "#f59e0b"  # Amber
        else:
            score_emoji = "📚"
            score_color = "#ef4444"  # Red
        
        response = f"""
### 📊 Grading Results

<div style="font-size: 2em; color: {score_color};">
{score_emoji} Score: {score}/100
</div>

---

### 💬 Feedback

{result.get('feedback', 'Analyzing...')}

---

### 🎯 Areas for Improvement

"""
        
        # Add error categories
        errors = result.get('error_categories', [])
        if errors:
            for i, error in enumerate(errors, 1):
                response += f"{i}. **{error.get('type', 'Error').title()}**: {error.get('description', 'N/A')}\n"
        else:
            response += "Great job! No major errors detected.\n"
        
        response += "\n---\n\n"
        
        # Add practice quiz
        quiz = result.get('remediation_quiz', [])
        if quiz and len(quiz) > 0:
            response += "### 📝 Practice Questions\n\n"
            
            for q in quiz[:3]:  # Show first 3 questions
                if q.get('type') == 'multiple_choice':
                    response += f"**Question {q.get('id', '?')}**: {q.get('question', '')}\n\n"
                    if q.get('options'):
                        for opt in q['options']:
                            response += f"  {opt}\n"
                    response += f"\n✅ Answer: {q.get('correct_answer', 'N/A')}\n"
                    response += f"💡 {q.get('explanation', '')}\n\n"
                    response += "---\n\n"
        
        response += """
---

### 📈 Progress Tracking

Keep practicing! Consistent effort leads to improvement. 

**Tips for Success:**
- Review mistakes carefully
- Practice similar problems daily
- Ask for help when stuck
- Celebrate your progress! 🎉
"""
        
        return response
        
    except Exception as e:
        return f"""
### ❌ Error

An error occurred during grading:

```
{str(e)}
```

Please try again with a clearer image or check that the model is loaded.

*Note: First run may take longer while loading models.*
"""


# Build Gradio interface
with gr.Blocks(
    title="🎓 Adaptive Tutor: Homework Helper",
    theme=gr.themes.Soft(primary_hue="violet")
) as demo:
    
    gr.Markdown("""
    # 🎓 Adaptive Learning Assistant
    
    Upload a photo of homework to receive instant grading, personalized feedback, and practice questions.
    **Supports multiple languages** and runs offline on edge devices.
    
    ### How to Use:
    1. Select subject and grade level
    2. Upload a clear photo of the homework
    3. Choose feedback language
    4. Click "Grade Homework"
    
    ✅ Supports math, science, and literacy assignments
    """)
    
    with gr.Row():
        with gr.Column(scale=1):
            gr.Markdown("### 📝 Assignment Details")
            
            subject_input = gr.Dropdown(
                choices=[
                    ("Mathematics", "math"),
                    ("Science", "science"),
                    ("Literacy/English", "literacy")
                ],
                label="Subject",
                value="math"
            )
            
            grade_input = gr.Slider(
                minimum=1,
                maximum=12,
                value=5,
                step=1,
                label="Grade Level"
            )
            
            language_input = gr.Dropdown(
                choices=[
                    ("English", "en"),
                    ("Español", "es"),
                    ("हिन्दी", "hi"),
                    ("Swahili", "sw")
                ],
                label="Feedback Language",
                value="en"
            )
            
            gr.Markdown("### 📸 Upload Homework")
            image_input = gr.Image(
                type="numpy",
                label="Homework Photo",
                sources=["upload", "clipboard"],
                height=300
            )
            
            grade_btn = gr.Button(
                "📊 Grade Homework",
                variant="primary",
                size="lg"
            )
        
        with gr.Column(scale=2):
            gr.Markdown("### 📋 Results & Feedback")
            output_display = gr.Markdown(label="Grading Results")
    
    # Examples
    gr.Markdown("### 📚 Try Examples")
    gr.Examples(
        examples=[
            ["Solving linear equations: 2x + 5 = 15", "math", 7, "en"],
            ["Basic addition: 23 + 45 = ?", "math", 3, "en"],
            ["Essay paragraph about my family", "literacy", 5, "es"],
        ],
        inputs=[image_input, subject_input, grade_input, language_input],
        label="Example scenarios (images would be added in production)"
    )
    
    # Footer
    gr.Markdown("""
    ---
    
    ### ℹ️ Technical Details
    
    - **Model**: Gemma 4 4B (quantized for edge deployment)
    - **OCR**: Integrated text extraction from handwritten work
    - **Multi-language**: English, Spanish, Hindi, Swahili
    - **Offline**: Runs on Raspberry Pi, Android tablets, low-end laptops
    - **Privacy**: All processing on-device, no data sent to cloud
    
    **Built with ❤️ for educational equity**
    
    [GitHub Repository](https://github.com/ankit-sengupta05/test) | [Documentation](README.md)
    """)
    
    # Event handlers
    grade_btn.click(
        fn=grade_homework,
        inputs=[image_input, subject_input, grade_input, language_input],
        outputs=output_display
    )


if __name__ == "__main__":
    print("🚀 Starting Education Track Demo...")
    print("📍 Access at: http://localhost:7861")
    print("💡 Tip: Supports multiple languages for global accessibility")
    
    demo.launch(
        server_name="0.0.0.0",
        server_port=7861,
        share=False,
        show_error=True
    )
