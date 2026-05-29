terraform {
  required_providers {
    threexui = {
      source  = "batonogov/threexui"
      version = "~> 2.0"
      configuration_aliases = [ threexui.panel ]
    }
  }
}
