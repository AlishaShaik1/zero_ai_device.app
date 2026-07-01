@echo off
set msg="%~1"
if %msg%=="" set msg="Auto-sync update"

echo Adding all changes...
git add .

echo Committing with message: %msg%
git commit -m %msg%

echo Pushing to AlishaShaik1 GitHub...
git push https://github.com/AlishaShaik1/zero_ai_device.app.git main

echo Done!
pause
