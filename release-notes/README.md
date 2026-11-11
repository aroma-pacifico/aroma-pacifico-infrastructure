# Release notes

This folder holds the filled release notes of infrastructure changes. A note is
committed as `release-notes/<release_id>.md` in the pull request of the release
candidate and linked from the pull request body, because that is the pull
request the production job reads (ASM-180, PD-181).

The templates and two worked examples live in the architecture repository, under
`docs/release-notes/` of
[aroma-pacifico-architecture](https://github.com/aroma-pacifico/aroma-pacifico-architecture).
Copy `template-infrastructure.md` from there, fill every row marked Owner, and
copy the rows marked Pipeline from the deployment event of the promotion run.

The pipeline never writes to this repository. The coded reading of the note by
the production job stays architecture and is not implemented in Epic 6 (ASM-214).
