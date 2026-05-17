"""
Browser Tools — Agentic browser automation for navigating, extracting, and interacting with web UI.
Provides a set of LangChain tools to control a Playwright browser instance.
"""
import asyncio
from typing import Optional, Dict, Any
from langchain_core.tools import tool
import structlog
from playwright.async_api import async_playwright, Page, Browser, BrowserContext

log = structlog.get_logger(__name__)

# Global singleton for the browser instance
_browser: Optional[Browser] = None
_context: Optional[BrowserContext] = None
_page: Optional[Page] = None
_playwright = None

async def _get_page() -> Page:
    """Initialize or return the existing Playwright page."""
    global _browser, _context, _page, _playwright
    if _page is not None and not _page.is_closed():
        return _page

    if _playwright is None:
        _playwright = await async_playwright().start()

    if _browser is None:
        _browser = await _playwright.chromium.launch(headless=False)
    
    if _context is None:
        # Create a persistent-like context with common user agent to reduce bot detection
        _context = await _browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
    
    if _page is None or _page.is_closed():
        _page = await _context.new_page()
    
    return _page

@tool
async def browser_navigate(url: str) -> str:
    """Navigate the browser to a specific URL and wait for it to load.
    
    Args:
        url: The full URL to navigate to (e.g., 'https://x.com/login').
    """
    try:
        page = await _get_page()
        await page.goto(url, wait_until="networkidle")
        title = await page.title()
        return f"Successfully navigated to {url}. Page title is '{title}'."
    except Exception as e:
        log.error("browser_navigate_error", error=str(e), url=url)
        return f"Error navigating to {url}: {e}"

@tool
async def browser_click(selector: str) -> str:
    """Click an element on the page using a CSS selector or text matching.
    
    Args:
        selector: CSS selector, 'text="Button Text"', or just a plain string to search for in text/labels.
    """
    try:
        page = await _get_page()
        
        # Strategy 1: Try direct selector/text match
        try:
            await page.click(selector, timeout=3000)
            await page.wait_for_load_state("networkidle", timeout=1000)
            return f"Successfully clicked element: {selector}"
        except:
            pass
            
        # Strategy 2: Visual Intelligence Fallback — Search for text content
        # This handles buttons that don't have stable IDs (like Instagram/X)
        found = await page.evaluate(f'''(text) => {{
            const els = Array.from(document.querySelectorAll('button, a, [role="button"], input[type="button"], input[type="submit"]'));
            const target = els.find(el => 
                el.innerText.toLowerCase().includes(text.toLowerCase()) || 
                (el.getAttribute('aria-label') && el.getAttribute('aria-label').toLowerCase().includes(text.toLowerCase())) ||
                (el.getAttribute('placeholder') && el.getAttribute('placeholder').toLowerCase().includes(text.toLowerCase()))
            );
            if (target) {{
                target.click();
                return true;
            }}
            return false;
        }}''', selector)
        
        if found:
            await page.wait_for_load_state("networkidle", timeout=1000)
            return f"Successfully found and clicked '{selector}' via visual text search."
            
        return f"Error: Could not find clickable element matching '{selector}' using selectors or text search."
    except Exception as e:
        return f"Error clicking element '{selector}': {e}"

@tool
async def browser_wait_for_load(seconds: int = 5) -> str:
    """Wait for the page to finish loading or for a specific duration.
    Use this if a page is slow or after a login submission.
    """
    try:
        page = await _get_page()
        await page.wait_for_timeout(seconds * 1000)
        return f"Waited for {seconds} seconds."
    except Exception as e:
        return f"Error waiting: {e}"

@tool
async def browser_type_text(selector: str, text: str) -> str:
    """Type text into an input field on the page.
    
    Args:
        selector: CSS selector, placeholder text, aria-label, name, or element index from browser_get_interactive_elements.
        text: The text to type.
    """
    try:
        page = await _get_page()
        
        # Strategy 1: Try direct CSS selector
        try:
            await page.fill(selector, text, timeout=2000)
            return f"Successfully typed text into element: {selector}"
        except:
            pass
            
        # Strategy 2: If it's a number, try index from browser_get_interactive_elements
        if selector.isdigit():
            idx = int(selector)
            found = await page.evaluate(f'''(idx, val) => {{
                const interactive = document.querySelectorAll('button, a, input, [role="button"], [onclick], select, textarea');
                if (idx >= 0 && idx < interactive.length) {{
                    const el = interactive[idx];
                    el.focus();
                    el.value = val;
                    el.dispatchEvent(new Event('input', {{ bubbles: true }}));
                    el.dispatchEvent(new Event('change', {{ bubbles: true }}));
                    return true;
                }}
                return false;
            }}''', idx, text)
            if found:
                return f"Successfully typed text into element index [{idx}]."
                
        # Strategy 3: Try text match / placeholder / aria-label
        found = await page.evaluate(f'''(sel, val) => {{
            const els = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"]'));
            const target = els.find(el => 
                (el.getAttribute('placeholder') && el.getAttribute('placeholder').toLowerCase().includes(sel.toLowerCase())) ||
                (el.getAttribute('aria-label') && el.getAttribute('aria-label').toLowerCase().includes(sel.toLowerCase())) ||
                (el.name && el.name.toLowerCase().includes(sel.toLowerCase())) ||
                (el.id && el.id.toLowerCase().includes(sel.toLowerCase()))
            );
            if (target) {{
                target.focus();
                target.value = val;
                target.dispatchEvent(new Event('input', {{ bubbles: true }}));
                target.dispatchEvent(new Event('change', {{ bubbles: true }}));
                return true;
            }}
            return false;
        }}''', selector, text)
        
        if found:
            return f"Successfully found and typed text into '{selector}' via placeholder/name search."
            
        return f"Error: Could not find input field matching '{selector}' using selectors or text search."
    except Exception as e:
        return f"Error typing into '{selector}': {e}"

