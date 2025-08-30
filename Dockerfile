FROM --platform=$BUILDPLATFORM golang:1.22-bookworm AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG VERSION=dev

WORKDIR /src

# Enable Go mod cache first for better layer reuse
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy the rest of the sources
COPY . .

# Build static binary for the requested target
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH GOARM=$(echo ${TARGETVARIANT} | sed 's/^v//') \
    go build -trimpath -buildvcs=false \
      -ldflags "-s -w -X github.com/coder/envbuilder/buildinfo.tag=${VERSION}" \
      -o /out/envbuilder ./cmd/envbuilder


# Final, minimal image
FROM gcr.io/distroless/static:nonroot

ENV KANIKO_DIR=/.envbuilder

WORKDIR /.envbuilder/bin

COPY --from=builder /out/envbuilder ./envbuilder

ENTRYPOINT ["/.envbuilder/bin/envbuilder"]


