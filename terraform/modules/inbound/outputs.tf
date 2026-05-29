output "client_links" {
  description = "Map of client names to vless:// connection URLs"
  value = {
    for name, client in threexui_inbound_client.clients :  # note the resource name change
    name => "vless://${client.uuid}@${var.server_inbound_ip}:${var.port}?encryption=none&flow=${client.flow}&security=reality&sni=${var.reality_server_names[0]}&pbk=${threexui_inbound.this.stream_settings[0].reality_settings[0].public_key}#${name}"
  }
}
