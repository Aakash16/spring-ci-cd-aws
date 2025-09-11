package com.springcicd.controller;

import com.springcicd.model.UserItem;
import com.springcicd.repository.DynamoRepository;
import com.springcicd.service.S3Service;
import com.springcicd.service.SecretsService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.util.UUID;

@RestController
@RequestMapping("/demo")
public class DemoController {

    private final DynamoRepository dynamoRepository;
    private final SqsClient sqsClient;
    private final S3Service s3Service;
    private final SecretsService secretsService;
    private final String queueUrl;
    private final String bucket;

    public DemoController(DynamoRepository dynamoRepository,
                          SqsClient sqsClient,
                          S3Service s3Service,
                          SecretsService secretsService,
                          @Value("${aws.sqs.queue-url}") String queueUrl,
                          @Value("${aws.s3.bucket}") String bucket) {
        this.dynamoRepository = dynamoRepository;
        this.sqsClient = sqsClient;
        this.s3Service = s3Service;
        this.secretsService = secretsService;
        this.queueUrl = queueUrl;
        this.bucket = bucket;
    }

    @PostMapping("/run")
    public ResponseEntity<?> runDemo(@RequestParam(name = "name", defaultValue = "akash") String name,
                                     @RequestParam(name = "email", defaultValue = "a@x.com") String email) {
        try {
            // 1) DynamoDB - save item
            String userId = UUID.randomUUID().toString();
            UserItem item = new UserItem();
            item.setUserId(userId);
            item.setName(name);
            item.setEmail(email);
            dynamoRepository.save(item);

            // 2) SQS - push message
            String messageBody = String.format("{\"userId\":\"%s\",\"action\":\"created\"}", userId);
            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .messageBody(messageBody)
                    .build());

            // 3) S3 - upload simple text using userId as key
            String key = "demo/" + userId + ".txt";
            String content = "Demo file for user " + name + " <" + email + ">";
            s3Service.uploadString(key, content);

            // 4) Secrets Manager - read secret (if configured)
            String secretInfo = "no-secret-configured";
            if (secretsService.getSecretAsJson() != null) {
                secretInfo = secretsService.getSecretAsJson().toString();
            }

            return ResponseEntity.ok(
                    String.format("ok; userId=%s; s3Object=%s/%s; secret=%s", userId, bucket, key, secretInfo)
            );
        } catch (Exception e) {
            return ResponseEntity.status(500).body("demo-failed: " + e.getMessage());
        }
    }
}
