$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$charts = @(
    @{ Song = "canon"; Path = Join-Path $root "charts\canon_demo.chart" },
    @{ Song = "fade";  Path = Join-Path $root "charts\fade_demo.chart" }
)

function Convert-LanesToBits([string]$lanes) {
    $bits = 0
    $upper = $lanes.ToUpperInvariant()
    if ($upper.Contains("L")) { $bits = $bits -bor 1 }
    if ($upper.Contains("C")) { $bits = $bits -bor 2 }
    if ($upper.Contains("R")) { $bits = $bits -bor 4 }
    return $bits
}

function Read-Chart($path) {
    $rows = @{}
    $holds = @{}
    $holdLens = @{}
    foreach ($line in Get-Content $path) {
        $clean = ($line -replace "#.*$", "").Trim()
        if ($clean.Length -eq 0) { continue }
        $parts = $clean -split "\s+"
        if ($parts.Count -lt 2) { throw "Bad chart line in ${path}: $line" }
        $step = [int]$parts[0]
        if ($step -lt 0 -or $step -gt 63) { throw "Step out of range 0..63 in ${path}: $line" }
        $bits = Convert-LanesToBits $parts[1]
        if ($bits -ne 0) { $rows[$step] = $bits }
        if ($parts.Count -ge 3) {
            $holdParts = $parts[2] -split ":"
            if ($holdParts.Count -ne 2) { throw "Bad hold field in ${path}: $line" }
            $holdBits = Convert-LanesToBits $holdParts[0]
            $holdLen = [int]$holdParts[1]
            if ($holdLen -lt 1 -or $holdLen -gt 63) { throw "Hold length out of range 1..63 in ${path}: $line" }
            if ($holdBits -ne 0) {
                $holds[$step] = $holdBits
                $holdLens[$step] = $holdLen
            }
        }
    }
    return @{ Taps = $rows; Holds = $holds; HoldLens = $holdLens }
}

$canon = Read-Chart $charts[0].Path
$fade = Read-Chart $charts[1].Path
$out = New-Object System.Collections.Generic.List[string]
$out.Add("// Generated from charts/*.chart. Edit those text files, then run scripts/generate_charts.ps1.")
$out.Add("function [2:0] chart_row;")
$out.Add("    input [1:0] song;")
$out.Add("    input [7:0] step;")
$out.Add("    begin")
$out.Add("        if (song == 2'd1) begin")
$out.Add("            case (step[5:0])")
foreach ($step in ($fade.Taps.Keys | Sort-Object)) {
    $out.Add(("                6'd{0}: chart_row = 3'b{1};" -f $step, [Convert]::ToString($fade.Taps[$step], 2).PadLeft(3, "0")))
}
$out.Add("                default: chart_row = 3'b000;")
$out.Add("            endcase")
$out.Add("        end else begin")
$out.Add("            case (step[5:0])")
foreach ($step in ($canon.Taps.Keys | Sort-Object)) {
    $out.Add(("                6'd{0}: chart_row = 3'b{1};" -f $step, [Convert]::ToString($canon.Taps[$step], 2).PadLeft(3, "0")))
}
$out.Add("                default: chart_row = 3'b000;")
$out.Add("            endcase")
$out.Add("        end")
$out.Add("    end")
$out.Add("endfunction")
$out.Add("")
$out.Add("function [2:0] chart_hold_row;")
$out.Add("    input [1:0] song;")
$out.Add("    input [7:0] step;")
$out.Add("    begin")
$out.Add("        if (song == 2'd1) begin")
$out.Add("            case (step[5:0])")
foreach ($step in ($fade.Holds.Keys | Sort-Object)) {
    $out.Add(("                6'd{0}: chart_hold_row = 3'b{1};" -f $step, [Convert]::ToString($fade.Holds[$step], 2).PadLeft(3, "0")))
}
$out.Add("                default: chart_hold_row = 3'b000;")
$out.Add("            endcase")
$out.Add("        end else begin")
$out.Add("            case (step[5:0])")
foreach ($step in ($canon.Holds.Keys | Sort-Object)) {
    $out.Add(("                6'd{0}: chart_hold_row = 3'b{1};" -f $step, [Convert]::ToString($canon.Holds[$step], 2).PadLeft(3, "0")))
}
$out.Add("                default: chart_hold_row = 3'b000;")
$out.Add("            endcase")
$out.Add("        end")
$out.Add("    end")
$out.Add("endfunction")
$out.Add("")
$out.Add("function [5:0] chart_hold_len;")
$out.Add("    input [1:0] song;")
$out.Add("    input [7:0] step;")
$out.Add("    begin")
$out.Add("        if (song == 2'd1) begin")
$out.Add("            case (step[5:0])")
foreach ($step in ($fade.HoldLens.Keys | Sort-Object)) {
    $out.Add(("                6'd{0}: chart_hold_len = 6'd{1};" -f $step, $fade.HoldLens[$step]))
}
$out.Add("                default: chart_hold_len = 6'd0;")
$out.Add("            endcase")
$out.Add("        end else begin")
$out.Add("            case (step[5:0])")
foreach ($step in ($canon.HoldLens.Keys | Sort-Object)) {
    $out.Add(("                6'd{0}: chart_hold_len = 6'd{1};" -f $step, $canon.HoldLens[$step]))
}
$out.Add("                default: chart_hold_len = 6'd0;")
$out.Add("            endcase")
$out.Add("        end")
$out.Add("    end")
$out.Add("endfunction")

$dest = Join-Path $root "Mini_IO.srcs\sources_1\new\rhythm_charts.vh"
Set-Content -Path $dest -Value $out -Encoding ASCII
Write-Host "Generated $dest"
