# The account identifier is discovered at plan time and never committed
# (PC-IAC-016). Against Floci it resolves to the emulator's fixed account.
data "aws_caller_identity" "current" {}
