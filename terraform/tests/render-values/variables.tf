variable "values" {
  description = "Values documents, in merge order."
  type        = list(string)
}

variable "output_dir" {
  description = "Directory that receives 00.yaml, 01.yaml, ..."
  type        = string
}
