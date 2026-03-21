## Docker AIO

```bash
docker compose -f docker-aio/docker-compose.yml up --build
docker compose -f docker-aio/docker-compose.yml up -d --build
docker compose -f docker-aio/docker-compose.yml down

# UPF EES subscriber tests
./docker-aio/tests/ue-traffic.sh start
./docker-aio/tests/run.sh
./docker-aio/tests/run.sh subscribe
./docker-aio/tests/run.sh get
./docker-aio/tests/run.sh list
./docker-aio/tests/run.sh delete
./docker-aio/tests/run.sh filters
./docker-aio/tests/run.sh maxreports
./docker-aio/tests/ue-traffic.sh stop
```

`get` and `list` are currently manual/diagnostic tests. The API endpoints under `GET /nupf-ee/v1/ee-subscriptions...` are still returning `501 Not Implemented`, so they are not included in the default `run.sh` suite.

- `9999` WebUI
- `38412/sctp` AMF NGAP
- `9090` UPF metrics
- `4355` UPF EES
