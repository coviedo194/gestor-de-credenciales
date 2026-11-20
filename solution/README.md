# Gestor de credenciales — Instalación

Esta carpeta contiene la **solución de Dataverse desempaquetada**. Está pensada para quien quiere **instalar y usar** el gestor de credenciales.

## 📦 ¿Dónde está el `.zip` para importar?

El archivo distribuible **no vive en este repositorio**: se publica como **Release de GitHub**.

👉 **[Ir a Releases](../../../releases)** → descarga el último `GestorDeCredenciales_<versión>.zip`.

> 📦 También puedes generarlo tú: `pac solution pack --zipfile GestorDeCredenciales.zip --folder solution/package --packagetype Unmanaged`.

---

## 🚀 Instalación paso a paso

### Requisitos

- Un entorno de **Power Platform** con Dataverse y permisos para importar soluciones y asignar roles.
- Una cuenta para las conexiones de **Microsoft Dataverse** y **Approvals** de los flujos.

### 1. Importar la solución

1. Ve a [make.powerapps.com](https://make.powerapps.com) y selecciona tu entorno.
2. **Soluciones** → **Importar solución** → arrastra el `.zip`.
3. Crea o selecciona una conexión para cada referencia de conexión:
   - `GC_Dataverse` (Microsoft Dataverse): la usan los flujos hijos para leer y escribir los campos protegidos.
   - `GC_Approvals` (Approvals): la usa la solicitud de permiso.
4. Pulsa **Importar** y comprueba que los seis flujos `(GC)` quedan **activados**.

### 2. Configurar la variable de entorno

| Variable | Para qué sirve |
|----------|----------------|
| `GC_UrlApp` (`ovg_GC_UrlApp`) | URL de la app basada en modelo que se incluye en la aprobación. **Hay que rellenarla** con `https://<tu-entorno>.<región>.dynamics.com/main.aspx?appid=<GUID de la app>` (el valor por defecto es una plantilla). |

### 3. Asignar los roles

| Rol | Para quién |
|-----|------------|
| `Gestión de credenciales - Usuarios` | Quien consulta el catálogo y solicita acceso. No crea credenciales. |
| `Gestión de credenciales - Admin` | Quien da de alta, mantiene y comparte credenciales y cuentas. |

Asígnalos desde [admin.powerplatform.microsoft.com](https://admin.powerplatform.microsoft.com) → tu entorno → **Usuarios + permisos** → **Roles de seguridad**.

> 🔐 Los campos contraseña y nota privada tienen **seguridad de campo**. No concedas su lectura a estos roles: el acceso se hace a través de la vista privada y los flujos.

### 4. Usar la app

Abre la app **Gestión de credenciales**. Desde una credencial, el comando **Vista Privada** abre la custom page que muestra o solicita el acceso al secreto.

> ⚠️ Los flujos aún no comprueban en el servidor quién los llama. Revisa [las limitaciones](../docs/alcance.md#6-limitaciones-y-mejoras-pendientes) antes de guardar credenciales reales.

---

## 📂 ¿Qué hay dentro de esta carpeta?

```
solution/
├── README.md              ← este archivo
├── package/               ← solución desempaquetada (fuente de verdad)
│   ├── AppModules/        ← app "Gestión de credenciales"
│   ├── CanvasApps/        ← custom page de vista privada y biblioteca de comandos
│   ├── Entities/          ← ovg_credencial, ovg_logdecredencial, account (formulario y vista)
│   ├── Roles/             ← Usuarios, Admin
│   ├── WebResources/      ← icono y script que abre la vista privada
│   ├── Workflows/         ← flujos padre/hijo
│   └── Other/             ← Solution.xml (versión), Customizations.xml
├── canvas-src/            ← fuentes YAML de la custom page (inspección)
└── scripts/
    └── regenerate-solution.ps1
```

> ⚠️ **No edites `package/` ni `canvas-src/` a mano.** Haz los cambios en el entorno y regenera.

---

## Para desarrolladores

Para regenerar, copia `.env.example` como `.env` en la raíz y configura `GC_PAC_PROFILE` con el perfil PAC del entorno fuente no administrado (`pac auth list`). `.env` está ignorado por Git.

```powershell
pwsh solution/scripts/regenerate-solution.ps1
```

El script exporta la solución, borra y regenera `package/` y `canvas-src/`, sustituye la URL del entorno en los flujos por una plantilla y restaura el perfil PAC que estuviera activo. `-PacProfileName <nombre>` sobrescribe `.env`.

**Releases:** con la solución regenerada y en `master`, lanza la Action «Release de la solución» desde la pestaña Actions o con `gh workflow run release-solution.yml`. Crea la release `vX.X.X.X` con `GestorDeCredenciales_X.X.X.X.zip` a partir de la versión de `Solution.xml`; si esa versión ya existe, no hace nada.
