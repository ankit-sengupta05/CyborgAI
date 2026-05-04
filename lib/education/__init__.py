"""
Education Track Module Initialization  
Adaptive learning agent with Gemma 4 integration
"""

from .adaptive_tutor.grader import HomeworkGrader
from .adaptive_tutor.quiz_generator import QuizGenerator
from .adaptive_tutor.progress_tracker import ProgressTracker

__all__ = [
    "HomeworkGrader",
    "QuizGenerator", 
    "ProgressTracker"
]

# Version info
__version__ = "1.0.0"
__author__ = "Cyborg AGI Team"
