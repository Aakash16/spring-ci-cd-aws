package com.springcicd.repository;

import com.springcicd.model.UserItem;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

@Repository
public class DynamoRepository {
    private final DynamoDbTable<UserItem> table;

    public DynamoRepository(DynamoDbEnhancedClient enhancedClient,
                            @Value("${aws.dynamodb.table-name}") String tableName) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(UserItem.class));
    }

    public void save(UserItem item) {
        table.putItem(item);
    }

    public UserItem findById(String id) {
        return table.getItem(r -> r.key(k -> k.partitionValue(id)));
    }
}
