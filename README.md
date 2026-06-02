# agent-skills

Mis [agent skills](https://agentskills.io) versionadas y listas para instalar con el
CLI de Vercel ([`npx skills`](https://github.com/vercel-labs/skills)). El versionado
se lleva con git: cada commit/tag del repo es la unidad de release.

## Skills

| Skill | Que hace |
|---|---|
| [`session-handoff`](skills/session-handoff) | Escribe un handoff estructurado para que una sesion nueva retome el trabajo sin releer toda la conversacion. |
| [`delegate-implementation`](skills/delegate-implementation) | Delega la implementacion de un plan a un agente externo (Codex) en modo no-interactivo y luego revisa el resultado. |
| [`pr-review-orchestrator`](skills/pr-review-orchestrator) | Coordina una revision de codigo multi-agente (correctness, simplificacion, convenciones, diseno) y sintetiza un veredicto. |

Forman un ciclo coherente: **planear -> `delegate-implementation` -> `pr-review-orchestrator` -> `session-handoff`**.

## Instalar

Reemplaza `<owner>` por tu usuario/org de GitHub una vez publicado el repo.

```bash
# Todas las skills
npx skills add <owner>/agent-skills

# Una sola skill
npx skills add <owner>/agent-skills --skill session-handoff

# Listar lo que hay sin instalar
npx skills add <owner>/agent-skills --list

# Instalacion global (en vez de por proyecto)
npx skills add <owner>/agent-skills -g
```

### Dev local (sin publicar)

```bash
# Desde la raiz del repo
npx skills add . --list
npx skills add . --skill pr-review-orchestrator
```

### Actualizar

```bash
npx skills update            # todas
npx skills update session-handoff
```

## Estructura

```
skills/<nombre>/
├── SKILL.md          # requerido: frontmatter (name, description) + instrucciones
├── references/       # opcional: detalle que se carga bajo demanda
└── scripts/          # opcional: codigo ejecutable
```

`npx skills` descubre cualquier `skills/<nombre>/SKILL.md`. El `name` del frontmatter
debe coincidir con el nombre de la carpeta.

## Anadir una skill nueva

```bash
npx skills init skills/<nombre>     # crea el SKILL.md plantilla
bash scripts/validate.sh            # valida frontmatter y naming
```

Guia de formato: https://agentskills.io/specification

## Validacion

`scripts/validate.sh` verifica que cada `SKILL.md` tenga `name` y `description` y que
el `name` coincida con su carpeta. Se corre en CI en cada push/PR
(`.github/workflows/validate.yml`).
