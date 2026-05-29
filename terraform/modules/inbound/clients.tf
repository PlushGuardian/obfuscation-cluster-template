locals {
  client_suffix = {
    for name in var.client_names :
    name => substr(sha256("${var.person_name}-${name}"), 0, 8)
  }
}

resource "threexui_inbound_client" "clients" {
  for_each = toset(var.client_names)
  provider = threexui.panel

  inbound_id = threexui_inbound.personal_inbound.id
  email      = "${var.person_name}-${each.key}-${local.client_suffix[each.key]}"
  enable     = true
  flow       = var.clients_default_flow
  total_gb   = var.clients_total_gb
}
