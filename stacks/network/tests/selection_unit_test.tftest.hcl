variables {
  environment       = "pdn"
  collection_center = { key = "cauca" }
}

run "cauca" {
  command = plan
  assert {
    condition     = output.selected_center == { key = "cauca", department = "cauca", cidr_block = "10.41.0.0/16", environment = "pdn" }
    error_message = "Only the Cauca configuration and its approved department block may be selected."
  }
}

run "huila" {
  command = plan
  variables {
    collection_center = { key = "huila" }
  }
  assert {
    condition     = output.selected_center == { key = "huila", department = "huila", cidr_block = "10.42.0.0/16", environment = "pdn" }
    error_message = "Only the Huila configuration and its approved department block may be selected."
  }
}

run "tolima" {
  command = plan
  variables {
    collection_center = { key = "tolima", department = "tolima", cidr_block = "10.43.0.0/16" }
  }
  assert {
    condition     = output.selected_center == { key = "tolima", department = "tolima", cidr_block = "10.43.0.0/16", environment = "pdn" }
    error_message = "Only the Tolima configuration and its approved department block may be selected."
  }
}

run "unknown_center" {
  command = plan
  variables {
    collection_center = { key = "unknown" }
  }
  expect_failures = [var.collection_center]
}

run "wrong_department" {
  command = plan
  variables {
    collection_center = { key = "cauca", department = "huila" }
  }
  expect_failures = [var.collection_center]
}

run "wrong_cidr" {
  command = plan
  variables {
    collection_center = { key = "cauca", cidr_block = "10.42.0.0/16" }
  }
  expect_failures = [var.collection_center]
}

run "buenaventura" {
  command = plan
  variables {
    collection_center = { key = "buenaventura" }
  }
  expect_failures = [var.collection_center]
}

run "dev_isolated" {
  command = plan
  variables {
    environment = "dev"
  }
  expect_failures = [var.environment]
}

run "qa_has_no_permanent_link" {
  command = plan
  variables {
    environment = "qa"
  }
  expect_failures = [var.environment]
}
