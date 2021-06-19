resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main"
  }

  lifecycle {
    prevent_destroy = true
  }

  enable_dns_hostnames = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

data "aws_subnet_ids" "main_public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Visibility = "public"
  }
}

data "aws_subnet_ids" "main_private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Visibility = "private"
  }
}

resource "aws_subnet" "main_public" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${10 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name       = "main-public-${data.aws_availability_zones.available.names[count.index]}"
    Visibility = "public"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "main_private" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${20 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name       = "main-private-${data.aws_availability_zones.available.names[count.index]}"
    Visibility = "private"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route_table" "main_public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name       = "main_public"
    Visibility = "public"
  }
}

resource "aws_route_table" "main_private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name       = "main_private"
    Visibility = "private"
  }
}

resource "aws_route_table_association" "main_subnets_public" {
  count          = length(data.aws_subnet_ids.main_public.ids)
  subnet_id      = tolist(data.aws_subnet_ids.main_public.ids)[count.index]
  route_table_id = aws_route_table.main_public.id
}

resource "aws_route_table_association" "main_subnets_private" {
  count          = length(data.aws_subnet_ids.main_private.ids)
  subnet_id      = tolist(data.aws_subnet_ids.main_private.ids)[count.index]
  route_table_id = aws_route_table.main_private.id
}

resource "aws_vpc_endpoint" "main_s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "main_s3_public" {
  route_table_id  = aws_route_table.main_public.id
  vpc_endpoint_id = aws_vpc_endpoint.main_s3.id
}

resource "aws_vpc_endpoint_route_table_association" "main_s3_private" {
  route_table_id  = aws_route_table.main_private.id
  vpc_endpoint_id = aws_vpc_endpoint.main_s3.id
}

resource "aws_route" "public_out_to_internet" {
  route_table_id         = aws_route_table.main_public.id
  gateway_id             = aws_internet_gateway.main.id
  destination_cidr_block = "0.0.0.0/0"
}
