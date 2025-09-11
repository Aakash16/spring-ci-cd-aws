package com.springcicd.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.ServerSideEncryption;

import java.nio.charset.StandardCharsets;

@Service
public class S3Service {
    private final S3Client s3;
    private final String bucket;
    private final String kmsKeyId;

    public S3Service(S3Client s3,
                     @Value("${aws.s3.bucket}") String bucket,
                     @Value("${aws.s3.kms-key-id}") String kmsKeyId) {
        this.s3 = s3;
        this.bucket = bucket;
        this.kmsKeyId = kmsKeyId;
    }

    public void uploadString(String key, String content) {
        PutObjectRequest req = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .serverSideEncryption(ServerSideEncryption.AWS_KMS)
                .ssekmsKeyId(kmsKeyId)
                .build();

        s3.putObject(req, RequestBody.fromBytes(content.getBytes(StandardCharsets.UTF_8)));
    }
}
