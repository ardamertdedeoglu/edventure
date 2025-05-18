@echo off
echo Deploying Firebase Functions...
cd %~dp0
call firebase deploy --only functions
pause 