# GenApp Demo — Final Verification: Use Case Coverage Summary

> This document maps every activity performed in this demo session to the 10 use cases defined  
> in the requirements specification, assesses coverage, and provides an honest gap analysis.

---

## Summary Scorecard

| Use Case | Title | Covered? | Evidence |
|---|---|---|---|
| UC-1 | Understand and visualize boundaries between CICS-based PL/I systems | ✅ Full | Steps 4, 6 |
| UC-2 | Understand and visualize batch job boundaries and functionality | ✅ Full | Steps 2, 6 |
| UC-3 | Find modules that integrate to other benefit systems (migration change points) | ✅ Full | Steps 6, 8, 9 |
| UC-4 | Find modules that use DB2 tables of the system being moved | ✅ Full | Steps 2, 3, 6 |
| UC-5 | Understand and visualize roles of CICS modules, batch jobs, DB2 tables | ✅ Full | Steps 2, 4, 6 |
| UC-6 | Understand integration interfaces (CTG, MQ) between mainframe and distributed | ✅ Partial | Step 6, Step 10 |
| UC-7 | Look at business rules to design equivalent rules in the target system | ✅ Full | Steps 7, BRD workflow |
| UC-8 | Use generated documentation to understand how the mainframe system functions | ✅ Full | All steps → docs/ |
| UC-9 | Understand hotspots: modules and DB2 tables used across many benefit systems | ✅ Full | Step 8 |
| UC-10 | PL/I programmer uses docs to understand functionality of a module | ✅ Full | BRD inventory, Step 11 (available) |

**Overall: 9/10 fully covered, 1/10 partially covered.**

---

## Detailed Use Case Mapping

---

### UC-1 — Understand and visualize boundaries between CICS-based PL/I systems

> *"An architect uses the tool to understand and visualize boundaries between different CICS-based PL/1 benefit systems in Kela's mainframe environment"*

**Coverage: ✅ Full**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 4** | [`docs/functional-domains.md`](docs/functional-domains.md) | Identified 5 functional domains (Customer, Policy, Motor, Batch Reporting, Infrastructure). Produced a Mermaid domain map showing all CICS programs, their transactions, how they call each other, and the shared tables that cross domain boundaries. |
| **Step 6** | [`docs/motor-domain-boundary.md`](docs/motor-domain-boundary.md) | Deep-drilled the Motor domain boundary: listed every component, its role, and whether it belongs exclusively to Motor or is shared. Produced a boundary visualization diagram showing data flows across the boundary. |

**Key findings delivered:**
- The Motor domain has the smallest boundary surface (1 program, 1 shared table, 1 output file, 0 CICS transactions, 0 inter-program calls).
- The cross-domain write coupling (`LGACUS01` writing the POLICY table) was flagged as an anomaly.
- Shared infrastructure programs (LGSTSQ, LGCMAREA.inc) were identified as cross-cutting all domains.

---

### UC-2 — Understand and visualize boundaries and functionality of batch jobs (JCL and PL/I code)

> *"An architect uses the tool to understand and visualize boundaries and functionality of batch jobs (including JCL and PL/1-code)"*

**Coverage: ✅ Full**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 2** | [`docs/application-inventory.md`](docs/application-inventory.md) | Inventoried all batch programs: LGBATCH, LGBATDB2, LGBATCHF, LGMOTOUT. Showed their input/output datasets, DB2 tables accessed, and sub-program calls. Listed the three JCL jobs (GenAppDDL, GenAppBind, CreateCSDDefs). |
| **Step 6** | [`docs/motor-domain-boundary.md`](docs/motor-domain-boundary.md) §3 | Documented LGMOTOUT batch flow step-by-step (file open → cursor open → fetch loop → write → close), its QSAM output record layout (132-byte FB), and return codes. Showed input dataset (GENASA1.MOTOR via DB2) and output dataset (MOTOROUT). |

**Key findings delivered:**
- LGMOTOUT is a pure batch program with no CICS context — clean separation from online tier.
- Batch jobs use `PGM=` invocation via JCL (no dedicated JCL in workspace for LGMOTOUT — flagged).
- LGBATCH reads a customer input file (CUSTIN), queries DB2, and writes a report (CUSTRPT).

---

### UC-3 — Find modules that integrate to other benefit systems (migration change points)

