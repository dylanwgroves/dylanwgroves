# update-cv.ps1 — Build the LaTeX CV from Overleaf source and publish it to the site.
#
#   .\update-cv.ps1            Build the PDF and stage it at static/groves_cv.pdf
#   .\update-cv.ps1 -Publish   ...and also commit ONLY that PDF and push (Netlify redeploys)
#
# The CV source lives in the Dropbox-synced Overleaf folder. We build in a temp
# dir because Dropbox corrupts a PDF written inside its tree. Publishing commits
# just the one file, so any other work-in-progress in this repo is left untouched.

param([switch]$Publish)
$ErrorActionPreference = 'Stop'

$Src   = 'C:\Users\grovesd\Dropbox\Apps\Overleaf\Dylan - CV'
$Build = Join-Path $env:TEMP 'cvbuild'
$Repo  = 'C:\repos\dylanwgroves'
$Dest  = Join-Path $Repo 'static\groves_cv.pdf'

# 1. Build in a temp dir outside Dropbox.
New-Item -ItemType Directory -Force -Path $Build | Out-Null
Copy-Item (Join-Path $Src 'main.tex')       $Build -Force
Copy-Item (Join-Path $Src 'references.bib') $Build -Force
Push-Location $Build
try {
    # latexmk needs Perl (not installed), so run the passes by hand:
    # pdflatex -> biber -> pdflatex x2 to resolve the bibliography.
    pdflatex -interaction=nonstopmode main.tex | Out-Null
    biber main | Out-Null
    pdflatex -interaction=nonstopmode main.tex | Out-Null
    pdflatex -interaction=nonstopmode main.tex | Out-Null
} finally { Pop-Location }

if (-not (Test-Path (Join-Path $Build 'main.pdf'))) {
    throw "Build failed - no PDF produced. See $Build\main.log"
}

# 2. Copy into the site under the stable filename the site links to.
Copy-Item (Join-Path $Build 'main.pdf') $Dest -Force
Write-Host "Built and staged -> $Dest"

# 3. Optionally publish just the CV (Netlify auto-deploys on push to main).
if ($Publish) {
    Push-Location $Repo
    try {
        git add static/groves_cv.pdf
        git commit -m "Update CV"
        git push
        Write-Host "Pushed to main - Netlify will redeploy dylanwgroves.com/groves_cv.pdf"
    } finally { Pop-Location }
}
