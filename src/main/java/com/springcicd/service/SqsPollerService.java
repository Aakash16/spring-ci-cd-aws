package com.springcicd.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.*;

@Service
public class SqsPollerService {
    private final Logger log = LoggerFactory.getLogger(SqsPollerService.class);
    private final SqsClient sqsClient;
    private final String queueUrl;
    private final ScheduledExecutorService executor = Executors.newSingleThreadScheduledExecutor();

    public SqsPollerService(SqsClient sqsClient,
                            @Value("${aws.sqs.queue-url}") String queueUrl) {
        this.sqsClient = sqsClient;
        this.queueUrl = queueUrl;
    }

    @PostConstruct
    public void start() {
        // Long-poll loop every 1s; receive uses waitTimeSeconds = 20 to long-poll
        executor.scheduleWithFixedDelay(this::pollOnce, 0, 1, TimeUnit.SECONDS);
    }

    private void pollOnce() {
        try {
            ReceiveMessageRequest req = ReceiveMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .maxNumberOfMessages(5)
                    .waitTimeSeconds(20) // long poll
                    .visibilityTimeout(60)
                    .build();

            List<Message> messages = sqsClient.receiveMessage(req).messages();
            for (Message m : messages) {
                try {
                    log.info("SQS message received: id={}, body={}", m.messageId(), m.body());
                    // TODO: process message body (e.g. push to DynamoDB or S3)
                    // on success, delete
                    sqsClient.deleteMessage(DeleteMessageRequest.builder()
                            .queueUrl(queueUrl)
                            .receiptHandle(m.receiptHandle())
                            .build());
                } catch (Exception e) {
                    log.error("Failed to process message {}, leaving in queue for retry", m.messageId(), e);
                    // don't delete -> visibility timeout will allow retries; DLQ set in infra
                }
            }
        } catch (Exception e) {
            log.error("Error polling SQS", e);
        }
    }

    @PreDestroy
    public void stop() {
        executor.shutdown();
        try {
            executor.awaitTermination(10, TimeUnit.SECONDS);
        } catch (InterruptedException ignored) {}
    }
}
