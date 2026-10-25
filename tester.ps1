# Script d'exécution rapide des tests automatisés Dicey-Forge (100% gratuit et local)
$godot = "D:\Godot\Godot_v4.5.1-stable_win64_console.exe"

if (-not (Test-Path $godot)) {
    Write-Host "Exécutable Godot introuvable à l'emplacement : $godot" -ForegroundColor Red
    exit 1
}

Write-Host "Lancement des tests en mode headless..." -ForegroundColor Cyan
& $godot --headless res://Tests/TestRunner.tscn
