"""
Visual Intelligence Tools — See the screen, understand it, act on it.

Uses the loaded vision model (Gemma-4 Vision + mmproj) to:
- Take a desktop or browser screenshot
- Ask the model where a UI element is (returns coordinates)
- Click, type, or interact at those coordinates

This gives the agent true "eyes" — it can navigate any UI without 
needing CSS selectors or pre-mapped element IDs.
"""
import os
import time
import base64
import subprocess
import tempfile
from pathlib import Path
from langchain_core.tools import tool
import structlog

log = structlog.get_logger(__name__)

# Will be injected by app startup
_llm_service = None
_app_state = None


def set_services(llm_service, app_state=None):
    """Called during app startup to inject the LLM service for vision inference."""
    global _llm_service, _app_state
    _llm_service = llm_service
    _app_state = app_state


def take_screenshot(region=None) -> str:
    """Take a screenshot and return the path."""
    import pyautogui
    pyautogui.FAILSAFE = False
    tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False, prefix="cyborg_vision_")
    path = tmp.name
    tmp.close()
    if region:
        img = pyautogui.screenshot(region=region)
    else:
        img = pyautogui.screenshot()
    img.save(path)
    return path


def _image_to_b64(path: str) -> str:
    """Convert image file to base64 data URL."""
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode("utf-8")
    return f"data:image/png;base64,{data}"


def ask_vision_model(image_path: str, question: str) -> str:
    """
    Send a screenshot to the loaded vision model and ask a question.
    Returns the model's text response.
    """
    if not _llm_service or not _llm_service._llm:
        return "Vision model not available."

    if not _llm_service.supports_vision:
        return "Vision projector not loaded — restart with a model that has an mmproj file."

    try:
        b64 = _image_to_b64(image_path)
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": b64}
                    },
                    {
                        "type": "text",
                        "text": question
                    }
                ]
            }
        ]

        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor() as pool:
            def run():
                with _llm_service._inference_lock:
                    result = _llm_service._llm.create_chat_completion(
                        messages=messages,
                        max_tokens=300,
                        temperature=0.1,
                        stream=False,
                    )
                    return result["choices"][0]["message"]["content"]
            return pool.submit(run).result(timeout=60)
    except Exception as e:
        log.error("Vision model inference failed", error=str(e))
        return f"Vision error: {e}"
    finally:
        try:
            os.unlink(image_path)
        except Exception:
            pass


