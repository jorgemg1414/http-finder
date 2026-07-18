# Escaner de red HTTP - Puerto 80
# Busca en el rango de IPs desde .2 hasta .253
# OMITE RESPUESTAS HTTP 500
# SOLO MUESTRA EN PANTALLA - NO GENERA ARCHIVOS

param(
    [Parameter(Mandatory=$true)]
    [string]$SegmentoIncompleto,  # Ejemplo: "192.168.1"
    
    [int]$Puerto = 80,
    
    [int]$TimeoutMilisegundos = 1000,
    
    [switch]$MostrarErrores,
    
    [switch]$Mostrar500  # Switch para mostrar errores 500 si se desea
)

# Validar formato del segmento
if ($SegmentoIncompleto -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}$') {
    Write-Host "Error: Formato de IP invalido. Use formato: 192.168.1" -ForegroundColor Red
    Write-Host "Ejemplo: .\Scan-Http.ps1 -SegmentoIncompleto 192.168.1" -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "ESCANER HTTP - PUERTO 80" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Segmento base: $SegmentoIncompleto.x" -ForegroundColor Yellow
Write-Host "Rango: .2 a .253" -ForegroundColor Yellow
Write-Host "Puerto: $Puerto" -ForegroundColor Yellow
Write-Host "Timeout: $TimeoutMilisegundos ms" -ForegroundColor Yellow
Write-Host "OMITIENDO ERRORES HTTP 500" -ForegroundColor Magenta
Write-Host "SOLO VISUALIZACION EN PANTALLA" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Contadores
$TotalIPs = 0
$IPsConRespuesta = 0
$IPsConError500 = 0
$IPsConError = 0

# Lista de IPs encontradas para mostrar al final
$Encontradas = @()

# Crear un objeto para medicion de tiempo
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Bucle para escanear todas las IPs del rango
for ($i = 2; $i -le 253; $i++) {
    $IPCompleta = "$SegmentoIncompleto.$i"
    $TotalIPs++
    
    # Mostrar progreso
    $Progreso = [math]::Round(($TotalIPs / 252) * 100, 1)
    Write-Progress -Activity "Escaneando red" -Status "IP: $IPCompleta" -PercentComplete $Progreso
    
    try {
        # Intentar conexion TCP al puerto 80
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $AsyncResult = $TcpClient.BeginConnect($IPCompleta, $Puerto, $null, $null)
        $WaitHandle = $AsyncResult.AsyncWaitHandle
        $Signal = $WaitHandle.WaitOne($TimeoutMilisegundos, $false)
        
        if ($Signal) {
            try {
                $TcpClient.EndConnect($AsyncResult)
                
                # Conexion exitosa, intentar obtener respuesta HTTP
                $NetworkStream = $TcpClient.GetStream()
                
                # Enviar solicitud HTTP GET basica
                $Request = "GET / HTTP/1.0`r`nHost: $IPCompleta`r`nConnection: close`r`n`r`n"
                $Bytes = [System.Text.Encoding]::ASCII.GetBytes($Request)
                $NetworkStream.Write($Bytes, 0, $Bytes.Length)
                $NetworkStream.Flush()
                
                # Leer respuesta (primeros 1024 bytes)
                $Buffer = New-Object byte[] 1024
                $BytesRead = $NetworkStream.Read($Buffer, 0, $Buffer.Length)
                
                if ($BytesRead -gt 0) {
                    $Respuesta = [System.Text.Encoding]::ASCII.GetString($Buffer, 0, $BytesRead)
                    
                    # Extraer codigo de estado HTTP
                    if ($Respuesta -match 'HTTP/\d\.\d\s+(\d{3})') {
                        $StatusCode = $Matches[1]
                        
                        # Verificar si es error 500
                        if ($StatusCode -eq "500") {
                            $IPsConError500++
                            # Omitir completamente este resultado
                            if ($Mostrar500) {
                                Write-Host "[500 OMITIDO] $IPCompleta -> Error HTTP 500 (ignorado)" -ForegroundColor DarkGray
                            }
                            $TcpClient.Close()
                            continue  # Saltar al siguiente IP
                        }
                    } else {
                        $StatusCode = "Desconocido"
                    }
                    
                    # Extraer Server header si existe
                    if ($Respuesta -match 'Server:\s*([^\r\n]+)') {
                        $Server = $Matches[1].Trim()
                    } else {
                        $Server = "No identificado"
                    }
                    
                    $IPsConRespuesta++
                    $Encontradas += [PSCustomObject]@{ IP = $IPCompleta; Codigo = $StatusCode; Server = $Server }

                    # Mostrar en pantalla con colores segun el codigo de estado
                    switch -wildcard ($StatusCode) {
                        "2*" { $Color = "Green" }
                        "3*" { $Color = "Yellow" }
                        "4*" { $Color = "Red" }
                        default { $Color = "White" }
                    }
                    
                    Write-Host "[OK] $IPCompleta -> HTTP $StatusCode" -ForegroundColor $Color -NoNewline
                    Write-Host " ($Server)" -ForegroundColor Gray
                    
                } else {
                    # Conexion pero sin respuesta HTTP
                    Write-Host "[INFO] $IPCompleta -> Conecta pero no responde HTTP" -ForegroundColor Yellow
                }
                
                $TcpClient.Close()
                
            } catch {
                $IPsConError++
                if ($MostrarErrores) {
                    Write-Host "[ERROR] $IPCompleta -> $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            # Timeout - sin conexion
            if ($MostrarErrores) {
                Write-Host "[TIMEOUT] $IPCompleta -> No responde" -ForegroundColor Gray
            }
            $TcpClient.Close()
        }
    } catch {
        $IPsConError++
        if ($MostrarErrores) {
            Write-Host "[ERROR] $IPCompleta -> $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

$Stopwatch.Stop()
$TiempoTotal = $Stopwatch.Elapsed

# Mostrar resumen
Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "RESUMEN DEL ESCANEO" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "IPs escaneadas: $TotalIPs" -ForegroundColor White
Write-Host "IPs con respuesta HTTP: $IPsConRespuesta" -ForegroundColor Green
Write-Host "IPs con Error 500 (omitidos): $IPsConError500" -ForegroundColor Magenta
Write-Host "IPs sin respuesta: $($TotalIPs - $IPsConRespuesta - $IPsConError500 - $IPsConError)" -ForegroundColor Yellow
Write-Host "IPs con errores: $IPsConError" -ForegroundColor Red
Write-Host "Tiempo total: $($TiempoTotal.TotalSeconds) segundos" -ForegroundColor White
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

if ($IPsConRespuesta -eq 0) {
    Write-Host "No se encontraron IPs con respuesta HTTP valida (diferente de 500)." -ForegroundColor Yellow
} else {
    Write-Host "IPs ENCONTRADAS:" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Cyan
    foreach ($item in $Encontradas) {
        Write-Host ("  http://{0}  ->  HTTP {1}  ({2})" -f $item.IP, $item.Codigo, $item.Server) -ForegroundColor White
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
