# Alcance funcional y técnico — Gestor de credenciales

## 1. Propósito y alcance del documento

La solución proporciona un catálogo de credenciales relacionado con clientes (cuentas), manteniendo visibles los metadatos necesarios para identificar cada registro y limitando el acceso a contraseña y nota privada. Un usuario sin acceso puede solicitarlo al propietario; tras la aprobación, el diseño comparte la fila para lectura y escritura. Un historial personalizado registra consultas y actualizaciones sin incluir los valores secretos.

Este documento distingue:

- **Comprobado estáticamente:** configuración y fórmulas presentes en la exportación local de `OVGGestordecontraseas` 1.0.0.9.
- **Comprobado en el entorno:** configuración consultada mediante las API de Dataverse y herramientas de Power Platform.
- **Pendiente de verificación:** configuración del entorno y comportamiento efectivo que aún no se conoce.

Este documento describe el funcionamiento y la configuración de la solución, no su historial de desarrollo. No es una auditoría de seguridad exhaustiva ni una prueba de explotación. El entorno de desarrollo contiene datos ficticios según su propietario. Una exportación no demuestra por sí sola el comportamiento con usuarios reales ni sus privilegios acumulados.

## 2. Alcance funcional

### 2.1 Funcionamiento definido

1. Usuarios consultan un catálogo de metadatos de credenciales asociados a clientes/cuentas.
2. Los campos contraseña y nota privada tienen seguridad de campo; la lectura y escritura privilegiadas se realizan a través de una conexión de Dataverse de los flujos hijos.
3. La página privada permite leer y actualizar esos campos si el usuario tiene permiso efectivo de edición de la fila.
4. Sin ese permiso, el usuario puede enviar una solicitud de aprobación al propietario; al aprobarse se comparte la fila con lectura y escritura.
5. El historial personalizado registra consultas y actualizaciones, sin incluir valores secretos. Ambos roles leen todo el historial a nivel organización y el formulario de credencial lo muestra en una subcuadrícula.
6. El rol Usuarios no permite crear credenciales.
7. Ambos roles pueden leer y anexar a cuentas globalmente; Admin puede además crear y escribir cuentas con profundidad Basic. Ninguno concede borrado ni reasignación de cuentas.
8. La aplicación incluye formulario, vista y navegación de cuentas. Los flujos padre autorizan cada llamada en el servidor (sección 7); Code Apps es una propuesta de V2.

La conexión privilegiada no representa una suplantación real del usuario que inició la aplicación. Por eso los flujos padre no usan el GUID ni el email que envía la página: identifican a quien llama a partir de la identidad autenticada que Power Platform añade a la llamada y solo pasan a los flujos hijos el usuario verificado.

### 2.2 Estado observable en la exportación

- La aplicación basada en modelo `ovg_Gestiondecredenciales` incluye `ovg_credencial` y `account`, con sus formularios/vistas seleccionados y una única entrada de Cuentas en el sitemap.
- El formulario principal de credencial muestra cliente, usuario, partner, nota pública y propietario; no muestra contraseña ni nota privada. El lookup de cliente usa por defecto la vista de cuentas `Activos - GC`.
- El mismo formulario incluye la subcuadrícula `Logs` (relación `ovg_logdecredencial_credencial_credencial`) con la vista `Logs de credencial activo`, cuatro filas por página y sin búsqueda rápida ni selector de vistas. Título, estado y razón para el estado están ocultos en el formulario.
- La vista `Logs de credencial activo` (`e615a369-be7e-4fb8-abc8-f0902f6afcac`) filtra `statecode=0`, muestra fecha de creación, usuario y título, y ordena por fecha de creación descendente. `ovg_logdecredencial` no figura como componente de la aplicación basada en modelo; el historial se consulta desde la subcuadrícula.
- La página `solution/canvas-src/ovg_gestindecredencialvistaprivada_462b9/Src/Pantalla Inicio.pa.yaml` consulta `RecordInfo.EditPermission`. Si es verdadero, invoca `(GC)Obtienecredenciales(Padre)` con el ID de credencial y el `systemuserid`; si no, navega a la pantalla de solicitud de permiso, excepto en el contexto de Studio.
- El guardado invoca `(GC)Actualizacredenciales(Padre)` pasando contraseña, nota privada, ID de credencial y `systemuserid`.
- `BtnGuardar.DisplayMode` habilita Guardar cuando la contraseña o la nota privada difieren de los valores obtenidos del flujo, comparándolos con `TxtContrasenia.Value` y `TxtNotaPrivada.Value`.
- La pantalla sin permiso invoca `(GC)Solicitarpermiso(Padre)` con ID de credencial, email del solicitante y `systemuserid`. Después navega a la pantalla de confirmación.
- La pantalla de confirmación ejecuta `RequestHide()` en `OnVisible`; el código de solicitud también la llama después de navegar. Por ello, el mensaje de “esperar aprobación” puede cerrarse inmediatamente.
- El recurso web `ovg_opencustompagedialogfixsize` abre una página personalizada con un cuadro de diálogo de tamaño fijo aproximado de 500×400 y desplazamiento vertical de 53 px. El `catch` está vacío y silencia errores.
- En las fórmulas revisadas no hay manejo explícito de errores (`IfError`) para estas llamadas.

