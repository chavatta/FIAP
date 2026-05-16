# syntax=docker/dockerfile:1
FROM golang:alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN go mod tidy && CGO_ENABLED=0 go build -o /out/app .

FROM alpine:latest
RUN adduser -D -u 65532 appuser
USER appuser
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
