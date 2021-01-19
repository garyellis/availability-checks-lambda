variable "name_prefix" {
  description = "a prefix applied to resources names"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "A list of subnet ids the function will run in"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "A list of security group ids attached to the lambda function"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags applied to all taggable resources"
  type        = map(string)
  default     = {}
}

variable "schedule_expression" {
  description = "the lambda job schedule"
  type = string
  default = "rate(5 minutes)"
}

variable "alarm_arns" {
  description = "A comma separated list of alarm arns"
  type        = string
  default     = ""
}

variable "environment" {
  description = "A map of environment variables"
  type        = map(string)
  default     = {}
}

variable "config" {
  description = "the monitoring config"
  type        = list(map(string))
  default     = []
}
