@echo off
title IDM Toolkit - GUI
:: Double-click to launch the IDM Toolkit WPF GUI

pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-STA -NoProfile -ExecutionPolicy Bypass -File """"%~dp0IDM-Toolkit-GUI.ps1""""'"
popd
