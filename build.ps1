function Get-CodeBlocks ($file, $language) {
  <#
  .SYNOPSIS
  Extracts the code blocks from a Markdown file tagged with a specified language.

  .PARAMETER file
  The Markdown file to process.

  .PARAMETER language
  The language to extract.
  #>

  [regex]::Matches((Get-Content -Raw $file), "``````$language([^``]+)``````") |
    ForEach-Object { $_.groups[1].value }
}

function Write-Protobuf ($base) {
  (Get-CodeBlocks ".\$base.md" 'protobuf') | Out-File ".\$base.proto" -Encoding utf8
}

Write-Protobuf 'metadata'
Write-Protobuf 'messaging'
Write-Protobuf 'transport'