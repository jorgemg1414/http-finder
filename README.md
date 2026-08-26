# http-finder

Escáner HTTP de red local (LAN) para descubrir routers, cámaras IP, DVRs y otros
dispositivos con interfaz web. Escrito en **PowerShell**, funciona en cualquier
Windows sin instalar nada (usa solo componentes que ya trae el sistema).

Recorre un rango de IPs (`.1` a `.254`) probando varios puertos web a la vez y,
al final, te muestra una lista limpia con lo que respondió: código HTTP, cabecera
`Server` y el `<title>` de la página, que suele delatar la marca y el modelo del
aparato. En los puertos 443 y 8443 habla HTTPS, aceptando los certificados
autofirmados que llevan casi todos estos cacharros.

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

| Parámetro              | Descripción                                          | Por defecto |
|------------------------|------------------------------------------------------|-------------|
| `-SegmentoIncompleto`  | Primeros 3 octetos de la red (ej. `192.168.1`). **Obligatorio.** | — |
| `-Puertos`             | Lista de puertos a escanear, separados por comas.    | `80, 81, 8080, 8000, 8081, 443, 8443, 9000` |
| `-TimeoutMilisegundos` | Tiempo de espera por objetivo (IP:puerto), en milisegundos. | `1000` |
| `-MaxConcurrencia`     | Cuántos objetivos se prueban a la vez. Más = más rápido, más carga. | `50` |
| `-MostrarErrores`      | Muestra también los puertos cerrados, timeouts y errores de red. | (oculto) |
| `-Mostrar500`          | Incluye en los resultados las IPs que devuelven HTTP 500. | (omitido) |

Ejemplo escaneando solo los puertos 80 y 8080, con timeout más corto y el doble
de concurrencia:

```powershell
.\httpFinder.ps1 -SegmentoIncompleto 192.168.0 -Puertos 80,8080 -TimeoutMilisegundos 500 -MaxConcurrencia 100
```

> `-MostrarErrores` imprime una línea **por cada puerto que no responde**. Con los
> 8 puertos por defecto eso son unas 2.000 líneas, así que úsalo junto a
> `-Puertos` para acotar el escaneo.

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

---

## Licencia

[MIT](LICENSE). Puedes usarlo, modificarlo y redistribuirlo libremente, incluso
con fines comerciales, siempre que conserves el aviso de copyright. Se ofrece
sin ninguna garantía.