def parse_coordinates(text: str):
    """
    Parse X, Y coordinates from vision model response.
    Handles formats like: (640, 480), x=640 y=480, 640, 480, [640, 480]
    Returns (x, y) tuple or None, automatically scaled to screen resolution if normalized.
    """
    import re
    try:
        import pyautogui
        screen_width, screen_height = pyautogui.size()
    except Exception:
        screen_width, screen_height = 1920, 1080

    # Try common patterns
    patterns = [
        r'\((\d+)[,\s]+(\d+)\)',          # (640, 480)
        r'\[(\d+)[,\s]+(\d+)\]',          # [640, 480]
        r'x\s*[=:]\s*(\d+).*?y\s*[=:]\s*(\d+)',  # x=640 y=480
        r'(\d{1,4})[,\s]+(\d{1,4})',      # 640, 480  (loose)
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            x, y = int(m.group(1)), int(m.group(2))
            
            # Check for percentage coordinates (0-100)
            if 0 < x <= 100 and 0 < y <= 100:
                x = int((x / 100.0) * screen_width)
                y = int((y / 100.0) * screen_height)
            # Check for standard VLM normalized coordinates (0-1000)
            elif 0 < x <= 1000 and 0 < y <= 1000:
                if screen_width > 1000 or screen_height > 1000:
                    x = int((x / 1000.0) * screen_width)
                    y = int((y / 1000.0) * screen_height)
            
            # Sanity check: reasonable screen coordinates
            if 0 < x < 7680 and 0 < y < 4320:
                return x, y
    return None


# ── Tools ────────────────────────────────────────────────────────────────────

@tool
def visual_find_and_click(description: str, context: str = "desktop") -> str:
    """
    Use the AI's vision to find a UI element on screen by description and click it.

    This takes a screenshot, sends it to the vision model, asks where the element is,
    then clicks those exact pixel coordinates. Works on ANY app — Instagram, WhatsApp,
    browsers, desktop apps — without needing CSS selectors.

    Args:
        description: What to look for. Be specific. Examples:
                     'the Login button', 'the username text field',
                     'the blue Post button', 'the WhatsApp search bar',
                     'the + Create button in Instagram'.
        context: 'desktop' for the full screen, 'browser' for the browser window.
    """
    try:
        import pyautogui
        pyautogui.FAILSAFE = False

        # Take screenshot
        screenshot_path = take_screenshot()

        # Ask vision model for coordinates
        question = (
            f"Look at this screenshot carefully. Find: {description}.\n"
            f"Respond with ONLY the pixel coordinates in the format (X, Y). "
            f"Example: (640, 480). Do not explain, just give coordinates."
        )
        response = ask_vision_model(screenshot_path, question)
        log.info(f"Vision model response for '{description}': {response}")

        coords = parse_coordinates(response)
        if not coords:
            return (
                f"⚠️ Could not parse coordinates from vision response: '{response}'\n"
                f"Try using desktop_screenshot() to see the current screen state, "
                f"then use desktop_click(x, y) with manual coordinates."
            )

        x, y = coords
        time.sleep(0.3)
        pyautogui.click(x, y)
        time.sleep(0.5)
        return f"✅ Found '{description}' at ({x}, {y}) and clicked it."

    except ImportError:
        return "❌ pyautogui not installed. Run: pip install pyautogui"
    except Exception as e:
        return f"❌ Visual click error: {e}"


@tool
def visual_find_and_type(description: str, text: str, press_enter: bool = False) -> str:
    """
    Use vision to find a text input field on screen, click it, then type text.

    Args:
        description: The input field to find. Examples:
                     'the username field', 'the search box', 'the message input',
                     'the caption text area'.
        text: Text to type into the field.
        press_enter: Whether to press Enter after typing.
    """
    try:
        import pyautogui
        pyautogui.FAILSAFE = False

        screenshot_path = take_screenshot()
        question = (
            f"Find this input field in the screenshot: {description}.\n"
            f"Give ONLY the pixel coordinates (X, Y) of the center of that field. "
            f"Format: (X, Y). Example: (512, 300)."
        )
        response = ask_vision_model(screenshot_path, question)
        coords = parse_coordinates(response)

        if not coords:
            return f"⚠️ Couldn't locate '{description}'. Vision response: '{response}'"

        x, y = coords
        pyautogui.click(x, y)
        time.sleep(0.4)
        pyautogui.hotkey("ctrl", "a")  # Select all existing text
        time.sleep(0.1)
        pyautogui.typewrite(text, interval=0.04)
        if press_enter:
            pyautogui.press("enter")

        return (
            f"✅ Found '{description}' at ({x}, {y}), clicked and typed: '{text[:60]}'"
            + (" + Enter" if press_enter else "")
        )
    except ImportError:
        return "❌ pyautogui not installed."
    except Exception as e:
        return f"❌ Visual type error: {e}"


@tool
def visual_describe_screen(area: str = "full screen") -> str:
    """
    Take a screenshot and ask the vision model to describe what it sees.

    Use this to understand the current state of any app or webpage before
    deciding which element to click. Essential for navigation and debugging.

    Args:
        area: What to describe: 'full screen', 'center', 'top', 'bottom'.
    """
    try:
        screenshot_path = take_screenshot()
        question = (
            f"Describe what you see on this {area}. Focus on:\n"
            f"1. What application/website is open?\n"
            f"2. What UI elements are visible (buttons, text fields, menus)?\n"
            f"3. What is the current state (login page, feed, chat, etc.)?\n"
            f"Be specific and concise. List clickable elements with approximate locations."
        )
        response = ask_vision_model(screenshot_path, question)
        return f"👁️ Screen description:\n{response}"
    except Exception as e:
        return f"❌ Visual describe error: {e}"


@tool
def visual_verify_action(expected_result: str) -> str:
    """
    Take a screenshot and verify whether an expected UI state is now visible.
    Use this AFTER clicking a button to confirm it worked.

    Args:
        expected_result: What you expect to see. Examples:
                         'Instagram feed is visible (logged in)',
                         'WhatsApp message was sent (checkmark visible)',
                         'The file upload dialog is open'.
    """
    try:
        screenshot_path = take_screenshot()
        question = (
            f"Look at this screenshot. Is this true: '{expected_result}'?\n"
            f"Answer YES or NO, then briefly explain what you actually see."
        )
        response = ask_vision_model(screenshot_path, question)
        icon = "✅" if response.upper().startswith("YES") else "❌"
        return f"{icon} Verification: {response}"
    except Exception as e:
        return f"❌ Verify error: {e}"


@tool
def browser_upload_file(file_path: str, selector: str = "input[type='file']") -> str:
    """
    Upload a local file to a browser file input element using Playwright.
    Use this for Instagram/Facebook photo posts — it handles the file picker dialog.

    Args:
        file_path: Absolute local path to the file. Example:
                   'C:\\Users\\ankit\\OneDrive\\Pictures\\photo.png'
        selector: CSS selector for the file input. Default works for most sites.
    """
    if not os.path.exists(file_path):
        return f"❌ File not found: {file_path}"

    # Try to use the browser_tools Playwright session
    try:
        from agents.tools.browser_tools import _get_page
        import asyncio

        async def _upload():
            page = await _get_page()
            # Try direct file input
            try:
                file_input = page.locator(selector).first
                await file_input.set_input_files(file_path)
                return f"✅ File uploaded via input element: {Path(file_path).name}"
            except Exception:
                pass

            # Fallback: find ANY file input on the page
            inputs = page.locator("input[type='file']")
            count = await inputs.count()
            if count > 0:
                await inputs.first.set_input_files(file_path)
                return f"✅ File uploaded via discovered input: {Path(file_path).name}"

            return "❌ No file input found on page. Try clicking the upload button first."

        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, _upload())
                return future.result(timeout=30)
        else:
            return asyncio.run(_upload())

    except Exception as e:
        return f"❌ File upload error: {e}"


@tool
def visual_screenshot_and_analyze(question: str) -> str:
    """
    Take a screenshot of the current screen and answer a specific question about it.
    Use this to check page state, find elements, or debug automation issues.

    Args:
        question: Any question about the current screen. Examples:
                  'Is the Instagram login page visible?'
                  'Where is the message send button?'
                  'Is there a popup or dialog blocking the screen?'
    """
    try:
        screenshot_path = take_screenshot()
        response = ask_vision_model(screenshot_path, question)
        return f"👁️ Answer: {response}"
    except Exception as e:
        return f"❌ Error: {e}"


# ── Export ─────────────────────────────────────────────────────────────────────

ALL_VISUAL_TOOLS = [
    visual_find_and_click,
    visual_find_and_type,
    visual_describe_screen,
    visual_verify_action,
    visual_screenshot_and_analyze,
    browser_upload_file,
]