### 2.3 Modelo de datos

**`ovg_credencial`**

- Tabla propiedad de usuario (`UserOwned`), auditoría de tabla habilitada.
- Icono vectorial `ovg_/icons/credencial.svg`: llave negra (`#000000`) con fondo transparente. La asignación mediante `IconVectorName` y el contenido del recurso están publicados y comprobados mediante la API de Dataverse en el entorno de desarrollo autorizado.
- `ovg_cliente`: lookup a cuenta, marcado como recomendado.
- `ovg_usuario`: texto requerido para el usuario o identificador de cliente de la credencial; no es un lookup a `systemuser`.
- `ovg_contrasenia` y `ovg_notaprivada`: campos con `IsSecured=1` y auditoría de campo habilitada.
- `ovg_notapublica`: campo no asegurado, auditoría habilitada.
- `ovg_titulo`: nombre autonumerado con formato `GC-{SEQNUM:4}`.
- `ovg_iddepartnervinculado`: opción; `ovg_mensajeparaauditoria`: campo presente.

**`ovg_logdecredencial`**

- Tabla propiedad de usuario; auditoría de tabla deshabilitada.
- Incluye título requerido y lookups requeridos a credencial y usuario.
- Los flujos hijos crean registros con título `Credencial consultada 🟡` u `Credencial actualizada 🟠`.
- En las acciones de auditoría revisadas no se guardan los valores de contraseña ni nota privada. Ambos roles conceden únicamente lectura de nivel Organización sobre la tabla; la creación de registros se realiza mediante la conexión de los flujos.

**Seguridad de campo en la exportación:** `FieldSecurityProfiles` en `solution/package/Other/Customizations.xml` está vacío. Esto por sí solo no demuestra que no exista un perfil en el entorno.

**Comprobación en el entorno:** se encontraron solo dos registros `fieldpermissions`, uno para `ovg_contrasenia` y otro para `ovg_notaprivada`; ambos tienen `canread`, `cancreate` y `canupdate` con valor `4`, asociados al perfil integrado `Administrador del sistema` (`572329c1-a042-4e22-be47-367c6374ea45`). El perfil tiene miembros usuarios y ningún equipo. Esta consulta confirma que no hay un perfil personalizado de acceso a esos campos entre los registros consultados; no se registra ni reproduce la lista de usuarios. El rol funcional `Gestión de credenciales - Admin` no equivale al perfil `Administrador del sistema` y no recibe acceso a esos campos por esta configuración.

## 3. Alcance técnico e implementación actual

### 3.1 Aplicación de lienzo y comandos

La app define `nfSystemUser` mediante `EntraObjectId` y la tabla Usuarios, y obtiene `nfCredencialId` de `Param("recordId")`. En Studio aparece un GUID fijo de desarrollo. Ese valor de diseño no es una validación de acceso y no debe confundirse con una identidad autenticada.

La vista privada abre desde el registro en contexto mediante la acción JavaScript de aplicación. La solución también contiene una biblioteca de comandos en formato MSAPP. El script de exportación extrae únicamente las custom pages (`CanvasAppType=2`) con PAC SourceCode; no extrae esa biblioteca. Las fuentes de inspección se mantienen separadas de los componentes de la solución.

### 3.2 Flujos y conexiones

