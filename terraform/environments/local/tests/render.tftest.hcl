mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "random" {
  mock_resource "random_password" {
    override_during = plan
    defaults = {
      result = "generated-password"
    }
  }
}

# Writes the Helm values to build/values/local/ for `make test-helm`.
variables {

  render_dir = "../../../build/values/local"
}

run "plan" {
  command = plan
}

run "render" {
  command = apply

  module {
    source = "../../tests/render-values"
  }

  variables {
    values     = run.plan.helm_values
    output_dir = var.render_dir
  }
}

# Same environment with Slack enabled, to validate the generated receiver with amtool.
run "plan_slack" {
  command = plan

  variables {
    alertmanager_slack_webhook_url = "https://hooks.slack.com/services/T000/B000/XXXX"
  }
}

run "render_slack" {
  command = apply

  module {
    source = "../../tests/render-values"
  }

  variables {
    values     = run.plan_slack.helm_values
    output_dir = "${var.render_dir}-slack"
  }
}
