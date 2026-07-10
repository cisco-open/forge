# Module Interface Contract Helper

This helper is used by module-local `*_interface_contract.tftest.hcl` tests.
It reads the Terraform source for the module under test and verifies:

- the exact public input variable names
- the exact public output names
- pinned variable and output block source lines, including types, defaults,
  validation expressions, sensitivity flags, descriptions, and output values

These tests complement behavior-focused `tofu test` files by catching interface
drift that would change how examples and consumers call a module.
