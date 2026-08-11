# syntax=docker/dockerfile:1

ARG GO_VERSION=1.25

FROM golang:${GO_VERSION}-bookworm AS builder

WORKDIR /src

# Copy dependency files first so Docker can reuse the module-download layer.
# go.sum is optional for projects that only use the standard library.
COPY go.mod go.sum* ./
RUN go mod download

COPY . .

ARG GO_BUILD_PACKAGE=./cmd/server
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/server \
    "${GO_BUILD_PACKAGE}"

FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /
COPY --from=builder --chown=nonroot:nonroot /out/server /server

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
