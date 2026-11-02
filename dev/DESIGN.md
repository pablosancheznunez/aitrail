# aitrail — diseño

**AI transparency, provenance and research integrity**
Estado: diseño, sin código. Fecha: 2026-11-02.

## 1. Qué es y qué no es

Un paquete para **documentar, verificar y declarar** el uso de IA en un proyecto de investigación, fase a fase, de forma que la declaración final se genere a partir de un registro y no se escriba de memoria al final.

No es:

- un cliente de ChatGPT, Claude u otro modelo: no llama a ninguna IA;
- un detector de texto generado por IA: esos detectores no son fiables y penalizan a quienes escriben en una segunda lengua, así que el paquete no lo intentará;
- un certificador de cumplimiento: ayuda a cumplir políticas de revistas y universidades, pero nunca afirma que un proyecto las cumple.

**Nombre:** `aitrail` (el rastro del uso de IA), libre en CRAN. Prefijo de funciones: `ait_`.

## 2. Aportación diferencial

1. **Registro estructurado por fases** del proyecto: revisión bibliográfica, diseño, recogida y tratamiento de datos, análisis y código, interpretación, redacción, traducción y edición, figuras, revisión por pares y divulgación.
2. **Supervisión humana explícita**: cada uso puede tener verificaciones asociadas (quién, cómo y con qué resultado). La auditoría señala los usos sin verificar.
3. **El registro vive con el proyecto**: ficheros de texto en `ai-log/`, versionados con git junto al código y los datos.
4. **Declaración generada desde el registro**: un texto breve para métodos o agradecimientos, un anexo completo y un JSON legible por máquina.
5. **Comprobación de referencias**: detecta referencias que no existen o cuyos metadatos no coinciden, un fallo típico de los modelos de lenguaje.

## 3. Marcos de referencia

Hay que comprobar la versión vigente de cada marco antes de implementar.

| Marco | Uso en el paquete |
|---|---|
| ICMJE Recommendations (sección sobre IA) | Qué declarar y dónde; la IA no puede ser autora |
| COPE, *Authorship and AI tools* | Responsabilidad humana y transparencia |
| Comisión Europea, *Living guidelines on the responsible use of generative AI in research* | Principios para investigadores, organizaciones y financiadores |
| GAIDeT (Generative AI Delegation Taxonomy) | Vocabulario de tareas delegadas a la IA |
| AID Framework (Weaver, 2024) | Estructura de la declaración por tipo de uso |
| CRediT | Roles humanos de quien usa y de quien verifica |

**Decisión:** el vocabulario de fases y tareas será propio, porque tiene que cubrir todo el ciclo de investigación, e incluirá una correspondencia publicada con GAIDeT. Así no queda atado a un solo marco.

## 4. Modelo de datos

Un directorio `ai-log/` en la raíz del proyecto, con **un fichero JSON por registro**: así los diffs son limpios y no hay conflictos al trabajar en equipo. Habrá un JSON Schema en `inst/schema/`, para que otras herramientas puedan leer y escribir el mismo formato, igual que en narrative-cv-crosswalk.

| Registro | Campos principales |
|---|---|
| `tool` | id, nombre, proveedor, modelo, versión, acceso (web, API, local), condiciones de retención de datos |
| `use` | id, fase, tarea, herramienta, propósito, persona (nombre u ORCID), fecha, grado de uso del resultado (`none`, `partial`, `substantial`), ficheros afectados, riesgos anotados |
| `interaction` | uso, fecha y hora, prompt (según la política de privacidad), resumen o hash de la respuesta, parámetros conocidos |
| `verification` | uso, verificador, método (`source_check`, `rerun_analysis`, `expert_review`, `reference_check`, `other`), resultado (`accepted`, `modified`, `rejected`), notas, fecha |

Los identificadores son cortos y se derivan del contenido, de modo que son estables y reproducibles.

## 5. Funciones

