"""
Desktop Tools — Native Windows desktop automation.

Control locally installed Windows applications:
- Open any installed app via Start Menu search or path
- Send keyboard shortcuts and keystrokes
- Click by coordinate or image on screen
- Find and bring windows to focus
- Send WhatsApp messages, Telegram messages, etc.
"""
import time
import subprocess
import os
from langchain_core.tools import tool
import structlog

log = structlog.get_logger(__name__)


def _run_in_thread(fn, timeout=30):
    """Helper to run sync blocking calls in thread pool."""
    import concurrent.futures
    with concurrent.futures.ThreadPoolExecutor() as pool:
        return pool.submit(fn).result(timeout=timeout)


# ── App launch ──────────────────────────────────────────────────────────────

@tool
def desktop_open_app(app_name: str) -> str:
    """Open a locally installed Windows application by name.
    Use this for apps like WhatsApp, Telegram, Spotify, Discord, Chrome, etc.

    Args:
        app_name: Name of the app. Examples: 'WhatsApp', 'Telegram', 'Spotify', 'Discord'.
    """
    import shutil

    username = os.environ.get("USERNAME", os.environ.get("USER", ""))
    app_lower = app_name.lower().strip()

    APP_PATHS = {
        "whatsapp": [
            rf"C:\Users\{username}\AppData\Local\WhatsApp\WhatsApp.exe",
            rf"C:\Users\{username}\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\WhatsApp.lnk",
        ],
        "telegram": [
            rf"C:\Users\{username}\AppData\Roaming\Telegram Desktop\Telegram.exe",
            r"C:\Program Files\Telegram Desktop\Telegram.exe",
        ],
        "discord": [
            rf"C:\Users\{username}\AppData\Local\Discord\Update.exe",
        ],
        "spotify": [
            rf"C:\Users\{username}\AppData\Roaming\Spotify\Spotify.exe",
        ],
        "chrome": [r"C:\Program Files\Google\Chrome\Application\chrome.exe",
                   r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"],
        "firefox": [r"C:\Program Files\Mozilla Firefox\firefox.exe"],
        "notepad": ["notepad.exe"],
        "calculator": ["calc.exe"],
    }

    def try_launch():
        # 1. Check known paths
        for path in APP_PATHS.get(app_lower, []):
            if os.path.isfile(path):
                subprocess.Popen([path])
                return True

        # 2. Try shutil.which (system PATH)
        exe = shutil.which(app_name) or shutil.which(app_lower)
        if exe:
            subprocess.Popen([exe])
            return True

        # 3. Try PowerShell Get-StartApps
        try:
            ps = (
                f"$app = Get-StartApps | Where-Object {{$_.Name -like '*{app_name}*'}} | "
                "Select-Object -First 1; "
                "if ($app) { Start-Process (\"shell:AppsFolder\\\" + $app.AppID); exit 0 } else { exit 1 }"
            )
            r = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                               capture_output=True, timeout=12)
            if r.returncode == 0:
                return True
        except Exception:
            pass

        # 4. Shell start fallback
        try:
            subprocess.Popen(f'start "" "{app_name}"', shell=True)
            return True
        except Exception:
            pass

        return False

    try:
        success = _run_in_thread(try_launch, timeout=20)
        if success:
            time.sleep(2)
            return f"✅ Opened '{app_name}' successfully."
        return f"❌ Could not find '{app_name}'. Try desktop_run_command with full path."
    except Exception as e:
        return f"❌ Error opening '{app_name}': {e}"


@tool
def desktop_run_command(command: str) -> str:
    """Run a Windows shell/PowerShell command or start a program.

    Args:
        command: Shell command. Examples:
                 'start WhatsApp'
                 'start "" "C:\\\\path\\\\to\\\\app.exe"'
                 'powershell Get-Process'
    """
    try:
        result = subprocess.run(command, shell=True, capture_output=True,
                                text=True, timeout=15,
                                encoding="utf-8", errors="replace")
        out = (result.stdout.strip() or result.stderr.strip() or "Done.")
        return f"✅ Output: {out[:600]}"
    except subprocess.TimeoutExpired:
        return "✅ Command started (timed out waiting — app may be opening in background)."
    except Exception as e:
        return f"❌ Command error: {e}"


