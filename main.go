package main

import (
	"fmt"
	"os"
	"time"
	"context"
	"os/signal"
	"path"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
)

func main() {
	url := os.Getenv("NATS_URL")
	tlsca := os.Getenv("NATS_CA")
	tlskey := os.Getenv("NATS_KEY")
	tlscert := os.Getenv("NATS_CERT")
	streamName := os.Getenv("PULLER_STREAM")
	topicbase := os.Getenv("PULLER_TOPICBASE")
	consumerName := os.Getenv("PULLER_CONSUMER")
	destination := os.Getenv("PULLER_DESTINATION")
	bucketName := os.Getenv("PULLER_BUCKET")

	if url == "" || tlsca == "" || tlskey == "" || tlscert == "" {
		fmt.Println("Must specify NATS_URL, NATS_CA, NATS_KEY, and NATS_CERT")
		os.Exit(1)
	}

	exit := make(chan os.Signal, 1)
	signal.Notify(exit, os.Interrupt)

	nc, err := nats.Connect(url)
	if err != nil {
		fmt.Printf("Error connecting to %s: %s\n", url, err.Error())
		os.Exit(2)
	}

	js, err := jetstream.New(nc); if err != nil {
		fmt.Printf("Error creating JetStream connection: %s\n", err.Error())
		os.Exit(3)
	}

	cfg := jetstream.StreamConfig {
		Name: streamName,
		Retention: jetstream.WorkQueuePolicy,
		Subjects: []string{fmt.Sprintf("%s.>", topicbase)},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10* time.Second)
	defer cancel()

	stream, err := js.CreateOrUpdateStream(ctx, cfg); if err != nil {
		fmt.Printf("Error creating stream %s: %s\n", streamName, err.Error())
		os.Exit(4)
	}

	consumerConfig := jetstream.ConsumerConfig {
		Name: consumerName,
		Durable: consumerName,
		Description: "filepuller",
		DeliverPolicy: jetstream.DeliverAllPolicy,
		AckPolicy: jetstream.AckExplicitPolicy,
		AckWait: 5*time.Minute,
		FilterSubject: fmt.Sprintf("%s.upload", topicbase),
		ReplayPolicy: jetstream.ReplayInstantPolicy,
	}

	consumer, err := stream.CreateOrUpdateConsumer(ctx, consumerConfig); if err != nil {
		fmt.Printf("Unable to create consumer %s: %s\n", consumerName, err.Error())
		os.Exit(5)
	}

	objStoreConfig := jetstream.ObjectStoreConfig {
		Bucket: bucketName,
		MaxBytes: 1024 * 1024 * 1024 * 50, // 50GB
		Compression: true,
		Storage: jetstream.FileStorage,
		Replicas: 1,
	}

	objStore, err := js.CreateOrUpdateObjectStore(ctx, objStoreConfig); if err != nil {
		fmt.Printf("Unable to create object store bucket connection %s: %s\n", bucketName, err.Error())
		os.Exit(6)
	}

	consumeErrorHandler := func(consumeCtx jetstream.ConsumeContext, err error) {
		fmt.Printf("Error consuming message: %s\n", err.Error())
		consumeCtx.Drain()
	}

	consumeCtx, err := consumer.Consume(func(msg jetstream.Msg) {
		fmt.Printf("Received message: %s\n", msg.Data())
		filename := string(msg.Data()[:])
		destinationPath := path.Join(destination, filename)
		err := objStore.GetFile(ctx, filename, destinationPath, jetstream.GetObjectShowDeleted()); if err != nil {
			fmt.Printf("Error getting file %s: %s\n", filename, err.Error())
			msg.NakWithDelay(30*time.Second)
			return
		}
		fmt.Printf("Successfully downloaded %s to %s\n", filename, destinationPath)
		msg.Ack()
	}, jetstream.ConsumeErrHandler(consumeErrorHandler))
	select {
		case <- exit:
			consumeCtx.Drain()
			cancel()
	}
}