> *"An architect uses the tool to find modules that integrate to other benefit systems, so that it is easier to find places to modify as one system is moved from mainframe to EEPOS"*

**Coverage: ✅ Full**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 6** | [`docs/motor-domain-boundary.md`](docs/motor-domain-boundary.md) §5, §7 | Listed every integration point between Motor and other domains, the mechanism (shared Db2 table, FK constraint), and the specific change required at each point when Motor moves off the mainframe. |
| **Step 8** | [`docs/migration-hotspots.md`](docs/migration-hotspots.md) | Ranked all application-wide integration points (programs, tables, files, includes) by the number of programs and domains they touch — exactly the list of "places to modify" when a domain is moved. |
| **Step 9** | [`docs/motor-migration-effort.md`](docs/motor-migration-effort.md) | For Motor specifically: identified 5 migration dependencies with risk, likelihood, impact, and mitigation — a ready-made change plan. |

**Key findings delivered:**
- `LGSTSQ` (error logger) is the most cross-cutting integration point — every CICS program calls it.
- `LGCMAREA.inc` is the inter-program API contract — must be translated to the target API schema.
- Motor's only integration point is the shared MOTOR Db2 table — no program-to-program calls.

---

### UC-4 — Find modules that use DB2 tables of the system being moved

> *"An architect uses the tool to find modules that use DB2 tables of the system that will be moved from mainframe to EEPOS"*

**Coverage: ✅ Full**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 2** | [`docs/application-inventory.md`](docs/application-inventory.md) §2.2 | Complete matrix of every program → DB2 tables it accesses, with access mode (read/write/delete). |
| **Step 3** | [`docs/db2-crud-matrix.md`](docs/db2-crud-matrix.md) | Full CRUD matrix: for each DB2 table, which programs perform Create / Read / Update / Delete. |
| **Step 6** | [`docs/motor-domain-boundary.md`](docs/motor-domain-boundary.md) §4 | Listed every program inside and outside the Motor domain that reads or writes the MOTOR table: LGAPDB01 (write), LGIPDB01 (read), LGMOTOUT (read). |

**Key findings delivered:**
- MOTOR table: 3 programs access it across 2 domains.
- POLICY table: 4 programs access it across 2 domains — cross-domain write coupling flagged.
- CUSTOMER table: 6 programs access it — the broadest DB2 dependency in the application.

---

### UC-5 — Understand and visualize roles of CICS modules, batch jobs, DB2 tables

> *"An architect uses the tool to understand and visualize roles of different components (CICS-modules, batch jobs, DB2 tables) of a mainframe benefit system"*

**Coverage: ✅ Full**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 2** | [`docs/application-inventory.md`](docs/application-inventory.md) | Every program with its type (CICS/batch/stub), role, transaction IDs, called programs, DB2 tables, VSAM files. Architecture diagram with all components. |
| **Step 4** | [`docs/functional-domains.md`](docs/functional-domains.md) | Domain map with Mermaid diagram grouping programs by domain, showing the data flows and shared resources between them. |
| **Step 6** | [`docs/motor-domain-boundary.md`](docs/motor-domain-boundary.md) | Component-level boundary diagram for the Motor domain showing LGMOTOUT, MOTOR table, MOTOROUT file and their relationships. |

**Key findings delivered:**
- The `LG<area><function><suffix>` naming convention was decoded (e.g. `DB` = Db2 backend, `VS` = VSAM backend, `OL` = orchestrator).
- Clear role separation: menu programs (LGTESTP*) → orchestrators (LGAPOL01) → Db2 backends (LGAPDB01) → VSAM backends (LGAPVS01).
- Three COBOL stubs (LGAPBR01, LGUPDB01, AAAAAAAA) identified with missing source — flagged as black boxes.

---

### UC-6 — Understand integration interfaces (CTG, MQ) between mainframe and distributed components

> *"An architect uses the tool to understand integration interfaces (ctg, MQ) between mainframe components and distributed components of a benefit system"*

**Coverage: ✅ Partial**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 6** | [`docs/motor-domain-boundary.md`](docs/motor-domain-boundary.md) §6 | Documented all external interfaces for the Motor domain: MOTOROUT QSAM file (outbound), GENASA1.MOTOR (inbound shared table). Explicitly confirmed: no CICS web services, no MQ queues, no CTG/ECI/EPI, no sockets. |
| **Step 10** | [`docs/motor-to-be-architecture.md`](docs/motor-to-be-architecture.md) §3 | Documented the interface patterns for the hybrid state: Db2 Connect, CDC replication, MFT file transfer, and the to-be cloud-native equivalents. |

