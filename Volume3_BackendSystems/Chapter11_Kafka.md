# Volume 3: Backend Systems
# Chapter 11: Apache Kafka & Event Streaming

---

## Table of Contents
1. [Kafka Core Concepts](#topic-1-kafka-core-concepts)
2. [Producers](#topic-2-producers)
3. [Consumers & Consumer Groups](#topic-3-consumers--consumer-groups)
4. [Offset Management](#topic-4-offset-management)
5. [Kafka Delivery Guarantees](#topic-5-kafka-delivery-guarantees)
6. [Partitioning Strategy](#topic-6-partitioning-strategy)
7. [Consumer Lag & Monitoring](#topic-7-consumer-lag--monitoring)
8. [Kafka Streams](#topic-8-kafka-streams)
9. [Kafka Connect](#topic-9-kafka-connect)
10. [Schema Registry & Avro](#topic-10-schema-registry--avro)
11. [Kafka in Spring Boot](#topic-11-kafka-in-spring-boot)
12. [Retention & Compaction](#topic-12-retention--compaction)
13. [Kafka vs RabbitMQ vs SQS](#topic-13-kafka-vs-rabbitmq-vs-sqs)
14. [Replication & Fault Tolerance](#topic-14-replication--fault-tolerance)
15. [Kafka Performance Tuning](#topic-15-kafka-performance-tuning)
16. [Cheat Sheet](#cheat-sheet)

---

### Topic 1: Kafka Core Concepts
**Difficulty:** Medium | **Frequency:** High | **Companies:** LinkedIn, Confluent, Uber, Netflix, Goldman Sachs

**Q: Explain the core architecture of Apache Kafka — what are brokers, topics, partitions, offsets, segments, and how does log compaction work?**

**Short Answer (2-3 sentences):**
Kafka is a distributed, partitioned, replicated commit-log service. Topics are logical categories of messages split into partitions, each of which is an ordered, immutable sequence of records stored on a broker. Each record within a partition has a monotonically increasing offset that uniquely identifies it; log compaction is a background process that retains only the latest value per key, enabling changelog-style topics.

**Deep Explanation:**
- **Broker**: A Kafka server process. A cluster has N brokers; each partition has exactly one leader broker and R-1 follower brokers (where R = replication factor). The leader handles all reads and writes; followers replicate asynchronously from the leader.
- **Topic**: A named, durable feed of records. Topics are the primary abstraction — producers write to topics and consumers read from them.
- **Partition**: The unit of parallelism and ordering. Records within a partition are totally ordered; across partitions, there is no global ordering guarantee. A partition is stored as an append-only log on the broker's disk. The number of partitions determines maximum consumer parallelism.
- **Offset**: A 64-bit integer uniquely identifying a record's position within a partition. Offsets are assigned by the broker at append time and are immutable. Consumer groups track their position via committed offsets.
- **Segment**: A partition log is physically stored as a set of segment files on disk (e.g., `00000000000000000000.log`). Kafka rolls over to a new segment when the current one reaches `log.segment.bytes` (default 1 GB) or `log.roll.hours` (default 168 h). Older segments are eligible for deletion per retention policy.
- **Log Compaction**: Rather than time- or size-based deletion, compaction retains the most recent record per key, cleaning up older duplicates. The cleaner thread merges "dirty" (post-last-clean) segments with clean segments. Tombstones (null-value records) mark deletes; they are retained for `delete.retention.ms` before being physically removed. Log compaction is critical for changelog topics in Kafka Streams state stores and Kafka Connect offset topics.

**Real-World Example:**
At LinkedIn, each user-event topic has hundreds of partitions. Each partition is ~1 GB on disk. The `__consumer_offsets` internal topic uses log compaction so it only stores the latest committed offset per group-topic-partition, keeping storage bounded even after billions of commits.

**Code Example:**
```java
// Spring Boot 3.x — programmatically creating a topic with compaction
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.config.TopicConfig;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaTopicConfig {

    // Standard topic: 6 partitions, replication factor 3
    @Bean
    public NewTopic orderEventsTopic() {
        return TopicBuilder.name("order-events")
                .partitions(6)
                .replicas(3)
                .config(TopicConfig.RETENTION_MS_CONFIG, String.valueOf(7 * 24 * 60 * 60 * 1000L)) // 7 days
                .build();
    }

    // Compacted topic for user-profile changelog
    @Bean
    public NewTopic userProfileChangelog() {
        return TopicBuilder.name("user-profile-changelog")
                .partitions(12)
                .replicas(3)
                .compact()
                .config(TopicConfig.MIN_CLEANABLE_DIRTY_RATIO_CONFIG, "0.1")
                .config(TopicConfig.DELETE_RETENTION_MS_CONFIG, String.valueOf(24 * 60 * 60 * 1000L))
                .build();
    }
}
```

**Follow-up Questions:**
1. How does Kafka guarantee ordering within a partition when a broker fails and a new leader is elected?
2. What is the difference between `log.retention.bytes` and `log.segment.bytes`?
3. How does the Kafka controller (or KRaft) manage leader election across brokers?

**Common Mistakes:**
- Confusing offset with message position in time — offsets are sequential integers, not timestamps. Use `log.message.timestamp.type` and `offsetsForTimes()` API if you need time-based seeks.
- Assuming messages are globally ordered across partitions — only intra-partition ordering is guaranteed.

**Interview Traps:**
- "Can a consumer read from a follower?" — Yes, since Kafka 2.4, consumers can fetch from the closest replica using `client.rack` configuration (rack-aware fetching), but writes always go to the leader.
- "Is a topic an append-only log?" — Technically partitions are append-only; the topic is the logical abstraction. Log compaction does delete older records (it rewrites segments), so it is not purely append-only at the storage level.

**Quick Revision (1-liner):**
A Kafka topic is split into ordered, append-only partitions stored as rolling segment files on brokers; offsets uniquely identify records within a partition, and log compaction retains only the latest value per key.

---

### Topic 2: Producers
**Difficulty:** Medium | **Frequency:** High | **Companies:** Confluent, Uber, Netflix, Goldman Sachs

**Q: How does the Kafka producer work internally — explain batching (linger.ms, batch.size), compression, acks modes, and the idempotent producer?**

**Short Answer (2-3 sentences):**
The Kafka producer accumulates records into per-partition batches before sending them to the broker, controlled by `batch.size` (bytes) and `linger.ms` (wait time). The `acks` setting controls durability: `0` = fire-and-forget, `1` = leader acknowledgment, `all` = all in-sync replicas. The idempotent producer (`enable.idempotence=true`) assigns a producer ID and sequence number per partition, allowing the broker to deduplicate retried batches and prevent duplicate records.

**Deep Explanation:**
**Batching Internals:**
The RecordAccumulator holds a deque of ProducerBatch objects per TopicPartition. A new record is appended to the current open batch. The batch is sent when either:
1. The batch is full (`batch.size` bytes, default 16 KB), or
2. `linger.ms` milliseconds have elapsed (default 0 ms — send immediately).

Setting `linger.ms=5` dramatically improves throughput by allowing more records to aggregate into a single network request at the cost of 5 ms additional latency.

**Compression:**
Compression is applied per-batch (`compression.type`: none, gzip, snappy, lz4, zstd). The broker stores the compressed batch as-is and consumers decompress. Snappy/LZ4 offer good throughput with moderate compression; zstd offers the best ratio. Compression reduces network I/O and broker disk usage significantly — typically 3-5x for JSON payloads.

**acks Settings:**
- `acks=0`: Producer does not wait for acknowledgment. Maximum throughput, zero durability guarantee.
- `acks=1`: Leader writes to its local log and acknowledges. Risk: if leader crashes before followers replicate, the message is lost.
- `acks=all` (or `-1`): Leader waits for all ISR (In-Sync Replicas) to acknowledge. Used with `min.insync.replicas=2` (or higher) for true durability. This is the recommended production setting.

**Idempotent Producer:**
With `enable.idempotence=true`:
- The broker assigns a Producer ID (PID) per producer.
- Each record batch gets a sequence number per partition.
- On retry (after network timeout), the broker checks: if it already received this (PID, partition, sequence), it de-duplicates.
- Requires `acks=all`, `retries > 0`, `max.in.flight.requests.per.connection <= 5`.
- Idempotence guarantees exactly-once within a single producer session (no cross-session or cross-partition guarantees — that requires transactions).

**Real-World Example:**
At Uber, the dispatch event producer uses `linger.ms=10`, `batch.size=65536`, `compression.type=lz4`, and `enable.idempotence=true`. This achieves ~500k messages/second per producer instance while preventing duplicates during broker failover retries.

**Code Example:**
```java
import org.apache.kafka.clients.producer.*;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.*;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaProducerConfig {

    @Bean
    public ProducerFactory<String, String> producerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

        // Batching
        props.put(ProducerConfig.LINGER_MS_CONFIG, 10);          // wait up to 10ms
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 65536);       // 64 KB batches

        // Compression
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "lz4");

        // Durability
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, Integer.MAX_VALUE);
        props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 5);

        // Idempotence
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);

        // Timeouts
        props.put(ProducerConfig.REQUEST_TIMEOUT_MS_CONFIG, 30000);
        props.put(ProducerConfig.DELIVERY_TIMEOUT_MS_CONFIG, 120000);

        return new DefaultKafkaProducerFactory<>(props);
    }

    @Bean
    public KafkaTemplate<String, String> kafkaTemplate(ProducerFactory<String, String> pf) {
        return new KafkaTemplate<>(pf);
    }
}

// Usage in a service
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
public class OrderEventProducer {

    private final KafkaTemplate<String, String> kafkaTemplate;

    public OrderEventProducer(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void sendOrderEvent(String orderId, String eventJson) {
        CompletableFuture<SendResult<String, String>> future =
            kafkaTemplate.send("order-events", orderId, eventJson);

        future.whenComplete((result, ex) -> {
            if (ex != null) {
                // Log and handle: dead-letter queue, alerting, etc.
                System.err.println("Failed to send order " + orderId + ": " + ex.getMessage());
            } else {
                RecordMetadata meta = result.getRecordMetadata();
                System.out.printf("Sent order %s to partition %d offset %d%n",
                    orderId, meta.partition(), meta.offset());
            }
        });
    }
}
```

**Follow-up Questions:**
1. What happens when `max.block.ms` is exceeded — where does the producer block?
2. How does `max.in.flight.requests.per.connection=5` interact with idempotence and ordering guarantees?
3. What is the difference between `delivery.timeout.ms` and `request.timeout.ms`?

**Common Mistakes:**
- Setting `linger.ms=0` (default) in high-throughput scenarios and wondering why batching doesn't kick in.
- Enabling idempotence without also setting `acks=all` — Kafka will throw a `ConfigException`.
- Using `acks=1` and thinking it provides durability — the leader can crash between write and follower replication.

**Interview Traps:**
- "Does idempotent producer guarantee exactly-once across producer restarts?" — No. The PID is session-scoped. Across restarts, a new PID is assigned, and the broker has no way to correlate. Use transactions with a stable `transactional.id` for cross-session idempotence.
- "Does compression hurt latency?" — Compression adds CPU overhead but typically reduces end-to-end latency because network I/O is reduced. For small messages, compression overhead may exceed savings.

**Quick Revision (1-liner):**
Kafka producers batch records by size (`batch.size`) and time (`linger.ms`), compress per-batch, use `acks=all` for durability, and rely on PID+sequence-number idempotence to deduplicate retries within a producer session.

---

### Topic 3: Consumers & Consumer Groups
**Difficulty:** Medium | **Frequency:** High | **Companies:** LinkedIn, Netflix, Confluent, Uber

**Q: How do Kafka consumer groups work, what is partition assignment, and what is the difference between eager and cooperative rebalancing?**

**Short Answer (2-3 sentences):**
A consumer group is a set of consumers that jointly consume a topic; each partition is assigned to exactly one consumer in the group, enabling parallel processing while ensuring each record is processed once per group. When consumers join or leave, Kafka triggers a rebalance to redistribute partitions. Eager rebalancing (the classic protocol) stops all consumers and reassigns from scratch, causing a brief stop-the-world pause, while cooperative (incremental) rebalancing only revokes and reassigns the affected partitions, allowing unaffected consumers to continue processing.

**Deep Explanation:**
**Group Coordinator & Group Leader:**
Each consumer group is managed by a Group Coordinator broker (determined by hashing `group.id` to an `__consumer_offsets` partition). One consumer in the group is elected the Group Leader by the coordinator; the leader runs the partition assignment algorithm and returns the result to the coordinator, which distributes assignments to all members.

**Partition Assignment Strategies:**
- `RangeAssignor` (default): Assigns consecutive ranges of partitions per topic. Can cause imbalance if topics have uneven partition counts.
- `RoundRobinAssignor`: Assigns partitions round-robin across all topics. Better balance.
- `StickyAssignor`: Tries to preserve existing assignments and minimize movement during rebalances.
- `CooperativeStickyAssignor`: Sticky + cooperative (incremental) rebalancing. Recommended for production.

**Eager Rebalancing (Classic Protocol):**
1. All consumers send a `LeaveGroup` or trigger via heartbeat timeout.
2. All consumers stop consuming and revoke all partitions (stop-the-world).
3. The leader computes new assignment; coordinator distributes.
4. All consumers resume with new partitions.
This creates a gap in processing during rebalance — problematic for latency-sensitive applications.

**Cooperative (Incremental) Rebalancing:**
1. First round: Coordinator notifies members of pending rebalance; members respond with their current assignments.
2. Only partitions that need to move are revoked; unaffected partitions continue processing.
3. Second round: Revoked partitions are assigned to new owners.
This eliminates the stop-the-world pause. Enabled by `partition.assignment.strategy=CooperativeStickyAssignor` and `group.protocol=consumer` (KIP-848 in Kafka 3.7+).

**Session Timeout vs Heartbeat:**
- `session.timeout.ms` (default 45s): If the coordinator doesn't receive a heartbeat within this window, the consumer is declared dead and triggers rebalance.
- `heartbeat.interval.ms` (default 3s): How often the consumer sends heartbeats. Should be ~1/3 of `session.timeout.ms`.
- `max.poll.interval.ms` (default 300s): Maximum time between `poll()` calls. If exceeded, the consumer is removed from the group (liveness failure separate from heartbeat).

**Real-World Example:**
At Netflix, streaming recommendation consumers use `CooperativeStickyAssignor` with rolling deployments. Without cooperative rebalancing, deploying 50 consumer instances would cause 50 sequential stop-the-world pauses. With cooperative, only the partitions moving to new instances are briefly paused.

**Code Example:**
```java
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.CooperativeStickyAssignor;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.listener.ContainerProperties;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaConsumerConfig {

    @Bean
    public ConsumerFactory<String, String> consumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "order-processing-group");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);

        // Cooperative sticky rebalancing
        props.put(ConsumerConfig.PARTITION_ASSIGNMENT_STRATEGY_CONFIG,
            CooperativeStickyAssignor.class.getName());

        // Offset management
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

        // Heartbeat / session tuning
        props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 45000);
        props.put(ConsumerConfig.HEARTBEAT_INTERVAL_MS_CONFIG, 15000);
        props.put(ConsumerConfig.MAX_POLL_INTERVAL_MS_CONFIG, 300000);
        props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 500);

        return new DefaultKafkaConsumerFactory<>(props);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, String> kafkaListenerContainerFactory(
            ConsumerFactory<String, String> cf) {
        ConcurrentKafkaListenerContainerFactory<String, String> factory =
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(cf);
        factory.setConcurrency(3); // 3 consumer threads per instance
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL_IMMEDIATE);
        return factory;
    }
}
```

**Follow-up Questions:**
1. What happens if a consumer takes longer than `max.poll.interval.ms` to process a batch? How do you mitigate this?
2. How does the static group membership (`group.instance.id`) reduce rebalances?
3. What is the maximum consumer parallelism for a topic with 6 partitions?

**Common Mistakes:**
- Setting `max.poll.records` too high — if processing takes >max.poll.interval.ms, the consumer is kicked out of the group mid-batch.
- Not handling `onPartitionsRevoked` — during eager rebalance, uncommitted offsets for revoked partitions may be re-processed by the new owner.
- Mixing `CooperativeStickyAssignor` with `EagerRebalanceProtocol` consumers in the same group during migration — can cause protocol mismatch errors.

**Interview Traps:**
- "Can two consumers in the same group read the same partition?" — No, within a group each partition is owned by exactly one consumer. Different groups can read the same partition independently.
- "If a topic has 3 partitions and 5 consumers in the group, what happens?" — 3 consumers get one partition each; 2 consumers are idle. Adding partitions is the only way to increase parallelism beyond the partition count.

**Quick Revision (1-liner):**
Consumer groups distribute topic partitions across members (one partition per consumer); eager rebalancing causes a stop-the-world pause while cooperative (incremental) rebalancing only moves affected partitions, keeping unaffected consumers running.

---

### Topic 4: Offset Management
**Difficulty:** Medium | **Frequency:** High | **Companies:** Goldman Sachs, Confluent, Uber, LinkedIn

**Q: What is the difference between auto and manual offset commit, and how do they map to at-most-once, at-least-once, and exactly-once delivery semantics?**

**Short Answer (2-3 sentences):**
Auto-commit (`enable.auto.commit=true`) periodically commits the latest polled offset at `auto.commit.interval.ms`, which can produce at-most-once or at-least-once depending on when the commit happens relative to processing. Manual commit gives the application control: committing before processing risks at-most-once (record processed zero times on crash), committing after processing achieves at-least-once (record re-processed on crash before commit). True exactly-once requires transactional producers + idempotent consumers or Kafka Streams EOS.

**Deep Explanation:**
**Auto-Commit Behavior:**
Auto-commit commits the offset of the last record returned by `poll()`, not the last record processed. If the consumer crashes after poll but before processing, the offset is still committed on the next poll cycle — leading to message loss (at-most-once). If the consumer crashes after processing but before the next auto-commit interval, the offset is not committed — leading to reprocessing (at-least-once). Auto-commit is non-deterministic and generally unsuitable for production critical paths.

**Manual Commit Strategies:**
1. **Commit Sync (`commitSync()`)**: Blocks until the broker acknowledges. Retries automatically on transient failure. Use when ordering is critical.
2. **Commit Async (`commitAsync()`)**: Non-blocking; pass a callback for error handling. Higher throughput but requires careful error handling to avoid skipping commits on transient failures.
3. **Per-Record Commit**: Commit after every record — maximum safety, lowest throughput.
4. **Per-Batch Commit**: Commit after processing all records in a `poll()` batch — good balance.
5. **Synchronous Commit on Rebalance/Shutdown**: Always commit synchronously in `onPartitionsRevoked` to avoid reprocessing when partitions are reassigned.

**Delivery Semantics Mapping:**
| Semantic | How | Config |
|---|---|---|
| At-most-once | Commit before processing | `auto.commit` or manual pre-processing commit |
| At-least-once | Commit after processing | `enable.auto.commit=false`, manual post-processing commit |
| Exactly-once | Transactional producer + idempotent consumer or Kafka Streams EOS | `isolation.level=read_committed`, transactional producer |

**Offset Reset Policy (`auto.offset.reset`):**
- `earliest`: Start from the beginning of the topic (or the earliest available offset after retention).
- `latest`: Start from the end — only new messages after consumer start.
- `none`: Throw exception if no committed offset exists.

**Real-World Example:**
Goldman Sachs trade confirmation service uses `enable.auto.commit=false` with synchronous per-batch commit inside a database transaction: process batch → write to DB → `commitSync()`. If the DB write fails, the offset is not committed, and the batch is retried — achieving at-least-once with idempotent DB upserts for effective exactly-once.

**Code Example:**
```java
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Service;

@Service
public class OrderConsumer {

    private final OrderRepository orderRepository;

    public OrderConsumer(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    // Manual commit: at-least-once — commit AFTER successful processing
    @KafkaListener(
        topics = "order-events",
        groupId = "order-processing-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {
        try {
            // 1. Process the record
            orderRepository.upsert(record.key(), record.value());

            // 2. Commit offset AFTER successful processing (at-least-once)
            ack.acknowledge();

        } catch (Exception e) {
            // Do NOT acknowledge — record will be redelivered after restart/rebalance
            // Optionally: send to dead-letter topic after N retries
            throw e; // Let Spring Kafka's error handler manage retry
        }
    }
}

// Batch commit example — commit whole batch at once
import java.util.List;

@Service
public class BatchOrderConsumer {

    @KafkaListener(
        topics = "order-events",
        groupId = "batch-order-group",
        containerFactory = "batchKafkaListenerContainerFactory"
    )
    public void consumeBatch(List<ConsumerRecord<String, String>> records, Acknowledgment ack) {
        try {
            for (ConsumerRecord<String, String> record : records) {
                processOrder(record);
            }
            // Commit after entire batch is processed
            ack.acknowledge();
        } catch (Exception e) {
            // Entire batch will be retried
            throw new RuntimeException("Batch processing failed", e);
        }
    }

    private void processOrder(ConsumerRecord<String, String> record) {
        // business logic
    }
}
```

**Follow-up Questions:**
1. What is the difference between `commitSync()` and `commitAsync()` in error handling — when would you use each?
2. How do you implement idempotent consumers to achieve effectively-exactly-once without transactions?
3. What happens to committed offsets when a consumer group is deleted?

**Common Mistakes:**
- Calling `ack.acknowledge()` inside a try-catch that swallows exceptions — this silently commits offsets for failed records, losing them forever.
- Using `auto.commit` and assuming it provides at-least-once — it actually provides at-most-once if the consumer crashes post-poll pre-commit interval.
- Not committing on `onPartitionsRevoked` — causes the new partition owner to reprocess already-processed records.

**Interview Traps:**
- "Does `enable.auto.commit=false` by itself give you exactly-once?" — No. It gives at-least-once. Exactly-once requires either idempotent consumers (application-level deduplication) or Kafka transactions.
- "What does `isolation.level=read_committed` do on the consumer side?" — It causes the consumer to only see records from committed transactions, filtering out aborted transaction records and pending (uncommitted) records.

**Quick Revision (1-liner):**
Manual post-processing offset commit gives at-least-once semantics; auto-commit is unreliable; true exactly-once requires transactional producers paired with `isolation.level=read_committed` consumers.

---

### Topic 5: Kafka Delivery Guarantees
**Difficulty:** Hard | **Frequency:** High | **Companies:** Confluent, Goldman Sachs, Netflix, Uber

**Q: How does Kafka achieve exactly-once semantics (EOS) using transactions — explain transactional.id, the two-phase commit protocol, and idempotent semantics?**

**Short Answer (2-3 sentences):**
Kafka EOS is built on two pillars: idempotent producers (deduplication within a session via PID + sequence number) and transactions (atomic multi-partition writes via `transactional.id`, Transaction Coordinator, and a two-phase commit protocol). A transactional producer writes records and offsets atomically — either all are committed or all are aborted. Consumers using `isolation.level=read_committed` only see records from committed transactions.

**Deep Explanation:**
**Idempotent Producer (Session-Level):**
- Broker assigns a Producer ID (PID) on `initTransactions()` or first produce.
- Each batch has a monotonically increasing sequence number per partition.
- Broker deduplicates: if a (PID, partition, sequence) batch is received twice, the second is silently dropped.
- Limitation: PID is invalidated on producer restart — no cross-session idempotence.

**Transactions (Cross-Session, Cross-Partition):**
`transactional.id` is a stable, application-assigned identifier (e.g., `"order-processor-instance-1"`). On restart, the broker uses it to fence older zombie producers.

**Transaction Flow:**
1. `initTransactions()` — Producer registers with the Transaction Coordinator (a broker partition of `__transaction_state` topic). The TC bumps the epoch; any old producer with same `transactional.id` and lower epoch is fenced (rejected).
2. `beginTransaction()` — Locally marks start.
3. Producer sends records to partitions (logged as part of the open transaction).
4. `sendOffsetsToTransaction(offsets, groupMetadata)` — Atomically includes consumer offset commits in the transaction.
5. `commitTransaction()` or `abortTransaction()` — Producer sends `EndTransactionMarker` to TC.
6. TC writes COMMIT/ABORT to `__transaction_state` and then writes transaction markers to each partition's log.
7. Consumers with `isolation.level=read_committed` only expose records up to the Last Stable Offset (LSO) — the offset of the oldest open transaction.

**Zombie Fencing:**
If a transactional producer restarts with the same `transactional.id`, the new epoch invalidates any in-flight batches from the old (zombie) producer, preventing duplicate writes.

**Performance Trade-off:**
Transactions add ~1-5 ms latency per transaction due to two-phase commit. Batch multiple records per transaction to amortize overhead.

**Real-World Example:**
A Kafka Streams application processing payments (read from `payments-input`, write to `payments-output`, commit consumer offsets) uses transactions to ensure that either all three operations succeed or none do — preventing double-charging or lost payments during broker failover.

**Code Example:**
```java
import org.apache.kafka.clients.producer.*;
import org.apache.kafka.clients.consumer.*;
import org.apache.kafka.common.serialization.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.*;
import org.springframework.kafka.transaction.KafkaTransactionManager;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaTransactionConfig {

    @Bean
    public ProducerFactory<String, String> transactionalProducerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.TRANSACTIONAL_ID_CONFIG, "payment-processor-1"); // stable ID

        DefaultKafkaProducerFactory<String, String> pf = new DefaultKafkaProducerFactory<>(props);
        pf.setTransactionIdPrefix("payment-tx-"); // Spring adds suffix for concurrency
        return pf;
    }

    @Bean
    public KafkaTemplate<String, String> transactionalKafkaTemplate(
            ProducerFactory<String, String> pf) {
        return new KafkaTemplate<>(pf);
    }

    @Bean
    public KafkaTransactionManager<String, String> kafkaTransactionManager(
            ProducerFactory<String, String> pf) {
        return new KafkaTransactionManager<>(pf);
    }
}

// Transactional consume-transform-produce pattern
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentProcessor {

    private final KafkaTemplate<String, String> kafkaTemplate;

    public PaymentProcessor(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    // @Transactional triggers KafkaTransactionManager — atomic produce + offset commit
    @Transactional("kafkaTransactionManager")
    @KafkaListener(
        topics = "payments-input",
        groupId = "payment-processor-group"
    )
    public void process(ConsumerRecord<String, String> record) {
        String result = transformPayment(record.value());

        // This send is part of the transaction
        kafkaTemplate.send("payments-output", record.key(), result);

        // If an exception is thrown here, the transaction is aborted:
        // - The output record is NOT visible to read_committed consumers
        // - The input offset is NOT committed
        // Both operations are atomic
    }

    private String transformPayment(String payment) {
        // business logic
        return payment.toUpperCase();
    }
}
```

**Follow-up Questions:**
1. What is the Last Stable Offset (LSO), and how does an open transaction affect consumer throughput?
2. How does Kafka handle a Transaction Coordinator failure mid-transaction?
3. What is the difference between Kafka EOS and database ACID transactions?

**Common Mistakes:**
- Using a different `transactional.id` per producer instance restart — zombie fencing only works with a stable ID.
- Not setting `isolation.level=read_committed` on the consumer side — consumers will see uncommitted (and potentially aborted) records.
- Using transactions for single-partition, single-record writes where idempotent producer alone suffices — unnecessary overhead.

**Interview Traps:**
- "Does Kafka EOS guarantee exactly-once with external systems (e.g., databases)?" — No. Kafka EOS is Kafka-internal only. For external systems, you need two-phase commit or application-level idempotency (e.g., upsert by record ID).
- "Can Kafka Streams automatically use EOS?" — Yes. Set `processing.guarantee=exactly_once_v2` (EOS v2, Kafka 2.6+) or `exactly_once` (EOS v1). Streams handles transactions transparently.

**Quick Revision (1-liner):**
Kafka EOS uses `transactional.id` + epoch-based zombie fencing for cross-session idempotence, a two-phase commit protocol for atomic multi-partition writes, and `isolation.level=read_committed` on consumers to hide uncommitted records.

---

### Topic 6: Partitioning Strategy
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** LinkedIn, Confluent, Uber

**Q: How does Kafka partition records, and how do you design a partitioning strategy to avoid hotspots while maintaining ordering guarantees?**

**Short Answer (2-3 sentences):**
By default, the Kafka producer routes keyed records using `murmur2(key) % numPartitions`, ensuring all records with the same key land in the same partition (ordering guarantee). Keyless records are distributed round-robin (or sticky partition per batch in newer versions). Hotspots occur when key cardinality is low or key distribution is skewed; solutions include key salting, custom partitioners, or compounded keys.

**Deep Explanation:**
**Default Partitioner (DefaultPartitioner / UniformStickyPartitioner):**
- Keyed records: `partition = murmur2(key) % numPartitions`. Deterministic mapping — same key always same partition.
- Keyless records: The sticky partitioner (default since Kafka 2.4) sends a batch to one partition until the batch is full or `linger.ms` elapses, then switches. This improves batching vs pure round-robin.

**Key-Based Partitioning (When to Use):**
Use when you need ordering per entity (e.g., all events for `orderId=123` must be processed in sequence). The key should have high cardinality and uniform distribution.

**Hotspot Scenarios:**
1. **Low-cardinality keys**: e.g., `country` — most traffic goes to a few partitions (US, EU).
2. **Viral users**: e.g., key = `userId` but one user generates 100x more events.
3. **Time-based keys**: e.g., key = `date` — all traffic goes to today's partition.

**Hotspot Avoidance Strategies:**
1. **Key Salting**: Append a random suffix to the key: `orderId + "-" + random(0, N)`. Spreads load but breaks ordering — requires downstream deduplication.
2. **Compound Keys**: `regionId + ":" + userId` — spreads across region+user combinations.
3. **Custom Partitioner**: Implement `org.apache.kafka.clients.producer.Partitioner` to apply domain-specific logic (e.g., route VIP users to dedicated partitions).
4. **Increase Partition Count**: More partitions reduce per-partition load, but can't fix a key with 100% of traffic.

**Partition Count Decisions:**
- Rule of thumb: `partitions = max(throughput_MB/s / 10, desired_parallelism)`.
- Consider: number of consumers, broker count, replication overhead, Zookeeper/KRaft metadata load.
- Adding partitions later is possible but breaks key-to-partition mapping for existing records — existing consumers may see out-of-order records for a key after the change.

**Real-World Example:**
LinkedIn's newsfeed uses `memberId` as the partition key. For members with large networks (e.g., influencers with millions of connections), a custom partitioner routes their events to a "heavy hitter" partition set with extra consumer capacity.

**Code Example:**
```java
import org.apache.kafka.clients.producer.Partitioner;
import org.apache.kafka.common.Cluster;
import org.apache.kafka.common.PartitionInfo;

import java.util.List;
import java.util.Map;

/**
 * Custom partitioner: routes "VIP" orders to dedicated partitions 0-2,
 * regular orders to partitions 3-N.
 */
public class OrderPartitioner implements Partitioner {

    private static final int VIP_PARTITION_COUNT = 3;

    @Override
    public int partition(String topic, Object key, byte[] keyBytes,
                         Object value, byte[] valueBytes, Cluster cluster) {
        List<PartitionInfo> partitions = cluster.partitionsForTopic(topic);
        int totalPartitions = partitions.size();

        if (keyBytes == null) {
            // No key — use round-robin across non-VIP partitions
            return VIP_PARTITION_COUNT + (int)(Math.random() * (totalPartitions - VIP_PARTITION_COUNT));
        }

        String orderKey = new String(keyBytes);
        if (orderKey.startsWith("VIP-")) {
            // VIP orders: use murmur2 within VIP partition range
            return Math.abs(murmur2(keyBytes)) % VIP_PARTITION_COUNT;
        }

        // Regular orders: distribute across remaining partitions
        int regularPartitions = totalPartitions - VIP_PARTITION_COUNT;
        return VIP_PARTITION_COUNT + (Math.abs(murmur2(keyBytes)) % regularPartitions);
    }

    private int murmur2(byte[] data) {
        // Simplified — in production use org.apache.kafka.common.utils.Utils.murmur2
        return java.util.Arrays.hashCode(data);
    }

    @Override
    public void close() {}

    @Override
    public void configure(Map<String, ?> configs) {}
}

// Register custom partitioner in producer config
// props.put(ProducerConfig.PARTITIONER_CLASS_CONFIG, OrderPartitioner.class.getName());
```

**Follow-up Questions:**
1. What happens to key-based ordering guarantees if you increase partition count on a live topic?
2. How does the UniformStickyPartitioner (keyless) improve throughput vs round-robin?
3. If you need ordering within a category (e.g., per-user) but want to avoid hotspots, what is your strategy?

**Common Mistakes:**
- Choosing a low-cardinality key (e.g., boolean `isPremium`) thinking it ensures ordering — creates severe hotspots.
- Not accounting for partition count increases in downstream consumers — consumers may need to rebuild state.
- Setting `num.partitions` too high initially — each partition has overhead (memory, file handles, replication network).

**Interview Traps:**
- "Does null key mean random partition?" — Not random per-record. Since Kafka 2.4, the UniformStickyPartitioner sends a batch to one sticky partition before switching, improving batch aggregation.
- "Can you decrease partition count?" — No. Kafka does not support partition reduction. You must create a new topic with fewer partitions and migrate.

**Quick Revision (1-liner):**
Keyed records use `murmur2(key) % numPartitions` for deterministic routing (ordering guarantee); hotspots from skewed keys require key salting, compound keys, or custom partitioners, while partition count decisions balance throughput parallelism against per-partition overhead.

---

### Topic 7: Consumer Lag & Monitoring
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Confluent, Netflix, LinkedIn

**Q: What is consumer lag, how is it calculated, and what monitoring and alerting strategies do you use in production?**

**Short Answer (2-3 sentences):**
Consumer lag is the difference between the latest offset on a partition (log-end offset, LEO) and the last committed offset of a consumer group on that partition. It indicates how far behind consumers are from the latest data. In production, lag is monitored via JMX, Kafka's AdminClient API, or tools like Confluent Control Center, Burrow, or Prometheus/Grafana, with alerts triggering when lag exceeds a threshold or grows monotonically.

**Deep Explanation:**
**Lag Calculation:**
For each (group, topic, partition):
```
lag = log_end_offset(partition) - committed_offset(group, partition)
```
Total group lag = sum of per-partition lags.

**Monitoring Tools:**
1. **kafka-consumer-groups.sh**: CLI tool, good for ad-hoc checks.
   ```bash
   kafka-consumer-groups.sh --bootstrap-server broker:9092 \
     --describe --group my-group
   ```
2. **JMX Metrics**: `kafka.consumer:type=consumer-fetch-manager-metrics,client-id=X` — `records-lag-max`, `records-lag-avg`.
3. **AdminClient API**: `listConsumerGroupOffsets()` + `listOffsets()` for programmatic lag calculation.
4. **Burrow (LinkedIn)**: Evaluates lag trends over time — not just current lag but whether it is growing (consumer is falling behind) vs. stable.
5. **Confluent Control Center / Grafana + JMX Exporter**: Dashboard-based monitoring.

**Key Metrics to Monitor:**
- `records-lag-max`: Highest lag across all partitions for a consumer — most critical.
- `records-consumed-rate`: Records per second consumed.
- `fetch-rate` and `fetch-latency-avg`: Network health.
- `commit-rate`: How frequently offsets are committed.

**Alerting Strategy:**
1. **Threshold Alert**: Lag > N records (e.g., >10,000) for > 5 minutes → Page on-call.
2. **Rate-of-Change Alert**: Lag increasing for > 10 consecutive minutes → Warning.
3. **Zero-Consumption Alert**: `records-consumed-rate = 0` for > 2 minutes → Critical (consumer may be stuck).
4. **Partition Imbalance**: One partition has 10x lag of others → hot partition or stuck consumer thread.

**Lag vs Latency:**
Lag in records is not directly comparable across topics. Convert to time: `lag_time = lag_records / consumption_rate`. Some systems (Confluent, custom tooling) use producer timestamp in the record header to calculate exact lag in milliseconds.

**Real-World Example:**
Netflix uses a custom lag monitoring system that calculates lag in milliseconds (using record timestamps) rather than record counts, because message sizes vary dramatically. An alert fires if any consumer group falls more than 30 seconds behind the producer.

**Code Example:**
```java
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;

import java.util.*;
import java.util.concurrent.ExecutionException;

public class KafkaLagMonitor {

    private final AdminClient adminClient;

    public KafkaLagMonitor(String bootstrapServers) {
        Properties props = new Properties();
        props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        this.adminClient = AdminClient.create(props);
    }

    public Map<TopicPartition, Long> calculateLag(String groupId) 
            throws ExecutionException, InterruptedException {

        // Step 1: Get committed offsets for the consumer group
        Map<TopicPartition, OffsetAndMetadata> committedOffsets =
            adminClient.listConsumerGroupOffsets(groupId)
                       .partitionsToOffsetAndMetadata()
                       .get();

        // Step 2: Get log-end offsets (LEO) for those partitions
        Map<TopicPartition, OffsetSpec> offsetSpecs = new HashMap<>();
        committedOffsets.keySet().forEach(tp ->
            offsetSpecs.put(tp, OffsetSpec.latest()));

        Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> latestOffsets =
            adminClient.listOffsets(offsetSpecs).all().get();

        // Step 3: Calculate lag per partition
        Map<TopicPartition, Long> lagMap = new LinkedHashMap<>();
        for (Map.Entry<TopicPartition, OffsetAndMetadata> entry : committedOffsets.entrySet()) {
            TopicPartition tp = entry.getKey();
            long committedOffset = entry.getValue().offset();
            long logEndOffset = latestOffsets.get(tp).offset();
            lagMap.put(tp, logEndOffset - committedOffset);
        }

        return lagMap;
    }

    public void printLag(String groupId) throws Exception {
        Map<TopicPartition, Long> lag = calculateLag(groupId);
        long totalLag = lag.values().stream().mapToLong(Long::longValue).sum();

        System.out.printf("Consumer Group: %s | Total Lag: %d%n", groupId, totalLag);
        lag.forEach((tp, l) ->
            System.out.printf("  %s partition %d: lag=%d%n",
                tp.topic(), tp.partition(), l));
    }

    public void close() {
        adminClient.close();
    }
}
```

**Follow-up Questions:**
1. Why is lag in records sometimes misleading — when would you prefer lag in time (milliseconds)?
2. How does Burrow's sliding-window analysis differ from simple threshold alerting?
3. What causes consumer lag to grow even when `records-consumed-rate` is non-zero?

**Common Mistakes:**
- Alerting only on total lag without checking per-partition lag — a stuck partition can be masked by healthy partitions.
- Using `records-lag-max` JMX metric from inside the consumer process — requires the consumer to be running. Dead consumers show no lag JMX but have growing actual lag.
- Not accounting for consumer group rebalances temporarily increasing lag metrics.

**Interview Traps:**
- "Lag is 0 — does that mean the consumer is healthy?" — Not necessarily. The consumer may have committed offsets ahead of processing (at-most-once commit), or the topic may have no new data.
- "Can lag be negative?" — In theory no, but AdminClient calculations can show negative lag briefly due to race conditions between offset commits and log-end-offset updates. Treat negative lag as zero.

**Quick Revision (1-liner):**
Consumer lag = log-end-offset minus committed offset per partition; monitor with JMX `records-lag-max`, AdminClient API, or Burrow, and alert on both absolute threshold and monotonically growing lag.

---

### Topic 8: Kafka Streams
**Difficulty:** Hard | **Frequency:** Medium | **Companies:** Confluent, LinkedIn, Uber

**Q: What is the difference between KStream and KTable in Kafka Streams, and how do tumbling, hopping, and session windows work for stateful aggregations?**

**Short Answer (2-3 sentences):**
A KStream represents an unbounded stream of events where each record is an independent event (insert semantics), while a KTable represents a changelog stream where each record updates the latest value for a key (upsert semantics). Windowing enables stateful aggregations over time-bounded buckets: tumbling windows are fixed-size non-overlapping, hopping windows are fixed-size overlapping, and session windows are dynamically sized based on gaps between events. Kafka Streams materializes windowed state in local RocksDB state stores, with changelog topics for fault tolerance.

**Deep Explanation:**
**KStream vs KTable:**
- **KStream**: Each record is an independent event. `stream.filter(...)`, `stream.map(...)`, `stream.flatMap(...)`. Use for event logs, clickstreams, transactions.
- **KTable**: Each record is an update to a key's current value. The table holds the latest value per key (like a materialized view). Use for current state: user profiles, account balances.
- **GlobalKTable**: A KTable replicated to all Kafka Streams instances, enabling non-partitioned joins (join with any key regardless of partitioning).

**Windowing Types:**
1. **Tumbling Window** (`TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5))`):
   - Fixed size, non-overlapping. Record at t=4m falls in window [0,5). Record at t=6m falls in window [5,10).
   - Use: page views per 5 minutes.

2. **Hopping Window** (`TimeWindows.of(Duration.ofMinutes(10)).advanceBy(Duration.ofMinutes(5))`):
   - Fixed size, overlapping. A record may fall in multiple windows.
   - Window size=10m, advance=5m → record at t=6m falls in both [0,10) and [5,15).
   - Use: moving averages.

3. **Session Window** (`SessionWindows.ofInactivityGapWithNoGrace(Duration.ofMinutes(30))`):
   - Dynamic size based on activity gaps. Events within 30 minutes of each other are merged into the same session.
   - Use: user session analytics.

**Stateful Processing & State Stores:**
Stateful operations (aggregations, joins, windowing) use local RocksDB state stores. Each task's state store is backed by a changelog Kafka topic (log compacted). On restart, the task restores state by replaying the changelog.

**Standby Replicas:** Set `num.standby.replicas=1` to keep a warm copy of state stores on another instance, reducing restoration time after failure.

**Joins:**
- `KStream-KStream join`: Both sides must be windowed (join within a time window).
- `KStream-KTable join`: Non-windowed. The KTable side provides current value for each stream record's key.
- `KTable-KTable join`: Triggers output on any update to either side.

**Real-World Example:**
Uber uses Kafka Streams for real-time surge pricing: a KStream of trip requests is aggregated with a tumbling 1-minute window per geohash (location cell), joined with a KTable of driver availability, to compute demand/supply ratio and update surge multipliers every minute.

**Code Example:**
```java
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.*;
import org.apache.kafka.streams.kstream.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.EnableKafkaStreams;

import java.time.Duration;
import java.util.Properties;

@Configuration
@EnableKafkaStreams
public class KafkaStreamsConfig {

    // KStream: count page views per URL in 5-minute tumbling windows
    @Bean
    public KStream<String, String> pageViewStream(StreamsBuilder builder) {
        KStream<String, String> pageViews = builder.stream(
            "page-views",
            Consumed.with(Serdes.String(), Serdes.String())
        );

        // Tumbling window: 5-minute non-overlapping buckets
        KTable<Windowed<String>, Long> viewCounts = pageViews
            .groupByKey()
            .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5)))
            .count(Materialized.as("page-view-counts"));

        // Convert back to stream and write to output topic
        viewCounts.toStream()
            .map((windowedKey, count) -> KeyValue.pair(
                windowedKey.key() + "@" + windowedKey.window().startTime(),
                String.valueOf(count)
            ))
            .to("page-view-aggregates", Produced.with(Serdes.String(), Serdes.String()));

        return pageViews;
    }

    // KTable: join user click stream with user profile table
    @Bean
    public KStream<String, String> enrichedClickStream(StreamsBuilder builder) {
        KStream<String, String> clicks = builder.stream(
            "user-clicks",
            Consumed.with(Serdes.String(), Serdes.String())
        );

        KTable<String, String> userProfiles = builder.table(
            "user-profiles",
            Consumed.with(Serdes.String(), Serdes.String())
        );

        // KStream-KTable join: enrich each click with user profile
        KStream<String, String> enriched = clicks.join(
            userProfiles,
            (clickEvent, userProfile) -> clickEvent + "|" + userProfile
        );

        enriched.to("enriched-clicks", Produced.with(Serdes.String(), Serdes.String()));
        return clicks;
    }

    @Bean(name = KafkaStreamsDefaultConfiguration.DEFAULT_STREAMS_CONFIG_BEAN_NAME)
    public KafkaStreamsConfiguration kafkaStreamsConfig() {
        Properties props = new Properties();
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "page-view-processor");
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092");
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass());
        props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2);
        props.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, 1);
        props.put(StreamsConfig.COMMIT_INTERVAL_MS_CONFIG, 1000);
        return new KafkaStreamsConfiguration(props.entrySet().stream()
            .collect(java.util.stream.Collectors.toMap(
                e -> e.getKey().toString(), Map.Entry::getValue)));
    }
}
```

**Follow-up Questions:**
1. How does Kafka Streams handle out-of-order records (late arrivals) — what is the grace period?
2. What is the relationship between Kafka Streams tasks, threads, and partitions?
3. How do you reprocess historical data in Kafka Streams (reset the application)?

**Common Mistakes:**
- Using `ofSizeAndGrace(size, Duration.ZERO)` without understanding that records arriving after the window closes are dropped.
- Not co-partitioning KStream and KTable topics for joins — results in `TopologyException`.
- Underestimating state store size — RocksDB can consume significant disk space for large windowed aggregations.

**Interview Traps:**
- "Can Kafka Streams replace Flink or Spark Streaming?" — For simple stateful stream processing on Kafka data, yes. For complex event processing, ML pipelines, or cross-system joins, Flink is more appropriate.
- "What is the difference between `processing.guarantee=exactly_once` and `exactly_once_v2`?" — v2 (Kafka 2.6+) uses a shared transaction producer per StreamThread rather than per task, reducing overhead. v2 requires Kafka brokers 2.5+.

**Quick Revision (1-liner):**
KStream treats every record as an independent event (insert), KTable as an upsert to the latest value; windowing (tumbling/hopping/session) enables stateful time-bounded aggregations backed by RocksDB state stores with changelog topic fault tolerance.

---

### Topic 9: Kafka Connect
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Confluent, LinkedIn, Goldman Sachs

**Q: What is Kafka Connect, how do source and sink connectors work, what are Single Message Transforms (SMTs), and how does Debezium enable CDC?**

**Short Answer (2-3 sentences):**
Kafka Connect is a scalable, fault-tolerant framework for streaming data between Kafka and external systems using source connectors (external system → Kafka) and sink connectors (Kafka → external system). Single Message Transforms (SMTs) are lightweight, stateless transformations applied per-record in the connector pipeline without writing custom code. Debezium is a CDC (Change Data Capture) source connector that reads the database binary log (MySQL binlog, Postgres WAL) and produces a Kafka event for every row-level INSERT, UPDATE, and DELETE.

**Deep Explanation:**
**Kafka Connect Architecture:**
- **Workers**: JVM processes running in standalone or distributed mode. Distributed mode: workers form a cluster; tasks are distributed across workers.
- **Connectors**: Logical configuration units. Each connector manages N tasks.
- **Tasks**: The actual units of work. For a source connector with 3 partitions, Kafka assigns 3 tasks in parallel.
- **Offset Storage**: Connect tracks source offsets (e.g., file position, DB log position) in a Kafka topic (`connect-offsets`), enabling restart-without-replay.
- **Config Storage**: Connector configs stored in `connect-configs` topic.
- **Status Storage**: Task status in `connect-status` topic.

**Source Connectors (External → Kafka):**
- FileStreamSourceConnector: Reads a file line by line.
- JdbcSourceConnector (Confluent): Polls a DB table for new/updated rows (timestamp or incrementing column strategy).
- Debezium (CDC): Reads DB binary log for real-time, low-latency CDC.

**Sink Connectors (Kafka → External):**
- JdbcSinkConnector: Writes to a relational DB (INSERT, UPSERT, DELETE based on record key).
- ElasticsearchSinkConnector: Indexes records to Elasticsearch.
- S3SinkConnector: Partitions and writes records to S3 as Parquet/JSON/Avro files.

**Single Message Transforms (SMTs):**
Stateless record-level transformations in the connector's processing chain:
- `InsertField`: Add a field to the record.
- `ReplaceField`: Rename or drop fields.
- `MaskField`: Replace field value with a mask (PII redaction).
- `TimestampRouter`: Route to time-partitioned topics.
- `ValueToKey`: Promote a field to the record key.
- `Flatten`: Flatten nested structs.
Chain multiple SMTs: `transforms=addTimestamp,redactEmail,...`

**Debezium CDC:**
Debezium connects to the DB's replication protocol:
- MySQL: Reads binlog (STATEMENT/ROW format, requires `binlog_format=ROW`).
- PostgreSQL: Uses logical replication slot (`pgoutput` or `decoderbufs`).
- Oracle: LogMiner.

Debezium emits a structured envelope per change event:
```json
{
  "before": { "id": 1, "email": "old@example.com" },
  "after":  { "id": 1, "email": "new@example.com" },
  "op": "u",  // c=create, u=update, d=delete, r=read (snapshot)
  "ts_ms": 1700000000000,
  "source": { "db": "orders", "table": "order_items", ... }
}
```

**Real-World Example:**
Goldman Sachs uses Debezium to capture every trade record change from their Oracle trade database into Kafka in real time (<100 ms latency), replacing nightly batch ETL jobs. Downstream consumers build real-time risk dashboards without querying the source OLTP database.

**Code Example:**
```json
// Debezium MySQL Connector configuration (REST API payload)
{
  "name": "mysql-orders-cdc",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "database.hostname": "mysql-primary.internal",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "${file:/opt/kafka/secrets/mysql.properties:password}",
    "database.server.id": "184054",
    "database.server.name": "mysql-orders",
    "database.include.list": "orders_db",
    "table.include.list": "orders_db.orders,orders_db.order_items",
    "database.history.kafka.bootstrap.servers": "broker1:9092",
    "database.history.kafka.topic": "schema-changes.orders",
    "include.schema.changes": "true",
    "snapshot.mode": "initial",

    "transforms": "unwrap,addTimestamp",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.addTimestamp.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.addTimestamp.timestamp.field": "kafka_ingest_ts",

    "key.converter": "io.confluent.kafka.serializers.KafkaAvroSerializer",
    "key.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter": "io.confluent.kafka.serializers.KafkaAvroSerializer",
    "value.converter.schema.registry.url": "http://schema-registry:8081"
  }
}
```

```java
// Spring Boot application consuming Debezium CDC events
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class OrderCdcConsumer {

    private final ObjectMapper mapper = new ObjectMapper();
    private final OrderProjectionService projectionService;

    public OrderCdcConsumer(OrderProjectionService projectionService) {
        this.projectionService = projectionService;
    }

    @KafkaListener(topics = "mysql-orders.orders_db.orders", groupId = "order-projection-group")
    public void consumeCdcEvent(ConsumerRecord<String, String> record) throws Exception {
        JsonNode payload = mapper.readTree(record.value());
        String op = payload.get("op").asText();

        switch (op) {
            case "c", "r" -> projectionService.insert(payload.get("after"));
            case "u"      -> projectionService.update(payload.get("after"));
            case "d"      -> projectionService.delete(payload.get("before").get("id").asText());
        }
    }
}
```

**Follow-up Questions:**
1. What is the difference between Debezium snapshot mode `initial` vs `schema_only`, and when would you use each?
2. How does Kafka Connect handle connector failures — what happens to in-flight records?
3. What are the limitations of JDBC polling source connectors compared to CDC?

**Common Mistakes:**
- Not setting `database.server.id` to a unique value when running multiple Debezium instances against the same MySQL cluster — causes replication conflicts.
- Chaining too many SMTs — SMTs are stateless, so complex transformations requiring state (joins, aggregations) should be done in Kafka Streams or a consumer application, not SMTs.
- Not monitoring replication slot lag in PostgreSQL — an idle or slow Debezium connector can cause WAL accumulation and disk exhaustion.

**Interview Traps:**
- "Is Kafka Connect fault-tolerant without Zookeeper?" — Yes. In distributed mode, Connect uses Kafka topics for offset/config/status storage. It is independent of Zookeeper.
- "Can SMTs do joins or aggregations?" — No. SMTs are stateless, per-record transforms. For stateful operations use Kafka Streams.

**Quick Revision (1-liner):**
Kafka Connect streams data between external systems and Kafka via source/sink connectors with lightweight SMTs for per-record transforms; Debezium is a CDC source connector that reads database binary logs to produce low-latency change events.

---

### Topic 10: Schema Registry & Avro
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Confluent, LinkedIn, Goldman Sachs

**Q: How does Confluent Schema Registry work with Avro serialization, and what are the schema evolution compatibility modes (backward, forward, full)?**

**Short Answer (2-3 sentences):**
Confluent Schema Registry stores Avro (or Protobuf/JSON Schema) schemas indexed by subject (topic name + "-value" or "-key"); producers register schemas and embed a 5-byte magic header (magic byte + schema ID) in each serialized record, while consumers retrieve the schema by ID for deserialization. Schema evolution compatibility ensures producers and consumers can be deployed independently: backward compatibility means new readers can read old records, forward compatibility means old readers can read new records, and full compatibility is both. Log compaction ensures schema registry subjects are durably stored in Kafka itself.

**Deep Explanation:**
**Wire Format:**
Each Kafka message serialized with KafkaAvroSerializer has the format:
```
[Magic Byte: 0x00] [Schema ID: 4 bytes big-endian] [Avro Binary Data]
```
Consumers call `GET /subjects/{subject}/versions/{id}` (cached locally) to retrieve the schema for deserialization.

**Subject Naming Strategies:**
- `TopicNameStrategy` (default): Subject = `{topic}-value` or `{topic}-key`. One schema per topic.
- `RecordNameStrategy`: Subject = fully qualified record name. Multiple record types per topic.
- `TopicRecordNameStrategy`: Subject = `{topic}-{recordName}`. Scoped per topic per type.

**Schema Evolution Rules:**
**Backward Compatible** (default): New schema can read data written with old schema.
- OK: Add optional field with default.
- NOT OK: Remove a required field, change a field type incompatibly.

**Forward Compatible**: Old schema can read data written with new schema.
- OK: Remove an optional field (old reader ignores the removed field).
- NOT OK: Add a required field without default (old reader can't read the new record).

**Full Compatible**: Both backward AND forward compatible.
- Only safe change: Add/remove optional fields with defaults.

**Avro Schema Example:**
```json
// v1
{ "type": "record", "name": "Order", "fields": [
  { "name": "id",     "type": "string" },
  { "name": "amount", "type": "double" }
]}

// v2 — backward compatible: adds optional field with default
{ "type": "record", "name": "Order", "fields": [
  { "name": "id",       "type": "string" },
  { "name": "amount",   "type": "double" },
  { "name": "currency", "type": "string", "default": "USD" }
]}
```

**Schema Registry HA:**
Schema Registry is stateless (schemas stored in `_schemas` Kafka topic with log compaction); multiple instances can be run for HA, with one designated as the primary writer.

**Real-World Example:**
LinkedIn's data pipeline uses Avro with Schema Registry for all internal events. When the Order service adds a `customerId` field (backward compatible), existing consumers (Elasticsearch sink, audit service) continue to work without redeployment — they read the old schema and `customerId` is absent in historical data.

**Code Example:**
```java
// Spring Boot 3.x + spring-kafka + confluent avro serializer
// pom.xml dependencies:
// io.confluent:kafka-avro-serializer:7.5.0
// org.apache.avro:avro:1.11.3

// Generated Avro class (from schema)
// src/main/avro/Order.avsc → compiled to com.example.avro.Order

import io.confluent.kafka.serializers.KafkaAvroDeserializer;
import io.confluent.kafka.serializers.KafkaAvroDeserializerConfig;
import io.confluent.kafka.serializers.KafkaAvroSerializer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.*;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class AvroKafkaConfig {

    private static final String SCHEMA_REGISTRY_URL = "http://schema-registry:8081";

    @Bean
    public ProducerFactory<String, Object> avroProducerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class);
        props.put("schema.registry.url", SCHEMA_REGISTRY_URL);
        props.put("auto.register.schemas", true);
        return new DefaultKafkaProducerFactory<>(props);
    }

    @Bean
    public KafkaTemplate<String, Object> avroKafkaTemplate(ProducerFactory<String, Object> pf) {
        return new KafkaTemplate<>(pf);
    }

    @Bean
    public ConsumerFactory<String, Object> avroConsumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "order-avro-group");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class);
        props.put("schema.registry.url", SCHEMA_REGISTRY_URL);
        // Return the specific generated type, not GenericRecord
        props.put(KafkaAvroDeserializerConfig.SPECIFIC_AVRO_READER_CONFIG, true);
        return new DefaultKafkaConsumerFactory<>(props);
    }
}

// Producer usage with generated Avro class
import com.example.avro.Order;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class AvroOrderProducer {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    public AvroOrderProducer(KafkaTemplate<String, Object> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void sendOrder(String orderId, double amount) {
        Order order = Order.newBuilder()
            .setId(orderId)
            .setAmount(amount)
            .setCurrency("USD") // new field with default
            .build();
        kafkaTemplate.send("orders-avro", orderId, order);
    }
}
```

**Follow-up Questions:**
1. What happens if a producer tries to register a schema that is not backward compatible with the existing schema?
2. How does Protobuf compare to Avro for Kafka schema evolution — what are the trade-offs?
3. What is the `TRANSITIVE` compatibility mode and when would you use it?

**Common Mistakes:**
- Setting `auto.register.schemas=true` in production — schema registration should be part of CI/CD, not runtime, to prevent accidental incompatible schema registration.
- Using `TopicNameStrategy` with multiple record types in one topic — each new record type overwrites the subject, causing deserialization failures.
- Removing a field without a default (backward-incompatible) and assuming it works because no consumers are currently deployed — future consumers reading old data will fail.

**Interview Traps:**
- "What is the difference between backward and forward compatibility from the consumer's perspective?" — Backward: NEW consumer can read OLD data (add fields with defaults). Forward: OLD consumer can read NEW data (remove fields). Most people get these backwards.
- "Does Schema Registry store schemas in Zookeeper?" — No. Schemas are stored in a Kafka topic (`_schemas`) with log compaction. Schema Registry itself is a REST service that is stateless and can run without Zookeeper.

**Quick Revision (1-liner):**
Schema Registry stores Avro schemas by subject and embeds a 4-byte schema ID in each message; backward compatibility (new reader + old data) is the default, requiring new optional fields to have defaults, while forward allows old readers to skip unknown fields.

---

### Topic 11: Kafka in Spring Boot
**Difficulty:** Medium | **Frequency:** High | **Companies:** Goldman Sachs, Confluent, Uber, Netflix

**Q: How do you implement a production-grade @KafkaListener in Spring Boot 3.x with manual commit, error handling, dead-letter topics, and retry logic?**

**Short Answer (2-3 sentences):**
Spring Kafka's `@KafkaListener` runs inside a `ConcurrentMessageListenerContainer` that manages consumer threads, polling, and offset commit lifecycle. For production use, manual acknowledgment mode (`AckMode.MANUAL_IMMEDIATE`) combined with a `DefaultErrorHandler` (formerly `SeekToCurrentErrorHandler`) enables configurable retry with backoff, and a `DeadLetterPublishingRecoverer` routes exhausted records to a dead-letter topic (DLT) rather than silently dropping them. The `@RetryableTopic` annotation (since Spring Kafka 2.7) provides non-blocking retry via dedicated retry topics.

**Deep Explanation:**
**AckMode Options:**
- `RECORD`: Commit after each record is processed (highest safety, lowest throughput).
- `BATCH`: Commit after all records from a `poll()` batch are processed.
- `MANUAL_IMMEDIATE`: Application calls `ack.acknowledge()` — commit happens immediately.
- `MANUAL`: Application calls `ack.acknowledge()` — commit happens on next `poll()`.
- `COUNT`: Commit after N records.
- `TIME`: Commit every T milliseconds.

**DefaultErrorHandler (Spring Kafka 2.8+):**
Replaces the deprecated `SeekToCurrentErrorHandler`. On exception, seeks the failed record's offset back and retries after a configurable `BackOff`. After exhausting retries, calls the `RecoveryCallback` (e.g., send to DLT).

**Non-Blocking Retry with @RetryableTopic:**
Instead of blocking the consumer thread during retry waits, `@RetryableTopic` creates retry topics (`topic.name-retry-1`, `topic.name-retry-2`, ...) and a DLT (`topic.name-dlt`). Failed records are re-published to retry topics with delay headers, processed by dedicated retry consumers after the delay expires. The main consumer thread is never blocked.

**Dead Letter Topic (DLT) Pattern:**
Records that fail all retries are sent to `{topic}-dlt` with headers containing the original topic, partition, offset, exception class, and message. A separate DLT consumer logs, alerts, or manually reprocesses these records.

**Real-World Example:**
Netflix payment notification service uses `@RetryableTopic` with 3 retry attempts (1s, 5s, 30s exponential backoff) and a DLT consumer that raises a PagerDuty alert and stores failed messages in S3 for manual reprocessing.

**Code Example:**
```java
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.common.TopicPartition;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.DltHandler;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.annotation.RetryableTopic;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.listener.*;
import org.springframework.kafka.retrytopic.TopicSuffixingStrategy;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.retry.annotation.Backoff;
import org.springframework.stereotype.Service;
import org.springframework.util.backoff.FixedBackOff;

// ---- Configuration ----
@Configuration
public class KafkaErrorHandlerConfig {

    @Bean
    public DefaultErrorHandler errorHandler(KafkaTemplate<Object, Object> kafkaTemplate) {
        // Send to DLT after 3 attempts with 1-second fixed backoff
        DeadLetterPublishingRecoverer recoverer =
            new DeadLetterPublishingRecoverer(kafkaTemplate,
                (record, ex) -> new TopicPartition(
                    record.topic() + "-dlt",
                    record.partition()
                )
            );

        DefaultErrorHandler handler = new DefaultErrorHandler(
            recoverer,
            new FixedBackOff(1000L, 3L) // 1s interval, 3 retries
        );

        // Do not retry on deserialization or business logic validation errors
        handler.addNotRetryableExceptions(
            org.apache.kafka.common.errors.SerializationException.class,
            IllegalArgumentException.class
        );

        return handler;
    }
}

// ---- Service with manual commit + traditional error handler ----
@Service
public class PaymentConsumer {

    private static final org.slf4j.Logger log =
        org.slf4j.LoggerFactory.getLogger(PaymentConsumer.class);

    private final PaymentService paymentService;

    public PaymentConsumer(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @KafkaListener(
        topics = "payment-events",
        groupId = "payment-consumer-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {
        log.info("Processing payment: topic={} partition={} offset={} key={}",
            record.topic(), record.partition(), record.offset(), record.key());
        try {
            paymentService.process(record.key(), record.value());
            ack.acknowledge(); // Manual commit AFTER successful processing
        } catch (RuntimeException e) {
            log.error("Payment processing failed for key={}: {}", record.key(), e.getMessage());
            // Do NOT acknowledge — DefaultErrorHandler will retry, then DLT
            throw e;
        }
    }
}

// ---- Non-Blocking Retry with @RetryableTopic ----
@Service
public class NotificationConsumer {

    private static final org.slf4j.Logger log =
        org.slf4j.LoggerFactory.getLogger(NotificationConsumer.class);

    @RetryableTopic(
        attempts = "4",                    // 1 original + 3 retries
        backoff = @Backoff(
            delay = 1000,
            multiplier = 2.0,
            maxDelay = 30000
        ),
        topicSuffixingStrategy = TopicSuffixingStrategy.SUFFIX_WITH_INDEX_VALUE,
        dltTopicSuffix = "-dlt",
        include = {RuntimeException.class}
    )
    @KafkaListener(
        topics = "notification-events",
        groupId = "notification-group"
    )
    public void consume(ConsumerRecord<String, String> record) {
        log.info("Processing notification for key={}", record.key());
        // If this throws, Spring Kafka routes to retry-1 topic after 1s
        // then retry-2 after 2s, retry-3 after 4s, then DLT
        sendNotification(record.value());
    }

    @DltHandler
    public void handleDlt(ConsumerRecord<String, String> record) {
        log.error("Notification failed permanently. key={} value={} topic={}",
            record.key(), record.value(), record.topic());
        // Alert, store to S3, raise incident
    }

    private void sendNotification(String value) {
        // business logic that may throw
    }
}
```

**Follow-up Questions:**
1. What is the difference between `SeekToCurrentErrorHandler` (deprecated) and `DefaultErrorHandler`?
2. How does `@RetryableTopic` differ from `DefaultErrorHandler` with `DeadLetterPublishingRecoverer` in terms of consumer thread blocking?
3. What happens to consumer lag metrics during non-blocking retry — do retry topics count against the group lag?

**Common Mistakes:**
- Catching and swallowing exceptions inside the `@KafkaListener` method — this prevents the error handler from retrying and causes silent message loss.
- Using `AckMode.BATCH` with `@RetryableTopic` — manual ack is not needed with non-blocking retry; mixing them causes unexpected behavior.
- Not setting `spring.kafka.consumer.properties.isolation.level=read_committed` when consuming from transactional topics — consumers see aborted records.

**Interview Traps:**
- "Does `@KafkaListener` create one consumer per annotation?" — It creates one `MessageListenerContainer`. The concurrency (threads/consumers) is set by `factory.setConcurrency(N)` or `@KafkaListener(concurrency="3")`. Each thread is an independent Kafka consumer with its own poll loop.
- "What happens if `ack.acknowledge()` is never called?" — The offset is never committed. After a restart or rebalance, the record is redelivered. This is at-least-once behavior, not a hang or error in itself.

**Quick Revision (1-liner):**
In Spring Boot, use `AckMode.MANUAL_IMMEDIATE` with `@KafkaListener` for at-least-once semantics, `DefaultErrorHandler` with `DeadLetterPublishingRecoverer` for blocking retry, or `@RetryableTopic` for non-blocking retry via dedicated retry topics.

---

### Topic 12: Retention & Compaction
**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Confluent, LinkedIn

**Q: How do time-based and size-based retention policies work, and when should you use log compaction instead of deletion?**

**Short Answer (2-3 sentences):**
Kafka supports two deletion-based retention policies: time-based (`log.retention.ms`, default 7 days) which deletes segments older than the configured duration, and size-based (`log.retention.bytes`, default -1 unlimited) which deletes oldest segments when the partition log exceeds the configured size. Log compaction (`log.cleanup.policy=compact`) is an alternative that retains the latest value per key indefinitely, making it ideal for changelog-style topics where consumers need the current state, not event history.

**Deep Explanation:**
**Segment-Level Deletion:**
Retention operates at the segment level, not per-record. A segment is eligible for deletion only when its largest timestamp (or oldest offset) is beyond the retention threshold AND it is not the active (current) segment. This means recent data in the last segment is always retained even if older than `log.retention.ms`.

**Time-Based Retention:**
`log.retention.ms` = `log.retention.minutes` × 60000. Kafka checks `LogSegment.largestTimestamp`. If the segment's newest record is older than the retention window, the whole segment is deleted.

**Size-Based Retention:**
`log.retention.bytes` is per-partition (not per-topic). When total partition size exceeds this, oldest segments are deleted one by one until under the limit.

**Combined Retention:**
Set both; whichever threshold is hit first triggers deletion. This is the recommended production approach for bounded storage with a time-based safety net.

**Log Compaction Internals:**
The Log Cleaner thread (background) divides the log into:
- **Clean** portion: Already compacted; only latest values.
- **Dirty** portion: Not yet compacted; may have multiple values per key.

The cleaner picks partitions where `dirtyRatio = dirty_bytes / total_bytes > min.cleanable.dirty.ratio` (default 0.5). It reads the dirty portion, builds an offset map (key → latest offset), then copies only the latest record per key into new segments, discarding older duplicates.

**Tombstone Records:**
A record with a null value is a tombstone — it marks a key for deletion. Tombstones are retained for `delete.retention.ms` (default 24h) before the cleaner physically removes them, giving consumers time to see the delete event.

**When to Use Compaction vs Deletion:**
| Use Case | Policy |
|---|---|
| Event log (analytics, audit) | Deletion (time or size) |
| Current state (user profile, account balance) | Compaction |
| Kafka Streams state store changelog | Compaction |
| Consumer offset commits (`__consumer_offsets`) | Compaction |
| Mixed (keep recent events + latest state) | `compact,delete` |

**Real-World Example:**
LinkedIn's user-profile topic uses `compact,delete` policy: compaction ensures only the latest profile per `memberId` is kept long-term, while deletion ensures profiles for deleted members (tombstones) are eventually removed after 30 days.

**Code Example:**
```java
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.config.TopicConfig;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class RetentionTopicConfig {

    // Standard deletion: 3 days or 10 GB per partition, whichever first
    @Bean
    public NewTopic analyticsEventsTopic() {
        return TopicBuilder.name("analytics-events")
            .partitions(12)
            .replicas(3)
            .config(TopicConfig.CLEANUP_POLICY_CONFIG, "delete")
            .config(TopicConfig.RETENTION_MS_CONFIG, String.valueOf(3 * 24 * 60 * 60 * 1000L))
            .config(TopicConfig.RETENTION_BYTES_CONFIG, String.valueOf(10L * 1024 * 1024 * 1024))
            .config(TopicConfig.SEGMENT_BYTES_CONFIG, String.valueOf(512 * 1024 * 1024)) // 512MB segments
            .build();
    }

    // Compacted changelog for user state
    @Bean
    public NewTopic userStateTopic() {
        return TopicBuilder.name("user-state")
            .partitions(24)
            .replicas(3)
            .compact()
            // Also delete tombstones after 48h
            .config(TopicConfig.DELETE_RETENTION_MS_CONFIG, String.valueOf(48 * 60 * 60 * 1000L))
            .config(TopicConfig.MIN_CLEANABLE_DIRTY_RATIO_CONFIG, "0.3") // more aggressive cleaning
            .config(TopicConfig.SEGMENT_MS_CONFIG, String.valueOf(60 * 60 * 1000L)) // 1h segments
            .build();
    }

    // Mixed policy: keep latest state + delete old records
    @Bean
    public NewTopic accountBalanceTopic() {
        return TopicBuilder.name("account-balance")
            .partitions(12)
            .replicas(3)
            .config(TopicConfig.CLEANUP_POLICY_CONFIG, "compact,delete")
            .config(TopicConfig.RETENTION_MS_CONFIG, String.valueOf(30L * 24 * 60 * 60 * 1000L)) // 30 days
            .compact()
            .build();
    }
}
```

**Follow-up Questions:**
1. What is the impact of very small `segment.bytes` on log compaction performance and broker I/O?
2. How does log compaction handle records with null keys — are they compacted?
3. What is `min.compaction.lag.ms` and why is it useful for changelog topics?

**Common Mistakes:**
- Expecting log compaction to be real-time — the cleaner runs in the background and may lag minutes to hours behind. Do not rely on compaction for immediate storage reduction.
- Using compaction on topics without keys — records with null keys are never compacted (compaction is key-based). All null-key records accumulate until the active segment rolls.
- Forgetting that compaction still preserves one record per key in the dirty portion, not just the single global latest — intermediate records in the clean portion may still exist until the next clean cycle.

**Interview Traps:**
- "Does log compaction guarantee only one record per key on the topic?" — No. It guarantees consumers will see the latest value eventually, but multiple records per key may exist until compaction catches up on the dirty portion.
- "Can you run both compaction and deletion simultaneously?" — Yes, `cleanup.policy=compact,delete` is a valid combined policy. Compaction runs on the clean portion while old segments are deleted by retention.

**Quick Revision (1-liner):**
Time-based and size-based retention delete entire segments past the threshold; log compaction retains only the latest value per key (with null-value tombstones for deletes) and is the right choice for changelog, state, and offset topics.

---

### Topic 13: Kafka vs RabbitMQ vs SQS
**Difficulty:** Easy | **Frequency:** High | **Companies:** Goldman Sachs, Netflix, Uber, LinkedIn

**Q: Compare Apache Kafka, RabbitMQ, and Amazon SQS — when would you choose each, and what are their fundamental architectural differences?**

**Short Answer (2-3 sentences):**
Kafka is a distributed commit-log optimized for high-throughput, durable, replayable event streaming where multiple consumers can read the same data independently. RabbitMQ is a traditional message broker with push-based delivery, rich routing (exchanges/queues/bindings), and per-message acknowledgment, suited for task queues and complex routing. SQS is a fully managed AWS queue service optimized for decoupling microservices with minimal operational overhead, offering at-least-once delivery (standard) or FIFO ordering, but without log replay or multi-consumer fan-out without SNS.

**Deep Explanation:**

| Dimension | Apache Kafka | RabbitMQ | Amazon SQS |
|---|---|---|---|
| **Model** | Distributed commit log (pull) | Message broker (push) | Managed queue (pull) |
| **Throughput** | Millions msg/s per cluster | ~50k msg/s typical | ~3000 msg/s (FIFO), unlimited (Standard) |
| **Retention** | Configurable (default 7 days) | Until consumed | Up to 14 days |
| **Replay** | Yes — consumers re-read at any offset | No — consumed messages deleted | No |
| **Consumer Model** | Pull; consumer groups | Push; competing consumers | Pull; competing consumers |
| **Ordering** | Per-partition ordering | Per-queue (with limitations) | FIFO queue: per MessageGroupId |
| **Fan-out** | Multiple independent consumer groups | Exchange bindings (fanout exchange) | Requires SNS → multiple SQS queues |
| **Latency** | ~5–50 ms (batched) | ~1–5 ms | ~10–100 ms |
| **Durability** | Replication factor (default 3) | Mirrored queues / quorum queues | Multi-AZ replicated |
| **Operational Complexity** | High (cluster management, tuning) | Medium (plugin ecosystem) | Low (fully managed) |
| **Schema** | Via Schema Registry | Application-level | Application-level |
| **Protocol** | Custom (Kafka protocol) | AMQP, MQTT, STOMP | SQS API (HTTP) |
| **Dead Letter** | Via custom DLT topics | Built-in dead-letter exchange | Built-in DLQ |
| **Exactly-Once** | Yes (with transactions) | No (at-least-once) | No (at-least-once / FIFO deduplication) |

**When to Choose Kafka:**
- Event streaming with replay requirements (audit logs, event sourcing).
- Multiple independent consumers on the same data stream.
- High-throughput pipelines (>100k msg/s).
- Kafka Streams or ksqlDB for stream processing.
- Long-term event retention.

**When to Choose RabbitMQ:**
- Complex routing logic (topic exchanges, header exchanges).
- Task queues with worker pools (competing consumers pattern).
- Push-based delivery with per-message acknowledgment.
- Low latency (<5 ms) requirements.
- Protocol flexibility (AMQP, MQTT for IoT).

**When to Choose SQS:**
- AWS-native architecture; operational simplicity is paramount.
- Decoupling microservices with standard queue semantics.
- FIFO ordering with exactly-once processing (SQS FIFO + deduplication ID).
- Lambda triggers (native integration).
- No expertise to operate Kafka/RabbitMQ.

**Real-World Example:**
Uber uses Kafka for rider event streaming (millions of GPS updates/second with replay for ML training), RabbitMQ for driver dispatch task queues (push-based, complex routing by city/vehicle type), and SQS for non-critical notification delivery (billing receipts, emails) where managed infrastructure reduces operational load.

**Code Example:**
```java
// Spring Boot: Kafka vs SQS consumer side-by-side comparison

// Kafka consumer (spring-kafka)
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class KafkaOrderConsumer {
    @KafkaListener(topics = "order-events", groupId = "order-group")
    public void consume(String message) {
        System.out.println("Kafka: " + message);
        // Kafka retains the record for retention period
        // Other consumer groups can independently read the same record
    }
}

// SQS consumer (spring-cloud-aws)
import io.awspring.cloud.sqs.annotation.SqsListener;

@Service
public class SqsOrderConsumer {
    @SqsListener("order-events-queue")
    public void consume(String message) {
        System.out.println("SQS: " + message);
        // Message is deleted from SQS after successful processing
        // No replay — once consumed, gone
    }
}

// RabbitMQ consumer (spring-amqp)
import org.springframework.amqp.rabbit.annotation.RabbitListener;

@Service
public class RabbitOrderConsumer {
    @RabbitListener(queues = "order.events")
    public void consume(String message) {
        System.out.println("RabbitMQ: " + message);
        // Push-based; broker delivers to consumer
        // Message acknowledged and removed after processing
    }
}
```

**Follow-up Questions:**
1. How would you migrate a RabbitMQ task queue workload to Kafka — what architectural changes are required?
2. In an AWS-native microservices architecture, when would you choose MSK (managed Kafka) over SQS?
3. How does SQS FIFO's `MessageGroupId` compare to Kafka's partition key for ordering?

**Common Mistakes:**
- Using Kafka for simple point-to-point task queues where RabbitMQ or SQS is simpler and more appropriate.
- Expecting RabbitMQ to replay messages — once a message is consumed and acknowledged, it is gone.
- Confusing SQS Standard (at-least-once, no ordering) with SQS FIFO (exactly-once within a group, ordered per MessageGroupId).

**Interview Traps:**
- "Is Kafka always better than RabbitMQ because it has higher throughput?" — No. For task queues needing push delivery, per-message ACK, or complex routing, RabbitMQ is simpler and more appropriate. Kafka's throughput advantage only matters at scale.
- "Does SQS guarantee exactly-once delivery?" — SQS Standard: no, at-least-once. SQS FIFO: yes, with deduplication IDs within a 5-minute window. But FIFO throughput is limited.

**Quick Revision (1-liner):**
Choose Kafka for high-throughput, replayable, multi-consumer event streams; RabbitMQ for complex routing, push delivery, and task queues; SQS for AWS-native simplicity with minimal operational overhead.

---

### Topic 14: Replication & Fault Tolerance
**Difficulty:** Hard | **Frequency:** High | **Companies:** Confluent, LinkedIn, Goldman Sachs, Netflix

**Q: Explain Kafka's ISR (In-Sync Replicas), leader election, unclean leader election, and the min.insync.replicas configuration for fault-tolerant cluster design.**

**Short Answer (2-3 sentences):**
The ISR (In-Sync Replicas) set contains the leader and all followers that are caught up within `replica.lag.time.max.ms` (default 30s). When the leader fails, the Kafka controller elects a new leader from the ISR, guaranteeing no data loss. Unclean leader election (`unclean.leader.election.enable=true`) allows out-of-ISR replicas to become leader, trading durability for availability; `min.insync.replicas` (combined with `acks=all`) rejects producer writes when fewer than the configured number of replicas are in-sync, preventing data loss at the cost of write availability.

**Deep Explanation:**
**ISR Mechanics:**
Each partition has one leader and N-1 followers (N = replication factor). Followers fetch from the leader and update their High Watermark (HW). A follower is in the ISR if it has fetched up to the leader's log-end offset within `replica.lag.time.max.ms`. If a follower falls behind (slow I/O, GC pause, network issue), it is removed from the ISR and the leader proceeds without it.

**High Watermark (HW) vs Log End Offset (LEO):**
- **LEO**: The next offset the leader will assign. Advances with every appended record.
- **HW**: The highest offset that has been replicated to all ISR members. Consumers can only read up to HW (ensuring read-your-writes consistency after leader election).

**Leader Election:**
The Kafka Controller (one broker elected via Zookeeper/KRaft) watches for leader failures. On failure:
1. Controller selects the first ISR member as the new leader (preferred: the replica with the highest LEO).
2. Broadcasts new leader metadata to all brokers and clients.
3. Old leader's uncommitted records (above old HW) are truncated by new leader after fencing.

**KRaft Mode (Kafka 3.3+ production-ready):**
Zookeeper replaced by an internal Raft consensus group (`@metadata` topic). The KRaft controller quorum manages metadata without external Zookeeper dependency. Faster failover (<10s vs 30s+) and simpler operations.

**Unclean Leader Election:**
`unclean.leader.election.enable=true` (default false in newer Kafka, true in older):
- Allows replicas NOT in the ISR to become leader when all ISR replicas are unavailable.
- Trades **durability for availability**: records between the old HW and the failed leader's LEO are permanently lost.
- Use case: log aggregation pipelines where some data loss is acceptable vs. complete unavailability.

**min.insync.replicas (minISR):**
With `acks=all`, the leader waits for all ISR members to acknowledge. `min.insync.replicas=2` (broker/topic config) rejects writes with `NotEnoughReplicasException` if ISR size drops below 2.

**Recommended Production Configuration:**
- `replication.factor=3`
- `min.insync.replicas=2`
- `acks=all` (producer)
- `unclean.leader.election.enable=false`

This tolerates 1 broker failure without data loss or write unavailability. 2 simultaneous broker failures → write unavailability (ISR < minISR), but no data loss.

**Real-World Example:**
Goldman Sachs trade topics use `replication.factor=3`, `min.insync.replicas=2`, and `unclean.leader.election.enable=false`. During a broker failure, writes block until the failed broker recovers or a new broker joins the ISR — acceptable for financial data correctness. Analytics topics use `unclean.leader.election.enable=true` to maintain write availability during broker failures.

**Code Example:**
```java
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.config.TopicConfig;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class FaultTolerantTopicConfig {

    // Financial data: durability over availability
    @Bean
    public NewTopic tradeEventsTopic() {
        return TopicBuilder.name("trade-events")
            .partitions(12)
            .replicas(3)
            .config(TopicConfig.MIN_IN_SYNC_REPLICAS_CONFIG, "2")
            .config(TopicConfig.UNCLEAN_LEADER_ELECTION_ENABLE_CONFIG, "false")
            .build();
    }

    // Analytics data: availability over durability
    @Bean
    public NewTopic clickEventsTopic() {
        return TopicBuilder.name("click-events")
            .partitions(24)
            .replicas(3)
            .config(TopicConfig.MIN_IN_SYNC_REPLICAS_CONFIG, "1")
            .config(TopicConfig.UNCLEAN_LEADER_ELECTION_ENABLE_CONFIG, "true")
            .build();
    }
}

// Monitoring ISR health programmatically
import org.apache.kafka.clients.admin.*;
import org.apache.kafka.common.TopicPartitionInfo;

import java.util.*;
import java.util.concurrent.ExecutionException;

public class IsrHealthChecker {

    private final AdminClient adminClient;

    public IsrHealthChecker(String bootstrapServers) {
        Properties props = new Properties();
        props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        this.adminClient = AdminClient.create(props);
    }

    public void checkIsrHealth(String topicName) throws ExecutionException, InterruptedException {
        DescribeTopicsResult result = adminClient.describeTopics(List.of(topicName));
        TopicDescription description = result.allTopicNames().get().get(topicName);

        for (TopicPartitionInfo partition : description.partitions()) {
            int isrSize = partition.isr().size();
            int replicaCount = partition.replicas().size();

            if (isrSize < replicaCount) {
                System.out.printf("WARNING: Partition %d ISR=%d of %d replicas — under-replicated!%n",
                    partition.partition(), isrSize, replicaCount);
            }
            if (partition.leader() == null) {
                System.out.printf("CRITICAL: Partition %d has no leader!%n", partition.partition());
            }
        }
    }
}
```

**Follow-up Questions:**
1. What happens to in-flight producer records when a leader election occurs mid-batch?
2. How does the preferred replica election differ from unclean leader election?
3. What is the `controlled.shutdown.enable` broker config and how does it reduce failover impact?

**Common Mistakes:**
- Setting `min.insync.replicas=replication.factor` — this means ANY broker failure makes the topic read-only (all writes fail). Always keep minISR at least 1 less than replication factor.
- Confusing `acks=all` on the producer with `min.insync.replicas` on the broker — both must be set together. `acks=all` alone only waits for all current ISR members, not a minimum count.
- Running with `replication.factor=1` in development/staging and forgetting to change it for production — no fault tolerance at all.

**Interview Traps:**
- "Is High Watermark the same as the committed offset?" — No. HW is a broker-side concept for replication: the offset up to which all ISR replicas have confirmed. Consumer committed offsets are stored in `__consumer_offsets`. These are independent concepts.
- "Does Kafka guarantee no data loss with `acks=all`?" — Only if `unclean.leader.election.enable=false`. If clean leader election is allowed but all ISR replicas fail simultaneously, and an out-of-ISR replica (with stale data) is elected, records acknowledged since the last replication will be lost.

**Quick Revision (1-liner):**
ISR tracks replicas within `replica.lag.time.max.ms` of the leader; `min.insync.replicas=2` with `acks=all` and `unclean.leader.election=false` is the production durability standard, tolerating 1 broker failure without data loss.

---

### Topic 15: Kafka Performance Tuning
**Difficulty:** Hard | **Frequency:** Medium | **Companies:** LinkedIn, Confluent, Uber, Netflix

**Q: What are the key tuning parameters for maximizing Kafka producer throughput, consumer throughput, and broker efficiency?**

**Short Answer (2-3 sentences):**
Producer throughput is maximized by increasing batch size and linger time, enabling compression, and tuning `max.in.flight.requests`. Consumer throughput scales via concurrency, larger `fetch.min.bytes` / `max.poll.records`, and parallel processing with thread pools. Broker efficiency relies on OS page cache (linear reads/writes), appropriate heap sizing (keep small to reduce GC), `num.io.threads` and `num.network.threads` tuning, and avoiding swapping with `vm.swappiness=1`.

**Deep Explanation:**
**Producer Throughput Tuning:**
| Config | Default | Tuning Recommendation |
|---|---|---|
| `batch.size` | 16384 (16KB) | 65536–262144 (64–256KB) for bulk |
| `linger.ms` | 0 | 5–50 ms for batching |
| `compression.type` | none | lz4 or zstd for 3-5x throughput |
| `buffer.memory` | 33554432 (32MB) | 128MB+ for high-throughput |
| `max.in.flight.requests.per.connection` | 5 | Keep 5 with idempotence; 1 for strict ordering without idempotence |
| `acks` | 1 | `all` for durability; `1` for non-critical high-throughput |
| `retries` | 2147483647 | INT_MAX with idempotence |

**Consumer Throughput Tuning:**
| Config | Default | Tuning Recommendation |
|---|---|---|
| `max.poll.records` | 500 | 1000–5000 for bulk processing |
| `fetch.min.bytes` | 1 | 1048576 (1MB) for throughput |
| `fetch.max.wait.ms` | 500 | 500ms (default is reasonable) |
| `max.partition.fetch.bytes` | 1048576 (1MB) | 4MB+ for large messages |
| `session.timeout.ms` | 45000 | 45–120s; larger for slow processing |
| `max.poll.interval.ms` | 300000 | Increase if processing is slow |

**Consumer-Side Parallelism:**
For CPU-bound processing, add threads using `ConcurrentKafkaListenerContainerFactory.setConcurrency(N)` — each thread is an independent consumer. For I/O-bound processing (DB writes, HTTP calls), use an `ExecutorService` within the listener to parallelize record processing within a batch.

**Broker Performance:**
1. **Page Cache**: Kafka is optimized for OS page cache. Give brokers 50–60% of RAM to the OS (not JVM heap). Default heap: 6 GB. Consumers reading recently produced data hit the page cache, not disk.
2. **JVM Heap**: Keep at 4–8 GB. Large heaps → long GC pauses → replication lag → ISR shrinkage. Use G1GC: `-XX:+UseG1GC -XX:MaxGCPauseMillis=20`.
3. **Disk**: Use separate disks for Kafka data and OS. Use JBOD (multiple `log.dirs`) for throughput. Avoid RAID (Kafka handles redundancy via replication). Use ext4 or XFS with `noatime` mount option.
4. **Network Threads**: `num.network.threads=8` (default 3); increase for high-connection-count clusters.
5. **I/O Threads**: `num.io.threads=16` (default 8); should be ~2× disk count for JBOD setups.
6. **OS Tuning**: `vm.swappiness=1`, `net.core.rmem_max=134217728`, `net.core.wmem_max=134217728`, `fs.file-max=100000`.

**Zero-Copy:**
Kafka uses `sendfile()` system call (Java NIO `FileChannel.transferTo()`) to send data from disk to network without copying through user space — critical for high-throughput consumer reads from disk. This is why avoiding encryption at the broker level (or using hardware TLS offload) matters for throughput.

**Real-World Example:**
LinkedIn tuned Kafka for peak throughput of 7 trillion messages/day. Key tunings: `linger.ms=5`, `batch.size=131072`, `compression.type=lz4`, 6-core machines with 128 GB RAM where 100 GB is left to OS page cache, 12 JBOD disks per broker, `num.network.threads=12`, `num.io.threads=24`.

**Code Example:**
```java
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.*;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executor;

@Configuration
public class KafkaHighThroughputConfig {

    // High-throughput producer configuration
    @Bean
    public ProducerFactory<String, String> highThroughputProducerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092,broker3:9092");
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,
            org.apache.kafka.common.serialization.StringSerializer.class);
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG,
            org.apache.kafka.common.serialization.StringSerializer.class);

        // Batching for throughput
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 131072);          // 128 KB batches
        props.put(ProducerConfig.LINGER_MS_CONFIG, 10);               // wait up to 10ms
        props.put(ProducerConfig.BUFFER_MEMORY_CONFIG, 134217728L);   // 128 MB buffer

        // Compression
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "lz4");

        // Durability
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 5);

        return new DefaultKafkaProducerFactory<>(props);
    }

    // High-throughput consumer configuration
    @Bean
    public ConsumerFactory<String, String> highThroughputConsumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092,broker3:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "high-throughput-group");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,
            org.apache.kafka.common.serialization.StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG,
            org.apache.kafka.common.serialization.StringDeserializer.class);

        // Fetch tuning
        props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 2000);
        props.put(ConsumerConfig.FETCH_MIN_BYTES_CONFIG, 1048576);       // wait for 1MB
        props.put(ConsumerConfig.FETCH_MAX_WAIT_MS_CONFIG, 500);
        props.put(ConsumerConfig.MAX_PARTITION_FETCH_BYTES_CONFIG, 4194304); // 4 MB

        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 60000);
        props.put(ConsumerConfig.MAX_POLL_INTERVAL_MS_CONFIG, 600000);

        return new DefaultKafkaConsumerFactory<>(props);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, String> highThroughputListenerFactory(
            ConsumerFactory<String, String> cf) {
        ConcurrentKafkaListenerContainerFactory<String, String> factory =
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(cf);
        factory.setConcurrency(6);  // 6 consumer threads per instance
        factory.setBatchListener(true);  // batch consumption
        factory.getContainerProperties().setAckMode(
            org.springframework.kafka.listener.ContainerProperties.AckMode.BATCH);
        return factory;
    }

    // Separate thread pool for async I/O within consumer
    @Bean
    public Executor consumerProcessingExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(20);
        executor.setMaxPoolSize(50);
        executor.setQueueCapacity(1000);
        executor.setThreadNamePrefix("kafka-processing-");
        executor.initialize();
        return executor;
    }
}
```

**Follow-up Questions:**
1. Why should Kafka broker JVM heap be kept small (4–8 GB) even on machines with 128 GB RAM?
2. What is the impact of enabling SSL/TLS on Kafka throughput, and how do you mitigate it?
3. How does the number of partitions affect producer and consumer throughput, and what are the limits?

**Common Mistakes:**
- Allocating most server RAM to JVM heap (-Xmx64g) — starves OS page cache, causing all reads to hit disk instead of memory.
- Setting `max.poll.records=1` for "safety" — eliminates batching, drastically reduces throughput, and increases overhead.
- Using synchronous `commitSync()` after every record in high-throughput scenarios — per-record commits to the `__consumer_offsets` topic create a throughput bottleneck.

**Interview Traps:**
- "Should you set `compression.type` on the broker or the producer?" — Both are possible. Producer-side compression is generally preferred because it reduces network I/O. Broker-side recompression (`compression.type != producer`) adds CPU overhead on the broker.
- "Does increasing partition count always improve throughput?" — Up to a point. Beyond ~4000 partitions per broker, the overhead of managing replicas, leader elections, and metadata updates degrades cluster performance. The real limit is broker CPU, I/O, and RAM — not a hard partition ceiling.

**Quick Revision (1-liner):**
Maximize producer throughput with larger batches, `linger.ms`, and compression; consumer throughput with concurrency and larger fetch sizes; broker efficiency by keeping heap small (4–8 GB) to maximize OS page cache for zero-copy reads.

---

## Cheat Sheet

### acks Settings & Delivery Guarantees

| acks | Meaning | Data Loss Risk | Throughput | Use Case |
|---|---|---|---|---|
| `0` | Fire and forget | High | Maximum | Metrics, logs (loss OK) |
| `1` | Leader ACK only | Medium (leader crash before replication) | High | Non-critical events |
| `all` / `-1` | All ISR ACK | Minimal (with minISR ≥ 2) | Lower | Financial, audit, critical data |

### Delivery Semantics

| Semantic | Producer Config | Consumer Config | Guarantee |
|---|---|---|---|
| At-most-once | Any | Commit before process | 0 or 1 delivery |
| At-least-once | `acks=all`, retries | Commit after process (manual) | 1+ delivery |
| Exactly-once | `enable.idempotence=true`, `transactional.id`, `acks=all` | `isolation.level=read_committed` | Exactly 1 delivery |

### Key Configuration Reference

#### Producer
| Config | Default | Recommended Production |
|---|---|---|
| `acks` | `1` | `all` |
| `enable.idempotence` | `false` | `true` |
| `compression.type` | `none` | `lz4` or `zstd` |
| `batch.size` | `16384` | `65536`–`262144` |
| `linger.ms` | `0` | `5`–`20` |
| `max.in.flight.requests.per.connection` | `5` | `5` (with idempotence) |
| `retries` | `2147483647` | `INT_MAX` |
| `delivery.timeout.ms` | `120000` | `120000`–`300000` |

#### Consumer
| Config | Default | Recommended Production |
|---|---|---|
| `enable.auto.commit` | `true` | `false` |
| `auto.offset.reset` | `latest` | `earliest` (new groups) |
| `max.poll.records` | `500` | `500`–`2000` |
| `fetch.min.bytes` | `1` | `1048576` (throughput) |
| `session.timeout.ms` | `45000` | `45000` |
| `max.poll.interval.ms` | `300000` | Tune per processing time |
| `isolation.level` | `read_uncommitted` | `read_committed` (transactions) |
| `partition.assignment.strategy` | `RangeAssignor` | `CooperativeStickyAssignor` |

#### Broker / Topic
| Config | Default | Notes |
|---|---|---|
| `replication.factor` | `1` | `3` in production |
| `min.insync.replicas` | `1` | `2` with RF=3 |
| `unclean.leader.election.enable` | `false` | Keep `false` for durability |
| `log.retention.ms` | `604800000` (7d) | Tune per data SLA |
| `log.segment.bytes` | `1073741824` (1GB) | `536870912` (512MB) for faster compaction |
| `num.partitions` | `1` | `max(throughput/10MB, consumers)` |
| `log.cleanup.policy` | `delete` | `compact` for changelog, `compact,delete` for mixed |

### Replication Quick Reference
```
RF=3, minISR=2, acks=all:
  - Tolerate 1 broker failure: writes continue (ISR=2 ≥ minISR=2)
  - Tolerate 2 broker failures: writes blocked (ISR=1 < minISR=2), no data loss
  - All 3 brokers fail: unavailable

unclean.leader.election=false → never lose acknowledged data
unclean.leader.election=true  → may lose data, always available
```

### Window Types at a Glance
```
Tumbling:  [0----5)[5----10)[10----15)   — non-overlapping, fixed size
Hopping:   [0--10)[5--15)[10--20)        — overlapping, fixed size, advance < size
Session:   [event...inactivity...event]  — dynamic, gap-based
```

### EOS Transaction Flow
```
initTransactions()
  beginTransaction()
    producer.send(record1)
    producer.send(record2)
    producer.sendOffsetsToTransaction(offsets, groupMetadata)
  commitTransaction()  ← atomic: all or nothing
```

### Common Kafka Port Reference
| Component | Default Port |
|---|---|
| Broker (plaintext) | `9092` |
| Broker (SSL) | `9093` |
| Broker (SASL) | `9094` |
| Schema Registry | `8081` |
| Kafka Connect REST | `8083` |
| KRaft Controller | `9093` |
| JMX | `9999` |

---

*End of Chapter 11: Apache Kafka & Event Streaming*

