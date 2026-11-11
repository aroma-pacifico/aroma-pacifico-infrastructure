# Diagram boxes D01 to D13

Each box of the complete architecture diagram marks one component that an Epic 6
task codes. This table maps every box to the issue that builds it and to the
place in this repository or in the modules repository where the code lives. The
definition of each box is in section 14 of the architecture document of
[aroma-pacifico-architecture](https://github.com/aroma-pacifico/aroma-pacifico-architecture).

| Box | Task | Issue | Lives in |
|---|---|---|---|
| D01 | B01 | [roadmap#21](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/21) | This repository: layout, `stacks/`, `environments/` |
| D02 | B02 | [roadmap#22](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/22) | `stacks/state-backend/` |
| D03 | B03 | [roadmap#23](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/23) | `environments/<env>/` variable and backend files |
| D04 | B04 | [roadmap#24](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/24) | Module in the modules repository, wired in `stacks/network/` |
| D05 | B05 | [roadmap#25](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/25) | Module in the modules repository, wired in the root stack that B05 selects |
| D06 | B06 | [roadmap#26](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/26) | Module in the modules repository, wired in `stacks/security/` |
| D07 | B07 | [roadmap#27](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/27) | Module in the modules repository, wired in `stacks/security/` |
| D08 | B08 | [roadmap#28](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/28) | Module in the modules repository, wired in `stacks/workload/` |
| D09 | B09 | [roadmap#29](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/29) | Module in the modules repository, wired in `stacks/workload/` |
| D10 | B10 | [roadmap#30](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/30) | Module in the modules repository, wired in `stacks/workload/` |
| D11 | B11 | [roadmap#31](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/31) | `.github/workflows/` (CI) |
| D12 | B12 | [roadmap#32](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/32) | `.github/workflows/` (CD) |
| D13 | B13 | [roadmap#33](https://github.com/aroma-pacifico/aroma-pacifico-roadmap/issues/33) | Evidence mapped across all stacks: [b13-final-validation.md](b13-final-validation.md) |