| Función | Qué hace |
|---|---|
| `ait_init(path = ".")` | Crea `ai-log/` y la configuración: metadatos del proyecto y política de almacenamiento de prompts |
| `ait_tool()` | Registra una herramienta y su versión |
| `ait_register_use(phase, task, tool, purpose, output_used, ...)` | Registra un uso en una fase |
| `ait_log_interaction(use, prompt, response = NULL, store = c("hash", "full", "excerpt", "none"))` | Registra prompts y respuestas según la política de privacidad |
| `ait_verify(use, method, outcome, verifier, notes)` | Registra la supervisión humana |
| `ait_check_references(x)` | Comprueba DOIs y referencias (BibTeX, texto o DOIs) en doi.org, Crossref y DataCite |
| `ait_audit(path)` | Aplica reglas de completitud y coherencia al registro |
| `ait_disclosure(path, style = c("short", "full", "json"), lang = c("en", "es"))` | Genera la declaración de uso de IA |
| `ait_report(path, file)` | Informe HTML autocontenido y reproducible |

Las funciones propuestas originalmente encajan así: `register_ai_use()` → `ait_register_use()`, `track_ai_interaction()` → `ait_log_interaction()`, `validate_ai_references()` → `ait_check_references()`, `audit_ai_workflow()` → `ait_audit()`, `generate_ai_disclosure()` → `ait_disclosure()`. El prefijo `ait_` sigue la convención de tus otros paquetes (`af_`, `vb_`, `nc_`).

### `ait_check_references()`: estados

| Estado | Significado |
|---|---|
| `verified` | El DOI existe y título, año y primer autor coinciden |
| `mismatch` | El DOI existe, pero los metadatos no coinciden (posible referencia inventada o mal atribuida) |
| `not_found` | No se encuentra en las fuentes consultadas; **no significa que sea inventada** |
| `no_identifier` | Sin DOI: se intenta buscar por título y se marca como menos fiable |
| `unchecked` | Sin conexión o fuente caída |

### `ait_audit()`: reglas

Cada regla tiene un identificador estable, una severidad (`info` o `warn`) y una explicación. **No hay puntuación global.**

- R01 Uso sin ninguna verificación.
- R02 Uso `substantial` en redacción o interpretación sin verificación de experto.
- R03 Herramienta sin modelo o versión.
- R04 Fase de revisión bibliográfica con IA sin `ait_check_references()`.
- R05 Uso de IA en revisión por pares, que muchas revistas prohíben.
- R06 Prompts guardados completos cuando la política del proyecto dice `hash`.
- R07 Posibles datos personales detectados en prompts guardados completos.

## 6. Privacidad y seguridad

- **Por defecto, los prompts se guardan como hash**, porque pueden contener datos no publicados o datos personales. Guardarlos completos es una decisión explícita.
- Antes de guardar un prompt completo, se avisa si contiene patrones de datos personales: correos, DNI o NIE, teléfonos.
- El registro nunca guarda claves de API.
- Todo queda en local. Solo `ait_check_references()` sale a la red, y solo envía DOIs o títulos.

## 7. Dependencias

`Imports`: jsonlite. `Suggests`: curl (comprobación de referencias), knitr, rmarkdown y testthat. Sin conexión, el paquete funciona entero salvo la comprobación de referencias, que devuelve `unchecked`.

## 8. Datos de ejemplo y web

- Un proyecto ficticio completo en `inst/extdata/demo-project/`, marcado como sintético: un estudio con uso de IA en revisión, análisis y redacción, con algunas verificaciones ausentes para que la auditoría tenga algo que señalar.
- Web en `pablosancheznunez.com/aitrail/`, con informe de ejemplo y declaración de ejemplo en inglés y en español.

## 9. Pruebas

- Validación de cada registro contra el JSON Schema.
- Un fichero de prueba por regla de auditoría.
- Comprobación de referencias contra respuestas grabadas, como en narrativecv; nunca contra la red en CRAN.

## 10. Hoja de ruta

| Versión | Contenido |
|---|---|
| 0.1 | Registro, verificaciones, auditoría, declaración (en y es), comprobación de referencias, informe |
| 0.2 | Importar exportaciones de chats (ChatGPT, Claude, genérico), integración con Quarto para insertar la declaración en el manuscrito, recordatorio opcional en un hook de git |
| 0.3 | Agregación entre proyectos para grupos, revistas o universidades, solo con consentimiento de cada proyecto |

## 11. Decisiones abiertas

1. Si la correspondencia con GAIDeT es suficiente o conviene ofrecer también vocabularios de revistas concretas.
2. Si la política de prompts por defecto debe ser `hash` (más privado) o `excerpt` (más útil para auditar).
