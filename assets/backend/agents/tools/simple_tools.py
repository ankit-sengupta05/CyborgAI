"""
Simple, reliable desktop/web tools that actually execute.
These bypass the complex vision pipeline to guarantee real execution.
"""
import subprocess
import time
import os
import sys
import structlog
from langchain_core.tools import tool

log = structlog.get_logger(__name__)


@tool
def open_chrome_and_navigate(url: str) -> str:
    """Open Google Chrome and navigate to a specific URL.

    Args:
        url: The full URL to navigate to. Example: 'https://www.google.com/search?q=jobs'
    """
    try:
        # Find chrome executable
        chrome_paths = [
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            os.path.expanduser(r"~\AppData\Local\Google\Chrome\Application\chrome.exe"),
        ]
        chrome_exe = None
        for path in chrome_paths:
            if os.path.exists(path):
                chrome_exe = path
                break

        if chrome_exe:
            subprocess.Popen([chrome_exe, url])
            time.sleep(2.5)
            return f"✅ Opened Chrome and navigated to: {url}"
        else:
            # Fallback: use os.startfile / start command
            subprocess.Popen(["cmd", "/c", "start", "", url], shell=True)
            time.sleep(2.0)
            return f"✅ Launched browser for: {url}"
    except Exception as e:
        return f"❌ Failed to open browser: {e}"


@tool
def web_search_and_open(query: str) -> str:
    """Search Google for a query and open the results in Chrome.

    Args:
        query: The search query. Example: 'Data Scientist jobs New York LinkedIn'
    """
    import urllib.parse
    encoded = urllib.parse.quote_plus(query)
    url = f"https://www.google.com/search?q={encoded}"
    return open_chrome_and_navigate.invoke({"url": url})


@tool
def open_url_in_existing_chrome(url: str) -> str:
    """Open a URL in the user's currently running Chrome instance via keyboard shortcut.

    This focuses Chrome and uses Ctrl+T (new tab) then types the URL.
    Use this when Chrome is already open.

    Args:
        url: The full URL to navigate to.
    """
    try:
        import pygetwindow as gw
        import pyautogui
        pyautogui.FAILSAFE = False

        # Find Chrome window
        chrome_win = None
        for title in gw.getAllTitles():
            if "chrome" in title.lower() or "google" in title.lower():
                try:
                    wins = gw.getWindowsWithTitle(title)
                    if wins:
                        chrome_win = wins[0]
                        break
                except Exception:
                    pass

        if chrome_win:
            chrome_win.restore()
            chrome_win.activate()
            time.sleep(0.6)

        # Open new tab and type URL
        pyautogui.hotkey("ctrl", "t")
        time.sleep(0.5)
        pyautogui.hotkey("ctrl", "l")  # Focus address bar
        time.sleep(0.3)
        pyautogui.typewrite(url, interval=0.02)
        pyautogui.press("enter")
        time.sleep(2.0)
        return f"✅ Navigated Chrome to: {url}"
    except ImportError:
        return open_chrome_and_navigate.invoke({"url": url})
    except Exception as e:
        return f"❌ Error navigating Chrome: {e}"


@tool
def type_into_focused_window(text: str, press_enter: bool = False) -> str:
    """Type text into whichever window is currently focused on screen.

    Args:
        text: The text to type.
        press_enter: Whether to press Enter after typing.
    """
    try:
        import pyautogui
        pyautogui.FAILSAFE = False
        time.sleep(0.3)
        pyautogui.typewrite(text, interval=0.03)
        if press_enter:
            pyautogui.press("enter")
        return f"✅ Typed: '{text[:80]}'" + (" + Enter" if press_enter else "")
    except Exception as e:
        return f"❌ Type error: {e}"


@tool
def press_keyboard_shortcut(keys: str) -> str:
    """Press a keyboard shortcut on the current focused window.

    Args:
        keys: Keys to press. Examples: 'ctrl+t', 'enter', 'ctrl+l', 'alt+tab', 'ctrl+a'
    """
    try:
        import pyautogui
        pyautogui.FAILSAFE = False
        parts = [k.strip() for k in keys.split("+")]
        if len(parts) > 1:
            pyautogui.hotkey(*parts)
        else:
            pyautogui.press(parts[0])
        time.sleep(0.3)
        return f"✅ Pressed: {keys}"
    except Exception as e:
        return f"❌ Keyboard error: {e}"


