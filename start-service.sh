#!/usr/bin/env sh
set -ex

. .env

systemd-run -u filepuller \
            --user \
            -E NATS_URL=${NATS_URL} \
            -E NATS_CA=${NATS_CA} \
            -E NATS_CERT=${NATS_CERT} \
            -E NATS_KEY=${NATS_KEY} \
            -E PULLER_TOPICBASE=${PULLER_TOPICBASE} \
            -E PULLER_STREAM=${PULLER_STREAM} \
            -E PULLER_CONSUMER=${PULLER_CONSUMER} \
            -E PULLER_BUCKET=${PULLER_BUCKET} \
            -E PULLER_DESTINATION=${PULLER_DESTINATION} \
            ./filepuller 

