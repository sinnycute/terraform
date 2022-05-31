 provider "aws" {
     region="ap-south-1"
     access_key="AKIASGKV5II24VQCOVPZ"
     secret_key="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"
 }
 resource "aws_vpc" "development_vpc" {
        cidr_block="10.0.0.0/16"
 }
 resource "aws_subnet" "dev-subnet-1" {
     vpc_id=aws_vpc.development_vpc.id
     cidr_block="10.0.0.0/24"
     availability_zone="ap-south-1"

 }