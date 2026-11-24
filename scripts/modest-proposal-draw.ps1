# Makes the Modest Proposal draw (the family's Christmas exchange) and writes
# it, scrambled, to static/modest-proposal/draw.js.
#
# Each person gives one book to one person and one gift to a different person.
# Nobody draws themselves or their spouse, and no two people draw each other
# for the same thing. The script never prints who drew whom, so whoever runs
# it stays as much in the dark as everyone else.
#
# There is meant to be ONE draw a year. Once draw.js exists the script refuses
# to run, so that nobody's names change after the link has gone out. To throw
# the draw away and make a new one on purpose:
#
#   powershell -File scripts\modest-proposal-draw.ps1 -Force

param([switch]$Force)

$ErrorActionPreference = 'Stop'

$out = Join-Path $PSScriptRoot '..\static\modest-proposal\draw.js'
if ((Test-Path $out) -and -not $Force) {
    Write-Output "A draw already exists in static/modest-proposal/draw.js, so nothing was changed. Use -Force to replace it."
    exit 1
}

# $people and $salt must match static/modest-proposal/index.html.
$people  = @('Julie', 'Barry', 'Holden', 'Valerie', 'Charlotte', 'Dylan')
$couples = @(@(0, 1), @(2, 3), @(4, 5))
$salt    = 'ely-hill-2026'

$n = $people.Count
$spouse = @{}
foreach ($c in $couples) { $spouse[$c[0]] = $c[1]; $spouse[$c[1]] = $c[0] }

function Get-Sha([string]$text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ,$sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text)) }
    finally { $sha.Dispose() }
}

function Test-Draw([int[]]$to) {
    for ($i = 0; $i -lt $n; $i++) {
        if ($to[$i] -eq $i) { return $false }                                        # yourself
        if ($spouse.ContainsKey($i) -and $to[$i] -eq $spouse[$i]) { return $false }  # your spouse
        if ($to[$to[$i]] -eq $i) { return $false }                                   # a straight swap
    }
    return $true
}

# True when nobody has the same person in both draws.
function Test-Apart([int[]]$a, [int[]]$b) {
    for ($i = 0; $i -lt $n; $i++) { if ($a[$i] -eq $b[$i]) { return $false } }
    return $true
}

function New-Draw {
    do { [int[]]$to = 0..($n - 1) | Get-Random -Count $n } until (Test-Draw $to)
    return ,$to
}

$book = New-Draw
do { $gift = New-Draw } until (Test-Apart $gift $book)

# Scramble each person's two names with a pad derived from their own name.
$entries = for ($i = 0; $i -lt $n; $i++) {
    $who = Get-Sha "$salt|who|$($people[$i])"
    $pad = Get-Sha "$salt|pad|$($people[$i])"
    $id = -join ($who[0..7] | ForEach-Object { '{0:x2}' -f $_ })
    $check = ($book[$i] * 31 + $gift[$i] * 17 + 99) -band 255
    $sealed = -join (@($book[$i], $gift[$i], $check) | ForEach-Object -Begin { $k = 0 } -Process {
        '{0:x2}' -f ($_ -bxor [int]$pad[$k]); $k++
    })
    "  `"$id`": `"$sealed`""
}

$body = "// Made by scripts/modest-proposal-draw.ps1. Do not edit by hand.`n" +
        "window.MP_DRAW = {`n" + (($entries | Sort-Object) -join ",`n") + "`n};`n"

[System.IO.File]::WriteAllText($out, $body)

Write-Output "The draw is made for $n people and sealed in static/modest-proposal/draw.js. Nobody has seen it."
