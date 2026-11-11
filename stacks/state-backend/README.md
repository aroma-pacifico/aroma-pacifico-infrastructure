# State backend bootstrap composition

The reviewed resource module is verified locally by `python scripts/verify-bootstrap.py --module-root <state-backend-directory>`.
The script stages the complete `root-template/` in a disposable directory, substitutes only the local module source, excludes the steady-state backend declaration, initializes with `-backend=false`, validates, and runs mock-provider plans for dev, qa and pdn. Each plan has eight creates, zero updates and zero deletes, with four domain outputs. No bucket exists or is contacted.

`root-template/*.tf.example` is the production consumption template. `REQUIRED_REVIEWED_RELEASE` remains an explicit release gate because no genuine SemVer tag exists. The first bucket must never use itself as a backend. `backend.tf.example` is only a future steady-state declaration after a separately authorized bootstrap and migration; both operations are outside this delivery.

The B01 scaffold files beside this README have no B02 resource invocation. Their successful empty validation is not bootstrap resource evidence. The complete executable offline root is generated from the template, and its resource graph is checked by the script.

```text
state-backend/
|-- backend.tf, providers.tf, variables.tf, versions.tf   B01 scaffold
|-- backends/                                          three inactive S3 examples
`-- root-template/                                     complete release-gated composition
```
