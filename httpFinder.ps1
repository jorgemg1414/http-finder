# Escaner de red HTTP - Multipuerto
# Busca dispositivos con interfaz web (routers, camaras, DVRs) en la LAN
# Escanea el rango .1 a .254 en varios puertos
# OMITE RESPUESTAS HTTP 500 por defecto
# SOLO MUESTRA EN PANTALLA - NO GENERA ARCHIVOS

param(
    [Parameter(Mandatory=$true)]
    [string]$SegmentoIncompleto,  # Ejemplo: "192.168.1"

    # Lista de puertos a escanear. Web comunes + tipicos de camaras/DVR.
    [int[]]$Puertos = @(80, 81, 8080, 8000, 8081, 443, 8443, 9000),

    [int]$TimeoutMilisegundos = 1000,

    [switch]$MostrarErrores,

    [switch]$Mostrar500  # Switch para mostrar errores 500 si se desea
)

# Validar formato del segmento
if ($SegmentoIncompleto -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}$') {
    Write-Host "Error: Formato de IP invalido. Use formato: 192.168.1" -ForegroundColor Red
    Write-Host "Ejemplo: .\httpFinder.ps1 -SegmentoIncompleto 192.168.1" -ForegroundColor Yellow
    exit 1
}

# ---------------------------------------------------------------------------
# Bloque que escanea UN objetivo (IP + puerto) y devuelve un objeto resultado
# o $null si no responde. Es autocontenido para poder reutilizarse.
# ---------------------------------------------------------------------------
$ScanTarget = {
    param($IP, $Puerto, $TimeoutMs)

    $Tcp = New-Object System.Net.Sockets.TcpClient
    try {
        # Conexion TCP con timeout
        $Async = $Tcp.BeginConnect($IP, $Puerto, $null, $null)
        if (-not $Async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            $Tcp.Close()
            return $null   # timeout, puerto cerrado
        }
        $Tcp.EndConnect($Async)

        $NetStream = $Tcp.GetStream()
        $NetStream.ReadTimeout = $TimeoutMs
        $NetStream.WriteTimeout = $TimeoutMs

        # Puertos TLS conocidos -> envolver la conexion en SSL/TLS
        $UsarTls = ($Puerto -eq 443 -or $Puerto -eq 8443)
        $Esquema = if ($UsarTls) { 'https' } else { 'http' }

        if ($UsarTls) {
            # Aceptar certificados autofirmados (comunes en routers/camaras/DVR)
            $Callback = [System.Net.Security.RemoteCertificateValidationCallback]{ param($s, $c, $ch, $e) $true }
            $Stream = New-Object System.Net.Security.SslStream($NetStream, $false, $Callback)
            try {
                $Stream.AuthenticateAsClient($IP)
            } catch {
                # Puerto TLS abierto pero el handshake fallo
                $Tcp.Close()
                return [PSCustomObject]@{
                    IP = $IP; Puerto = $Puerto; Esquema = $Esquema
                    Codigo = 'ABIERTO'; Server = ''; Titulo = ''; Nota = 'Puerto TLS abierto (handshake fallo)'
                }
            }
        } else {
            $Stream = $NetStream
        }

        # Enviar peticion HTTP GET basica
        $Request = "GET / HTTP/1.0`r`nHost: $IP`r`nUser-Agent: http-finder`r`nConnection: close`r`n`r`n"
        $Bytes = [System.Text.Encoding]::ASCII.GetBytes($Request)
        $Stream.Write($Bytes, 0, $Bytes.Length)
        $Stream.Flush()

        # Leer respuesta (hasta 16 KB)
        $Sb = New-Object System.Text.StringBuilder
        $Buffer = New-Object byte[] 4096
        $Total = 0
        try {
            while ($true) {
                $Read = $Stream.Read($Buffer, 0, $Buffer.Length)
                if ($Read -le 0) { break }
                [void]$Sb.Append([System.Text.Encoding]::ASCII.GetString($Buffer, 0, $Read))
                $Total += $Read
                if ($Total -ge 16384) { break }
            }
        } catch { }
        $Tcp.Close()

        $Respuesta = $Sb.ToString()

        # Conecta pero no habla HTTP (posible DVR/camara en puerto propietario)
        if ($Total -le 0) {
            return [PSCustomObject]@{
                IP = $IP; Puerto = $Puerto; Esquema = $Esquema
                Codigo = 'ABIERTO'; Server = ''; Titulo = ''; Nota = 'Conecta pero no responde HTTP'
            }
        }

        # Codigo de estado HTTP
        if ($Respuesta -match 'HTTP/\d\.\d\s+(\d{3})') { $Codigo = $Matches[1] } else { $Codigo = 'Desconocido' }
        # Cabecera Server
        if ($Respuesta -match 'Server:\s*([^\r\n]+)') { $Server = $Matches[1].Trim() } else { $Server = '' }

        # Titulo de la pagina: suele identificar el dispositivo (marca/modelo)
        if ($Respuesta -match '(?is)<title[^>]*>\s*(.*?)\s*</title>') {
            $Titulo = ($Matches[1] -replace '\s+', ' ').Trim()
            if ($Titulo.Length -gt 60) { $Titulo = $Titulo.Substring(0, 60) + '...' }
        } else {
            $Titulo = ''
        }

        return [PSCustomObject]@{
            IP = $IP; Puerto = $Puerto; Esquema = $Esquema
            Codigo = $Codigo; Server = $Server; Titulo = $Titulo; Nota = ''
        }
    } catch {
        try { $Tcp.Close() } catch { }
        return $null
    }
}

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "ESCANER HTTP - MULTIPUERTO" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Segmento base: $SegmentoIncompleto.x" -ForegroundColor Yellow
Write-Host "Rango: .1 a .254" -ForegroundColor Yellow
Write-Host "Puertos: $($Puertos -join ', ')" -ForegroundColor Yellow
Write-Host "Timeout: $TimeoutMilisegundos ms" -ForegroundColor Yellow
Write-Host "OMITIENDO ERRORES HTTP 500" -ForegroundColor Magenta
Write-Host "SOLO VISUALIZACION EN PANTALLA" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Contadores
$TotalTareas = 0
$ConRespuesta = 0
$Con500 = 0
$ConError = 0

