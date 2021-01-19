# availability-checks-lambda
Lambda based availability monitoring. Creates cloudwatch availability metrics and cloudwatch alarms. Implemented check types are:
* port check

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| archive | n/a |
| aws | n/a |
| null | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alarm\_arns | A comma separated list of alarm arns | `string` | `""` | no |
| config | the monitoring config | `list(map(string))` | `[]` | no |
| create\_alarms | when true, creates cloudwatch alarms | `bool` | `true` | no |
| environment | A map of environment variables | `map(string)` | `{}` | no |
| name\_prefix | a prefix applied to resources names | `string` | `""` | no |
| schedule\_expression | the lambda job schedule | `string` | `"rate(5 minutes)"` | no |
| security\_group\_ids | A list of security group ids attached to the lambda function | `list(string)` | `[]` | no |
| subnet\_ids | A list of subnet ids the function will run in | `list(string)` | `[]` | no |
| tags | A map of tags applied to all taggable resources | `map(string)` | `{}` | no |

## Outputs

No output.
