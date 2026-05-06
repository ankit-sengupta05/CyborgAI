Write-Host "Building Cyborg for Web..." -ForegroundColor Cyan

# 1. Build Flutter Web
flutter build web --release --base-href "/"

# 2. Ensure static directory exists in backend
$staticDir = "assets\backend\static"
if (!(Test-Path $staticDir)) {
    New-Item -ItemType Directory -Path $staticDir
}

# 3. Copy web build to backend
Write-Host "Copying web build to $staticDir..." -ForegroundColor Yellow
Copy-Item -Path "build\web\*" -Destination $staticDir -Recurse -Force

Write-Host "Done! You can now deploy the assets\backend folder or use the Dockerfile." -ForegroundColor Green