# Lista de resultados encontrados para mostrar al final
$Encontradas = @()

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$TareasTotales = 254 * $Puertos.Count

# Recorrer todas las IPs del rango y cada puerto
for ($i = 1; $i -le 254; $i++) {
    $IPCompleta = "$SegmentoIncompleto.$i"

    foreach ($Puerto in $Puertos) {
        $TotalTareas++
        $Progreso = [math]::Round(($TotalTareas / $TareasTotales) * 100, 1)
        Write-Progress -Activity "Escaneando red" -Status "Probando $IPCompleta`:$Puerto" -PercentComplete $Progreso

        $R = & $ScanTarget $IPCompleta $Puerto $TimeoutMilisegundos
        if ($null -eq $R) { continue }

        # Omitir HTTP 500 salvo que se pida lo contrario
        if ($R.Codigo -eq '500') {
            $Con500++
            if ($Mostrar500) {
                Write-Host "[500 OMITIDO] $($R.IP):$($R.Puerto) -> Error HTTP 500 (ignorado)" -ForegroundColor DarkGray
            }
            continue
        }

        $ConRespuesta++
        $Encontradas += $R

        # Color segun el codigo
        switch -wildcard ($R.Codigo) {
            "2*"     { $Color = "Green" }
            "3*"     { $Color = "Yellow" }
            "4*"     { $Color = "Red" }
            default  { $Color = "White" }
        }

        $Extra = @()
        if ($R.Titulo) { $Extra += "titulo: $($R.Titulo)" }
        if ($R.Server)  { $Extra += $R.Server } elseif ($R.Nota) { $Extra += $R.Nota }
        $ExtraTxt = if ($Extra.Count) { " (" + ($Extra -join ' | ') + ")" } else { "" }
        Write-Host "[OK] $($R.Esquema)://$($R.IP):$($R.Puerto) -> HTTP $($R.Codigo)" -ForegroundColor $Color -NoNewline
        Write-Host $ExtraTxt -ForegroundColor Gray
    }
}

$Stopwatch.Stop()
$TiempoTotal = $Stopwatch.Elapsed

# Mostrar resumen
Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "RESUMEN DEL ESCANEO" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Objetivos probados (IP:puerto): $TotalTareas" -ForegroundColor White
Write-Host "Respuestas validas: $ConRespuesta" -ForegroundColor Green
Write-Host "Error 500 (omitidos): $Con500" -ForegroundColor Magenta
Write-Host "Tiempo total: $($TiempoTotal.TotalSeconds) segundos" -ForegroundColor White
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

if ($ConRespuesta -eq 0) {
    Write-Host "No se encontraron dispositivos con respuesta HTTP valida (diferente de 500)." -ForegroundColor Yellow
} else {
    Write-Host "DISPOSITIVOS ENCONTRADOS:" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Cyan
    foreach ($item in $Encontradas) {
        $Partes = @()
        if ($item.Titulo) { $Partes += $item.Titulo }
        if ($item.Server) { $Partes += $item.Server } elseif ($item.Nota) { $Partes += $item.Nota }
        $Detalle = if ($Partes.Count) { $Partes -join ' | ' } else { '-' }
        Write-Host ("  {0}://{1}:{2}  ->  HTTP {3}  [{4}]" -f $item.Esquema, $item.IP, $item.Puerto, $item.Codigo, $Detalle) -ForegroundColor White
    }
    Write-Host "====================================" -ForegroundColor Cyan
}

Write-Host ""

# Pausa final robusta: ReadKey solo funciona en la consola normal.
# En ISE/VSCode/no interactivo se usa Read-Host como alternativa.
try {
    if ($Host.Name -eq 'ConsoleHost' -and -not [System.Console]::IsInputRedirected) {
        Write-Host "Presione cualquier tecla para salir..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Read-Host "Presione ENTER para salir"
    }
} catch {
    # Entorno sin entrada interactiva: no bloquear la salida.
}