**Partial gap**: The GenApp application has one external interface (LGWEBST5 / SSST web gateway), but it is not a CTG or MQ interface — it is a CICS web services entry point. No MQ queues or CTG interfaces exist in this application. The tool confirmed this absence via the scanner database (no MQ transactions found). In a real Kela environment with MQ/CTG interfaces, the same scanner database approach would surface them in the `Resources` table (ResourceType=14 for transactions, ResourceType=5 for program calls through CTG).

---

### UC-7 — Look at business rules of a mainframe system that will be moved to EEPOS

> *"An architect looks at business rules of a mainframe system that will be moved to EEPOS. The rules have been generated by the tool to Kela's confluence. The rules generated by the tool from the mainframe system help the architect to design same (or similar) rules for EEPOS benefit system"*

**Coverage: ✅ Full**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 7** | [`docs/motor-business-rules.md`](docs/motor-business-rules.md) | 24 business rules across 7 sections: policy lifecycle, premium calculation (accident surcharges), bundling discounts, broker commissions, entity relationships, batch output rules, error handling. Each rule has: ID, rule statement, conditions, outcome, program/procedure reference, data involved, explicit/inferred flag, and a verifiable example. |
| **BRD workflow** | [`docs/business-rule/pli/LGAPDB01-overview.md`](docs/business-rule/pli/LGAPDB01-overview.md) | Hierarchical business rules overview for LGAPDB01: 4 top-level functions (Request Intake, Premium Calculation, Broker Commission, Record Persistence), 10 sub-functions, 16 individual rules with rule steps and business significance statements. Formatted for direct publication to Confluence. |
| **BRD workflow** | [`docs/business-rule/pli/LGAPDB01-inventory.md`](docs/business-rule/pli/LGAPDB01-inventory.md) | Code-linked inventory: every rule with its exact PL/I code snippet, variable table, and decision list — ordered by program appearance for developer cross-reference. |

**Key findings delivered for EEPOS design:**
- Accident surcharge tiers (×1.00 / ×1.20 / ×1.50 / ×3.00) are explicit implementation rules to replicate.
- Bundling discount (15% for >2 active Motor/House policies) applies to all policy types — a non-obvious rule that a developer reading only motor code might miss.
- Broker commission halving on >3 claims/year is a governance rule that must be implemented in the EEPOS broker management module.
- Serial `IF` vs `IF-ELSE` coding anomaly in accident surcharge logic was flagged (MOT-P05) — important for test case design.

---

### UC-8 — Use generated documentation to understand how the mainframe system functions

> *"An architect uses the (confluence) documentation generated by the tool in addition to existing system documentation in order to have a better understanding on how the mainframe system functions, and the role of different modules"*

**Coverage: ✅ Full**

All documentation was produced in Markdown, ready for publication to Confluence (headings, tables, Mermaid diagrams). The complete documentation set in `docs/` covers:

| Document | Audience Value |
|---|---|
| [`application-inventory.md`](docs/application-inventory.md) | Program catalogue with roles, transactions, dependencies, architecture diagram |
| [`db2-crud-matrix.md`](docs/db2-crud-matrix.md) | DB2 data access matrix — who reads/writes what |
| [`functional-domains.md`](docs/functional-domains.md) | Domain decomposition with Mermaid domain map |
| [`migration-domain-recommendation.md`](docs/migration-domain-recommendation.md) | Rationale for choosing Motor as the first migration domain |
| [`motor-domain-boundary.md`](docs/motor-domain-boundary.md) | Motor domain deep-dive with batch flow, output layout, integration points |
| [`motor-business-rules.md`](docs/motor-business-rules.md) | 24 business rules in tabular Confluence-ready format |
| [`business-rule/pli/LGAPDB01-overview.md`](docs/business-rule/pli/LGAPDB01-overview.md) | BRD overview — hierarchical rule structure |
| [`business-rule/pli/LGAPDB01-inventory.md`](docs/business-rule/pli/LGAPDB01-inventory.md) | BRD inventory — code-linked rule catalogue |
| [`migration-hotspots.md`](docs/migration-hotspots.md) | Application-wide hotspot ranking with anomaly flags |
| [`motor-migration-effort.md`](docs/motor-migration-effort.md) | Migration dependency analysis and risk register |
| [`motor-to-be-architecture.md`](docs/motor-to-be-architecture.md) | Hybrid to-be architecture diagram with integration patterns |