@tool
def click_on_screen(x: int, y: int) -> str:
    """Click at specific pixel coordinates on the screen.

    Args:
        x: X coordinate in pixels.
        y: Y coordinate in pixels.
    """
    try:
        import pyautogui
        pyautogui.FAILSAFE = False
        pyautogui.click(x, y)
        time.sleep(0.3)
        return f"✅ Clicked at ({x}, {y})"
    except Exception as e:
        return f"❌ Click error: {e}"


@tool
def take_screen_snapshot() -> str:
    """Take a screenshot and save it to a temporary file. Returns the file path.
    Use this BEFORE visual_find_and_click to understand what is on screen.
    """
    try:
        import pyautogui
        import tempfile
        pyautogui.FAILSAFE = False
        path = os.path.join(tempfile.gettempdir(), "cyborg_snapshot.png")
        pyautogui.screenshot(path)
        size = os.path.getsize(path)
        return f"✅ Screenshot saved: {path} ({size} bytes). Screen resolution: {pyautogui.size()}"
    except Exception as e:
        return f"❌ Screenshot error: {e}"


@tool
def list_windows() -> str:
    """List all currently open application windows on the desktop."""
    try:
        import pygetwindow as gw
        titles = []
        for title in gw.getAllTitles():
            if title.strip():
                try:
                    titles.append(title.encode('ascii', errors='replace').decode('ascii'))
                except Exception:
                    pass
        return "Open windows:\n" + "\n".join(f"  • {t}" for t in titles[:30]) if titles else "No windows found."
    except Exception as e:
        return f"❌ Error listing windows: {e}"


@tool
def focus_window(window_title: str) -> str:
    """Bring a specific application window to the foreground.

    Args:
        window_title: Partial window title. Example: 'Chrome', 'Notepad', 'WhatsApp'
    """
    try:
        import pygetwindow as gw
        import pyautogui
        pyautogui.FAILSAFE = False

        matches = [t for t in gw.getAllTitles()
                   if window_title.lower() in t.lower() and t.strip()]
        if not matches:
            return f"❌ No window containing '{window_title}' found."

        w = gw.getWindowsWithTitle(matches[0])[0]
        w.restore()
        w.activate()
        time.sleep(0.6)
        return f"✅ Focused window: '{matches[0][:80]}'"
    except Exception as e:
        return f"❌ Focus error: {e}"


@tool
def read_screen_text_via_clipboard() -> str:
    """Extract all text from the current active window (e.g., Chrome) by simulating Ctrl+A, Ctrl+C.
    Returns the copied text. Use this to 'scrape' or read the current webpage or document.
    """
    try:
        import pyautogui
        import pyperclip
        pyautogui.FAILSAFE = False
        time.sleep(0.5)
        # Clear clipboard first
        pyperclip.copy("")
        pyautogui.hotkey("ctrl", "a")
        time.sleep(0.2)
        pyautogui.hotkey("ctrl", "c")
        time.sleep(0.5)
        pyautogui.press("esc")  # clear selection
        text = pyperclip.paste()
        if not text.strip():
            return "❌ No text found. Clipboard is empty. Are you sure the window is focused and selectable?"
        if len(text) > 30000:
            text = text[:30000] + "... [TRUNCATED]"
        return text
    except Exception as e:
        return f"❌ Clipboard read error: {e}"


@tool
def save_data_to_csv(file_path: str, data: list[dict]) -> str:
    """Save a list of dictionaries to a CSV or Excel-compatible file.
    Use this to autonomously update spreadsheets with extracted information (e.g., job listings, leads).

    Args:
        file_path: Absolute path to the .csv file (e.g., 'C:/Users/.../leads.csv')
        data: List of dictionaries representing rows (e.g., [{'Name': 'John', 'Phone': '123'}])
    """
    try:
        import csv
        import os
        
        if not data:
            return "❌ No data provided to save."
            
        file_path = os.path.abspath(file_path)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        
        file_exists = os.path.exists(file_path)
        keys = list(data[0].keys())
        
        with open(file_path, 'a', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=keys)
            if not file_exists:
                writer.writeheader()
            for row in data:
                writer.writerow(row)
                
        return f"✅ Successfully saved {len(data)} rows to {file_path}"
    except Exception as e:
        return f"❌ CSV save error: {e}"


ALL_SIMPLE_TOOLS = [
    open_chrome_and_navigate,
    web_search_and_open,
    open_url_in_existing_chrome,
    type_into_focused_window,
    press_keyboard_shortcut,
    click_on_screen,
    take_screen_snapshot,
    list_windows,
    focus_window,
    read_screen_text_via_clipboard,
    save_data_to_csv,
]
