# Instrucciones para agentes - Gestor de credenciales

Este es el **único** archivo de instrucciones del repositorio (válido para cualquier agente/arnés).

## Contexto del proyecto

- Solución de Power Platform `OVGGestordecontraseas` (publisher `Ovigi`, prefijo `ovg`): app basada en modelo, custom page de vista privada y seis flujos padre/hijo.
- El entorno fuente no administrado se identifica por el perfil PAC de `.env` (`GC_PAC_PROFILE`). No asumir nombres de perfiles personales ni deducir el entorno a partir del perfil PAC activo.
- Usar las skills de Power Platform/Dataverse, PAC y las API soportadas para consultar o modificar componentes. Los cambios se aplican directamente en el entorno.
- Antes de exportar o modificar, verificar perfil, URL e ID del entorno con el desarrollador.
- No importar, publicar, modificar permisos ni ejecutar flujos con efectos laterales fuera del alcance acordado con el usuario.
- No incorporar contraseñas, tokens ni secretos a archivos, logs o commits. No publicar URLs, IDs de entorno, organización o tenant ni listas de usuarios.

## Estilo de documentación

- Redactar todos los archivos Markdown del repositorio como documentación vigente, en presente y como un diseño definido desde cero. Incluye `README.md`, `solution/README.md`, `docs/alcance.md` y este archivo.
- No incluir historial de desarrollo, errores corregidos, intentos, reversiones ni comparativas con estados anteriores.
- Mantener explícitas las limitaciones actuales y las mejoras futuras, sin presentar capacidades pendientes como implementadas.
- Separar funcionamiento comprobado, intención funcional y propuestas. No presentar una lectura estática como prueba de ejecución con usuarios reales.
- Mantener `README.md`, `solution/README.md` y `docs/alcance.md` coherentes con los cambios verificados.

## Estructura del repositorio

| Ruta | Contenido |
|------|-----------|
| `solution/package/` | Solución desempaquetada con PAC. Solo lectura. |
| `solution/canvas-src/` | Fuentes de inspección (PAC SourceCode) de las custom pages (`CanvasAppType=2`). Solo lectura; no son componentes listos para importar. |
| `solution/scripts/regenerate-solution.ps1` | Exporta, desempaqueta, oculta la URL del entorno en los flujos y extrae las custom pages. |
| `docs/alcance.md` | Especificación funcional y técnica. |
| `.github/workflows/release-solution.yml` | Action manual que empaqueta `solution/package/` y crea la release `vX.X.X.X`. |
| `local/` | Scripts puntuales ligados al entorno de desarrollo. Ignorado por Git. |

- **No commitear** `.env`, `local/`, `.playwright-mcp/` ni archivos `.zip`.
- `regenerate-solution.ps1` sustituye en los flujos el `defaultValue` de la URL de la app por una plantilla.

## Sincronización con Dataverse

`solution/package/` y `solution/canvas-src/` **solo se actualizan con `pwsh solution/scripts/regenerate-solution.ps1`**. No editarlas, copiar componentes en ellas ni extraer exportaciones parciales a mano.

- Tras cambios en el entorno, recordar al usuario que ejecute el script desde la raíz.
- El script lee `GC_PAC_PROFILE` de `.env` sin ejecutar su contenido; si falta, crear `.env` copiando `.env.example` y solicitar el valor. `-PacProfileName` lo sobrescribe y `-PacProfileName ''` usa el perfil activo solo si el desarrollador lo pide. Al terminar restaura el perfil PAC activo previo.
- Cada ejecución borra y regenera ambas carpetas tras exportar correctamente. Si falla un desempaquetado, conserva `solution/solution.zip`. No extrae la biblioteca de comandos.
- Al analizar custom pages fuera del script, extraer sus `.msapp` con PAC en una carpeta separada.
- Si hay una sesión activa de Canvas Authoring, sincronizar sus archivos mediante `sync_canvas` antes de trabajar con ellos.

## Releases

Se publican a mano: con la solución regenerada y en `master`, lanzar la Action «Release de la solución» (pestaña Actions o `gh workflow run release-solution.yml`). Usa la versión de `solution/package/Other/Solution.xml`; si ya existe la release, no hace nada. Nunca hacer commit, push ni lanzar releases sin que el usuario lo pida.

## Líneas de trabajo

- La migración a Power Apps Code Apps es una propuesta de versión 2: documentarla, no implementarla sin una petición posterior.
- La autorización en servidor de los flujos (identidad, roles y acceso al registro) es una mejora pendiente, independiente de la migración a Code Apps.

## Seguridad funcional

- Distinguir lectura del registro de acceso al secreto; no mostrar contraseñas en formularios o vistas públicas.
- No asumir que un permiso o una comprobación en Canvas protege un flujo: la autorización debe comprobarse en el servidor con la identidad real del solicitante.
- No conceder lectura del campo protegido a roles como atajo para resolver incidencias.
- Antes de cambiar roles, explicar el alcance efectivo de los privilegios, incluyendo propiedad, equipos, compartición y privilegios acumulativos.
- Decisión vigente: Usuarios no puede crear credenciales. No conceder ese privilegio como parte de una corrección técnica.
- Política de cuentas aprobada: ambos roles leen y pueden vincular cuentas a nivel organización; solo Admin crea y edita sus propias cuentas. No conceder borrado ni reasignación de cuentas.