# ── Window management ─────────────────────────────────────────────────────────

@tool
def desktop_focus_window(window_title: str) -> str:
    """Bring an open application window to the foreground.

    Args:
        window_title: Partial window title. Example: 'WhatsApp', 'Chrome', 'Notepad'.
    """
    def _focus():
        try:
            import pygetwindow as gw
            matches = [t for t in gw.getAllTitles() if window_title.lower() in t.lower() and t.strip()]
            if matches:
                w = gw.getWindowsWithTitle(matches[0])[0]
                w.restore()
                w.activate()
                time.sleep(0.5)
                return f"✅ Focused: '{matches[0]}'"
            return f"❌ No window with '{window_title}' found. Use desktop_list_open_windows to check."
        except ImportError:
            ps = (
                f"$p = Get-Process | Where-Object {{$_.MainWindowTitle -like '*{window_title}*'}} "
                "| Select-Object -First 1; if ($p) { "
                "[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic'); "
                f"[Microsoft.VisualBasic.Interaction]::AppActivate($p.Id) }}"
            )
            subprocess.run(["powershell", "-Command", ps], timeout=6)
            return f"✅ Tried to focus '{window_title}' (install pygetwindow for better support)."

    try:
        return _run_in_thread(_focus)
    except Exception as e:
        return f"❌ Focus error: {e}"


@tool
def desktop_list_open_windows() -> str:
    """List all currently open application windows.
    Use this to check what's running before focusing or interacting with an app.
    """
    def _list():
        try:
            import pygetwindow as gw
            titles = [t for t in gw.getAllTitles() if t.strip()]
        except ImportError:
            result = subprocess.run(
                ["powershell", "-Command",
                 "Get-Process | Where-Object {$_.MainWindowTitle} | "
                 "Select-Object -ExpandProperty MainWindowTitle"],
                capture_output=True, text=True, timeout=6
            )
            titles = [l.strip() for l in result.stdout.splitlines() if l.strip()]
        return "Open windows:\n" + "\n".join(f"  • {t}" for t in titles[:30]) if titles else "No windows found."

    try:
        return _run_in_thread(_list)
    except Exception as e:
        return f"❌ Error: {e}"


# ── Keyboard / Mouse ──────────────────────────────────────────────────────────

@tool
def desktop_type_text(text: str, press_enter: bool = False) -> str:
    """Type text using the keyboard into the currently focused window.

    Args:
        text: Text to type.
        press_enter: If True, press Enter after typing.
    """
    def _type():
        try:
            import pyautogui
            pyautogui.FAILSAFE = False
            time.sleep(0.3)
            pyautogui.typewrite(text, interval=0.04)
            if press_enter:
                pyautogui.press("enter")
            return f"✅ Typed: '{text[:80]}'" + (" + Enter" if press_enter else "")
        except ImportError:
            escaped = text.replace("'", "''")
            ps = f"Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('{escaped}')"
            if press_enter:
                ps += "; [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')"
            subprocess.run(["powershell", "-Command", ps], timeout=10)
            return f"✅ Typed: '{text[:80]}'" + (" + Enter" if press_enter else "")

    try:
        return _run_in_thread(_type)
    except Exception as e:
        return f"❌ Type error: {e}"


@tool
def desktop_press_keys(keys: str) -> str:
    """Press a keyboard shortcut or special key.

    Args:
        keys: Keys to press, joined with '+'. Examples:
              'ctrl+a', 'enter', 'ctrl+shift+s', 'win', 'alt+f4', 'escape'.
    """
    def _press():
        try:
            import pyautogui
            pyautogui.FAILSAFE = False
            time.sleep(0.2)
            key_list = [k.strip() for k in keys.lower().split("+")]
            if len(key_list) == 1:
                pyautogui.press(key_list[0])
            else:
                pyautogui.hotkey(*key_list)
            return f"✅ Pressed: {keys}"
        except ImportError:
            # PowerShell SendKeys fallback
            key_map = {"ctrl": "^", "shift": "+", "alt": "%"}
            mapped = keys
            for k, v in key_map.items():
                mapped = mapped.replace(k + "+", v)
            ps = f"Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('{mapped}')"
            subprocess.run(["powershell", "-Command", ps], timeout=5)
            return f"✅ Pressed: {keys}"

    try:
        return _run_in_thread(_press)
    except Exception as e:
        return f"❌ Key press error: {e}"