@tool
async def browser_get_html() -> str:
    """Get the raw HTML content of the current page for analysis.
    Useful to find exact selectors or read content.
    """
    try:
        page = await _get_page()
        html = await page.content()
        # Truncate if too large to avoid blowing up context window
        if len(html) > 50000:
            return html[:50000] + "... [HTML truncated due to size]"
        return html
    except Exception as e:
        return f"Error getting HTML: {e}"

@tool
async def browser_get_text() -> str:
    """Get the visible text content of the current page."""
    try:
        page = await _get_page()
        text = await page.evaluate("document.body.innerText")
        return text[:10000] # truncate
    except Exception as e:
        return f"Error getting text: {e}"

@tool
async def browser_take_screenshot(filename: str = "screenshot.png") -> str:
    """Take a screenshot of the current page and save it to disk.
    
    Args:
        filename: Name of the file (e.g. 'twitter_login.png'). Will be saved in scratch/
    """
    try:
        page = await _get_page()
        path = f"scratch/{filename}"
        await page.screenshot(path=path)
        return f"Screenshot saved to {path}"
    except Exception as e:
        return f"Error taking screenshot: {e}"

@tool
async def browser_close() -> str:
    """Close the active browser session when finished."""
    global _browser, _context, _page, _playwright
    try:
        if _page:
            await _page.close()
            _page = None
        if _context:
            await _context.close()
            _context = None
        if _browser:
            await _browser.close()
            _browser = None
        if _playwright:
            await _playwright.stop()
            _playwright = None
        return "Browser session closed successfully."
    except Exception as e:
        return f"Error closing browser: {e}"

@tool
async def browser_get_interactive_elements() -> str:
    """Get a structured list of all clickable or interactive elements on the current page.
    Use this to find buttons, links, and inputs when raw HTML is too complex.
    """
    try:
        page = await _get_page()
        # Extract interactive elements using a client-side script
        elements = await page.evaluate('''() => {
            const results = [];
            const interactive = document.querySelectorAll('button, a, input, [role="button"], [onclick], select, textarea');
            interactive.forEach((el, index) => {
                const rect = el.getBoundingClientRect();
                if (rect.width > 0 && rect.height > 0 && window.getComputedStyle(el).visibility !== 'hidden') {
                    results.push({
                        index: index,
                        tag: el.tagName.toLowerCase(),
                        text: el.innerText || el.value || el.getAttribute('placeholder') || el.getAttribute('aria-label') || "",
                        role: el.getAttribute('role') || "",
                        type: el.getAttribute('type') || ""
                    });
                }
            });
            return results.slice(0, 50); // Limit to top 50
        }''')
        if not elements:
            return "No interactive elements found on the current view."
        
        output = "Interactive elements found:\n"
        for el in elements:
            text = el['text'].strip().replace("\n", " ")
            output += f"- [{el['index']}] {el['tag']}{' ('+el['role']+')' if el['role'] else ''}: \"{text[:50]}\"\n"
        return output
    except Exception as e:
        return f"Error getting elements: {e}"

@tool
async def browser_click_coords(x: int, y: int) -> str:
    """Click at specific screen coordinates [x, y]. Use only if selector-based clicking fails.
    
    Args:
        x: X coordinate (pixels).
        y: Y coordinate (pixels).
    """
    try:
        page = await _get_page()
        await page.mouse.click(x, y)
        return f"Successfully clicked at coordinates [{x}, {y}]"
    except Exception as e:
        return f"Error clicking at coordinates [{x}, {y}]: {e}"

@tool
def browser_get_credentials() -> str:
    """Fetch the user's saved social media credentials (usernames and passwords) for logging in."""
    import json
    import os
    path = "data/social_credentials.json"
    if not os.path.exists(path):
        return "No credentials saved. Please ask the user to enter them in the Settings tab."
    try:
        with open(path, "r", encoding="utf-8") as f:
            creds = json.load(f)
            return f"Saved credentials:\n" + "\n".join([f"{k}: {v}" for k, v in creds.items() if v])
    except Exception as e:
        return f"Error reading credentials: {e}"

ALL_BROWSER_TOOLS = [
    browser_navigate,
    browser_click,
    browser_type_text,
    browser_wait_for_load,
    browser_get_html,
    browser_get_text,
    browser_get_interactive_elements,
    browser_click_coords,
    browser_take_screenshot,
    browser_close,
    browser_get_credentials
]
