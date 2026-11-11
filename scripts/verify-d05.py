"""Stage the complete B05 release template for offline mock plans; never initialize S3."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "stacks/network/association-template"
EXPECTED = {"aws_ec2_transit_gateway_vpc_attachment", "aws_ec2_transit_gateway_vpc_attachment_accepter", "aws_customer_gateway", "aws_vpn_connection", "aws_ec2_managed_prefix_list"}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--module-root", type=Path, required=True)
args = parser.parse_args()
module = args.module_root.resolve()
assert (module/"versions.tf").is_file()

def execute(root, *arguments, success=True):
    result = subprocess.run(["terraform", f"-chdir={root}", *arguments],capture_output=True,
                            text=True,encoding="utf-8",errors="replace",timeout=180)
    if success and result.returncode:
        raise RuntimeError(result.stdout+result.stderr)
    return result

scratch=ROOT/".local"
scratch.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix="b05-mock-",dir=scratch) as temp:
    root=Path(temp)
    (root/"module").mkdir()
    for path in module.glob("*.tf"):
        shutil.copyfile(path,root/"module"/path.name)
    for path in TEMPLATE.glob("*.tf.example"):
        if path.name == "backend.tf.example":
            continue
        text=path.read_text()
        if path.name=="main.tf.example":
            source="git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/collection-center-association?ref=REQUIRED_REVIEWED_RELEASE"
            assert text.count(source)==1
            text=text.replace(source,"./module")
        (root/path.name.removesuffix(".example")).write_text(text)
    (root/"tests").mkdir()
    test=(TEMPLATE/"association_test.tftest.hcl.example").read_text()
    (root/"tests/association_test.tftest.hcl").write_text(test)
    shutil.copyfile(module/"sample/.terraform.lock.hcl",root/".terraform.lock.hcl")
    flags=["init","-backend=false","-input=false","-lockfile=readonly","-no-color"]
    if os.environ.get("B02_PROVIDER_MIRROR"):
        flags.append("-plugin-dir="+os.environ["B02_PROVIDER_MIRROR"])
    execute(root,*flags)
    execute(root,"validate","-no-color")
    events=[json.loads(line) for line in execute(root,"test","-json","-verbose","-no-color").stdout.splitlines()]
    summary=next(e["test_summary"] for e in events if e.get("type")=="test_summary")
    assert summary["passed"]==3 and summary["failed"]==0,summary
    for event in events:
        if event.get("type")!="test_plan":
            continue
        plan=event["test_plan"]
        changes=[c for c in plan["resource_changes"] if c["mode"]=="managed"]
        assert Counter(c["type"] for c in changes)==Counter({kind:1 for kind in EXPECTED})
        assert all(c["change"]["actions"]==["create"] for c in changes)
        selected=plan["output_changes"]["selected_center"]["after"]
        prefix=next(c["change"]["after"] for c in changes if c["type"]=="aws_ec2_managed_prefix_list")
        vpn=next(c["change"]["after"] for c in changes if c["type"]=="aws_vpn_connection")
        assert len(prefix["entry"])==1 and prefix["entry"][0]["cidr"]==selected["cidr_block"]==vpn["local_ipv4_network_cidr"]
        assert all(c["change"]["after"]["tags"]["CollectionCenter"]==selected["key"] for c in changes)
        print(f"OFFLINE MOCKED TERRAFORM PLAN private association root / {event['@testrun']}: selected={selected['key']}, CIDR={selected['cidr_block']}, creates=5, updates=0, deletes=0; assertions PASS")
    # Prove invalid operational inputs fail in this complete composition.
    head=test[:test.index('run "')]
    cases={"multi_center_list":'collection_center = [{ key = "cauca" }, { key = "huila" }]',
           "buenaventura":'collection_center = { key = "buenaventura" }',
           "wrong_cidr":'collection_center = { key = "cauca", cidr_block = "10.42.0.0/16" }',
           "missing_certificate":'hub = { account_id = format("%012d",1), region = "us-east-1", transit_gateway_id = "tgw-00000000000000000", customer_certificate_arn = "" }',
           "dev_connection":'environment = "dev"', "permanent_qa":'environment = "qa"'}
    for name,values in cases.items():
        (root/"tests/association_test.tftest.hcl").write_text(head+'run "reject" {\n command = plan\n variables {\n'+values+'\n }\n}\n')
        result=execute(root,"test","-json","-no-color",success=False)
        diagnostics=[e["diagnostic"] for line in result.stdout.splitlines() if (e:=json.loads(line)).get("type")=="diagnostic"]
        assert result.returncode != 0 and any(d["severity"]=="error" and d["summary"] in {"Invalid value for variable","Invalid value for input variable","Required variable not set","No value for required variable"} for d in diagnostics),result.stdout
        print(f"PASS negative full-graph fixture: {name}; expected error exit {result.returncode}")
    assert not list(root.rglob("*.tfstate*"))
print("PASS: release template unchanged; isolated local source only; no remote backend or cloud calls")
