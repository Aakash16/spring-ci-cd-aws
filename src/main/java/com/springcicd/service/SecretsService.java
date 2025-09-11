package com.springcicd.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;

@Service
public class SecretsService {
    private final SecretsManagerClient client;
    private final String secretArn;
    private final ObjectMapper mapper = new ObjectMapper();

    public SecretsService(SecretsManagerClient client,
                          @Value("${aws.secrets.api-secret-arn:}") String secretArn) {
        this.client = client;
        this.secretArn = secretArn;
    }

    public JsonNode getSecretAsJson() {
        if (secretArn == null || secretArn.isEmpty()) return null;
        String secret = client.getSecretValue(GetSecretValueRequest.builder().secretId(secretArn).build()).secretString();
        try {
            return mapper.readTree(secret);
        } catch (Exception e) {
            throw new RuntimeException("Failed to parse secret JSON", e);
        }
    }
}