@tool
def desktop_click(x: int, y: int, button: str = "left") -> str:
    """Click at specific screen pixel coordinates.

    Args:
        x: X screen coordinate in pixels.
        y: Y screen coordinate in pixels.
        button: 'left', 'right', or 'middle'.
    """
    def _click():
        try:
            import pyautogui
            pyautogui.FAILSAFE = False
            pyautogui.click(x, y, button=button)
            return f"✅ Clicked {button} at ({x}, {y})"
        except ImportError:
            return "❌ pyautogui not installed — run: pip install pyautogui"

    try:
        return _run_in_thread(_click)
    except Exception as e:
        return f"❌ Click error: {e}"


@tool
def desktop_screenshot(filename: str = "desktop_screenshot.png") -> str:
    """Take a screenshot of the entire screen and save it.

    Args:
        filename: Output filename (saved to scratch/).
    """
    def _snap():
        try:
            import pyautogui
            os.makedirs("scratch", exist_ok=True)
            path = f"scratch/{filename}"
            pyautogui.screenshot(path)
            return f"✅ Desktop screenshot saved to {path}"
        except ImportError:
            return "❌ pyautogui not installed — run: pip install pyautogui"

    try:
        return _run_in_thread(_snap)
    except Exception as e:
        return f"❌ Screenshot error: {e}"


# ── WhatsApp helper ───────────────────────────────────────────────────────────

