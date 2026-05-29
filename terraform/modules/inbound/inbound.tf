resource "threexui_inbound" "personal_inbound" {
  provider = threexui.panel

  port     = var.port
  protocol = "vless"
  remark   = var.person_name
  enable   = var.inbound_enabled

  vless_settings {
    decryption = "none"
  }

  stream_settings {
    network  = "tcp"
    security = "reality"
    reality_settings {
      target       = var.reality_target
      server_names = var.reality_server_names
    }
  }

  sniffing {
    enabled       = false
    dest_override = ["http", "tls", "quic", "fakedns"]
  }
}
