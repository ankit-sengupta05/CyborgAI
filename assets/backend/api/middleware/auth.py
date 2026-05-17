"""
Firebase Authentication Middleware
- With service account: full token verification
- Without service account (dev mode): allows all local requests through
  so you can develop without setting up Firebase admin
"""
import structlog
from pathlib import Path
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
import firebase_admin
from firebase_admin import credentials, auth as fb_auth

from config.settings import settings

log = structlog.get_logger(__name__)

PUBLIC_PATHS = {"/api/v1/health", "/api/docs", "/api/redoc", "/openapi.json"}

_firebase_initialized = False
_full_auth_enabled = False


def _init_firebase():
    global _firebase_initialized, _full_auth_enabled
    if _firebase_initialized:
        return

    sa_path = Path(settings.firebase_service_account_path)
    if sa_path.exists():
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(str(sa_path))
                firebase_admin.initialize_app(cred)
            _full_auth_enabled = True
            log.info("Firebase: full token verification enabled")
        except Exception as e:
            log.warning(f"Firebase service account load failed: {e}")
    else:
        try:
            if not firebase_admin._apps:
                firebase_admin.initialize_app(
                    options={"projectId": settings.firebase_project_id}
                )
        except Exception:
            pass
        _full_auth_enabled = False
        log.info(
            "Firebase: running in DEV mode — auth verification disabled. "
            "Add config/firebase-service-account.json to enable full auth."
        )

    _firebase_initialized = True


class FirebaseAuthMiddleware:
    """
    ASGI Middleware for Firebase Authentication.
    - Properly handles HTTP requests with token verification.
    - COMPLETELY ignores WebSockets to prevent connection resets/timeouts.
    """
    def __init__(self, app):
        self.app = app
        _init_firebase()

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            # Direct bypass for WebSockets and other non-HTTP types
            return await self.app(scope, receive, send)

        path = scope.get("path", "")
        
        # Always allow public paths
        if (
            path in PUBLIC_PATHS
            or path.startswith("/api/docs")
            or path.startswith("/api/redoc")
        ):
            scope["user_id"] = "anonymous"
            return await self.app(scope, receive, send)

        # DEV MODE: no service account → skip auth, assign local user
        if not _full_auth_enabled:
            scope["user_id"] = "local"
            scope["user_email"] = "local@cyborg.dev"
            return await self.app(scope, receive, send)

        # PRODUCTION MODE: verify Firebase ID token
        headers = dict(scope.get("headers", []))
        auth_header = headers.get(b"authorization", b"").decode()
        token = None

        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
        else:
            # Check query string for token
            from urllib.parse import parse_qs
            query = parse_qs(scope.get("query_string", b"").decode())
            if "token" in query:
                token = query["token"][0]

        if not token:
            await self._reject(send, "Authentication required")
            return

        try:
            decoded = fb_auth.verify_id_token(token)
            scope["user_id"] = decoded["uid"]
            scope["user_email"] = decoded.get("email", "")
            scope["user"] = decoded
        except Exception as e:
            log.warning("Token verification failed", error=str(e))
            await self._reject(send, "Invalid or expired token")
            return

        return await self.app(scope, receive, send)

    async def _reject(self, send, message: str):
        import json
        response_body = json.dumps({"error": message}).encode()
        await send({
            "type": "http.response.start",
            "status": 401,
            "headers": [
                [b"content-type", b"application/json"],
            ],
        })
        await send({
            "type": "http.response.body",
            "body": response_body,
        })
