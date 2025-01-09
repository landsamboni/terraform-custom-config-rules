variable "function_name" {
  description = "Nombre de la función Lambda."
  type        = string
}

variable "handler" {
  description = "Handler de la función Lambda (archivo.función)."
  type        = string
}

variable "runtime" {
  description = "Runtime de la función Lambda (por ejemplo, python3.9)."
  type        = string
}

variable "memory_size" {
  description = "Cantidad de memoria asignada a la Lambda en MB."
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Tiempo de espera de la Lambda en segundos."
  type        = number
  default     = 10
}

variable "source_zip" {
  description = "Ruta al archivo ZIP con el código fuente de la Lambda."
  type        = string
}
