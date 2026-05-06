$ErrorActionPreference = "Stop"

Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
Remove-Item package-lock.json -ErrorAction SilentlyContinue

Write-Host "Instalando dependencias en contenedor Linux..."
docker run --rm `
    -v ${PWD}:/var/task `
    -w /var/task `
    node:20 `
    npm install --omit=dev

$sharpBinary = "node_modules/@img/sharp-linux-x64/lib/sharp-linux-x64.node"

if (Test-Path $sharpBinary) {
    Write-Host "OK Binario Linux x64: $sharpBinary" -ForegroundColor Green
} else {
    Write-Host "ERROR No se encontro el binario Linux x64" -ForegroundColor Red
    Write-Host "Carpetas en node_modules/@img/:"
    Get-ChildItem node_modules/@img/ -ErrorAction SilentlyContinue | Select-Object Name
    exit 1
}