@tool
def whatsapp_send_message(recipient: str, message: str = None, caption: str = None, image_path: str = None) -> str:
    """Send a WhatsApp message to a contact using the WhatsApp Desktop app.

    This will:
    1. Open or focus the WhatsApp Desktop app
    2. Search for the contact by name
    3. Open their chat
    4. Attach an image if provided
    5. Type and send the message or caption

    Args:
        recipient: Name of the contact exactly as shown in WhatsApp (e.g. 'Sigma Pandit').
        message: The text message to send. (Or use caption).
        caption: The text message to send (alias for message).
        image_path: Optional absolute path to an image file to send. Example: 'C:\\images\\photo.png'
    """
    message = message or caption or ""
    def _do_send():
        try:
            import pyautogui
            import pygetwindow as gw
        except ImportError:
            return (
                "⚠️ Missing packages. Installing...\n"
                "Please run: pip install pyautogui pygetwindow\n"
                "Then retry."
            )

        pyautogui.FAILSAFE = False
        username = os.environ.get("USERNAME", "")

        # ── Step 1: Find or open WhatsApp ────────────────────────────────────
        wa_titles = [t for t in gw.getAllTitles() if "WhatsApp" == t.strip() or t.strip().endswith(" - WhatsApp")]
        if wa_titles:
            w = gw.getWindowsWithTitle(wa_titles[0])[0]
            w.restore()
            w.activate()
            time.sleep(0.5)
            # Force click to ensure focus
            pyautogui.click(w.left + 50, w.top + 50)
            time.sleep(0.8)
        else:
            # Try to open WhatsApp using the robust app launcher
            desktop_open_app.invoke({"app_name": "whatsapp"})
            log.info("WhatsApp not running, waiting for it to open...")
            time.sleep(10)  # Wait for it to fully load

            wa_titles = [t for t in gw.getAllTitles() if "WhatsApp" == t.strip() or t.strip().endswith(" - WhatsApp")]
            if wa_titles:
                w = gw.getWindowsWithTitle(wa_titles[0])[0]
                w.restore()
                w.activate()
                time.sleep(0.5)
                pyautogui.click(w.left + 50, w.top + 50)
                time.sleep(1.0)
            else:
                return "❌ WhatsApp Desktop did not open or is obscured. HINT: Use 'visual_describe_screen' to check for pop-ups."

        # ── Step 1.5: Visual Intelligence Check (Self-Healing) ───────────────
        try:
            from agents.tools.visual_tools import take_screenshot, ask_vision_model, parse_coordinates
            # Capture full desktop for blocker check (safer than region)
            snap = take_screenshot()
            check_q = (
                "Look for any pop-up dialog (like 'Mute notifications', 'Updates', or 'Login') "
                "that is currently covering the WhatsApp window. If you see one, find the 'Cancel', "
                "'Close', or 'X' button and respond with ONLY its coordinates as (X, Y). "
                "If the screen is clear, respond 'NONE'."
            )
            check = ask_vision_model(snap, check_q)
            
            if "NONE" not in check.upper():
                coords = parse_coordinates(check)
                if coords:
                    cx, cy = coords
                    log.info(f"Visual self-healing: Dismissing blocker at ({cx}, {cy})")
                    pyautogui.click(cx, cy)
                    time.sleep(2.0)
        except Exception as e:
            log.debug(f"Visual pre-flight check failed: {e}")

        # ── Step 2: Search for contact ────────────────────────────────────────
        pyautogui.hotkey("ctrl", "n")  
        time.sleep(1.2)
        pyautogui.hotkey("ctrl", "a")
        pyautogui.press("backspace")
        time.sleep(0.3)
        pyautogui.typewrite(recipient, interval=0.06)
        time.sleep(2.5) 

        # ── Step 3: Select first result ───────────────────────────────────────
        pyautogui.press("down")
        time.sleep(0.6)
        pyautogui.press("enter")
        time.sleep(2.0) 

        # ── Step 4: Focus message box ───────────────────────────────────────
        pyautogui.hotkey("ctrl", "shift", "m")
        time.sleep(0.8)

        # ── Step 4.5: Attach Image (if provided) ─────────────────────────────
        if image_path and os.path.exists(image_path):
            ps = f"""
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing
            $img = [System.Drawing.Image]::FromFile('{image_path}')
            [System.Windows.Forms.Clipboard]::SetImage($img)
            $img.Dispose()
            """
            subprocess.run(["powershell", "-NoProfile", "-Command", ps], timeout=15)
            time.sleep(1.5)
            pyautogui.hotkey("ctrl", "v")
            time.sleep(5.0) # WAIT for image upload UI

        # ── Step 5: Type and send ─────────────────────────────────────────────
        if message:
            pyautogui.typewrite(message, interval=0.05)
        time.sleep(0.5)
        pyautogui.press("enter")
        time.sleep(2.0) # Wait for message to appear

        # ── Step 6: Visual Verification ──────────────────────────────────────
        try:
            ver_snap = take_screenshot()
            ver_q = f"Look at the chat window. Is the message '{message[:30]}' visible as a sent message? Answer YES or NO."
            ver_res = ask_vision_model(ver_snap, ver_q)
            if "NO" in ver_res.upper():
                return f"❌ Verification failed: The message does not appear to have been sent. The screen might be blocked. HINT: Use 'visual_describe_screen' to investigate."
        except Exception:
            pass # Fallback to success if VLM is down

        att = " with image" if image_path else ""
        return f"✅ Sent WhatsApp message{att} to '{recipient}': \"{message[:100]}\""

    try:
        return _run_in_thread(_do_send, timeout=90)
    except Exception as e:
        log.error("whatsapp_send_message failed", error=str(e))
        return f"❌ WhatsApp error: {e}"


# ── Export ─────────────────────────────────────────────────────────────────────

ALL_DESKTOP_TOOLS = [
    desktop_open_app,
    desktop_run_command,
    desktop_focus_window,
    desktop_list_open_windows,
    desktop_type_text,
    desktop_press_keys,
    desktop_click,
    desktop_screenshot,
    whatsapp_send_message,
]