---

### UC-9 — Understand hotspots: modules and DB2 tables used across many benefit systems

> *"An architect uses the tool to have a better understanding of the mainframe benefit systems as a whole, and to recognize 'hot-spots' like modules and DB2 tables that are used/called from a large number of benefit systems and which are especially critical to changes"*

**Coverage: ✅ Full**

| Step | Deliverable | What It Showed |
|---|---|---|
| **Step 8** | [`docs/migration-hotspots.md`](docs/migration-hotspots.md) | 9 hotspots ranked by programs × domains impacted. Included: program count, domain count, explanation of why the hotspot is critical, and specific anomalies. |

**Hotspot ranking summary:**

| Rank | Hotspot | Programs Affected | Domains | Risk |
|---|---|---|---|---|
| 1 | LGSTSQ (error logger) | All CICS programs | All 5 | 🔴 Critical |
| 2 | LGCMAREA.inc (COMMAREA) | All CICS programs | 3+ | 🔴 Critical |
| 3 | CUSTOMER table | 6 | 2 | 🟠 High |
| 4 | POLICY table | 4 | 2 | 🟠 High |
| 5 | KSDSPOLY (VSAM) | 4 | 1 | 🟠 High |

**Anomalies flagged:**
- `LGACUS01` cross-domain write to POLICY
- `LGAPBR01` missing COBOL source
- `LGIPDB01` cyclomatic complexity = 70 (highest in application)
- Dual VSAM+DB2 storage for Customer and Policy

---

### UC-10 (Extra) — A PL/I programmer uses generated docs to understand a module

> *"A PL/1 programmer looks at the (confluence) documentation generated by the tool to help understand the functionality of a module"*

**Coverage: ✅ Full**

| Deliverable | Value to PL/I Programmer |
|---|---|
| [`docs/business-rule/pli/LGAPDB01-inventory.md`](docs/business-rule/pli/LGAPDB01-inventory.md) | Every procedure in LGAPDB01 documented with its exact PL/I code snippet, a plain-English description, the decisions it makes, and the variables it reads and writes. A programmer can navigate directly to a rule by section and understand its intent without reading the full source. |
| [`docs/motor-business-rules.md`](docs/motor-business-rules.md) | Program and line number references for every rule (e.g. "LGAPDB01 / INSERT_MOTOR line 522") — programmer can jump directly to the relevant source line. |
| [`docs/motor-domain-boundary.md`](docs/motor-domain-boundary.md) §3.4 | MOTOROUT record layout with field-by-field PL/I variable → DB2 column mapping. |

---

## Overall Assessment

### What the Tool Demonstrated Successfully

1. **Automated inventory generation** from scanner metadata — no manual code reading required to produce the program catalogue, DB2 CRUD matrix, and dependency map.
2. **Domain boundary visualisation** with Mermaid diagrams — architects can see the system structure at a glance.
3. **Business rule extraction at two levels** — both a Confluence-ready hierarchical overview and a code-linked developer inventory, generated from PL/I source with no manual authoring.
4. **Hotspot ranking from the metadata database** — SQL queries over the scanner database produced objective, data-driven rankings rather than subjective assessments.
5. **Migration readiness assessment** — from boundary analysis through hotspot ranking to to-be architecture, the tool covered the full architect journey.

### Partial Gap: UC-6 (CTG/MQ Interfaces)

GenApp does not have MQ or CTG interfaces — only a CICS web services entry point (LGWEBST5). The tool correctly confirmed their absence. In a real Kela environment, the scanner database's `Resources` table (ResourceType=14 for CICS transactions, ResourceType=5 for CALL/LINK targets) and the `StatementReference` table would surface MQ and CTG calls. The absence of results is a valid and accurate finding, not a tool limitation.

### Documentation Coverage

All 11 documents are Markdown-formatted, contain Mermaid diagrams, use consistent heading structures, and are Confluence-compatible. They were committed to the `bob_demo` branch in the workspace.

---

*Final verification completed — all 10 use cases assessed.*