- Los tres flujos padre de Power Apps V2 comprueban identidad, rol y, en obtención y actualización, el acceso de escritura a la credencial antes de invocar a sus flujos hijos (sección 7). Usan la referencia `ovg_GC_Dataverse` para esas consultas.
- Los hijos emplean la referencia `ovg_GC_Dataverse`; el hijo de solicitud también utiliza una conexión de Approvals (`ovg_sharedapprovals_2c685`). Que una referencia figure en la solución no confirma quién es su propietario, credenciales, uso compartido o permisos efectivos.
- El hijo de obtención ejecuta `GetItem` seleccionando contraseña y nota privada, devuelve esos valores y ejecuta una rama de auditoría. La rama de auditoría tiene `runAfter: {}`; la respuesta no espera a que termine y puede registrarse aunque falle la operación principal.
- El hijo de actualización escribe los campos secretos mediante `UpdateOnlyRecord`, responde a la app y ejecuta su rama de auditoría de forma paralela, sin que la respuesta espere esa auditoría.
- Las entradas y salidas que transportan secretos están ocultas en el historial de ejecución (`secureData`): disparadores de obtención y actualización (padre e hijo), `GetCredencial`, `Actualizar_una_fila`, las respuestas a la app y las llamadas a los hijos. Las acciones de auditoría y el flujo de solicitud no transportan secretos y se mantienen visibles.
- La auditoría personalizada observada se limita a obtención y actualización. No se registra explícitamente solicitud, resultado de aprobación ni concesión de acceso. Los mensajes de auditoría revisados no contienen los campos secretos.
- El flujo de solicitud obtiene la credencial, expande `owninguser` y `ovg_cliente`, y dirige la aprobación estándar al email del propietario usuario. Si se aprueba, ejecuta `GrantAccess` con `ReadAccess` y `WriteAccess` para el `systemuserid` recibido. Si se rechaza, no concede acceso. La respuesta del hijo se emite tras la aprobación o rechazo; el padre no tiene acción `Response` y espera al flujo hijo, por lo que hay un riesgo de demora o timeout de UX, no un fallo probado.
- La ruta observada presupone propietario usuario (`owninguser`); la aprobación para filas propiedad de equipo no está claramente soportada.
- No se identificó un mecanismo de revocación, expiración o notificación de acceso concedido en el flujo exportado.

### 3.3 Organización de los roles

#### Matriz actual por tabla y rol

Fuente: definiciones de roles en `solution/package/Roles/`.
Estas matrices cubren las tablas funcionales de la solución, no todos los
privilegios auxiliares de plataforma incluidos en los roles.

**Leyenda de niveles**

| Nivel | Valor en la exportación | Alcance |
| --- | --- | --- |
| Ninguno | Privilegio ausente | Este rol no concede el privilegio sobre la tabla. |
| Usuario | `Basic` | Registros propios y otros accesibles mediante los mecanismos de seguridad de Dataverse, como equipos o compartición, según el derecho concedido. |
| Unidad de negocio | `Local` | Registros de la unidad de negocio del rol. |
| Unidad y subordinadas | `Deep` | Registros de esa unidad de negocio y sus unidades subordinadas. |
| Organización | `Global` | Todos los registros de la tabla en el entorno. |

**Gestión de credenciales - Usuarios**

| Tabla de Dataverse | Crear | Leer | Escribir | Eliminar | Anexar | Anexar a | Asignar | Compartir |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Credenciales (`ovg_credencial`) | Ninguno | Organización | Usuario | Ninguno | Usuario | Ninguno | Ninguno | Ninguno |
| Cuentas / clientes (`account`) | Ninguno | Organización | Ninguno | Ninguno | Ninguno | Organización | Ninguno | Ninguno |
| Historial (`ovg_logdecredencial`) | Ninguno | Organización | Ninguno | Ninguno | Ninguno | Ninguno | Ninguno | Ninguno |

**Gestión de credenciales - Admin**

| Tabla de Dataverse | Crear | Leer | Escribir | Eliminar | Anexar | Anexar a | Asignar | Compartir |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Credenciales (`ovg_credencial`) | Usuario | Organización | Usuario | Usuario | Usuario | Ninguno | Ninguno | Usuario |
| Cuentas / clientes (`account`) | Usuario | Organización | Usuario | Ninguno | Ninguno | Organización | Ninguno | Ninguno |
| Historial (`ovg_logdecredencial`) | Ninguno | Organización | Ninguno | Ninguno | Ninguno | Ninguno | Ninguno | Ninguno |

**Cómo interpretar la matriz**

- **Anexar** permite asociar una fila de esa tabla a otra; **Anexar a** permite
  que otras filas se asocien a ella. Para vincular una credencial a una cuenta,
  intervienen Anexar en credencial y Anexar a en cuenta, además de los permisos
  necesarios para leer y crear o actualizar la credencial.
- Escritura de nivel Usuario no equivale a poder editar cualquier credencial:
  un usuario que solo tiene lectura del registro necesita adquirir el derecho
  de escritura, por ejemplo mediante la compartición aprobada.
- **Ninguno no es una denegación global.** Otros roles y equipos pueden
  conceder el privilegio. Compartir una fila no sustituye la necesidad de
  disponer del privilegio de tabla correspondiente.
