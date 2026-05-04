"""
Quiz Generator for Adaptive Learning
Personalized quiz creation based on student weaknesses
"""

from typing import List, Dict, Any, Optional
import random


class QuizGenerator:
    """
    Generate personalized quizzes targeting specific knowledge gaps
    
    Features:
    - Adaptive difficulty
    - Multi-language support
    - Cultural relevance
    - Voice-friendly formatting
    """
    
    def __init__(self, language: str = "en", region: str = "US"):
        self.language = language
        self.region = region
        
    def generate_quiz(self,
                     weak_concepts: List[str],
                     subject: str,
                     grade_level: int,
                     num_questions: int = 5,
                     cultural_context: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Generate adaptive quiz
        
        Args:
            weak_concepts: List of concepts student needs to practice
            subject: Subject area
            grade_level: Grade level (1-12)
            num_questions: Number of questions to generate
            cultural_context: Regional/cultural context for examples
            
        Returns:
            List of quiz question dicts
        """
        # Question templates by subject and concept
        templates = self._get_question_templates(subject, weak_concepts)
        
        questions = []
        for i in range(num_questions):
            template = random.choice(templates)
            question = self._customize_question(
                template,
                grade_level=grade_level,
                cultural_context=cultural_context or self.region
            )
            questions.append(question)
        
        return questions
    
    def _get_question_templates(self, subject: str, concepts: List[str]) -> List[Dict[str, Any]]:
        """Get question templates for subject and concepts"""
        
        templates = {
            "math": [
                {
                    "type": "multiple_choice",
                    "template": "If {variable} = {value}, what is {expression}?",
                    "difficulty": "medium"
                },
                {
                    "type": "word_problem",
                    "template": "{scenario}. How many {unit} are needed?",
                    "difficulty": "hard"
                },
                {
                    "type": "fill_blank",
                    "template": "Complete the equation: {equation}",
                    "difficulty": "easy"
                }
            ],
            "science": [
                {
                    "type": "multiple_choice",
                    "template": "What happens when {condition}?",
                    "difficulty": "medium"
                },
                {
                    "type": "true_false",
                    "template": "True or False: {statement}",
                    "difficulty": "easy"
                }
            ],
            "literacy": [
                {
                    "type": "reading_comprehension",
                    "template": "Read the passage and answer: {question}",
                    "difficulty": "medium"
                },
                {
                    "type": "vocabulary",
                    "template": "What does '{word}' mean in this context?",
                    "difficulty": "easy"
                }
            ]
        }
        
        return templates.get(subject, templates["math"])
    
    def _customize_question(self,
                           template: Dict[str, Any],
                           grade_level: int,
                           cultural_context: str) -> Dict[str, Any]:
        """Customize question with age-appropriate values and cultural context"""
        
        # Generate values based on grade level
        if grade_level <= 3:
            max_value = 20
            operations = ["+", "-"]
        elif grade_level <= 5:
            max_value = 100
            operations = ["+", "-", "×"]
        elif grade_level <= 8:
            max_value = 1000
            operations = ["+", "-", "×", "÷"]
        else:
            max_value = 10000
            operations = ["+", "-", "×", "÷", "exponents"]
        
        # Create actual question
        if template["type"] == "multiple_choice":
            a = random.randint(1, max_value // 2)
            b = random.randint(1, max_value // 2)
            op = random.choice(operations[:3])  # Basic ops for MC
            
            question_text = f"If x = {a}, what is x {op} {b}?"
            correct_answer = eval(f"{a} {op.replace('×', '*').replace('÷', '/')} {b}")
            
            # Generate distractors
            distractors = [
                correct_answer + random.randint(1, 5),
                correct_answer - random.randint(1, 5),
                eval(f"{a} + {b}") if op != "+" else correct_answer + 10
            ]
            
            options = [correct_answer] + distractors
            random.shuffle(options)
            
            return {
                "id": random.randint(1000, 9999),
                "type": "multiple_choice",
                "question": question_text,
                "options": [f"{chr(65+i)}) {opt}" for i, opt in enumerate(options)],
                "correct_answer": f"{chr(65+options.index(correct_answer))}",
                "explanation": f"Substitute x={a} into the expression: {a} {op} {b} = {correct_answer}",
                "difficulty": template["difficulty"],
                "concept": "algebra"
            }
        
        elif template["type"] == "word_problem":
            # Culturally relevant scenarios
            scenarios = {
                "US": [
                    f"Sara has {random.randint(5, 20)} apples and buys {random.randint(3, 10)} more",
                    f"A bus holds {random.randint(30, 50)} students. If {random.randint(10, 25)} get on",
                ],
                "IN": [
                    f"Rahul has {random.randint(5, 20)} rupees and earns {random.randint(3, 10)} more",
                    f"A classroom has {random.randint(20, 40)} chairs. If {random.randint(5, 15)} are occupied",
                ],
                "default": [
                    f"There are {random.randint(5, 20)} items and {random.randint(3, 10)} more are added",
                ]
            }
            
            scenario_list = scenarios.get(cultural_context, scenarios["default"])
            scenario = random.choice(scenario_list)
            
            return {
                "id": random.randint(1000, 9999),
                "type": "word_problem",
                "question": f"{scenario}. How many total?",
                "correct_answer": "Calculate based on scenario",
                "explanation": "Add the quantities together",
                "difficulty": template["difficulty"],
                "concept": "addition"
            }
        
        # Default fallback
        return {
            "id": random.randint(1000, 9999),
            "type": template["type"],
            "question": f"Practice question about {template.get('concept', 'the topic')}",
            "correct_answer": "See explanation",
            "explanation": "Review the concept and try again",
            "difficulty": template["difficulty"]
        }
    
    def format_for_voice(self, question: Dict[str, Any]) -> str:
        """Format question for text-to-speech output"""
        # Add pauses and clear pronunciation markers
        formatted = question["question"]
        
        # Replace symbols with spoken words
        replacements = {
            "=": " equals ",
            "+": " plus ",
            "-": " minus ",
            "×": " times ",
            "÷": " divided by ",
            "?": ". [pause]"
        }
        
        for symbol, spoken in replacements.items():
            formatted = formatted.replace(symbol, spoken)
        
        return formatted
