variable "person_name" {
  description = "Name of the inbound user"
  type        = string
}

variable "client_names" {
  description = "List of client devices (default [\"pc\", \"phone\"])"
  type        = list(string)
  default     = ["pc", "phone"]
}

variable "server_inbound_ip" {
  description = "Server IP that is used in inbounds"
  type        = number
}

variable "port" {
  description = "Port for the inbound"
  type        = number
}

variable "reality_target" {
  description = "Reality target (e.g., 'www.amazon.com:443')"
  type        = string
}

variable "reality_server_names" {
  description = "List of SNI server names for Reality"
  type        = list(string)
}

variable "inbound_enabled" {
  description = "Enable the inbound"
  type        = bool
  default     = true
}

variable "clients_default_flow" {
  description = "Flow setting for all clients"
  type        = string
  default     = "xtls-rprx-vision"
}

variable "clients_total_gb" {
  description = "Traffic limit in GB per client (null = unlimited)"
  type        = number
  default     = null
}
