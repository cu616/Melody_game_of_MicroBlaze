param(
    [Parameter(Mandatory=$true)]
    [string]$PortName,
    [int]$Seconds = 10,
    [string]$OutFile = "uart_pcm_capture.wav"
)

$baud = 9600
$sampleRate = 800
$bytesToRead = $Seconds * $sampleRate

function Write-WavHeader {
    param(
        [System.IO.BinaryWriter]$Writer,
        [int]$SampleRate,
        [int]$DataBytes
    )

    $byteRate = $SampleRate
    $blockAlign = 1
    $bitsPerSample = 8
    $riffSize = 36 + $DataBytes

    $Writer.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
    $Writer.Write([UInt32]$riffSize)
    $Writer.Write([Text.Encoding]::ASCII.GetBytes("WAVE"))
    $Writer.Write([Text.Encoding]::ASCII.GetBytes("fmt "))
    $Writer.Write([UInt32]16)
    $Writer.Write([UInt16]1)
    $Writer.Write([UInt16]1)
    $Writer.Write([UInt32]$SampleRate)
    $Writer.Write([UInt32]$byteRate)
    $Writer.Write([UInt16]$blockAlign)
    $Writer.Write([UInt16]$bitsPerSample)
    $Writer.Write([Text.Encoding]::ASCII.GetBytes("data"))
    $Writer.Write([UInt32]$DataBytes)
}

$serial = New-Object System.IO.Ports.SerialPort $PortName, $baud, "None", 8, "One"
$serial.ReadTimeout = 5000
$serial.Open()

try {
    Write-Host "Waiting for ENDHDR on $PortName at $baud baud..."
    $header = ""
    while (-not $header.Contains("ENDHDR")) {
        $header += [char]$serial.ReadByte()
        if ($header.Length -gt 256) {
            $header = $header.Substring($header.Length - 256)
        }
    }

    Write-Host "Capturing $Seconds seconds of $sampleRate Hz 8-bit PCM..."
    $buffer = New-Object byte[] $bytesToRead
    $offset = 0
    while ($offset -lt $bytesToRead) {
        $offset += $serial.Read($buffer, $offset, $bytesToRead - $offset)
    }
} finally {
    $serial.Close()
}

$fullOut = [IO.Path]::GetFullPath($OutFile)
$fs = [IO.File]::Create($fullOut)
$writer = New-Object System.IO.BinaryWriter $fs
try {
    Write-WavHeader -Writer $writer -SampleRate $sampleRate -DataBytes $bytesToRead
    $writer.Write($buffer)
} finally {
    $writer.Close()
}

Write-Host "Wrote $fullOut"
Start-Process $fullOut
