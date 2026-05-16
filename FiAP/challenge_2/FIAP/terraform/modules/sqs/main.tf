resource "aws_sqs_queue" "this" {
  name                      = replace(var.queue_name, "_", "-")
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds

  tags = {
    Name = var.queue_name
  }
}
