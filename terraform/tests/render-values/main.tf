/**
 * Test helper: writes Helm values documents to disk so `make test-helm` can render
 * the real chart with exactly what Terraform would pass to it.
 * Used only from `tests/render.tftest.hcl` in the environment roots.
 */

resource "terraform_data" "write" {
  for_each = { for i, v in var.values : format("%02d", i) => v }

  # Runs of the same test file share state: replace (not update) so the provisioner runs again.
  triggers_replace = [each.value, var.output_dir]

  provisioner "local-exec" {
    command     = "mkdir -p \"$DIR\" && printf '%s\\n' \"$CONTENT\" > \"$DIR/$NAME.yaml\""
    interpreter = ["/bin/sh", "-c"]
    environment = {
      DIR     = var.output_dir
      NAME    = each.key
      CONTENT = each.value
    }
  }
}