- Leer o escribir la tabla no concede por sí solo acceso a `ovg_contrasenia`
  ni `ovg_notaprivada`: ambos campos tienen seguridad de campo independiente.
  El Admin funcional tampoco obtiene ese acceso directo.
- Ambos roles leen todo el historial a nivel Organización: cualquier persona
  con uno de ellos ve quién consultó o actualizó cada credencial, aunque no
  tenga acceso a sus secretos. Ningún rol crea, modifica ni borra registros
  del historial; los flujos los crean mediante su conexión. Esta visibilidad
  es la política aprobada para aportar trazabilidad y disuadir el uso indebido;
  no impide por sí sola una filtración ni registra los valores secretos.
- Los privilegios auxiliares sobre tablas del sistema, procesos y SharePoint
  se conservan en los XML de roles y se describen más abajo. No deben
  confundirse con permisos funcionales de estas tres tablas.

#### Responsabilidad de cada rol

Admin es el gestor del catálogo: crea, mantiene y comparte credenciales, y
crea y edita cuentas con alcance Usuario. No es un administrador global de
credenciales ni obtiene acceso directo a todos los secretos.

Usuarios consulta el catálogo y solicita acceso a las credenciales que necesita.
No puede crear ni compartir credenciales mediante este rol. Ambos roles tienen
lectura global de credenciales y escritura/anexado con alcance Usuario.
Ninguno incluye privilegios `Assign` o `AppendTo` sobre credencial. Sobre
`ovg_logdecredencial` ambos tienen solo lectura de nivel Organización.

Los privilegios de cuenta no
conceden permisos equivalentes sobre credenciales ni sustituyen la autorización
para acceder a secretos.

Los dos roles incluyen privilegios extensos sobre procesos/workflows y SharePoint, comunes a ambos. Esos privilegios de Dataverse no equivalen automáticamente a administración de cloud flows; no se recomienda eliminarlos sin una validación de dependencias. Los derechos efectivos son acumulativos: otros roles, equipos, propiedad y comparticiones pueden ampliarlos; un rol sin un privilegio no revoca lo concedido por otro. La política de cuentas también está presente en las copias de los roles por unidad de negocio. Esto no sustituye una prueba con usuarios limitados.

**Conexiones y seguridad de campo:** ambas connection references están activas según consulta a Dataverse. La identidad exacta con que se ejecutan los flujos sigue pendiente. La consulta de `fieldpermissions` descrita arriba confirmó únicamente las dos asignaciones al perfil Administrador del sistema; el rol funcional Admin no tiene perfil propio de acceso a los campos.

**Aún pendiente de verificación:** identidad/privilegios efectivos de las conexiones al ejecutar cada flujo, usuarios de ejecución y uso compartido de cada flujo, asignaciones reales de roles fuera de la comparación de privilegios, licencias, políticas DLP y auditoría configurada en la organización. No se ha confirmado que la conexión privilegiada tenga privilegios de sistema.

## 4. Gestión de cuentas

La aplicación incluye cuentas en su navegación y utiliza estos componentes:

| Componente | Definición | Identificador |
| --- | --- | --- |
| Formulario principal `Principal GC` | Únicamente el campo `name`, sin etiqueta de sección y con encabezado y pie vacíos | `7ffe6e2c-a43c-4f07-8da6-2046af72e7f5` |
| Vista `Activos - GC` | Filtro `statecode=0`, orden ascendente por `name` y única columna visible `name` | `7bbc8016-b0e6-42e5-9e32-76e81260b623` |

La solución incluye account sin todos sus subcomponentes y referencia explícitamente
el formulario y la vista. La MDA contiene el componente tipo 1 de account
(`70816501-edb9-4740-a16c-6a5efbc05d84`) y una única subárea de Cuentas.
Para gestionar esta referencia mediante `AddAppComponents` se utiliza el tipo
concreto `Microsoft.Dynamics.CRM.account`.

La solución incluye además la configuración de búsqueda de Dataverse de la
aplicación (`dvtablesearch` `M365_Primary_model_ovg_Gestiondecredenciales`,
`39664f67-0eb5-f111-aaac-7c1e5272617c`) con las tablas `ovg_credencial` y
`account`. Está inactiva (`statecode=1`).

La validación mediante `ValidateApp` es satisfactoria, con una advertencia de
dependencia de la vista Credenciales con permisos sobre `principalobjectaccess`.
No figura una dependencia pendiente de account.

La vista `Activos - GC` es además la vista por defecto del lookup de cliente en el formulario de credencial.

