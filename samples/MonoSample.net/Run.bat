@echo off 
pushd "%~dp0../../redist/" 
call "log.txt" 
call "ParaEngineClient.exe" bootstrapper="source/MonoSample.net/main.lua" single="false" mc="true" noupdate="true" dev="%~dp0"  
popd 
