FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder
LABEL maintainer="Antonio Mika <me@antoniomika.me>"

ENV CGO_ENABLED=0

WORKDIR /app

RUN mkdir -p /emptydir
RUN apk add --no-cache git ca-certificates

COPY go.* ./

RUN --mount=type=cache,target=/go/pkg/,rw \
  --mount=type=cache,target=/root/.cache/,rw \
  go mod download

FROM builder AS build-image

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG DATE=unknown
ARG REPOSITORY=unknown

ARG TARGETOS
ARG TARGETARCH

ENV GOOS=${TARGETOS} GOARCH=${TARGETARCH}

RUN --mount=type=cache,target=/go/pkg/,rw \
  --mount=type=cache,target=/root/.cache/,rw \
  go build -o /go/bin/app -ldflags="-s -w -X github.com/${REPOSITORY}/cmd.Version=${VERSION} -X github.com/${REPOSITORY}/cmd.Commit=${COMMIT} -X github.com/${REPOSITORY}/cmd.Date=${DATE}"

RUN mkdir -p /root/.ssh
COPY authorized_keys /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys

ENTRYPOINT ["/go/bin/app"]

FROM scratch AS release
LABEL maintainer="Antonio Mika <me@antoniomika.me>"

WORKDIR /app

COPY --from=build-image /emptydir /tmp
COPY --from=build-image /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build-image /app/deploy/ /app/deploy/
COPY --from=build-image /app/README* /app/LICENSE* /app/
COPY --from=build-image /app/templates /app/templates
COPY --from=build-image /go/bin/ /app/
COPY --from=build-image /root/.ssh /root/.ssh

ENTRYPOINT ["/app/app"]
