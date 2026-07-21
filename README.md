# http-finder

Escáner HTTP de red local (LAN) para descubrir routers, cámaras IP, DVRs y otros
dispositivos con interfaz web. Escrito en **PowerShell**, funciona en cualquier
Windows sin instalar nada (usa solo componentes que ya trae el sistema).

Recorre un rango de IPs (`.1` a `.254`), prueba el puerto HTTP, y al final te
muestra una lista limpia con las IPs que respondieron, su código HTTP y el
servidor detectado.

> ⚠️ **Uso responsable:** utilízalo solo en tu propia red o en redes donde tengas
> autorización. Escanear redes ajenas puede ser ilegal.

---

## Descargar y ejecutar

Abre **PowerShell** y descarga el script:

```powershell
Invoke-WebRequest "https://raw.githubusercontent.com/jorgemg1414/http-finder/refs/heads/main/httpFinder.ps1" -OutFile "httpFinder.ps1"
```

Ejecútalo indicando los tres primeros octetos de tu red (ejemplo `192.168.1`):

```powershell
.\httpFinder.ps1 -SegmentoIncompleto 192.168.1
```

### Si los scripts están deshabilitados

Windows bloquea los `.ps1` por defecto. Si ves un error de *"scripts deshabilitados"*,
ejecútalo así:

```powershell
powershell -ExecutionPolicy Bypass -File .\httpFinder.ps1 -SegmentoIncompleto 192.168.1
```

---

## Parámetros

| Parámetro              | Descripción                                         | Por defecto |
|------------------------|-----------------------------------------------------|-------------|
| `-SegmentoIncompleto`  | Primeros 3 octetos de la red (ej. `192.168.1`). **Obligatorio.** | —      |
| `-Puerto`              | Puerto a escanear.                                  | `80`        |
| `-TimeoutMilisegundos` | Tiempo de espera por IP, en milisegundos.           | `1000`      |
| `-MostrarErrores`      | Muestra también timeouts y errores de conexión.     | (oculto)    |
| `-Mostrar500`          | Muestra las IPs que devuelven HTTP 500.             | (omitido)   |

Ejemplo escaneando el puerto 8080 con timeout más corto:

```powershell
.\httpFinder.ps1 -SegmentoIncompleto 192.168.0 -Puerto 8080 -TimeoutMilisegundos 500
```

---

## Nota sobre el caché de GitHub

La URL `raw.githubusercontent.com/.../main/...` se guarda en un **caché** unos
~5 minutos. Si acabas de actualizar el script y necesitas la última versión
**enseguida**, tienes dos opciones:

**1. Añadir un parámetro a la URL para saltarte el caché:**

```powershell
Invoke-WebRequest "https://raw.githubusercontent.com/jorgemg1414/http-finder/refs/heads/main/httpFinder.ps1?x=$(Get-Random)" -OutFile "httpFinder.ps1"
```

**2. Descargar por número de commit** (esas URLs nunca se cachean; reemplaza
`COMMIT` por el hash que quieras):

```powershell
Invoke-WebRequest "https://raw.githubusercontent.com/jorgemg1414/http-finder/COMMIT/httpFinder.ps1" -OutFile "httpFinder.ps1"
```

Pasados ~5 minutos, la URL normal de `main` ya sirve la versión más reciente sin trucos.

---

## Solución de problemas

- **Errores raros del parser** (`Array index expression is missing`, `The string is
  missing the terminator`): son problemas de **codificación**. Guarda siempre el
  `.ps1` como **ASCII** o **UTF-8 con BOM**, nunca UTF-8 sin BOM (Windows PowerShell
  lo lee mal y corrompe los acentos).
- **No renombres el archivo a `.batch` ni `.bat`**: es un script de PowerShell, tiene
  que ejecutarse como `.ps1`.
