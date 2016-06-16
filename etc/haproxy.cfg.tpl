global
  maxconn 100

defaults
  log	global
  mode	tcp
  retries 2
  timeout client 30m
  timeout connect 4s
  timeout server 30m
  timeout check 5s

frontend ft_master_postgresql
  bind *:5000
  default_backend db_write

frontend ft_slave_postgresql
  bind *:5001
  default_backend db_read

{{range $service := ls "/services"}}backend db_write
    balance leastconn
    option httpchk GET /
    option log-health-checks
    default-server inter 10s fall 2
    {{range $upstream := ls (printf "/services/%s/upstreams" $service)}}server {{$upstream}} {{printf "/services/%s/upstreams/%s" $service $upstream | getv}}:5432 check maxconn 100 check check-ssl verify none port 8001
    {{end}}{{end}}

{{range $service := ls "/services"}}backend db_read
    balance leastconn
    option pgsql-check
    option log-health-checks
    default-server inter 10s fall 2
    {{range $upstream := ls (printf "/services/%s/upstreams" $service)}}server {{$upstream}} {{printf "/services/%s/upstreams/%s" $service $upstream | getv}}:5432 check maxconn 100 check
    {{end}}{{end}}