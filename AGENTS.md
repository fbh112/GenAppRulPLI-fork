# AGENTS.md — GenApp PL/I Workspace

## Documentation Output Directory
All generated documentation, analysis reports, diagrams, and plans MUST be saved under the `docs/` folder.

### Folder Structure
```
docs/
  inventory/          # Application inventory reports
  crud-matrix/        # DB2 CRUD matrix
  domains/            # Functional domain analysis
  business-rules/     # Extracted business rules
  hotspots/           # Migration hotspot analysis
  migration/          # Migration plans and to-be architecture
  programs/           # Per-program documentation
```

## Local Metadata Database
- **Location**: `/Users/tingwu/Library/Application Support/IBM Bob/User/workspaceStorage/791364b0f08ce1ae20fe0806793fa031/IBM.bob-z-extension/.tmi/WCA4ZTMIOutput/ScannerOutput.db`
- Stored in `.bobz/local-settings.json` under `databaseLocation`

## Data Dictionary
- Location: `.bobz/DD.json`

## Source Directories
| Directory | Contents |
|-----------|----------|
| `pli/`    | PL/I source programs |
| `plinc/`  | PL/I include (copybook) files |
| `jcl/`    | JCL jobs |
| `DDL/`    | DB2 DDL scripts |
| `Resources/` | BMS maps and other resources |

## Selected Migration Domain
**Customer** domain has been selected as the migration target domain.

## Notes
- This is a PL/I port of the IBM GenApp sample application
- Programs follow naming convention: LG + function code + AC/IC/UC/DP/AP/UP + DB/VS/US/OL + 01
