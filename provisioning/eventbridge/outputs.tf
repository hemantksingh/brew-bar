output "event_bus_name" {
  description = "Name of the event bus."
  value = module.eventbridge.eventbridge_bus_name
}

output "event_bus_role" {
  description = "Name of the event bus IAM role."
  value = module.eventbridge.eventbridge_role_name
}

