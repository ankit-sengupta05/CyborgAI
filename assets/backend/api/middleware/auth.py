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


class FirebaseAuthMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        _init_firebase()

    async def dispatch(self, request, call_next):
        path = request.url.path

        # Always allow public paths and WebSocket upgrades
        if (
            path in PUBLIC_PATHS
            or path.startswith("/api/docs")
            or path.startswith("/api/redoc")
            or request.headers.get("upgrade", "").lower() == "websocket"
        ):
            request.state.user_id = "anonymous"
            request.state.user_email = ""
            return await call_next(request)

        # DEV MODE: no service account → skip auth, assign local user
        if not _full_auth_enabled:
            request.state.user_id = "local"
            request.state.user_email = "local@cyborg.dev"
            return await call_next(request)

        # PRODUCTION MODE: verify Firebase ID token
        auth_header = request.headers.get("Authorization", "")
        token = None

        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
        elif "token" in request.query_params:
            token = request.query_params["token"]

        if not token:
            return JSONResponse(
                status_code=401,
                content={"error": "Authentication required"},
            )

        try:
            decoded = fb_auth.verify_id_token(token)
            request.state.user_id = decoded["uid"]
            request.state.user_email = decoded.get("email", "")
            request.state.user = decoded
        except Exception as e:
            log.warning("Token verification failed", error=str(e))
            return JSONResponse(
                status_code=401,
                content={"error": "Invalid or expired token"},
            )

        return await call_next(request)
