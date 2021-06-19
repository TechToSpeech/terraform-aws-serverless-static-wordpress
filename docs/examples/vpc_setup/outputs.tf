output "main_vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = toset(aws_subnet.main_public.*.id)
}

output "route_table_private" {
  value = aws_route_table.main_private
}

output "route_table_public" {
  value = aws_route_table.main_public
}
