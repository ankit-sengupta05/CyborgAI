"""
Progress Tracker for Adaptive Learning
Agent-based learning path optimization
"""

from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
import json
import os


class ProgressTracker:
    """
    Track student progress and optimize learning paths
    
    Features:
    - Knowledge gap identification
    - Learning velocity tracking
    - Personalized recommendations
    - Progress visualization data
    """
    
    def __init__(self, storage_path: str = "data/learning_progress"):
        self.storage_path = storage_path
        self.student_profiles = {}
        
        # Ensure storage directory exists
        os.makedirs(storage_path, exist_ok=True)
    
    def load_student_profile(self, student_id: str) -> Dict[str, Any]:
        """Load or create student profile"""
        profile_path = os.path.join(self.storage_path, f"{student_id}.json")
        
        if os.path.exists(profile_path):
            with open(profile_path, 'r') as f:
                return json.load(f)
        else:
            # Create new profile
            profile = {
                "student_id": student_id,
                "created_at": datetime.now().isoformat(),
                "subjects": {},
                "overall_stats": {
                    "total_assignments": 0,
                    "average_score": 0,
                    "improvement_rate": 0,
                    "time_spent_minutes": 0
                },
                "learning_path": [],
                "achievements": []
            }
            return profile
    
    def save_student_profile(self, student_id: str, profile: Dict[str, Any]):
        """Save student profile to disk"""
        profile_path = os.path.join(self.storage_path, f"{student_id}.json")
        
        with open(profile_path, 'w') as f:
            json.dump(profile, f, indent=2)
    
    def record_submission(self,
                         student_id: str,
                         subject: str,
                         grade_level: int,
                         score: int,
                         error_categories: List[Dict[str, str]],
                         time_spent_minutes: int = 0) -> Dict[str, Any]:
        """
        Record a homework submission and update progress
        
        Returns updated progress summary
        """
        profile = self.load_student_profile(student_id)
        
        # Initialize subject if new
        if subject not in profile["subjects"]:
            profile["subjects"][subject] = {
                "submissions": [],
                "weak_concepts": [],
                "strong_concepts": [],
                "average_score": 0,
                "trend": "stable"
            }
        
        subject_data = profile["subjects"][subject]
        
        # Add submission record
        submission = {
            "timestamp": datetime.now().isoformat(),
            "score": score,
            "grade_level": grade_level,
            "errors": error_categories,
            "time_spent": time_spent_minutes
        }
        subject_data["submissions"].append(submission)
        
        # Update average score
        all_scores = [s["score"] for s in subject_data["submissions"]]
        subject_data["average_score"] = sum(all_scores) / len(all_scores)
        
        # Identify weak concepts (errors appearing frequently)
        error_counts = {}
        for sub in subject_data["submissions"]:
            for error in sub.get("errors", []):
                error_type = error.get("type", "unknown")
                error_counts[error_type] = error_counts.get(error_type, 0) + 1
        
        # Weak concepts: errors occurring in >30% of submissions
        total_submissions = len(subject_data["submissions"])
        subject_data["weak_concepts"] = [
            {"concept": k, "frequency": v / total_submissions}
            for k, v in error_counts.items()
            if v / total_submissions > 0.3
        ]
        
        # Strong concepts: high scores on related questions
        if subject_data["average_score"] >= 85:
            subject_data["strong_concepts"].append({
                "concept": "general",
                "mastery_date": datetime.now().isoformat()
            })
        
        # Calculate trend
        if len(all_scores) >= 3:
            recent_avg = sum(all_scores[-3:]) / 3
            older_avg = sum(all_scores[:-3]) / len(all_scores[:-3]) if len(all_scores) > 3 else recent_avg
            
            if recent_avg > older_avg + 5:
                subject_data["trend"] = "improving"
            elif recent_avg < older_avg - 5:
                subject_data["trend"] = "declining"
            else:
                subject_data["trend"] = "stable"
        
        # Update overall stats
        profile["overall_stats"]["total_assignments"] += 1
        all_subject_scores = [
            s["average_score"] 
            for s in profile["subjects"].values()
        ]
        profile["overall_stats"]["average_score"] = (
            sum(all_subject_scores) / len(all_subject_scores)
            if all_subject_scores else 0
        )
        profile["overall_stats"]["time_spent_minutes"] += time_spent_minutes
        
        # Save updated profile
        self.save_student_profile(student_id, profile)
        
        return self.get_progress_summary(student_id, subject)
    
    def get_progress_summary(self, student_id: str, subject: Optional[str] = None) -> Dict[str, Any]:
        """Get progress summary for dashboard"""
        profile = self.load_student_profile(student_id)
        
        if subject:
            if subject not in profile["subjects"]:
                return {"error": "Subject not found"}
            
            subject_data = profile["subjects"][subject]
            
            return {
                "student_id": student_id,
                "subject": subject,
                "average_score": round(subject_data["average_score"], 1),
                "trend": subject_data["trend"],
                "total_submissions": len(subject_data["submissions"]),
                "weak_concepts": subject_data["weak_concepts"],
                "strong_concepts": subject_data["strong_concepts"],
                "recent_scores": [s["score"] for s in subject_data["submissions"][-5:]],
                "recommendations": self._generate_recommendations(subject_data)
            }
        else:
            # Overall summary
            return {
                "student_id": student_id,
                "overall_stats": profile["overall_stats"],
                "subjects": list(profile["subjects"].keys()),
                "recent_activity": self._get_recent_activity(profile)
            }
    
    def _generate_recommendations(self, subject_data: Dict[str, Any]) -> List[str]:
        """Generate personalized learning recommendations"""
        recommendations = []
        
        # Based on weak concepts
        for weak in subject_data.get("weak_concepts", []):
            recommendations.append(
                f"Practice {weak['concept']} problems to improve accuracy"
            )
        
        # Based on trend
        if subject_data.get("trend") == "declining":
            recommendations.append(
                "Consider reviewing foundational concepts before continuing"
            )
        elif subject_data.get("trend") == "improving":
            recommendations.append(
                "Great progress! Try more challenging problems"
            )
        
        # Based on average score
        avg = subject_data.get("average_score", 0)
        if avg < 60:
            recommendations.append(
                "Schedule extra practice time or seek additional help"
            )
        elif avg > 90:
            recommendations.append(
                "Ready for advanced topics - consider acceleration"
            )
        
        return recommendations[:3]  # Top 3 recommendations
    
    def _get_recent_activity(self, profile: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Get recent activity across all subjects"""
        activity = []
        
        for subject, data in profile["subjects"].items():
            if data["submissions"]:
                latest = data["submissions"][-1]
                activity.append({
                    "subject": subject,
                    "timestamp": latest["timestamp"],
                    "score": latest["score"],
                    "trend": data["trend"]
                })
        
        # Sort by timestamp descending
        activity.sort(key=lambda x: x["timestamp"], reverse=True)
        return activity[:5]  # Last 5 activities
    
    def generate_learning_path(self,
                               student_id: str,
                               subject: str,
                               weeks_ahead: int = 4) -> List[Dict[str, Any]]:
        """
        Generate personalized learning path for upcoming weeks
        
        Returns weekly learning plan
        """
        profile = self.load_student_profile(student_id)
        
        if subject not in profile["subjects"]:
            return []
        
        subject_data = profile["subjects"][subject]
        learning_path = []
        
        # Week 1-2: Focus on weak concepts
        for week in range(1, min(weeks_ahead + 1, 3)):
            learning_path.append({
                "week": week,
                "focus": "Remediation",
                "topics": [wc["concept"] for wc in subject_data["weak_concepts"][:2]],
                "goals": [
                    f"Improve accuracy on {wc['concept']} to 80%",
                    "Complete 5 practice problems daily"
                ],
                "resources": ["Practice worksheets", "Video tutorials"]
            })
        
        # Week 3+: Build on strengths and introduce new concepts
        for week in range(3, weeks_ahead + 1):
            learning_path.append({
                "week": week,
                "focus": "Advancement",
                "topics": ["New concept based on curriculum"],
                "goals": [
                    "Master new topic with 85%+ accuracy",
                    "Apply concepts to word problems"
                ],
                "resources": ["Textbook chapter", "Interactive exercises"]
            })
        
        return learning_path
    
    def visualize_progress(self, student_id: str, subject: str) -> Dict[str, Any]:
        """
        Generate data for progress visualization
        
        Returns chart-ready data structures
        """
        summary = self.get_progress_summary(student_id, subject)
        
        # Prepare chart data
        chart_data = {
            "score_trend": {
                "labels": [f"Assignment {i+1}" for i in range(len(summary.get("recent_scores", [])))],
                "datasets": [{
                    "label": "Scores",
                    "data": summary.get("recent_scores", []),
                    "borderColor": "#8b5cf6",
                    "tension": 0.1
                }]
            },
            "concept_mastery": {
                "labels": [wc["concept"] for wc in summary.get("weak_concepts", [])],
                "datasets": [{
                    "label": "Improvement Needed",
                    "data": [wc["frequency"] * 100 for wc in summary.get("weak_concepts", [])],
                    "backgroundColor": "#ef4444"
                }]
            }
        }
        
        return chart_data
