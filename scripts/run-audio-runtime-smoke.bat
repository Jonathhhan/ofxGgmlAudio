@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-audio-runtime-smoke.ps1" %*
