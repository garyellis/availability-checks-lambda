locals {
  config = [
    { target = "gitlab", type = "port", host = "gitlab-ee.ews.works", port = "443" },
    { target = "gitlab444", type = "port", host = "gitlab-ee.ews.works", port = "444" },
    { target = "vault", type = "port", host = "vault-demo.ews.works", port = "443" },
    { target = "vault2", type = "port", host = "vault-demo.ews.works", port = "444" },
    { target = "vault3", type = "port", host = "vault-demo.ews.works", port = "443" },
  ]
}

module "lambda_function" {
  source = "../"

  subnet_ids         = ["subnet-0ac15066f0c44f76f"]
  security_group_ids = ["sg-0421bd249d42c7db3"]
  environment = {
    no_proxy    = "localhost,127.0.0.1,::1,169.254.169.254,169.254.170.2,ews.works"
    http_proxy  = "http://squid-proxy.shared-services.ews.works:3128"
    https_proxy = "http://squid-proxy.shared-services.ews.works:3128"
  }

  alarm_arns = "arn:aws:sns:us-west-2:529332856614:alarms-test2"
  config = local.config
}
