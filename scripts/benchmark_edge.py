#!/usr/bin/env python3
"""
Gemma 4 Edge Deployment Script
Benchmark latency and accuracy on target edge devices (Raspberry Pi 4, Jetson Nano, Android Go)
"""

import time
import argparse
import json
import os
import sys
import statistics

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'assets', 'backend'))


def benchmark_xray_analysis(num_runs: int = 5, image_path: str = None) -> dict:
    """Benchmark MedGemma X-ray analysis latency"""
    print(f"\n🏥 Benchmarking X-ray Analysis ({num_runs} runs)...")
    
    try:
        from services.health.inference import MedGemmaPipeline
        pipeline = MedGemmaPipeline.get_instance()
    except Exception as e:
        print(f"  ⚠️ Could not load pipeline: {e}")
        return {"error": str(e)}

    # Use test image or create synthetic one
    test_image = image_path
    if not test_image or not os.path.exists(test_image):
        try:
            from PIL import Image
            import tempfile
            img = Image.new("RGB", (512, 512), color=(200, 200, 200))
            tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
            img.save(tmp.name)
            test_image = tmp.name
            print("  ℹ️  Using synthetic test image")
        except Exception:
            return {"error": "No test image available"}

    latencies = []
    for i in range(num_runs):
        start = time.perf_counter()
        try:
            pipeline.analyze_xray(test_image, patient_context={"age": 45, "symptoms": ["cough"]})
            elapsed = time.perf_counter() - start
            latencies.append(elapsed)
            print(f"  Run {i+1}/{num_runs}: {elapsed:.2f}s")
        except Exception as e:
            print(f"  Run {i+1}/{num_runs}: ERROR — {e}")

    if not latencies:
        return {"error": "All runs failed"}

    return {
        "task": "xray_analysis",
        "runs": num_runs,
        "mean_s": round(statistics.mean(latencies), 2),
        "median_s": round(statistics.median(latencies), 2),
        "stdev_s": round(statistics.stdev(latencies), 3) if len(latencies) > 1 else 0,
        "min_s": round(min(latencies), 2),
        "max_s": round(max(latencies), 2),
        "target_s": 18,
        "passes": statistics.mean(latencies) <= 18,
    }


def benchmark_homework_grading(num_runs: int = 5, image_path: str = None) -> dict:
    """Benchmark HomeworkGrader latency"""
    print(f"\n🎓 Benchmarking Homework Grading ({num_runs} runs)...")

    try:
        from services.education.grader import HomeworkGrader
        grader = HomeworkGrader()
    except Exception as e:
        return {"error": str(e)}

    test_image = image_path
    if not test_image or not os.path.exists(test_image):
        try:
            from PIL import Image
            import tempfile
            img = Image.new("RGB", (640, 480), color=(255, 255, 255))
            tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
            img.save(tmp.name)
            test_image = tmp.name
        except Exception:
            return {"error": "No test image available"}

    latencies = []
    for i in range(num_runs):
        start = time.perf_counter()
        try:
            grader.grade_submission(test_image, subject="math", grade_level=5, language="en")
            elapsed = time.perf_counter() - start
            latencies.append(elapsed)
            print(f"  Run {i+1}/{num_runs}: {elapsed:.2f}s")
        except Exception as e:
            print(f"  Run {i+1}/{num_runs}: ERROR — {e}")

    if not latencies:
        return {"error": "All runs failed"}

    return {
        "task": "homework_grading",
        "runs": num_runs,
        "mean_s": round(statistics.mean(latencies), 2),
        "median_s": round(statistics.median(latencies), 2),
        "stdev_s": round(statistics.stdev(latencies), 3) if len(latencies) > 1 else 0,
        "min_s": round(min(latencies), 2),
        "max_s": round(max(latencies), 2),
        "target_s": 15,
        "passes": statistics.mean(latencies) <= 15,
    }


def get_device_info() -> dict:
    """Collect device hardware info"""
    info = {"platform": sys.platform, "python": sys.version.split()[0]}
    try:
        import psutil
        info["ram_gb"] = round(psutil.virtual_memory().total / 1024**3, 1)
        info["cpu_cores"] = os.cpu_count()
    except ImportError:
        pass
    try:
        import torch
        info["cuda"] = torch.cuda.is_available()
        if info["cuda"]:
            info["gpu"] = torch.cuda.get_device_name(0)
    except ImportError:
        info["cuda"] = False
    return info


def main():
    parser = argparse.ArgumentParser(description="Benchmark Gemma 4 edge deployment")
    parser.add_argument("--runs", type=int, default=3, help="Number of benchmark runs")
    parser.add_argument("--xray-image", help="Path to test X-ray image")
    parser.add_argument("--hw-image", help="Path to test homework image")
    parser.add_argument("--output", default="benchmark_results.json", help="Output JSON path")
    parser.add_argument("--skip-xray", action="store_true")
    parser.add_argument("--skip-edu", action="store_true")
    args = parser.parse_args()

    print("=" * 60)
    print("🔬 Cyborg AGI — Gemma 4 Edge Benchmark")
    print("=" * 60)

    device = get_device_info()
    print(f"\n📱 Device: {device}")

    results = {"device": device, "benchmarks": {}}

    if not args.skip_xray:
        results["benchmarks"]["xray"] = benchmark_xray_analysis(args.runs, args.xray_image)

    if not args.skip_edu:
        results["benchmarks"]["homework"] = benchmark_homework_grading(args.runs, args.hw_image)

    # Summary
    print("\n" + "=" * 60)
    print("📊 BENCHMARK SUMMARY")
    print("=" * 60)
    all_pass = True
    for task, r in results["benchmarks"].items():
        if "error" in r:
            print(f"  ❌ {task}: ERROR — {r['error']}")
            all_pass = False
        else:
            status = "✅ PASS" if r["passes"] else "❌ FAIL"
            print(f"  {status} {task}: {r['mean_s']}s avg (target: <{r['target_s']}s)")
            if not r["passes"]:
                all_pass = False

    with open(args.output, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n📄 Results saved to {args.output}")
    print(f"\n{'🎉 All benchmarks passed!' if all_pass else '⚠️  Some benchmarks failed — check device specs'}")


if __name__ == "__main__":
    main()
