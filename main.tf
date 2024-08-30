
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "nginx-config"
    namespace = "bts-nginx"
  }

  data = {

    "app.conf"                  = file("${path.module}/nginx-config-files/app.conf")
    "booking.conf"              = file("${path.module}/nginx-config-files/booking.conf")
    "cms.conf"                  = file("${path.module}/nginx-config-files/cms.conf")
    "hertzb2b.conf"             = file("${path.module}/nginx-config-files/hertzb2b.conf")
    "members.conf"              = file("${path.module}/nginx-config-files/members.conf")
    "notificationssupport.conf" = file("${path.module}/nginx-config-files/notificationssupport.conf")
    "policies.conf"             = file("${path.module}/nginx-config-files/policies.conf")
    "rules.conf"                = file("${path.module}/nginx-config-files/rules.conf")
    "searchengine.conf"         = file("${path.module}/nginx-config-files/searchengine.conf")
    "searchenginehotels.conf"   = file("${path.module}/nginx-config-files/searchenginehotels.conf")
    "cmsaws.conf"               = file("${path.module}/nginx-config-files/cmsaws.conf")


  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = "bts-nginx"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-deployment"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-deployment"
        }
      }

      spec {
        node_selector = {
          "eks.amazonaws.com/nodegroup" = "bts-app-node-group"
        }



        container {
          name  = "nginx"
          image = "nginx:latest"


          volume_mount {
            name       = "nginx-config-volume"
            mount_path = "/etc/nginx/conf.d"
          }
        }

        volume {
          name = "nginx-config-volume"

          config_map {
            name = kubernetes_config_map.nginx_config.metadata[0].name
          }
        }
      }
    }
  }
}

# creación del servicio 

resource "kubernetes_service" "nginx_service" {
  metadata {
    name      = "nginx-deployment"
    namespace = "bts-nginx"
  }

  spec {
    type = "NodePort"

    selector = {
      app = "nginx-deployment"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}




# Creación del ALB para que maneje el ingress hacia el Servidor NGINX


resource "kubernetes_ingress_v1" "nginx_ingress" {
  metadata {
    name      = "nginx-deployment"
    namespace = "bts-nginx"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:637423610894:certificate/cae6da42-8ceb-4d0d-a41b-03ed24d4ddb3"
      "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      "alb.ingress.kubernetes.io/waf-acl-id"      = "arn:aws:wafv2:us-east-1:637423610894:regional/webacl/viajemos-dev-waf-acl/7531e5a7-a559-46dd-8268-5d7580d7c6cc"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "nginx-deployment"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