Quedan por validar las reglas de asociación, propiedad y acceso efectivo a credenciales. Los privilegios de cuenta aprobados no sustituyen esa revisión.

## 5. V2 futura: Code Apps — excluida del trabajo actual

Code Apps es una línea futura solicitada. No implementarla ahora. Su evaluación futura debe comparar, al menos:

- **Vault dedicado:** gestión de secretos, rotación, expiración, revocación y separación del catálogo.
- **Dataverse con API/plug-in personalizado:** servicio de servidor autorizado que valida identidad y acceso al registro, usa privilegios mínimos y no confía en GUIDs proporcionados por el cliente.

Un frontend Code App no resuelve la autorización por sí mismo. La arquitectura futura debe definir identidad de servidor, modelo de permisos, acceso condicionado por cliente, historial no sensible, revocación/expiración, gestión del ciclo de vida de cuentas y credenciales, y continuidad del catálogo cuando un empleado deja la organización. No iniciar implementación ni migración de datos como parte de este documento.

## 6. Limitaciones y mejoras pendientes

### Mejoras funcionales y técnicas

1. Mantener visible la confirmación de solicitud y añadir estado/manejo claro de error.
2. Definir auditoría de solicitudes, decisiones y concesiones; encadenar operación, auditoría y respuesta para no registrar éxito de una operación fallida ni responder antes de asegurar el registro.
3. Diseñar expiración/revocación y comprobar soporte a filas propiedad de equipo en el flujo de solicitud.
4. Devolver a la app un resultado de denegación explícito en lugar de un error genérico.

### Decisiones/verificaciones pendientes

- Probar la MDA con roles limitados; la configuración de formulario, vista, referencia de tabla y navegación está verificada mediante API.
- Probar la autorización de los flujos con usuarios reales del rol Usuarios, con credenciales compartidas y con equipos propietarios.
- Confirmar quién puede enlazar cuentas y leer/escribir/compartir cada credencial.
- Probar con roles limitados la subcuadrícula `Logs` y la apertura de sus registros, ya que `ovg_logdecredencial` no es componente de la aplicación basada en modelo.
- Verificar uso compartido de flujos, DLP y auditoría; las referencias de conexión están activas y la configuración de seguridad de campo se describe en la sección de modelo de datos.
- Confirmar la ruta de apertura de la página privada y si la biblioteca de comandos participa realmente en el comando de aplicación.
- Probar UX y manejo de errores con datos ficticios en un entorno controlado antes de publicar.

## 7. Autorización en servidor

Cada flujo padre autoriza la llamada antes de invocar a su flujo hijo:

1. **Identidad:** toma el ID de Microsoft Entra de la cabecera `x-ms-client-object-id` del disparador, que Power Platform rellena a partir del token de quien ejecuta la app, y busca el usuario activo con ese `azureactivedirectoryobjectid`. Los parámetros `Solicitante Guid` y `Solicitante Email` que envía la página se ignoran.
2. **Rol:** exige `Gestión de credenciales - Usuarios` o `Gestión de credenciales - Admin` (cualquier copia por unidad de negocio, por `parentrootroleid`), asignado directamente o mediante un equipo.
3. **Registro (obtención y actualización):** exige acceso de escritura a la credencial. Como ambos roles conceden Escribir con alcance Usuario, ese acceso existe si la persona es propietaria, pertenece al equipo propietario o tiene la fila compartida con escritura, directamente o mediante un equipo (`principalobjectaccess`, derechos directos o heredados). La credencial se lee primero por ID, de modo que un ID no válido detiene el flujo.
4. **Solicitud de permiso:** solo exige identidad y rol, porque la usa quien todavía no tiene acceso. El hijo recibe el email y el `systemuserid` verificados.

Si alguna comprobación falla, el flujo termina con el error `GC_NO_AUTORIZADO`, no invoca al hijo y la app muestra un error.

**Comprobado en el entorno de desarrollo:** usuario sin rol de la app (denegado), usuario con rol sobre una credencial propia (lectura y actualización correctas, con el secreto oculto en el historial) y usuario con rol sobre una credencial ajena no compartida (denegado).

**Limitaciones:**

- Un administrador del sistema sin rol de la app queda denegado, y con rol solo accede a las credenciales propias o compartidas: el control no aplica los privilegios de otros roles.
- El cálculo de escritura presupone el alcance Usuario de ambos roles. Si se amplía ese alcance o se activa la seguridad jerárquica, hay que revisar la comprobación.
- La página sigue enviando los parámetros de solicitante por compatibilidad, aunque los flujos no los usen.
