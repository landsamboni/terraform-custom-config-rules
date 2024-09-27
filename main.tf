
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "nginx-config"
    namespace = "bts-nginx"
  }

  data = {

    "app.conf"      = file("${path.module}/nginx-config-files/app.conf")
    "booking.conf"  = file("${path.module}/nginx-config-files/booking.conf")
    "cms.conf"      = file("${path.module}/nginx-config-files/cms.conf")
    "hertzb2b.conf" = file("${path.module}/nginx-config-files/hertzb2b.conf")
    "members.conf"  = file("${path.module}/nginx-config-files/members.conf")
    #"notificationssupport.conf" = file("${path.module}/nginx-config-files/notificationssupport.conf")
    "policies.conf"               = file("${path.module}/nginx-config-files/policies.conf")
    "rules.conf"                  = file("${path.module}/nginx-config-files/rules.conf")
    "searchengine.conf"           = file("${path.module}/nginx-config-files/searchengine.conf")
    "searchenginehotels.conf"     = file("${path.module}/nginx-config-files/searchenginehotels.conf")
    "cmsaws.conf"                 = file("${path.module}/nginx-config-files/cmsaws.conf")
    "app-miles.conf"              = file("${path.module}/nginx-config-files/app-miles.conf")
    "app-vjs-argentina.conf"      = file("${path.module}/nginx-config-files/app-vjs-argentina.conf")
    "app-vjs-bolivia.conf"        = file("${path.module}/nginx-config-files/app-vjs-bolivia.conf")
    "app-vjs-brasil.conf"         = file("${path.module}/nginx-config-files/app-vjs-brasil.conf")
    "app-vjs-canada.conf"         = file("${path.module}/nginx-config-files/app-vjs-canada.conf")
    "app-vjs-chile.conf"          = file("${path.module}/nginx-config-files/app-vjs-chile.conf")
    "app-vjs-colombia.conf"       = file("${path.module}/nginx-config-files/app-vjs-colombia.conf")
    "app-vjs-costa-rica.conf"     = file("${path.module}/nginx-config-files/app-vjs-costa-rica.conf")
    "app-vjs-ecuador.conf"        = file("${path.module}/nginx-config-files/app-vjs-ecuador.conf")
    "app-vjs-espana.conf"         = file("${path.module}/nginx-config-files/app-vjs-espana.conf")
    "app-vjs-guatemala.conf"      = file("${path.module}/nginx-config-files/app-vjs-guatemala.conf")
    "app-vjs-honduras.conf"       = file("${path.module}/nginx-config-files/app-vjs-honduras.conf")
    "app-vjs-mexico.conf"         = file("${path.module}/nginx-config-files/app-vjs-mexico.conf")
    "app-vjs-nicaragua.conf"      = file("${path.module}/nginx-config-files/app-vjs-nicaragua.conf")
    "app-vjs-panama.conf"         = file("${path.module}/nginx-config-files/app-vjs-panama.conf")
    "app-vjs-paraguay.conf"       = file("${path.module}/nginx-config-files/app-vjs-paraguay.conf")
    "app-vjs-peru.conf"           = file("${path.module}/nginx-config-files/app-vjs-peru.conf")
    "app-vjs-portugal.conf"       = file("${path.module}/nginx-config-files/app-vjs-portugal.conf")
    "app-vjs-puerto-rico.conf"    = file("${path.module}/nginx-config-files/app-vjs-puerto-rico.conf")
    "app-vjs-reino-unido.conf"    = file("${path.module}/nginx-config-files/app-vjs-reino-unido.conf")
    "app-vjs-rep-dominicana.conf" = file("${path.module}/nginx-config-files/app-vjs-rep-dominicana.conf")
    "app-vjs-salvador.conf"       = file("${path.module}/nginx-config-files/app-vjs-salvador.conf")
    "app-vjs-uruguay.conf"        = file("${path.module}/nginx-config-files/app-vjs-uruguay.conf")
    "app-vjs-venezuela.conf"      = file("${path.module}/nginx-config-files/app-vjs-venezuela.conf")
    "leads.conf"                  = file("${path.module}/nginx-config-files/leads.conf")
    "requests.conf"               = file("${path.module}/nginx-config-files/requests.conf")
    "unfinish.conf"               = file("${path.module}/nginx-config-files/unfinish.conf")
    "crm.conf"                    = file("${path.module}/nginx-config-files/crm.conf")

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


# Se eliminó el ALB para Grafana debido a que Viajemos solicitó eliminar los pods de monitoreo, ya que van a usar DataDog
/* resource "kubernetes_ingress_v1" "grafana_ingress" {
  metadata {
    name      = "grafana-ingress"
    namespace = "prometheus"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:637423610894:certificate/629f27f6-d34c-4702-b492-09737f3a8c6c"
      "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      # TargetGroup Healthcheck configuration:
      "alb.ingress.kubernetes.io/healthcheck-path" = "/login"
      "alb.ingress.kubernetes.io/healthcheck-port" = "traffic-port"
      "alb.ingress.kubernetes.io/success-codes"    = "200-399"

    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/grafana"
          path_type = "Prefix"

          backend {
            service {
              name = "grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
} */

