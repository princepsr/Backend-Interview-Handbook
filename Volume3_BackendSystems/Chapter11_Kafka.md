# Volume 3: Backend Systems
# Chapter 11: Kafka

---

## Table of Contents

1. Kafka Core Concepts
2. Producers
3. Consumers and Consumer Groups
4. Offset Management
5. Kafka Delivery Guarantees
6. Partitioning Strategy
7. Consumer Lag and Monitoring
8. Kafka Streams
9. Kafka Connect
10. Schema Registry and Avro
11. Kafka in Spring Boot
12. Retention and Log Compaction
13. Kafka vs RabbitMQ vs SQS
14. Replication and Fault Tolerance
15. Kafka Performance Tuning

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Kafka Core Concepts

<svg viewBox="0 0 760 340" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" style="width:100%; max-width:760px; display:block; margin:16px 0;">
  <defs>
    <style>
      /* ── Fonts &amp; base ── */
      text { font-family: 'Courier New', monospace; fill: #e2e8f0; }
      /* ── Producer pulse ── */
      @keyframes producerPulse {
        0%, 100% { opacity: 1; }
        50%       { opacity: 0.7; }
      }
      /* ── Message block: P0 ── */
      @keyframes msgP0 {
        0%         { transform: translateX(-60px); opacity: 0; }
        8%         { transform: translateX(0);     opacity: 1; }
        45%        { transform: translateX(0);     opacity: 1; }
        55%        { transform: translateX(0);     opacity: 0; }
        100%       { transform: translateX(0);     opacity: 0; }
      }
      /* ── Message block: P1 ── */
      @keyframes msgP1 {
        0%,  18%   { transform: translateX(-60px); opacity: 0; }
        26%        { transform: translateX(0);     opacity: 1; }
        55%        { transform: translateX(0);     opacity: 1; }
        65%        { transform: translateX(0);     opacity: 0; }
        100%       { transform: translateX(0);     opacity: 0; }
      }
      /* ── Message block: P2 ── */
      @keyframes msgP2 {
        0%,  34%   { transform: translateX(-60px); opacity: 0; }
        42%        { transform: translateX(0);     opacity: 1; }
        70%        { transform: translateX(0);     opacity: 1; }
        80%        { transform: translateX(0);     opacity: 0; }
        100%       { transform: translateX(0);     opacity: 0; }
      }
      /* ── Offset counter flash ── */
      @keyframes offsetP0 {
        0%,  7%   { opacity: 0; }
        8%,  54%  { opacity: 1; }
        55%, 100% { opacity: 0; }
      }
      @keyframes offsetP1 {
        0%,  25%  { opacity: 0; }
        26%, 64%  { opacity: 1; }
        65%, 100% { opacity: 0; }
      }
      @keyframes offsetP2 {
        0%,  41%  { opacity: 0; }
        42%, 79%  { opacity: 1; }
        80%, 100% { opacity: 0; }
      }
      /* ── Consumer pull arrows ── */
      @keyframes arrowP0 {
        0%,  44%  { stroke-dashoffset: 80; opacity: 0; }
        46%        { opacity: 1; }
        55%        { stroke-dashoffset: 0; opacity: 1; }
        62%        { opacity: 0; }
        100%       { stroke-dashoffset: 80; opacity: 0; }
      }
      @keyframes arrowP1 {
        0%,  62%  { stroke-dashoffset: 80; opacity: 0; }
        64%        { opacity: 1; }
        73%        { stroke-dashoffset: 0; opacity: 1; }
        80%        { opacity: 0; }
        100%       { stroke-dashoffset: 80; opacity: 0; }
      }
      @keyframes arrowP2 {
        0%,  78%  { stroke-dashoffset: 80; opacity: 0; }
        80%        { opacity: 1; }
        90%        { stroke-dashoffset: 0; opacity: 1; }
        97%        { opacity: 0; }
        100%       { stroke-dashoffset: 80; opacity: 0; }
      }
      /* ── Consumer green flash ── */
      @keyframes consumerFlashC0 {
        0%,  54%  { fill: #10b981; }
        55%,  62% { fill: #34d399; }
        63%, 100% { fill: #10b981; }
      }
      @keyframes consumerFlashC1 {
        0%,  72%  { fill: #10b981; }
        73%,  80% { fill: #34d399; }
        81%, 100% { fill: #10b981; }
      }
      @keyframes consumerFlashC2 {
        0%,  89%  { fill: #10b981; }
        90%,  97% { fill: #34d399; }
        98%, 100% { fill: #10b981; }
      }
      /* ── Group label blink ── */
      @keyframes groupLabel {
        0%,  10%  { opacity: 0; }
        15%,  85% { opacity: 1; }
        90%, 100% { opacity: 0; }
      }
      /* ── Producer line dash flow ── */
      @keyframes dashFlow {
        0%   { stroke-dashoffset: 20; }
        100% { stroke-dashoffset: 0; }
      }
      .producer-box   { animation: producerPulse 6s infinite; }
      .msg-p0  { animation: msgP0 6s infinite; }
      .msg-p1  { animation: msgP1 6s infinite; }
      .msg-p2  { animation: msgP2 6s infinite; }
      .off-p0  { animation: offsetP0 6s infinite; }
      .off-p1  { animation: offsetP1 6s infinite; }
      .off-p2  { animation: offsetP2 6s infinite; }
      .arrow-p0 { animation: arrowP0 6s infinite; }
      .arrow-p1 { animation: arrowP1 6s infinite; }
      .arrow-p2 { animation: arrowP2 6s infinite; }
      .consumer-c0 { animation: consumerFlashC0 6s infinite; }
      .consumer-c1 { animation: consumerFlashC1 6s infinite; }
      .consumer-c2 { animation: consumerFlashC2 6s infinite; }
      .group-label { animation: groupLabel 6s infinite; }
      .prod-line { animation: dashFlow 0.6s linear infinite; }
    </style>
    <!-- arrowhead markers -->
    <marker id="arrowAmber" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#f59e0b"/>
    </marker>
    <marker id="arrowGreen" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L0,6 L8,3 z" fill="#10b981"/>
    </marker>
  </defs>
  <!-- ══════════════════════════════════════════════════
       BACKGROUND
  ══════════════════════════════════════════════════ -->
  <rect width="760" height="340" fill="#f8fafc" rx="10"/>
  <!-- ══════════════════════════════════════════════════
       TITLE
  ══════════════════════════════════════════════════ -->
  <text x="380" y="26" text-anchor="middle" font-size="14" font-weight="bold" fill="#64748b">Kafka Producer-Consumer Flow</text>
  <!-- ══════════════════════════════════════════════════
       PRODUCER  (left, x=30..130, vertically centered)
  ══════════════════════════════════════════════════ -->
  <g class="producer-box">
    <rect x="30" y="120" width="100" height="100" rx="8" fill="#3b82f6" stroke="#60a5fa" stroke-width="1.5"/>
    <text x="80" y="163" text-anchor="middle" font-size="12" font-weight="bold">Producer</text>
    <text x="80" y="180" text-anchor="middle" font-size="9" fill="#1d4ed8">orders-svc</text>
    <!-- animated dashes representing activity -->
    <line x1="48" y1="200" x2="112" y2="200" stroke="#bfdbfe" stroke-width="1" stroke-dasharray="4 3" opacity="0.5" class="prod-line"/>
  </g>
  <!-- ══════════════════════════════════════════════════
       PRODUCER → TOPIC connector line
  ══════════════════════════════════════════════════ -->
  <line x1="130" y1="170" x2="218" y2="170"
        stroke="#f59e0b" stroke-width="2" stroke-dasharray="6 3"
        marker-end="url(#arrowAmber)" class="prod-line"/>
  <!-- ══════════════════════════════════════════════════
       TOPIC BOX  (center, x=220..530)
  ══════════════════════════════════════════════════ -->
  <!-- outer topic container -->
  <rect x="218" y="50" width="316" height="240" rx="10" fill="#f1f5f9" stroke="#475569" stroke-width="1.5"/>
  <text x="376" y="74" text-anchor="middle" font-size="12" font-weight="bold" fill="#64748b">Topic: orders</text>
  <!-- ── Partition 0 (y=85..135) ── -->
  <rect x="230" y="82" width="294" height="46" rx="5" fill="#1e293b" stroke="#475569" stroke-width="1"/>
  <text x="246" y="110" font-size="10" fill="#334155">Partition 0</text>
  <!-- slot for message block -->
  <clipPath id="clipP0"><rect x="300" y="84" width="210" height="42" rx="3"/></clipPath>
  <g clip-path="url(#clipP0)">
    <g class="msg-p0">
      <rect x="382" y="88" width="60" height="32" rx="3" fill="#f59e0b"/>
      <text x="412" y="107" text-anchor="middle" font-size="9" fill="#fffbeb" font-weight="bold">msg-42</text>
    </g>
    <!-- second message -->
    <rect x="306" y="88" width="56" height="32" rx="3" fill="#f59e0b" opacity="0.4"/>
    <text x="334" y="107" text-anchor="middle" font-size="9" fill="#fffbeb">msg-41</text>
  </g>
  <!-- offset label -->
  <g class="off-p0">
    <text x="454" y="110" font-size="9" fill="#92400e">offset: 43</text>
  </g>
  <!-- ── Partition 1 (y=145..195) ── -->
  <rect x="230" y="143" width="294" height="46" rx="5" fill="#1e293b" stroke="#475569" stroke-width="1"/>
  <text x="246" y="171" font-size="10" fill="#334155">Partition 1</text>
  <clipPath id="clipP1"><rect x="300" y="145" width="210" height="42" rx="3"/></clipPath>
  <g clip-path="url(#clipP1)">
    <g class="msg-p1">
      <rect x="382" y="149" width="60" height="32" rx="3" fill="#f59e0b"/>
      <text x="412" y="168" text-anchor="middle" font-size="9" fill="#fffbeb" font-weight="bold">msg-17</text>
    </g>
    <rect x="306" y="149" width="56" height="32" rx="3" fill="#f59e0b" opacity="0.4"/>
    <text x="334" y="168" text-anchor="middle" font-size="9" fill="#fffbeb">msg-16</text>
  </g>
  <g class="off-p1">
    <text x="454" y="171" font-size="9" fill="#92400e">offset: 18</text>
  </g>
  <!-- ── Partition 2 (y=205..255) ── -->
  <rect x="230" y="204" width="294" height="46" rx="5" fill="#1e293b" stroke="#475569" stroke-width="1"/>
  <text x="246" y="232" font-size="10" fill="#334155">Partition 2</text>
  <clipPath id="clipP2"><rect x="300" y="206" width="210" height="42" rx="3"/></clipPath>
  <g clip-path="url(#clipP2)">
    <g class="msg-p2">
      <rect x="382" y="210" width="60" height="32" rx="3" fill="#f59e0b"/>
      <text x="412" y="229" text-anchor="middle" font-size="9" fill="#fffbeb" font-weight="bold">msg-09</text>
    </g>
    <rect x="306" y="210" width="56" height="32" rx="3" fill="#f59e0b" opacity="0.4"/>
    <text x="334" y="229" text-anchor="middle" font-size="9" fill="#fffbeb">msg-08</text>
  </g>
  <g class="off-p2">
    <text x="454" y="232" font-size="9" fill="#92400e">offset: 10</text>
  </g>
  <!-- ══════════════════════════════════════════════════
       PULL ARROWS  (partition right edge → consumer left edge)
       Partition right edge x=524, Consumer left edge x=548
  ══════════════════════════════════════════════════ -->
  <!-- Arrow P0 → C0 -->
  <line x1="524" y1="105" x2="548" y2="105"
        stroke="#10b981" stroke-width="2.5"
        stroke-dasharray="10 4" stroke-dashoffset="80"
        marker-end="url(#arrowGreen)"
        class="arrow-p0"/>
  <!-- Arrow P1 → C1 -->
  <line x1="524" y1="166" x2="548" y2="166"
        stroke="#10b981" stroke-width="2.5"
        stroke-dasharray="10 4" stroke-dashoffset="80"
        marker-end="url(#arrowGreen)"
        class="arrow-p1"/>
  <!-- Arrow P2 → C2 -->
  <line x1="524" y1="227" x2="548" y2="227"
        stroke="#10b981" stroke-width="2.5"
        stroke-dasharray="10 4" stroke-dashoffset="80"
        marker-end="url(#arrowGreen)"
        class="arrow-p2"/>
  <!-- ══════════════════════════════════════════════════
       CONSUMER GROUP BOX  (right, x=546..730)
  ══════════════════════════════════════════════════ -->
  <rect x="546" y="50" width="190" height="240" rx="10" fill="#f1f5f9" stroke="#059669" stroke-width="1.5"/>
  <!-- Consumer Group label (flashing) -->
  <g class="group-label">
    <rect x="556" y="56" width="170" height="22" rx="4" fill="#d1fae5"/>
    <text x="641" y="71" text-anchor="middle" font-size="9" fill="#065f46">Consumer Group: my-group</text>
  </g>
  <!-- ── Consumer 0 ── -->
  <rect x="562" y="84" width="158" height="46" rx="6" class="consumer-c0" fill="#10b981"/>
  <text x="641" y="108" text-anchor="middle" font-size="10" font-weight="bold" fill="#022c22">Consumer-0</text>
  <text x="641" y="122" text-anchor="middle" font-size="8" fill="#d1fae5">← P0 assigned</text>
  <!-- ── Consumer 1 ── -->
  <rect x="562" y="143" width="158" height="46" rx="6" class="consumer-c1" fill="#10b981"/>
  <text x="641" y="167" text-anchor="middle" font-size="10" font-weight="bold" fill="#022c22">Consumer-1</text>
  <text x="641" y="181" text-anchor="middle" font-size="8" fill="#d1fae5">← P1 assigned</text>
  <!-- ── Consumer 2 ── -->
  <rect x="562" y="204" width="158" height="46" rx="6" class="consumer-c2" fill="#10b981"/>
  <text x="641" y="228" text-anchor="middle" font-size="10" font-weight="bold" fill="#022c22">Consumer-2</text>
  <text x="641" y="242" text-anchor="middle" font-size="8" fill="#d1fae5">← P2 assigned</text>
  <!-- ══════════════════════════════════════════════════
       LEGEND  (bottom)
  ══════════════════════════════════════════════════ -->
  <rect x="30" y="305" width="700" height="26" rx="5" fill="#f1f5f9" stroke="#cbd5e1" stroke-width="1"/>
  <!-- Message block legend -->
  <rect x="44" y="313" width="14" height="10" rx="2" fill="#f59e0b"/>
  <text x="62" y="322" font-size="9" fill="#64748b">Message (amber)</text>
  <!-- Consumer legend -->
  <rect x="190" y="313" width="14" height="10" rx="2" fill="#10b981"/>
  <text x="208" y="322" font-size="9" fill="#64748b">Consumer (green)</text>
  <!-- Producer legend -->
  <rect x="340" y="313" width="14" height="10" rx="2" fill="#3b82f6"/>
  <text x="358" y="322" font-size="9" fill="#64748b">Producer (blue)</text>
  <!-- Offset text -->
  <text x="470" y="322" font-size="9" fill="#92400e">offset: N</text>
  <text x="510" y="322" font-size="9" fill="#64748b">= committed read position</text>
</svg>

---

#### The Idea

Imagine a city's postal sorting office that never throws away any letter — it just stacks them in numbered slots. Every letter that arrives gets a unique slot number, and that number never changes. If you want to re-read letter number 42, it's still there. Multiple delivery teams can each keep their own bookmark (saying "I've read up to slot 42") and work independently without interfering with each other.

That is Kafka. A **topic** is the address (e.g., "order-events"). A **partition** is one physical stack of letters inside that address — ordered, append-only, numbered from zero. The number on each letter is its **offset**. A **broker** is a server that hosts those stacks. Multiple brokers together form the **cluster**, and each partition is replicated across several brokers for fault tolerance — one broker is the **leader** (handles reads and writes) and the rest are **followers** (copy from the leader).

**Segments** are just how the partition's letter-stack is broken into manageable files on disk — when a file grows past 1 GB or a week old, Kafka starts a new segment file. **Log compaction** is a background process that, for changelog-style topics (e.g., the latest state of a user profile), throws away old versions of a key and keeps only the most recent one, bounding disk usage without losing the current picture.

---

#### How It Works

```
CLUSTER STRUCTURE

  Broker 1 (Leader for P0, P2)        Broker 2 (Leader for P1)
  ┌────────────────────────────┐       ┌────────────────────────┐
  │  Topic: order-events       │       │  Topic: order-events   │
  │  Partition 0  (replica)    │       │  Partition 1  (leader) │
  │  ┌──────────────────────┐  │       │  ┌──────────────────┐  │
  │  │ offset 0 | offset 1  │  │       │  │ offset 0 | off 1 │  │
  │  │ offset 2 | offset 3  │  │       │  │ offset 2 | off 3 │  │
  │  └──────────────────────┘  │       │  └──────────────────┘  │
  │  Partition 2  (leader)     │       │  Partition 0  (follower)│
  └────────────────────────────┘       └────────────────────────┘

  Each partition = append-only segment files on disk
  e.g. 00000000000000000000.log (segment 1)
       00000000000001048576.log (segment 2, starts at offset 1048576)

  Consumer Group A bookmarks:
    P0 → committed offset 47
    P1 → committed offset 31
    P2 → committed offset 55
```

Key rules:
- Ordering is guaranteed **within** a partition only — not across partitions.
- One leader per partition; all writes go to the leader; followers replicate asynchronously.
- Segment rollover triggers: `log.segment.bytes` (1 GB default) or `log.roll.hours` (168 h default).
- Log compaction keeps the latest record per key; a null-value record (tombstone) signals deletion and is kept for `delete.retention.ms` before physical removal.
- Consumers can read from follower replicas since Kafka 2.4 (`client.rack` config) to reduce cross-AZ traffic — but writes always go to the leader.

```java
// Must-memorise: creating a compacted changelog topic in Spring Boot
@Bean
public NewTopic userProfileChangelog() {
    return TopicBuilder.name("user-profile-changelog")
            .partitions(12)
            .replicas(3)
            .compact()
            .config(TopicConfig.MIN_CLEANABLE_DIRTY_RATIO_CONFIG, "0.1")
            .config(TopicConfig.DELETE_RETENTION_MS_CONFIG,
                    String.valueOf(24 * 60 * 60 * 1000L))
            .build();
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Explain the core architecture of Kafka — what are brokers, topics, partitions, and offsets?"**

**One-line answer:** Kafka topics are split into ordered, append-only partitions stored on broker servers; each record within a partition gets a unique sequential offset number.

**Full answer to give in an interview:**

> "Kafka is a distributed commit-log system. You write messages to a **topic** — a named logical category like 'order-events'. A topic is physically divided into **partitions**, each of which is an append-only, ordered log of records. Every record appended to a partition gets a **offset** — a 64-bit integer that starts at zero and increments forever. That offset is how consumers bookmark their position.
>
> The partitions live on **brokers** — Kafka server processes in the cluster. For fault tolerance, each partition is replicated: one broker is the **leader** (the only one that accepts writes) and the others are **followers** that copy from the leader. If the leader fails, a follower is promoted.
>
> On disk, a partition is stored as rolling **segment** files — when a file hits roughly 1 GB or a week of age, Kafka starts a new one. Older segments are deleted based on your retention policy. For topics that represent the latest state of something — like the current address for each user — you can enable **log compaction**, which deletes old values for a key and keeps only the most recent one, so the log grows only as fast as the number of unique keys."

> *Sketch the broker/partition/offset diagram if you have a whiteboard — it immediately shows you understand the physical layout.*

**Gotcha follow-up they'll ask:** *"Is ordering guaranteed across partitions?"*

> "No — ordering is only guaranteed within a single partition. Across partitions there is no global order. This is a deliberate trade-off: multiple partitions enable parallel producers and consumers, which is where Kafka gets its throughput. If you need total ordering for a business entity — like all events for a given order — you route them to the same partition by using the order ID as the message key. Kafka hashes the key to consistently pick the same partition."

---

##### Q2 — Tradeoff Question
**"What is log compaction and when would you use it instead of time-based retention?"**

**One-line answer:** Log compaction keeps only the latest value per key in a partition — use it when the topic represents current state (like a cache) rather than a time-series event stream.

**Full answer to give in an interview:**

> "By default, Kafka deletes records based on age or total partition size — after 7 days, old segments are removed regardless of what keys they contain. That works for event streams where you care about the history.
>
> **Log compaction** is an alternative where Kafka runs a background cleaner that looks at 'dirty' segments — the parts not yet compacted — and merges them, keeping only the most recent record for each key. If you update the same user's profile 100 times, after compaction only the 100th version remains. This means you can always rebuild current state by replaying the topic from the beginning, making it perfect for **database changelogs**, **Kafka Connect offset topics**, or **Kafka Streams state store restore topics**.
>
> The trade-off: compaction is asynchronous, so there's a window where duplicates exist; and it uses more broker CPU. You also need keys on every record — compaction is key-based. Tombstones — records with a null value — signal that a key should be deleted entirely; they're retained for `delete.retention.ms` before physical removal so slow consumers can observe the delete."

> *If they push on Kafka Streams: the internal state store changelog topics use compaction so a restarted stream app can restore its state store from the beginning of the topic instead of a remote snapshot.*

**Gotcha follow-up they'll ask:** *"Can a consumer read from a follower replica?"*

> "Yes, since Kafka 2.4. Using the `client.rack` configuration, a consumer can be directed to fetch from the closest replica — typically the one in the same availability zone — instead of always going to the leader. This reduces cross-AZ data transfer costs significantly in cloud deployments. Writes still always go to the partition leader; only reads are rack-aware."

---

> **Common Mistake — confusing offset with time:** An offset is a sequential integer, not a timestamp. If you need to seek to a point in time, use the `offsetsForTimes()` API, which translates a timestamp to an offset. Trying to calculate offsets from timestamps manually will break when brokers delete old segments.

---

**Quick Revision (one line):**
A Kafka topic is split into ordered append-only partitions stored as rolling segment files on brokers; offsets uniquely identify records within a partition, and log compaction retains only the latest value per key.

---

## Topic 2: Producers

---

#### The Idea

Think of a Kafka producer like a courier company that doesn't send a truck for every single letter — it waits in the depot until either the truck is full or a short time window expires, then sends a single truck carrying a compressed bundle. This dramatically cuts transport costs compared to one truck per letter.

The two knobs controlling that depot behaviour are **batch.size** (how full the truck must be before it leaves) and **linger.ms** (how long the depot waits for more letters before sending a half-full truck). The default is `linger.ms=0` — the truck leaves immediately — which is great for latency but terrible for throughput.

Now imagine your courier occasionally crashes and tries to re-deliver the same package twice. To prevent that, each driver is issued a unique **Producer ID** and each package gets a **sequence number**. The receiving broker checks: if it already accepted this driver's package number 42, it silently drops the duplicate. That is the **idempotent producer** — it protects against duplicate records caused by retries after network timeouts.

---

#### How It Works

```
Producer internals:

  Application thread          Background I/O thread
  ─────────────────           ───────────────────────
  send(record)
      │
      ▼
  RecordAccumulator
  (one ProducerBatch deque per TopicPartition)
      │
      ├─ batch full? (batch.size bytes, default 16 KB)  ──► send now
      └─ linger.ms elapsed?                             ──► send now
                                                │
                                                ▼
                                    Compress batch (lz4/snappy/zstd)
                                                │
                                                ▼
                                    Send to leader broker
                                                │
                                    acks=0 ──► fire and forget
                                    acks=1 ──► leader confirms write
                                    acks=all ► all ISR replicas confirm
```

**acks settings — the durability ladder:**
- `acks=0`: Maximum throughput, zero durability. Message may be lost if broker is unavailable.
- `acks=1`: Leader writes and confirms. Risk: leader crashes before followers replicate — message is lost.
- `acks=all` (or `-1`): All in-sync replicas (ISR) confirm. Use with `min.insync.replicas=2` for production durability. Recommended default.

**Idempotent producer flow:**
```
Producer assigned PID=7 by broker

Batch 1 for Partition-0:  PID=7, seq=0  → broker writes, ACKs
Network blip — producer retries
Batch 1 retry:            PID=7, seq=0  → broker sees (7, P0, 0) already written → drops silently
Batch 2 for Partition-0:  PID=7, seq=1  → broker writes, ACKs
```

Constraints: requires `acks=all`, `retries > 0`, `max.in.flight.requests.per.connection <= 5`. Guarantees deduplication within one producer session only — a restart gets a new PID.

```java
// Must-memorise: idempotent producer config
props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
props.put(ProducerConfig.ACKS_CONFIG, "all");
props.put(ProducerConfig.RETRIES_CONFIG, Integer.MAX_VALUE);
props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 5);
// Also tune for throughput:
props.put(ProducerConfig.LINGER_MS_CONFIG, 10);        // wait 10ms for batch fill
props.put(ProducerConfig.BATCH_SIZE_CONFIG, 65536);    // 64 KB batches
props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "lz4");
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does Kafka producer batching work and what configs control it?"**

**One-line answer:** The producer buffers records in per-partition batches and sends them when either the batch is full (`batch.size` bytes) or a time window expires (`linger.ms`).

**Full answer to give in an interview:**

> "The Kafka producer maintains a **RecordAccumulator** — essentially a queue of in-memory batches, one deque per topic-partition. When your application calls `send()`, the record is appended to the current open batch for that partition.
>
> Two conditions trigger a flush: the batch fills up to **`batch.size`** bytes (default 16 KB), or **`linger.ms`** milliseconds have elapsed since the first record was added to the batch (default 0 — which means send immediately with no waiting). For high-throughput scenarios, setting `linger.ms=5` to `linger.ms=20` dramatically improves throughput because more records aggregate into a single network request — you pay the round-trip cost once for many records instead of once per record.
>
> Before sending, the batch is **compressed** as a unit using the codec set in `compression.type` — options are none, gzip, snappy, lz4, or zstd. LZ4 is a popular production choice: fast CPU-wise and 3–5x compression for JSON payloads. The broker stores the compressed batch as-is and consumers decompress on their side.
>
> The **`acks`** setting then controls durability: `acks=0` means fire-and-forget, `acks=1` means the leader acknowledges, and `acks=all` means every in-sync replica acknowledges. Production should use `acks=all` with `min.insync.replicas=2`."

> *If asked about latency vs throughput trade-off: linger.ms adds intentional latency at the producer to improve throughput downstream. It's a knob you tune based on your SLAs.*

**Gotcha follow-up they'll ask:** *"Does the idempotent producer guarantee exactly-once across producer restarts?"*

> "No, and this is a common trap. The **Producer ID (PID)** is assigned per session — when the producer process restarts, it gets a brand new PID. The broker has no way to correlate the old PID with the new one, so a duplicate sent by the old producer and then retried by the new producer after restart will not be deduplicated. Idempotence is session-scoped only. For cross-session exactly-once, you need **transactions** with a stable `transactional.id` — that identifier persists across restarts and lets the broker use epoch-based fencing to invalidate zombie producers."

---

##### Q2 — Tradeoff Question
**"When would you use acks=1 vs acks=all, and what can go wrong with each?"**

**One-line answer:** `acks=1` is faster but can lose messages if the leader crashes before followers replicate; `acks=all` is durable but adds latency proportional to the slowest in-sync replica.

**Full answer to give in an interview:**

> "With **`acks=1`**, the leader writes the batch to its local log and immediately sends back an acknowledgment. The producer considers the message delivered. But if the leader broker fails before the followers have replicated that batch, the new leader — promoted from a follower — won't have that record. It is permanently lost. This is acceptable for metrics or logs where occasional loss is tolerable, but not for financial events or order confirmations.
>
> With **`acks=all`** (equivalent to `-1`), the leader waits until all brokers in the **ISR** — the In-Sync Replica set, the set of followers that are caught up within `replica.lag.time.max.ms` — have acknowledged. This means a message survives even if the leader fails immediately after the ACK, because all ISR members have it. You typically pair this with `min.insync.replicas=2`, which means if only one broker is up (leader only, all followers are down), the producer gets a `NotEnoughReplicasException` instead of silently losing durability.
>
> The trade-off: `acks=all` latency is bounded by the slowest ISR follower. In practice with modern hardware this is 1–5 ms, which is acceptable for most use cases. The throughput difference matters more for fire-hose workloads — there you might tune `linger.ms` higher to amortize the acks cost across larger batches."

> *Mention min.insync.replicas — interviewers love that follow-up. It's the safety net that prevents acks=all from being silently bypassed when the ISR shrinks to just the leader.*

**Gotcha follow-up they'll ask:** *"Does compression hurt latency?"*

> "Usually not — it improves it. Compression adds a small amount of CPU overhead on the producer side, but the reduction in bytes sent over the network typically more than compensates. For large messages, especially JSON, you're often seeing 3–5x compression, which means much less network time. The only scenario where compression hurts is very small messages where the compression overhead exceeds the byte savings — in that case, none or snappy is better."

---

> **Common Mistake — enabling idempotence without acks=all:** If you set `enable.idempotence=true` but leave `acks=1`, Kafka will throw a `ConfigException` at startup. Idempotence requires `acks=all` by design — there is no point deduplicating retries if the original write might not have reached all replicas. Always set them together.

---

**Quick Revision (one line):**
Kafka producers batch records by size (`batch.size`) and time (`linger.ms`), compress per-batch, use `acks=all` for durability, and rely on PID + sequence-number idempotence to deduplicate retries within a single producer session.

---

## Topic 3: Consumers and Consumer Groups

---

#### The Idea

Imagine a call centre with 20 incoming phone lines (partitions). You have a team of agents (consumers) who need to handle those calls. The rule is: each line is handled by exactly one agent — no two agents pick up the same line simultaneously. But multiple teams (consumer groups) can each have their own set of agents independently listening to all 20 lines — a customer service team and a QA team can both monitor calls without stepping on each other.

When an agent goes on break or a new agent joins, the supervisor (Kafka's **Group Coordinator**) redistributes the lines. The classic way to do this — the **eager protocol** — was to have everyone put down their phone at the same time, wait for new instructions, then pick up again. That's a "stop the world" pause. The newer **cooperative protocol** is smarter: only the lines that actually need to move are handed off; everyone else keeps working.

Each agent also has to check in with the supervisor regularly (heartbeat) to prove they're still alive. If they stop checking in, the supervisor assumes they've left and redistributes their lines.

---

#### How It Works

```
Topic: order-events (6 partitions)

Consumer Group A (3 consumers):
  Consumer-1 ──► Partition 0, Partition 1
  Consumer-2 ──► Partition 2, Partition 3
  Consumer-3 ──► Partition 4, Partition 5

Consumer Group B (6 consumers):
  Consumer-1 ──► Partition 0
  Consumer-2 ──► Partition 1
  ...each consumer gets exactly one partition

Consumer Group C (8 consumers):
  6 consumers get one partition each
  2 consumers are IDLE (partitions < consumers = wasted capacity)
```

**Assignment strategies (who decides which consumer gets which partition):**
```
RangeAssignor       – consecutive ranges per topic (default, can be uneven)
RoundRobinAssignor  – round-robin across all topics (better balance)
StickyAssignor      – minimise moves on rebalance (keeps existing assignments)
CooperativeStickyAssignor – Sticky + incremental (recommended for production)
```

**Rebalance protocols:**
```
Eager (classic):
  1. ALL consumers revoke ALL partitions (stop the world)
  2. All rejoin the group
  3. Leader computes new assignment
  4. All consumers get new assignment and resume
  Problem: gap in processing for every rebalance

Cooperative (incremental):
  Round 1: Members report current assignments
           Only partitions that must move are revoked
  Round 2: Revoked partitions assigned to new owners
           Unaffected partitions NEVER stop
  Result: zero pause for partitions not being moved
```

**Critical timing configs:**
```
session.timeout.ms     = 45000  (45s) — if no heartbeat in this window → consumer declared dead
heartbeat.interval.ms  = 15000  (15s) — how often consumer sends heartbeat (~1/3 of session.timeout)
max.poll.interval.ms   = 300000 (5m)  — max time between poll() calls; if exceeded → consumer removed
max.poll.records       = 500          — max records per poll(); tune to fit within max.poll.interval.ms
```

```java
// Must-memorise: cooperative sticky rebalancing config
props.put(ConsumerConfig.PARTITION_ASSIGNMENT_STRATEGY_CONFIG,
    CooperativeStickyAssignor.class.getName());
props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
props.put(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 45000);
props.put(ConsumerConfig.HEARTBEAT_INTERVAL_MS_CONFIG, 15000);
props.put(ConsumerConfig.MAX_POLL_INTERVAL_MS_CONFIG, 300000);
props.put(ConsumerConfig.MAX_POLL_RECORDS_CONFIG, 500);
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How do Kafka consumer groups work, and what is the maximum parallelism for a topic?"**

**One-line answer:** A consumer group splits a topic's partitions across its members — one partition per consumer — so the maximum parallelism equals the number of partitions.

**Full answer to give in an interview:**

> "A **consumer group** is a named set of consumer processes that jointly consume a topic. Kafka's invariant is: within a group, each partition is owned by exactly one consumer at any time. So if your topic has 6 partitions and your group has 3 consumers, each consumer handles 2 partitions. This is where Kafka gets its parallel processing — each consumer reads independently from its assigned partitions.
>
> The assignment is managed by two roles. The **Group Coordinator** is a broker that tracks group membership and stores committed offsets in the internal `__consumer_offsets` topic. One of the consumer instances is elected the **Group Leader** — it receives the full member list from the coordinator, runs the partition assignment algorithm locally, and sends the result back to the coordinator, which then pushes assignments to each member.
>
> The maximum parallelism within a group is capped by the number of partitions. If you add a 7th consumer to a 6-partition topic, that consumer sits idle — it gets no partitions. Multiple consumer groups are independent: a monitoring group and a processing group can both read all 6 partitions without interfering with each other."

> *If they ask about increasing parallelism: you must increase partition count. This requires a repartition — existing messages don't move, but new messages route differently. Plan partition count upfront; it's hard to change cleanly.*

**Gotcha follow-up they'll ask:** *"What happens if processing takes longer than max.poll.interval.ms?"*

> "The consumer is removed from the group — Kafka treats it as a liveness failure separate from the heartbeat mechanism. The heartbeat thread runs in the background and keeps the session alive, but `max.poll.interval.ms` is checked between calls to `poll()`. If your processing of one batch takes longer than 5 minutes (the default), Kafka assumes the consumer is stuck and triggers a rebalance, handing its partitions to another consumer. The mitigation is to either reduce `max.poll.records` so each batch is smaller and faster to process, or increase `max.poll.interval.ms` to match your worst-case processing time, or offload processing to an async thread pool and call `poll()` more frequently."

---

##### Q2 — Tradeoff Question
**"What is the difference between eager and cooperative rebalancing, and why does it matter?"**

**One-line answer:** Eager rebalancing stops all consumers and reassigns all partitions from scratch; cooperative rebalancing only pauses partitions that need to move, leaving the rest running.

**Full answer to give in an interview:**

> "The classic **eager rebalancing protocol** works in one round: when any consumer joins or leaves the group, every consumer revokes all its partitions simultaneously, rejoins the group, and waits for new assignments. This stop-the-world pause means zero processing happens across the entire group during rebalance. For a rolling deployment of 50 consumer instances, that's 50 sequential pauses — potentially seconds of total downtime per deployment.
>
> **Cooperative (incremental) rebalancing**, enabled with `CooperativeStickyAssignor`, uses two rounds. In round one, members report what they currently own; only the partitions that need to actually move are revoked. In round two, those revoked partitions are handed to their new owners. Partitions that don't need to move are never interrupted — consumers keep reading them throughout the rebalance. The result is near-zero downtime during deployments and consumer group changes.
>
> The only catch is migrating from eager to cooperative in a live cluster. During the migration window, you can't have a mix of eager-only and cooperative-only consumers in the same group — you need to go through an intermediate `StickyAssignor` step or do a full group restart."

> *CooperativeStickyAssignor is the answer to 'how do you do zero-downtime Kafka deployments' — it's worth knowing cold.*

**Gotcha follow-up they'll ask:** *"Can two consumers in the same group read the same partition?"*

> "No — within a consumer group, each partition is exclusively owned by one consumer at any given time. This is the core guarantee that prevents double-processing within a group. However, two different consumer groups can each read the same partition completely independently. This is how Kafka supports multiple use cases off the same topic — a real-time processing group and a batch analytics group both reading 'order-events' without affecting each other."

---

> **Common Mistake — max.poll.records too high:** Setting `max.poll.records=5000` and then writing slow database logic per record is a recipe for consumers being kicked out of the group mid-batch. The batch processing time must fit inside `max.poll.interval.ms`. Start with 500 and tune up only after measuring.

---

**Quick Revision (one line):**
Consumer groups distribute topic partitions across members (one partition per consumer, maximum parallelism = partition count); cooperative rebalancing only moves affected partitions, keeping unaffected consumers running.

---

## Topic 4: Offset Management

---

#### The Idea

Think of reading a very long book with a bookmark. The bookmark is your **offset** — it records where you stopped. If you put the bookmark in before you actually finish reading a page (commit before processing), and then you drop the book, you'll think you've read that page even though you haven't — the page is lost. If you wait until you finish reading before moving the bookmark (commit after processing), and then you drop the book, you'll re-read the last page — duplicated, but nothing lost. True "exactly read each page once" requires the bookmark and your brain state to update atomically, which is much harder.

Kafka's auto-commit is like having an assistant move your bookmark every 5 seconds whether you've finished the page or not — unreliable in either direction. Manual commit gives you direct control. The question of "when do I move the bookmark?" is the core of delivery semantics.

---

#### How It Works

```
Auto-commit (enable.auto.commit=true):
  poll() ──► records returned
  ... processing happens ...
  5 seconds later, background thread commits latest polled offset
  
  Problem 1 (at-most-once): crash AFTER poll but BEFORE processing
    → offset was committed at end of previous interval
    → next consumer starts after the lost records → LOST
  
  Problem 2 (at-least-once): crash AFTER processing but BEFORE next commit interval
    → offset not yet committed
    → next consumer re-reads and re-processes → DUPLICATE

Manual commit patterns:
  BEFORE processing  → at-most-once  (message may be lost on crash)
  AFTER processing   → at-least-once (message may be reprocessed on crash)
  Transactional      → exactly-once  (atomic offset commit + produce)
```

**commit strategies:**
```
commitSync()   – blocks until broker confirms; auto-retries; use at shutdown or partition revoke
commitAsync()  – non-blocking; pass callback for error handling; higher throughput
per-record     – maximum safety, lowest throughput (commit after every single record)
per-batch      – good balance (commit after processing all records from one poll())
on-revoke      – always call commitSync() inside onPartitionsRevoked() to avoid reprocessing
```

**auto.offset.reset (what to do when no committed offset exists):**
```
earliest  – start from the beginning of the partition (safe for new consumers)
latest    – start from the end (only new messages after consumer start)
none      – throw exception if no committed offset found
```

```java
// Must-memorise: manual at-least-once commit pattern
@KafkaListener(topics = "order-events", groupId = "order-processing-group",
               containerFactory = "kafkaListenerContainerFactory")
public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {
    try {
        orderRepository.upsert(record.key(), record.value()); // 1. process
        ack.acknowledge();                                      // 2. commit AFTER
    } catch (Exception e) {
        throw e; // do NOT ack — record will be redelivered
    }
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between auto-commit and manual commit, and what delivery semantics does each give you?"**

**One-line answer:** Auto-commit is unreliable — it can give at-most-once or at-least-once depending on crash timing; manual post-processing commit reliably gives at-least-once.

**Full answer to give in an interview:**

> "**Auto-commit** (`enable.auto.commit=true`) works by having a background thread periodically commit the offset of the last record returned by `poll()`, regardless of whether your application has finished processing it. The interval is `auto.commit.interval.ms`, defaulting to 5 seconds. This creates two failure windows: if the consumer crashes after `poll()` returns records but before the next commit interval, the records were never committed — on restart, they're re-read. That's at-least-once. But if the consumer crashes after the commit fires but before it finishes processing, the records are marked done even though they weren't — that's at-most-once. You get a mix of both, non-deterministically. That's why auto-commit is generally unsuitable for critical paths.
>
> **Manual commit** with `enable.auto.commit=false` gives you deterministic control. If you commit the offset **after** successful processing — calling `ack.acknowledge()` in Spring Kafka — you get **at-least-once**: a crash before commit means the record is re-read and reprocessed on recovery. Your processing logic must be idempotent to handle this. If you commit **before** processing (for audit-log style workloads where you prefer to lose a record rather than process it twice) you get **at-most-once**.
>
> True **exactly-once** requires either application-level idempotency on the consumer side — like an upsert keyed on record ID — or Kafka transactions, where the offset commit is part of a transactional write and `isolation.level=read_committed` on the consumer filters out uncommitted records."

> *The Goldman Sachs pattern is worth mentioning: process batch → write to DB with upsert → commitSync(). The upsert provides idempotency; the synchronous commit ensures the offset only advances on success.*

**Gotcha follow-up they'll ask:** *"Does enable.auto.commit=false by itself give you exactly-once?"*

> "No — that's a common misconception. Disabling auto-commit gives you at-least-once when you commit after processing. To get exactly-once, you need either: idempotent consumers at the application level (e.g., database upserts keyed on the record's unique ID — so reprocessing the same record has no additional effect), or Kafka transactions where the consumer offset commit is bundled atomically with a producer write using `sendOffsetsToTransaction()`, and consumers set `isolation.level=read_committed` to skip records from aborted transactions."

---

##### Q2 — Tradeoff Question
**"When would you use commitSync vs commitAsync?"**

**One-line answer:** Use `commitSync` at shutdown and partition revoke (guaranteed delivery); use `commitAsync` during normal processing (higher throughput, handle errors in callback).

**Full answer to give in an interview:**

> "**`commitSync()`** blocks the consumer thread until the broker acknowledges the offset commit, and automatically retries on transient failures. The cost is that your consumer can't call `poll()` during the block — throughput drops. It's the right choice at two specific moments: when you're shutting down the consumer gracefully, and inside `onPartitionsRevoked()` — the callback Kafka triggers before a rebalance takes your partitions away. In both cases, you must be sure the commit lands before the consumer is no longer responsible for that partition, so blocking is correct.
>
> **`commitAsync()`** returns immediately and lets you pass a callback that's invoked when the broker responds. During normal processing of batches, this is better — you commit the previous batch's offset while already processing the next one, hiding the commit latency. The risk: if the commit fails and the callback doesn't retry (because a later commit for a higher offset may have already succeeded), you could have a gap. The standard pattern is: use `commitAsync()` in the processing loop for throughput, and always call `commitSync()` in the finally block on shutdown or partition revoke to flush any pending commits."

> *Not committing in onPartitionsRevoked is one of the most common bugs in Kafka consumers — the new partition owner re-reads and reprocesses records the old owner already handled.*

**Gotcha follow-up they'll ask:** *"What does isolation.level=read_committed do?"*

> "It tells the consumer to only expose records that are part of committed transactions. Records from aborted transactions are filtered out and never delivered to your application. Additionally, the consumer will not advance past the **Last Stable Offset** — the offset of the oldest open (not yet committed or aborted) transaction. This means if a slow transactional producer has an open transaction at offset 100, consumers with `read_committed` won't see records beyond offset 99 even if records at offset 200 are already in the log. This can cause consumer lag to grow if a transaction is left open — something to monitor in production."

---

> **Common Mistake — swallowing exceptions after acknowledging:** Calling `ack.acknowledge()` inside a catch block that silently handles the exception means Kafka commits the offset for a record your application failed to process. That record is gone forever with no alert. Always either re-throw the exception or send the record to a dead-letter topic before acknowledging.

---

**Quick Revision (one line):**
Manual post-processing offset commit gives at-least-once semantics; auto-commit is unreliable; true exactly-once requires either idempotent consumers or transactional producers paired with `isolation.level=read_committed`.

---

## Topic 5: Kafka Delivery Guarantees

---

#### The Idea

Imagine you are transferring money between two bank accounts. You need the debit and the credit to either both happen or both not happen — partial execution is worse than failure. In Kafka terms, you might be reading a payment from one topic, transforming it, and writing a result to another topic while also committing your read position. If any one of those three steps fails, you want to roll back all three.

Kafka's **exactly-once semantics (EOS)** builds this guarantee in two layers. The first layer — the **idempotent producer** — ensures that if a network blip causes your producer to retry a message, the broker notices it's a duplicate (matching Producer ID and sequence number) and silently drops it. The second layer — **transactions** — wraps multiple writes across multiple partitions into an atomic unit: either everything commits or everything aborts. Consumers reading with `isolation.level=read_committed` see only the committed results, never the in-progress or aborted ones.

The catch is that this guarantee is Kafka-internal only. If you also write to a database as part of the same logical operation, Kafka cannot atomically coordinate with that external system — you need application-level idempotency (like a database upsert keyed on the record's unique ID) to cover that boundary.

---

#### How It Works

**Delivery guarantee comparison:**

| Semantic | What it means | How to achieve | When to use |
|---|---|---|---|
| At-most-once | Message processed zero or one time. May be lost. | Commit offset before processing; or `acks=0`. | Metrics, logs, telemetry — loss is acceptable, duplicates are not. |
| At-least-once | Message processed one or more times. Never lost. | `enable.auto.commit=false`, commit after processing, idempotent consumer. | Most production workloads. Handle duplicates via idempotent logic. |
| Exactly-once | Message processed exactly one time. Never lost, never duplicated. | Transactional producer + `isolation.level=read_committed` consumer. | Payments, financial ledgers, stateful stream processing. |

**Transaction flow (two-phase commit inside Kafka):**
```
1. initTransactions()
   → Producer registers with Transaction Coordinator (TC) broker
   → TC bumps epoch; any old producer with same transactional.id + lower epoch is FENCED

2. beginTransaction()
   → Local marker only (no broker call)

3. send(records to partition A)
   send(records to partition B)
   → Records written to partitions but NOT visible to read_committed consumers yet

4. sendOffsetsToTransaction(consumerOffsets, groupMetadata)
   → Consumer offset commit bundled INTO the transaction

5. commitTransaction()
   → Producer sends EndTransactionMarker to TC
   → TC writes COMMIT to __transaction_state
   → TC writes transaction markers to each involved partition
   → Records now visible to read_committed consumers

   OR abortTransaction() → records remain invisible, offsets not advanced
```

**Zombie fencing:**
```
Old producer (epoch 1) crashes mid-transaction
New producer starts with same transactional.id → gets epoch 2
Zombie retries with epoch 1 → TC rejects (stale epoch)
Result: no duplicate commit from the zombie
```

**Consumer side — Last Stable Offset (LSO):**
```
read_committed consumers only advance to the LSO
LSO = offset of the oldest OPEN transaction
If a transaction is open at offset 100:
  consumers stop at offset 99 even if offset 500 is in the log
→ Monitor for open transactions; a stuck producer causes consumer lag to grow
```

```java
// Must-memorise: exactly-once transactional produce + consume
// Producer config:
props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
props.put(ProducerConfig.ACKS_CONFIG, "all");
props.put(ProducerConfig.TRANSACTIONAL_ID_CONFIG, "payment-processor-1"); // stable, unique per instance

// Consumer config:
props.put(ConsumerConfig.ISOLATION_LEVEL_CONFIG, "read_committed");

// Spring: @Transactional("kafkaTransactionManager") on the listener method
// atomically wraps offset commit + downstream produce
@Transactional("kafkaTransactionManager")
@KafkaListener(topics = "payments-input", groupId = "payment-processor-group")
public void process(ConsumerRecord<String, String> record) {
    String result = transformPayment(record.value());
    kafkaTemplate.send("payments-output", record.key(), result);
    // exception here → transaction aborts → input offset NOT committed → output NOT visible
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does Kafka achieve exactly-once semantics — explain idempotent producers and transactions?"**

**One-line answer:** EOS combines session-level deduplication (idempotent producer via PID + sequence number) with atomic multi-partition writes (transactions via transactional.id and a two-phase commit), with consumers filtering uncommitted data via isolation.level=read_committed.

**Full answer to give in an interview:**

> "Kafka exactly-once semantics has two building blocks.
>
> The first is the **idempotent producer**. When you set `enable.idempotence=true`, the broker assigns the producer a **Producer ID (PID)** and tracks a monotonically increasing **sequence number** for each partition the producer writes to. If a network timeout causes the producer to retry a batch, the broker checks whether it has already seen that (PID, partition, sequence number) combination. If yes, it silently drops the duplicate. This eliminates the classic retry-induced duplicate problem. Limitation: the PID is session-scoped — a producer restart gets a new PID, so idempotence doesn't survive restarts.
>
> The second building block is **transactions**. You assign a stable, application-chosen `transactional.id` — like `'payment-processor-instance-1'`. On startup, `initTransactions()` registers with the **Transaction Coordinator**, a broker that manages the `__transaction_state` internal topic. The TC increments an **epoch**: any old producer using the same `transactional.id` with a lower epoch is now **fenced** — its batches are rejected. This is zombie fencing.
>
> Inside a transaction, you call `beginTransaction()`, send records to one or more partitions, optionally include consumer offset commits via `sendOffsetsToTransaction()`, and then call `commitTransaction()`. The TC orchestrates a two-phase commit: writes the COMMIT record to `__transaction_state`, then writes transaction markers to each involved partition's log. Until the commit marker lands, consumers with **`isolation.level=read_committed`** see nothing from that transaction — they block at the **Last Stable Offset**, the offset of the oldest open transaction."

> *In Spring, the @Transactional("kafkaTransactionManager") annotation wires all of this automatically — the KafkaTransactionManager handles beginTransaction/commitTransaction/rollback transparently.*

**Gotcha follow-up they'll ask:** *"Does Kafka EOS guarantee exactly-once with external systems like databases?"*

> "No — and this is the critical boundary. Kafka EOS is Kafka-internal only. If your transaction writes to Kafka AND to a relational database, those are two independent systems with no shared coordinator. The database write and the Kafka commit cannot be made atomic from Kafka's perspective. To achieve effectively-exactly-once across that boundary, you need application-level idempotency: for example, the database write uses an upsert keyed on the Kafka record's unique business ID, so reprocessing the same record on retry has no additional effect. The combination of at-least-once Kafka delivery plus idempotent downstream writes is the standard production pattern for cross-system exactly-once."

---

##### Q2 — Design Scenario
**"Design a consume-transform-produce pipeline that guarantees exactly-once — e.g., read from payments-input, transform, write to payments-output."**

**One-line answer:** Use a transactional producer with a stable transactional.id, bundle the output write and input offset commit in one transaction via sendOffsetsToTransaction, and set isolation.level=read_committed on the downstream consumer.

**Full answer to give in an interview:**

> "The pattern is called **consume-transform-produce with EOS**. Here is how I'd build it.
>
> On the producer side, configure `transactional.id` to a stable, unique identifier per consumer instance — for example `'payment-processor-' + instanceId`. Set `enable.idempotence=true` and `acks=all`. On the consumer side, set `isolation.level=read_committed` and `enable.auto.commit=false`.
>
> For each batch: call `beginTransaction()`, process the records, call `kafkaTemplate.send('payments-output', key, result)` to write the output, then call `sendOffsetsToTransaction(currentOffsets, groupMetadata)` to bundle the input offset commit inside the transaction, and finally `commitTransaction()`. If any step throws, call `abortTransaction()` — the output records are rolled back and the input offset is not advanced, so the records will be redelivered.
>
> **Zombie fencing** protects against the scenario where two instances start up with the same `transactional.id` — the TC will fence the older epoch, preventing duplicate writes.
>
> The performance cost: each `commitTransaction()` adds roughly 1–5 ms of two-phase commit overhead. To amortise this, process as many records as possible per transaction — tune `max.poll.records` upward and commit once per batch rather than once per record.
>
> In Kafka Streams, all of this is handled automatically by setting `processing.guarantee=exactly_once_v2`."

> *If they ask about Kafka Streams EOS: exactly_once_v2 (EOS v2, introduced in Kafka 2.6) uses a shared transaction coordinator per task group rather than one per thread, reducing coordinator load — prefer it over the older exactly_once setting.*

**Gotcha follow-up they'll ask:** *"What is the Last Stable Offset and how does it affect consumer throughput?"*

> "The **Last Stable Offset (LSO)** is the offset up to which `read_committed` consumers can safely read — it's the offset just before the oldest open (uncommitted, not yet aborted) transaction in the partition. If a transactional producer opens a transaction at offset 100 and takes 30 seconds to commit, all `read_committed` consumers on that partition are blocked at offset 99 for those 30 seconds, even if records at offset 200 are already sitting in the log. This is a real production concern: a slow or stuck transactional producer can cause consumer lag to grow rapidly and trigger processing SLA violations. Monitor LSO lag separately from consumer group lag, and set appropriate `transaction.timeout.ms` on the producer (default 60 seconds) so the TC auto-aborts stuck transactions."

---

> **Common Mistake — not setting isolation.level=read_committed:** If you configure a transactional producer but forget `isolation.level=read_committed` on the consumer, the consumer will happily read records from aborted transactions — seeing data that was supposed to be rolled back. The transactional guarantee on the producer side is useless without the corresponding filter on the consumer side. Always configure both ends.

---

**Quick Revision (one line):**
Kafka EOS uses `transactional.id` + epoch-based zombie fencing for cross-session idempotence, a two-phase commit protocol for atomic multi-partition writes, and `isolation.level=read_committed` on consumers to hide uncommitted records.

---

## Topic 6: Partitioning Strategy

---

#### The Idea

Imagine a busy post office sorting mail into numbered bins. Each bin is a partition. The rule is simple: every letter addressed to "Alice" always goes into bin 3, every letter to "Bob" always goes into bin 7. This guarantees that when someone processes bin 3, they see all of Alice's letters in the exact order they arrived — that is Kafka's ordering guarantee per partition.

The problem is that some people receive far more mail than others. If your celebrity friend gets a thousand letters a day and everyone else gets ten, bin 3 is overflowing while other bins sit empty. That is a hotspot: one partition doing all the work while the rest are idle.

Fixing hotspots means rethinking the "rule" for choosing which bin a message goes into. You can salt the key (spread one person's mail across several bins at the cost of ordering), use a compound key (combine region + user so traffic fans out), or write a custom partitioner that gives high-traffic senders their own dedicated bins.

---

#### How It Works

```
// Default routing for keyed records
partition = murmur2(key) % numPartitions

// For keyless records (Kafka 2.4+ UniformStickyPartitioner)
stick to one partition until batch is full or linger.ms elapses, then rotate
// Better batching than pure per-record round-robin
```

**Hotspot scenarios:**
- Low-cardinality key (e.g., `country`) — most traffic lands on US/EU partitions
- Viral user — `userId` as key but one user generates 100x traffic
- Time-based key (e.g., `date`) — all today's traffic goes to one partition

**Avoidance strategies:**

```
// Key salting: spread load, break ordering
saltedKey = orderId + "-" + random(0, N)

// Compound key: fan out by region+user
compoundKey = regionId + ":" + userId

// Partition count rule of thumb
partitions = max(throughputMB_per_sec / 10, desired_parallelism)
```

**Critical gotcha — partition count increases break key ordering:** adding partitions to a live topic changes `murmur2(key) % numPartitions` for every key. Existing records stay in their old partitions; new records go to newly calculated partitions. Consumers that rely on per-key ordering will see interleaved out-of-order records during and after the resize. You cannot decrease partition count — create a new topic and migrate.

The must-memorise code: a custom partitioner routing VIP orders to dedicated partitions.

```java
import org.apache.kafka.clients.producer.Partitioner;
import org.apache.kafka.common.Cluster;
import org.apache.kafka.common.PartitionInfo;
import java.util.List;
import java.util.Map;

// Routes keys prefixed "VIP-" to partitions 0-2; regular keys to 3-N.
public class OrderPartitioner implements Partitioner {

    private static final int VIP_PARTITION_COUNT = 3;

    @Override
    public int partition(String topic, Object key, byte[] keyBytes,
                         Object value, byte[] valueBytes, Cluster cluster) {
        List<PartitionInfo> partitions = cluster.partitionsForTopic(topic);
        int totalPartitions = partitions.size();

        if (keyBytes == null) {
            return VIP_PARTITION_COUNT +
                   (int)(Math.random() * (totalPartitions - VIP_PARTITION_COUNT));
        }

        String orderKey = new String(keyBytes);
        if (orderKey.startsWith("VIP-")) {
            return Math.abs(murmur2(keyBytes)) % VIP_PARTITION_COUNT;
        }

        int regularPartitions = totalPartitions - VIP_PARTITION_COUNT;
        return VIP_PARTITION_COUNT + (Math.abs(murmur2(keyBytes)) % regularPartitions);
    }

    private int murmur2(byte[] data) {
        return java.util.Arrays.hashCode(data); // use Utils.murmur2 in production
    }

    @Override public void close() {}
    @Override public void configure(Map<String, ?> configs) {}
}

// Wire it up in producer config:
// props.put(ProducerConfig.PARTITIONER_CLASS_CONFIG, OrderPartitioner.class.getName());
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does Kafka decide which partition a message goes to?"**

**One-line answer:** Keyed records use `murmur2(key) % numPartitions` for deterministic routing; keyless records use the sticky partitioner to fill a batch before rotating.

**Full answer to give in an interview:**

> "When a producer sends a message with a key — say, an order ID — Kafka applies the murmur2 hash of that key and takes the result modulo the number of partitions. That calculation is deterministic: the same key always lands on the same partition, which is how Kafka guarantees ordered delivery per key. If I send no key at all, Kafka 2.4 introduced the Uniform Sticky Partitioner: instead of round-robining every single record, it sticks to one partition until the current batch is full or `linger.ms` expires, then picks a new partition. That improves batching efficiency. You can also override both behaviours by supplying a custom `Partitioner` implementation in the producer config."

> *Keep it crisp — the interviewer usually follows up on hotspots, so save that depth for Q2.*

**Gotcha follow-up they'll ask:** *"What happens to key-based ordering if you add partitions to a live topic?"*

> "It breaks. The hash formula is `murmur2(key) % numPartitions`. Once numPartitions changes, the same key now maps to a different partition number. Records already written stay in their old partition; new records go to the new one. Any consumer relying on per-key ordering will see interleaved records from both partitions. This is why partition count changes need careful planning — Kafka provides no way to decrease partitions, and increasing them requires migrating consumers."

---

##### Q2 — Tradeoff Question
**"Your Kafka topic has a hotspot — one partition is getting 80% of all traffic. Walk me through how you would fix it."**

**One-line answer:** Diagnose the key distribution, then choose between key salting (breaks ordering), compound keys, or a custom partitioner that dedicates extra partitions to high-traffic keys.

**Full answer to give in an interview:**

> "First I'd confirm the hotspot by looking at per-partition lag and broker throughput metrics. The root cause is almost always a low-cardinality or skewed key — classic examples are using `country` as a key (most traffic is US/EU), a boolean flag, or a user ID where one viral account generates 100x the events of anyone else. Once I know the cause, I pick a fix based on whether ordering matters. If ordering within a key is not required, key salting is the simplest option: I append a random suffix from 0 to N, which fans the key out across N partitions and distributes load. The downside is that downstream consumers now see records for the same logical entity on multiple partitions, so if I need to reconstruct order I have to dedup or sort. If I do need ordering, I switch to a compound key — for example `regionId:userId` — which provides high cardinality while still grouping semantically. For enterprise use cases like VIP customers requiring guaranteed low-latency processing, I write a custom `Partitioner` that routes those specific keys to a reserved set of partitions backed by higher-capacity consumer threads."

> *Mentioning the tradeoff (salting breaks ordering) shows senior-level thinking.*

**Gotcha follow-up they'll ask:** *"Will adding more partitions solve the hotspot?"*

> "Not if the hotspot is one specific key. If 80% of traffic comes from a single key value, splitting the topic into 200 partitions still sends 80% of records to whichever partition that key hashes to. More partitions help when many keys are competing for the same small set of partitions — it spreads the load across more bins. For a genuinely skewed single key, you need salting or a custom partitioner."

---

##### Q3 — Design Scenario
**"You are designing a Kafka-based order processing pipeline. Orders must be processed in sequence per customer, but some enterprise customers generate 1,000x more orders than standard customers. How do you partition?"**

**One-line answer:** Use a custom partitioner that routes enterprise customer keys to a dedicated reserved partition set and regular customers to the remaining partitions, preserving per-customer ordering in both tiers.

**Full answer to give in an interview:**

> "I would use a two-tier partitioning strategy. First, I'd size the topic: suppose I have 20 partitions total, and enterprise customers — maybe 50 of them — generate 80% of traffic. I would reserve partitions 0 through 9 for enterprise customers and partitions 10 through 19 for standard customers. Then I write a custom `Partitioner`: if the order key starts with an enterprise prefix, I apply `murmur2(key) % 10` to land in the enterprise range; otherwise `10 + murmur2(key) % 10` for the standard range. On the consumer side, I run two separate consumer groups — one with higher-throughput instances assigned to the enterprise partitions, one lighter group on standard partitions. This preserves per-customer ordering (same customer always hits the same partition), avoids enterprise traffic starving standard customers, and lets me scale the two tiers independently."

> *This answer demonstrates you think end-to-end: partitioner + consumer sizing together.*

**Gotcha follow-up they'll ask:** *"What happens when a new enterprise customer signs up and their volume is not yet known?"*

> "I'd configure the partitioner to check a dynamically refreshable set of enterprise customer IDs — loaded from a config store or a feature flag service — rather than hardcoding the prefix check. On startup it loads the set; a background thread refreshes it periodically. New enterprise customers are added to the set before their order volume ramps up, ensuring they land in the right partition range from day one."

---

> **Common Mistake — Low-Cardinality Key:** Choosing a key like `isPremium` (boolean) or `status` (a few values) thinking it ensures ordering creates severe hotspots — all premium orders go to one partition. Always verify key cardinality before choosing it as a partition key.

---

**Quick Revision (one line):**
Keyed records route via `murmur2(key) % numPartitions` for ordering; hotspots from skewed keys require key salting (breaks ordering), compound keys, or a custom partitioner — and adding partitions to a live topic silently breaks existing key-to-partition mappings.

---

## Topic 7: Consumer Lag and Monitoring

---

#### The Idea

Imagine a conveyor belt at a factory carrying boxes past a worker who stamps each one. Consumer lag is how many boxes are piled up on the belt waiting to be stamped — the difference between the last box that arrived and the last box the worker finished. If boxes keep arriving faster than the worker stamps, the pile grows and the factory falls behind.

In Kafka, the conveyor belt is a topic partition. Each position on the belt is an offset — a sequential number. The "log-end offset" (LEO) is the position of the newest message the broker has received. The "committed offset" is the position the consumer group last confirmed it processed. Lag = LEO minus committed offset. If that number is growing, your consumer is falling behind producers.

Lag in records can be misleading if messages have wildly different sizes — a lag of 100 large records might be worse than 10,000 tiny ones. Production systems therefore also measure lag in time: how many milliseconds behind the producer is the consumer, calculated from timestamps embedded in records.

---

#### How It Works

```
// Per-partition lag formula
lag(group, topic, partition) = log_end_offset(partition) - committed_offset(group, partition)

// Total group lag
total_lag = sum of per-partition lags

// Lag in time (preferred for variable message sizes)
lag_ms = lag_records / consumption_rate_per_second * 1000
      OR use producer timestamp in record header for exact wall-clock lag
```

**Key metrics to monitor:**
- `records-lag-max` (JMX) — highest single-partition lag for the consumer group; most critical
- `records-consumed-rate` — records per second being consumed
- `fetch-latency-avg` — network health between consumer and broker
- `commit-rate` — how often offsets are committed

**Alerting strategy:**
```
threshold alert:    lag > 10,000 records for > 5 minutes  → page on-call
rate-of-change:     lag increasing for > 10 consecutive minutes → warning
zero-consumption:   records-consumed-rate = 0 for > 2 minutes → critical
partition imbalance: one partition has 10x lag of others → hot partition or stuck thread
```

The must-memorise code: programmatic lag calculation using the `AdminClient` API (works even when the consumer is dead — unlike JMX metrics, which require a live consumer process).

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

        // Step 1: get what the consumer group has committed
        Map<TopicPartition, OffsetAndMetadata> committedOffsets =
            adminClient.listConsumerGroupOffsets(groupId)
                       .partitionsToOffsetAndMetadata()
                       .get();

        // Step 2: get the latest offset on each partition (log-end offset)
        Map<TopicPartition, OffsetSpec> offsetSpecs = new HashMap<>();
        committedOffsets.keySet().forEach(tp -> offsetSpecs.put(tp, OffsetSpec.latest()));

        Map<TopicPartition, ListOffsetsResult.ListOffsetsResultInfo> latestOffsets =
            adminClient.listOffsets(offsetSpecs).all().get();

        // Step 3: lag = LEO - committed
        Map<TopicPartition, Long> lagMap = new LinkedHashMap<>();
        for (Map.Entry<TopicPartition, OffsetAndMetadata> entry : committedOffsets.entrySet()) {
            TopicPartition tp = entry.getKey();
            long committedOffset = entry.getValue().offset();
            long logEndOffset = latestOffsets.get(tp).offset();
            lagMap.put(tp, logEndOffset - committedOffset);
        }
        return lagMap;
    }

    public void close() { adminClient.close(); }
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is consumer lag and how is it calculated?"**

**One-line answer:** Consumer lag is the log-end offset of a partition minus the last committed offset of the consumer group on that partition — it counts how many messages the consumer has not yet processed.

**Full answer to give in an interview:**

> "Consumer lag measures how far behind a consumer group is from the latest data on a topic partition. Kafka brokers track two numbers per partition: the log-end offset, which is the offset of the newest message written by producers, and the committed offset, which is the offset the consumer group last confirmed it finished processing. Lag is simply log-end offset minus committed offset. If I have five partitions, I sum across all five to get total group lag. The important nuance is that lag in record count can be misleading if messages vary in size — a lag of 500 large records might represent more processing work than 5,000 small ones. Production systems at companies like Netflix therefore also measure lag in milliseconds by comparing the producer timestamp embedded in each record against wall clock time."

> *Mentioning the record-count vs time-lag distinction immediately shows production experience.*

**Gotcha follow-up they'll ask:** *"Lag is 0 — does that mean the consumer is healthy?"*

> "Not necessarily. Zero lag means the consumer has committed offsets up to the log-end offset, but it says nothing about correctness. If the consumer is using at-most-once delivery — committing offsets before processing — it can report zero lag while actually losing messages. Zero lag also occurs when no new messages are being produced, which might look healthy but could mask a stuck consumer. The key health signal is not just lag but also that `records-consumed-rate` is non-zero and that offsets are advancing when new messages arrive."

---

##### Q2 — Tradeoff Question
**"Why is the JMX `records-lag-max` metric sometimes insufficient for production monitoring, and what do you use instead?"**

**One-line answer:** JMX metrics only work while the consumer process is alive — a dead consumer shows no JMX lag at all — so you combine JMX with AdminClient-based polling and tools like Burrow that detect growing lag trends.

**Full answer to give in an interview:**

> "The `records-lag-max` JMX metric is exposed by the consumer process itself. If the consumer crashes or is stuck in a long GC pause, the JMX endpoint goes dark — you get no lag reading at all, which looks like zero lag to naive monitors. This is the most dangerous failure mode: the alerting system thinks everything is fine while lag is actually skyrocketing. To avoid this I use the AdminClient API, specifically `listConsumerGroupOffsets()` combined with `listOffsets()`, to calculate lag server-side against broker data regardless of whether consumers are running. I also use Burrow, which LinkedIn open-sourced: rather than checking instantaneous lag, Burrow applies a sliding window to detect whether lag is growing monotonically over time — a much stronger signal that a consumer is falling behind, as opposed to a temporary spike that recovers. For per-partition visibility, I alert separately when one partition has ten times the lag of others, which flags hot partitions or a stuck consumer thread without waiting for total group lag to cross a threshold."

> *Naming Burrow's sliding-window analysis distinguishes you from candidates who only know JMX.*

**Gotcha follow-up they'll ask:** *"Can consumer lag be negative?"*

> "In theory no, but in practice AdminClient calculations can briefly show negative values due to a race condition: the consumer commits an offset at the same moment the broker is updating its log-end offset metadata. Treat any negative lag reading as zero — it is a transient artefact of the measurement, not a real state."

---

##### Q3 — Design Scenario
**"Design a lag monitoring system for 50 consumer groups across 200 topics. What would you build?"**

**One-line answer:** A polling service using AdminClient to calculate per-partition lag every 30 seconds, publishing metrics to Prometheus with Grafana dashboards and multi-tier alerts combining threshold, rate-of-change, and zero-consumption rules.

**Full answer to give in an interview:**

> "I would build a standalone monitoring service — not embedded in the consumer — that runs on a separate JVM so it works even when consumers are down. Every 30 seconds it calls `listConsumerGroupOffsets()` for all 50 groups and `listOffsets()` for their partitions, calculates lag per partition, and publishes Prometheus gauges labelled by group, topic, and partition. In Grafana I'd set up three alert tiers: first, an absolute threshold — lag above 10,000 records for more than five minutes pages the on-call engineer; second, a rate-of-change rule — lag increasing for ten consecutive polling intervals fires a warning before it becomes critical; third, a zero-consumption alert — if `records-consumed-rate` from JMX is zero for two minutes while lag is non-zero, that means the consumer is alive but stuck, which is a critical page. For topics where message size varies, I'd also track lag in milliseconds by comparing the producer timestamp in the latest unprocessed record against wall clock time. All metrics are retained for 30 days for capacity planning."

> *Showing the three alert tiers demonstrates that you think about failure modes, not just steady-state.*

**Gotcha follow-up they'll ask:** *"What causes lag to grow even when `records-consumed-rate` is non-zero?"*

> "Several things: the consumer is processing but not fast enough — producers are writing faster than the consumer can handle, so lag grows even though consumption is happening. A rebalance can temporarily stall partitions being migrated between consumer instances. A slow downstream dependency — a database write, an HTTP call — can bottleneck the processing loop. Finally, a consumer with manual offset commit might be consuming but delaying commits, so the committed offset doesn't advance even though records are being read."

---

> **Common Mistake — Monitoring Total Lag Only:** Alerting on total group lag without checking per-partition breakdown lets a single stuck partition be hidden by healthy ones. Always alert at partition granularity and check that `records-consumed-rate` is non-zero independently of the lag number.

---

**Quick Revision (one line):**
Consumer lag equals log-end offset minus committed offset per partition; monitor with AdminClient API (works when consumers are dead) and Burrow's sliding-window trend analysis, and alert on both absolute threshold and monotonically growing lag.

---

## Topic 8: Kafka Streams

---

#### The Idea

Imagine two kinds of whiteboards in a meeting room. The first whiteboard is a running log: every time someone calls in, you write down what they said in order — you never erase anything, just keep appending. That is a KStream: each record is an independent event, an immutable fact about something that happened. The second whiteboard is a scoreboard: it shows the current score, and whenever a team scores you overwrite the old number. That is a KTable: each record is an update to the latest known value for a key.

Kafka Streams is a Java library that lets you process these streams inside your application — no separate cluster like Flink or Spark needed. It runs as threads inside your JVM and uses Kafka partitions directly for parallelism. The magic is that it can do stateful computations — counting, summing, joining — by maintaining a local database (RocksDB) on each instance, backed by a Kafka changelog topic for fault tolerance.

Windowing adds a time dimension to stateful computations. Instead of counting all events since the beginning of time, you count events within a five-minute bucket (tumbling window), or within a rolling ten-minute window that advances every five minutes (hopping window), or within a session that stretches as long as a user keeps interacting (session window).

---

#### How It Works

```
// KStream: insert semantics — every record is a new independent event
stream = builder.stream("clicks")       // append-only log
stream.filter(r -> r.value > 0)
stream.map(r -> new KeyValue(r.key, transform(r.value)))

// KTable: upsert semantics — each record replaces the prior value for that key
table = builder.table("user-profiles")  // materialized view, latest value per key
// When key "user-123" appears again, the old value is overwritten

// GlobalKTable: full copy on every instance — join without co-partitioning
globalTable = builder.globalTable("config-data")
```

**Windowing types:**
```
// Tumbling: fixed-size, non-overlapping
// Event at t=4m → window [0,5). Event at t=6m → window [5,10).
TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5))

// Hopping: fixed-size, overlapping — a record may land in multiple windows
// size=10m, advance=5m → event at t=6m falls in [0,10) AND [5,15)
TimeWindows.of(Duration.ofMinutes(10)).advanceBy(Duration.ofMinutes(5))

// Session: dynamic size — events within gap of each other merge into one session
SessionWindows.ofInactivityGapWithNoGrace(Duration.ofMinutes(30))
```

**State store fault tolerance:**
```
stateful operation  →  local RocksDB state store
                    →  backed by changelog Kafka topic (log-compacted)
on restart          →  replay changelog to restore state
num.standby.replicas=1  →  warm copy on another instance, faster recovery
```

The must-memorise gotcha: the KTable vs KStream distinction and stateful windowed aggregation wired to a state store.

```java
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.*;
import org.apache.kafka.streams.kstream.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.kafka.config.KafkaStreamsDefaultConfiguration;
import java.time.Duration;
import java.util.Properties;

@Configuration
@EnableKafkaStreams
public class KafkaStreamsConfig {

    // KStream example: count page views per URL in 5-minute tumbling windows
    @Bean
    public KStream<String, String> pageViewStream(StreamsBuilder builder) {
        KStream<String, String> pageViews = builder.stream(
            "page-views",
            Consumed.with(Serdes.String(), Serdes.String())
        );

        // Tumbling window: non-overlapping 5-minute buckets
        // Materialized.as() names the RocksDB state store
        KTable<Windowed<String>, Long> viewCounts = pageViews
            .groupByKey()
            .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5)))
            .count(Materialized.as("page-view-counts"));  // state store name

        viewCounts.toStream()
            .map((windowedKey, count) -> KeyValue.pair(
                windowedKey.key() + "@" + windowedKey.window().startTime(),
                String.valueOf(count)
            ))
            .to("page-view-aggregates", Produced.with(Serdes.String(), Serdes.String()));

        return pageViews;
    }

    // KTable example: enrich click stream with user profile (KStream-KTable join)
    @Bean
    public KStream<String, String> enrichedClickStream(StreamsBuilder builder) {
        KStream<String, String> clicks = builder.stream(
            "user-clicks", Consumed.with(Serdes.String(), Serdes.String()));

        // KTable holds the latest user profile per userId key — upsert semantics
        KTable<String, String> userProfiles = builder.table(
            "user-profiles", Consumed.with(Serdes.String(), Serdes.String()));

        // Non-windowed join: each click is enriched with the current profile value
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
        // exactly_once_v2 (Kafka 2.6+): shared transaction producer per StreamThread
        // v1 used one producer per task — much higher overhead
        props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.EXACTLY_ONCE_V2);
        props.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, 1);
        return new KafkaStreamsConfiguration(props.entrySet().stream()
            .collect(java.util.stream.Collectors.toMap(
                e -> e.getKey().toString(), Map.Entry::getValue)));
    }
}
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between a KStream and a KTable in Kafka Streams?"**

**One-line answer:** KStream has insert semantics — every record is a new independent event; KTable has upsert semantics — each record replaces the previous value for that key, representing the latest known state.

**Full answer to give in an interview:**

> "The distinction comes down to what each record means. In a KStream, every message is a new, independent fact — think of a clickstream where each click event is its own entry. If the same user clicks twice, I get two records, and both matter. KStream operations like filter, map, and flatMap treat every record as immutable and independent. A KTable, by contrast, is like a database table where each key has exactly one current value. When a new record arrives for a key that already has a value, the KTable overwrites the old one — upsert semantics. This makes KTable ideal for holding current state: user profiles, account balances, feature flag settings. The practical consequence in joins is important: a KStream-KTable join is non-windowed — for every stream record, Kafka Streams looks up the current KTable value for that key. A KStream-KStream join requires both sides to be windowed because two event streams have no concept of 'current value' — you have to bound the join in time."

> *The join consequence is what interviewers really want to hear — lead there.*

**Gotcha follow-up they'll ask:** *"What is a GlobalKTable and when would you use it?"*

> "A GlobalKTable is a KTable where the full contents are replicated to every Kafka Streams instance in the application, regardless of partition assignment. A regular KTable is co-partitioned — each instance only holds the slice of the table for its assigned partitions, so a KStream-KTable join only works if both topics have the same number of partitions and use the same partitioning key. If they don't, Kafka throws a TopologyException. A GlobalKTable sidesteps this: since every instance has the full table, a stream record with any key can be looked up locally without co-partitioning. The trade-off is memory and replication cost — GlobalKTable is only practical for smaller, slowly-changing reference data like config tables or country codes."

---

##### Q2 — Tradeoff Question
**"Explain the three Kafka Streams window types and when you would choose each."**

**One-line answer:** Tumbling windows are fixed non-overlapping buckets for per-period aggregations; hopping windows are fixed overlapping buckets for moving averages; session windows are gap-based and dynamically sized for user activity analytics.

**Full answer to give in an interview:**

> "Tumbling windows divide time into fixed-size, non-overlapping buckets. A record belongs to exactly one window. If I'm counting page views per five minutes, tumbling is the right choice — I want clean, non-overlapping periods that don't double-count. Hopping windows are also fixed-size but they overlap: a ten-minute window advancing every five minutes means every record falls into two windows. That is the right model for moving averages or rolling sums where I care about recent trends, not clean periods. Session windows are different in kind — they are event-driven rather than clock-driven. A session is created when the first event arrives; as long as new events keep coming within an inactivity gap — say 30 minutes — they are merged into the same session. When no event arrives for 30 minutes the session closes. This naturally models user sessions on a website without needing to know their length in advance. The operational gotcha with all three is the grace period: by default, `ofSizeWithNoGrace` drops late-arriving records — records that arrive after their window has closed. In production you almost always want to set a non-zero grace period to handle out-of-order events."

> *Mentioning the grace period / late arrivals gotcha is a strong differentiator.*

**Gotcha follow-up they'll ask:** *"How does Kafka Streams recover state after a crash?"*

> "Every stateful operation — windowed count, aggregation, join — writes to a local RocksDB state store on disk. That state store is backed by a Kafka changelog topic that is log-compacted, meaning it retains the latest value per key. On restart, Kafka Streams replays the changelog topic to rebuild the state store. This can be slow for large state. To speed it up, you set `num.standby.replicas=1`, which keeps a warm copy of the state store on a second instance. When the primary crashes, the standby can take over with minimal replay needed."

---

##### Q3 — Design Scenario
**"Design a real-time surge pricing calculation for a ride-sharing app using Kafka Streams."**

**One-line answer:** Aggregate a KStream of trip requests by geohash in a one-minute tumbling window, join with a KTable of driver availability, compute demand/supply ratio, and write the surge multiplier back to an output topic.

**Full answer to give in an interview:**

> "I'd model it as a pipeline with two inputs and one output. The first input is a KStream from the `trip-requests` topic, keyed by geohash — a string that encodes a geographic cell at roughly city-block granularity. The second input is a KTable from the `driver-locations` topic, also keyed by geohash, holding the current count of available drivers in that cell — upsert semantics, so it always reflects the latest known driver count. In the Streams topology, I group the trip-request KStream by geohash and aggregate with a one-minute tumbling window to count requests per cell per minute — this produces a KTable of `(geohash, window) -> requestCount`. I then join that with the driver KTable: for each windowed request count, I look up the current driver availability for that geohash and compute `surgeMultiplier = requestCount / driverCount` with a floor of 1.0. The result is written to a `surge-multipliers` output topic that the pricing service consumes. State is stored in RocksDB per Streams instance. I'd set `processing.guarantee=EXACTLY_ONCE_V2` to prevent double-counting a surge update, and `num.standby.replicas=1` for fast failover."

> *Walking through the topology step by step — KStream, KTable, join, output — is exactly what interviewers want.*

**Gotcha follow-up they'll ask:** *"What is the difference between `exactly_once` and `exactly_once_v2` in Kafka Streams config?"*

> "Both guarantee that each record is processed and its result produced to the output topic exactly once, even on failures. The difference is implementation efficiency. In `exactly_once` (v1), Kafka Streams creates one transactional producer per task — if a StreamThread manages ten tasks, that is ten producers, each with its own transaction coordinator overhead. `exactly_once_v2`, introduced in Kafka 2.6, uses one shared transactional producer per StreamThread instead of per task, dramatically reducing the number of open transactions and the coordinator load. V2 requires brokers running Kafka 2.5 or later. For new deployments, always use v2."

---

> **Common Mistake — Not Co-Partitioning for Joins:** Joining a KStream and a KTable that have different partition counts or different partition keys throws a `TopologyException` at startup. Before wiring a join, confirm both topics are co-partitioned — same partition count, same key, same partitioner. If they are not, use a GlobalKTable for the smaller side.

---

**Quick Revision (one line):**
KStream treats every record as an independent insert; KTable treats each record as an upsert to the latest value; windowed aggregations (tumbling/hopping/session) maintain state in local RocksDB stores backed by changelog topics, with `exactly_once_v2` guaranteeing each record affects output exactly once.

---

## Topic 9: Kafka Connect

---

#### The Idea

Imagine a universal adapter plug that lets you connect any device to any power socket in the world. Kafka Connect is that adapter for data: it provides a standard framework for moving data between Kafka and external systems — databases, object stores, search indexes, file systems — without writing custom consumer or producer code for every integration.

The framework has two directions. A source connector reads from an external system and writes into Kafka — for example, reading every new row from a MySQL table and publishing it as a Kafka message. A sink connector reads from Kafka and writes into an external system — for example, taking Kafka messages and indexing them into Elasticsearch. Connectors run inside worker processes, and each connector manages multiple tasks that run in parallel.

The most powerful source connector is Debezium, which implements CDC — Change Data Capture. Instead of polling a database table for new rows (which misses deletes and updates), Debezium reads the database's internal binary log — the same log MySQL or Postgres uses for replication — and produces a Kafka event for every single row-level INSERT, UPDATE, and DELETE. This gives you a real-time, complete audit trail of every change with latency under 100 milliseconds.

---

#### How It Works

```
// Connect cluster roles
Workers  → JVM processes; distributed mode forms a cluster, tasks spread across workers
Connectors → logical config unit; each manages N tasks
Tasks    → actual work units; source task pulls from external system, sink task pushes to it

// Internal Kafka topics (created automatically)
connect-offsets  → tracks source progress (file position, DB log position)
connect-configs  → stores connector configurations
connect-status   → tracks task health
```

**Source connector strategies:**
```
JdbcSourceConnector   → polls DB table for new/changed rows (timestamp or incrementing column)
                         limitation: misses DELETEs, high DB poll load, higher latency
Debezium (CDC)        → reads database binary log, captures INSERT/UPDATE/DELETE
                         low latency (<100ms), zero polling load on DB, complete change history
```

**Single Message Transforms (SMTs) — stateless per-record transforms in the connector chain:**
```
InsertField      → add a field to the record (e.g., ingest timestamp)
ReplaceField     → rename or drop fields
MaskField        → replace field value with a mask (PII redaction)
TimestampRouter  → route to time-partitioned topic names
ValueToKey       → promote a record field to become the message key
Flatten          → flatten nested structs to dot-notation keys

// Chain multiple SMTs:
transforms=addTimestamp,redactEmail
transforms.addTimestamp.type=org.apache.kafka.connect.transforms.InsertField$Value
transforms.addTimestamp.timestamp.field=kafka_ingest_ts
```

**Debezium event envelope:**
```json
{
  "before": { "id": 1, "email": "old@example.com" },
  "after":  { "id": 1, "email": "new@example.com" },
  "op": "u",
  "ts_ms": 1700000000000,
  "source": { "db": "orders", "table": "order_items" }
}
// op values: c=create (INSERT), u=update (UPDATE), d=delete (DELETE), r=read (snapshot)
```

The must-memorise code: Debezium MySQL connector configuration and a Spring Boot consumer handling CDC events.

```json
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

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is Kafka Connect and how do source and sink connectors differ?"**

**One-line answer:** Kafka Connect is a framework for streaming data between Kafka and external systems; source connectors pull data from an external system into Kafka, sink connectors push data from Kafka into an external system.

**Full answer to give in an interview:**

> "Kafka Connect is a scalable, fault-tolerant framework that standardises how data moves between Kafka and the outside world. Without it, every integration requires a custom producer or consumer application — error handling, offset tracking, parallelism, all written from scratch each time. Connect provides that infrastructure once: connectors are just configuration files that specify the external system, topic names, and any transforms, while the Connect workers handle execution, fault tolerance, and offset management. A source connector reads from an external system and writes to Kafka — a common example is JdbcSourceConnector polling a database table for new rows, or Debezium reading MySQL's binary log for real-time CDC. A sink connector reads from Kafka and writes to an external system — ElasticsearchSinkConnector indexing records, S3SinkConnector writing Parquet files to object storage. In distributed mode, multiple worker nodes share the connector tasks, so if one worker fails another picks up its tasks automatically. Connector state — which file offset, which DB log position — is stored in Kafka topics, so it survives worker restarts without replay."

> *Mentioning offset storage in Kafka topics is the detail that shows you understand the architecture.*

**Gotcha follow-up they'll ask:** *"Is Kafka Connect fault-tolerant without Zookeeper?"*

> "Yes, fully. In distributed mode, Connect stores connector configurations, task offsets, and task status in three internal Kafka topics: `connect-configs`, `connect-offsets`, and `connect-status`. Zookeeper is not involved. This means Connect can run in environments that have migrated to KRaft-based Kafka, and the configuration persists independently of which worker process is currently running. Workers elect a group leader using Kafka's consumer group protocol — the same mechanism as consumer group rebalancing."

---

##### Q2 — Tradeoff Question
**"Compare JDBC polling source connectors with Debezium CDC. When would you choose each?"**

**One-line answer:** JDBC polling is simple to set up but misses deletes, has higher DB load, and has higher latency; Debezium reads the binary log for complete, low-latency change capture but requires database replication privileges and more operational complexity.

**Full answer to give in an interview:**

> "JdbcSourceConnector works by periodically querying a database table — say every 60 seconds — for rows where an `updated_at` timestamp is greater than the last seen value. It is simple to configure, works with any JDBC-compatible database, and requires no special database privileges beyond SELECT. But it has three fundamental limitations: first, it cannot detect row deletions — a deleted row simply disappears from the query results with no event produced. Second, it creates polling load on the source database — at scale this can be significant. Third, the latency equals the poll interval, so events are at best 60 seconds stale. Debezium solves all three by reading the database's internal replication log directly — MySQL binlog, Postgres WAL, Oracle LogMiner. Every INSERT, UPDATE, and DELETE produces a Kafka event with before and after values, operation type, and a timestamp, with latency typically under 100 milliseconds. The trade-offs are complexity: the source database must have binary logging enabled in ROW format for MySQL, or a logical replication slot configured for Postgres. Debezium requires a dedicated database account with REPLICATION privilege. For Postgres, you must monitor replication slot lag, because a slow or idle Debezium connector can cause WAL to accumulate and fill the disk. Choose JDBC polling for simple, low-volume use cases where deletes do not matter and latency of minutes is acceptable. Choose Debezium for real-time pipelines, event sourcing, audit trails, and any case where deletes must be captured."

> *The WAL disk accumulation risk for Postgres is a production gotcha that shows hands-on experience.*

**Gotcha follow-up they'll ask:** *"Can Single Message Transforms do joins or aggregations?"*

> "No. SMTs are stateless, per-record transforms — they operate on one record at a time with no access to any other record. For stateless work like adding a timestamp field, masking a PII field, or renaming columns they are perfect. For anything requiring state — joining two streams, counting, deduplication, sessionisation — you need Kafka Streams or a downstream consumer application. Chaining too many SMTs also degrades connector throughput because each transform adds CPU per record; complex logic belongs in the processing layer, not the connector."

---

##### Q3 — Design Scenario
**"Design a real-time data pipeline that captures every order change from a MySQL database and makes it queryable in Elasticsearch within 5 seconds."**

**One-line answer:** Debezium MySQL source connector captures binlog changes to Kafka, an SMT unwraps the envelope and adds an ingest timestamp, and an Elasticsearch sink connector indexes the records — all within the 5-second SLA.

**Full answer to give in an interview:**

> "I'd build this as a three-stage Connect pipeline with no custom code. Stage one: deploy a Debezium MySQL connector pointing at the primary MySQL instance. MySQL must have `binlog_format=ROW` enabled. Debezium reads the binlog and produces one Kafka message per change event to a topic named `mysql-orders.orders_db.orders`, with the full before/after payload. End-to-end latency from MySQL commit to Kafka message is typically under 100 milliseconds. Stage two: configure SMTs on the connector — first `ExtractNewRecordState` to unwrap Debezium's nested envelope down to just the `after` fields for inserts and updates, plus tombstone records for deletes; then `InsertField` to add a `kafka_ingest_ts` timestamp field for observability. Stage three: deploy an ElasticsearchSinkConnector consuming from that topic, configured to use the record key as the Elasticsearch document ID and UPSERT mode, so updates correctly overwrite existing documents rather than creating duplicates. The Elasticsearch connector batches records and flushes every second by default, which puts total pipeline latency well under the 5-second SLA. For resilience, I'd run three Connect workers in distributed mode so any single worker failure triggers automatic task redistribution without human intervention."

> *Calling out `UPSERT mode` and document ID mapping for Elasticsearch shows you have actually debugged duplicate records.*

**Gotcha follow-up they'll ask:** *"Debezium has been running for a month and the Postgres disk is filling up. What happened?"*

> "That is the WAL accumulation problem. Postgres logical replication slots retain all WAL segments that the slot has not yet consumed. If Debezium is slow, paused, or misconfigured, the replication slot falls behind and Postgres cannot reclaim old WAL files. This grows until the disk is full and Postgres crashes. The fix is to monitor replication slot lag in Postgres with `pg_replication_slots` — alert when `pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)` exceeds a threshold like 10 GB. If the connector is permanently stopped, drop the replication slot immediately."

---

> **Common Mistake — Duplicate `database.server.id` Values:** Running two Debezium MySQL connectors against the same MySQL cluster with the same `database.server.id` causes MySQL to think it is replicating to the same replica twice, resulting in replication conflicts and missed events. Every Debezium instance must have a globally unique server ID.

---

**Quick Revision (one line):**
Kafka Connect streams data between external systems and Kafka via source and sink connectors with lightweight stateless SMTs for per-record transforms; Debezium reads the database binary log to produce low-latency (<100ms) change events including deletes, which JDBC polling cannot capture.

---

## Topic 10: Schema Registry and Avro

---

#### The Idea

Imagine two teams in different buildings exchanging messages in envelopes. The sender writes a letter using an agreed template — field 1 is the customer ID, field 2 is the amount. The receiver reads the letter by following the same template. If the sender one day adds a new field 3 for currency without telling the receiver, the receiver's code might crash trying to parse a structure it does not recognise.

Schema Registry solves this coordination problem. It is a central catalogue that stores every version of every message format (schema). When a producer sends a message, it registers its schema with the registry and receives back a small integer ID — say, 42. It then embeds that ID in the first five bytes of every message it sends. When a consumer receives the message, it reads those five bytes, fetches schema 42 from the registry (caching it locally), and uses that schema to deserialise the rest of the bytes. Both sides always know exactly what structure to expect, without embedding the full schema in every message.

Avro is the most common serialisation format used with Schema Registry. It is compact (binary, not text), fast, and schema-aware — a valid Avro message cannot be written or read without a schema. The critical discipline is schema evolution: when you need to change the schema, you must do so in a way that does not break existing consumers or producers. The registry enforces compatibility rules so that incompatible schemas are rejected before they reach production.

---

#### How It Works

```
// Wire format of every Kafka message serialised with KafkaAvroSerializer
[Magic Byte: 0x00][Schema ID: 4 bytes big-endian][Avro Binary Payload]

// Producer flow
1. producer calls KafkaAvroSerializer.serialize(record)
2. serialiser registers schema → GET /subjects/{topic}-value/versions (or POST if new)
3. registry returns schema ID (e.g. 42)
4. serialiser writes: 0x00 + int32(42) + avro_binary(record)

// Consumer flow
1. consumer calls KafkaAvroDeserialiser.deserialise(bytes)
2. deserialiser reads magic byte (must be 0x00) + schema ID (42)
3. deserialiser checks local cache; if miss: GET /schemas/ids/42 from registry
4. deserialiser uses schema 42 to decode the avro binary payload
```

**Subject naming strategies:**
```
TopicNameStrategy (default)  → subject = "{topic}-value" or "{topic}-key"
                                one schema per topic; fails if multiple record types share a topic
RecordNameStrategy           → subject = fully-qualified record class name
                                multiple record types can share a topic
TopicRecordNameStrategy      → subject = "{topic}-{recordName}"
                                scoped per topic per record type
```

**Schema evolution compatibility modes:**
```
BACKWARD (default)  → new schema can read data written with old schema
                       safe change: ADD optional field with default value
                       unsafe:      REMOVE a required field, CHANGE a field type

FORWARD             → old schema can read data written with new schema
                       safe change: REMOVE an optional field (old reader ignores it)
                       unsafe:      ADD a required field without default
                                    (old reader cannot parse the new record)

FULL                → both BACKWARD and FULL — the safest, most restrictive
                       only safe change: ADD or REMOVE optional fields with defaults

NONE                → no compatibility check — any change allowed (dangerous in production)
```

The must-memorise gotcha: schema evolution compatibility modes and which is the safe default.

```java
// Spring Boot 3.x + spring-kafka + Confluent Avro serialiser

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
        // DANGER in production: set to false and register schemas in CI/CD instead
        props.put("auto.register.schemas", false);
        return new DefaultKafkaProducerFactory<>(props);
    }

    @Bean
    public ConsumerFactory<String, Object> avroConsumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "order-avro-group");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class);
        props.put("schema.registry.url", SCHEMA_REGISTRY_URL);
        // true = return the generated Java class (Order), not a GenericRecord map
        props.put(KafkaAvroDeserializerConfig.SPECIFIC_AVRO_READER_CONFIG, true);
        return new DefaultKafkaConsumerFactory<>(props);
    }
}

// Avro schema evolution example
// v1 schema (Order.avsc)
// { "type": "record", "name": "Order", "fields": [
//   { "name": "id",     "type": "string" },
//   { "name": "amount", "type": "double" }
// ]}

// v2 schema — BACKWARD compatible: optional field with default
// { "type": "record", "name": "Order", "fields": [
//   { "name": "id",       "type": "string" },
//   { "name": "amount",   "type": "double" },
//   { "name": "currency", "type": "string", "default": "USD" }  // safe: has default
// ]}

// v2 would be REJECTED if compatibility=BACKWARD and currency had no default,
// because a new consumer reading old v1 records would have no value for currency.
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does Confluent Schema Registry work with Avro — walk me through what happens when a producer sends a message."**

**One-line answer:** The producer serialises the record to Avro binary, registers (or looks up) the schema to get a 4-byte ID, prepends a magic byte plus that ID to the payload, and the consumer reverses the process using the cached schema.

**Full answer to give in an interview:**

> "When a producer calls `KafkaAvroSerializer.serialize()`, three things happen. First, the serialiser contacts Schema Registry to register or look up the schema for the topic subject — by default, the subject is the topic name plus `-value`, so for a topic called `orders` the subject is `orders-value`. If the schema is new, Registry assigns it an integer ID, say 42, and stores it durably in a Kafka topic called `_schemas` with log compaction. If the schema was already registered, Registry returns the existing ID. Second, the serialiser writes the wire format: one magic byte (always `0x00`, a sentinel that tells consumers this is a Registry-managed message), four bytes containing the schema ID in big-endian format, and then the Avro binary payload. Third, the consumer receives this message, reads the first five bytes to extract the schema ID, checks its local in-memory cache — to avoid hitting the registry on every record — and on a cache miss fetches the schema with `GET /schemas/ids/42`. It then uses that schema to decode the binary payload. The whole round trip adds roughly one HTTP call per unique schema per consumer lifetime, not per message."

> *Explaining the caching behaviour shows you understand this is production-safe at scale.*

**Gotcha follow-up they'll ask:** *"Does Schema Registry store schemas in Zookeeper?"*

> "No. Schema Registry stores all schemas in a Kafka topic called `_schemas` with log compaction, which retains the latest version of each schema indefinitely. Schema Registry itself is a stateless REST service — you can run multiple instances for high availability, with one designated as the primary writer to prevent concurrent registration conflicts. Because it is stateless, it does not depend on Zookeeper at all and works with KRaft-based Kafka clusters."

---

##### Q2 — Tradeoff Question
**"Explain the three schema compatibility modes — BACKWARD, FORWARD, and FULL — and which one you would use as a default in production."**

**One-line answer:** BACKWARD means new consumers can read old data (add optional fields with defaults); FORWARD means old consumers can read new data (remove optional fields); FULL requires both and is the safest default because it allows rolling deployments without coordination.

**Full answer to give in an interview:**

> "The three modes answer the question: which side can be deployed first without breaking the other? BACKWARD compatibility means the new schema can deserialise data written with the old schema. Practically, this means you can deploy a new consumer before the old producer is updated — the consumer can read historical messages even though they were written with the old schema. The only schema change that is BACKWARD safe is adding an optional field with a default value: when the new consumer reads an old message that lacks the new field, it uses the default. FORWARD compatibility is the mirror: the old schema can deserialise data written with the new schema. This means you can deploy a new producer before updating consumers — old consumers can still read the new messages. The safe change here is removing an optional field: old consumers that expect that field get the default, new consumers stop writing it. FULL compatibility requires both at once: you can deploy either side first. The only safe change is adding or removing optional fields with defaults — which is actually what most normal schema evolution looks like. I use FULL as the production default because it enforces the strictest discipline and allows rolling blue-green deployments without any deployment ordering requirement. BACKWARD is a reasonable second choice if you always update consumers before producers."

> *The deployment ordering consequence — which side can go first — is what interviewers are really testing.*

**Gotcha follow-up they'll ask:** *"What is TRANSITIVE compatibility and when does it matter?"*

> "Non-transitive BACKWARD only checks compatibility between the new schema and the immediately previous version. TRANSITIVE_BACKWARD checks the new schema against every prior version. This matters when historical data is still in the topic and consumers replaying from the beginning will encounter old schema versions, not just the latest. If you have log compaction disabled and retention is long — say 90 days — any consumer replaying from day 1 will encounter every schema version that existed during that period. TRANSITIVE mode ensures compatibility across all of them, not just the last one. For most operational topics with short retention, non-transitive is fine. For event-sourced systems where the full history is replayed on rebuild, TRANSITIVE is safer."

---

##### Q3 — Design Scenario
**"Your Order service needs to add a `customerId` field to the Kafka message schema. There are 12 downstream consumers already deployed. How do you roll this change safely?"**

**One-line answer:** Add `customerId` as an optional Avro field with a default value of null, register the new schema against the subject (Schema Registry enforces BACKWARD compatibility), deploy consumers first, then the updated producer — no consumer redeployment needed for old messages.

**Full answer to give in an interview:**

> "The safe path depends on the compatibility mode configured for the `orders-value` subject in Schema Registry. Assuming we run FULL or BACKWARD, which is the standard, I take these steps. First, I update the Avro schema file to add `customerId` as a nullable field with a default of null: in Avro JSON that looks like `{ 'name': 'customerId', 'type': ['null', 'string'], 'default': null }`. This is a BACKWARD-compatible change: new consumers reading old messages that lack `customerId` get null, which is handled gracefully. Second, I register the new schema against Schema Registry in the CI/CD pipeline — never at runtime with `auto.register.schemas=true`. Registry validates compatibility and either accepts the schema and assigns a new ID, or rejects it with an HTTP 409 if the change violates the configured mode. Third, I deploy the 12 downstream consumers with the updated generated Avro class. Since the change is BACKWARD compatible, they continue to work correctly against both old messages (null `customerId`) and new messages. Fourth, I deploy the updated Order service producer. From this point it sends messages with schema v2 and a real `customerId` value. No consumer restart is needed because they already have the updated schema. The key discipline here is registering the schema in CI/CD and not production startup — this way an accidental incompatible change fails the build pipeline before any consumer or producer is deployed."

> *The CI/CD registration point — not `auto.register.schemas=true` — is the senior-level signal interviewers look for.*

**Gotcha follow-up they'll ask:** *"What happens if a producer tries to register a schema that is NOT backward compatible?"*

> "Schema Registry rejects it with an HTTP 409 Conflict response. The KafkaAvroSerializer receives a non-2xx response, throws a `SerializationException`, and the `producer.send()` call fails. If this happens at application startup, the application fails to start — which is the desired behaviour if schema registration is done eagerly on boot. If `auto.register.schemas=true` and the registration happens lazily on the first `send()` call, the first message that uses the incompatible schema triggers the exception and that message is lost unless the application handles the exception and retries after a schema fix. This is why incompatible schema changes should be caught in CI/CD using the Schema Registry compatibility check endpoint, not discovered at runtime."

---

> **Common Mistake — `auto.register.schemas=true` in Production:** Leaving auto-registration enabled means any developer who deploys a service with an accidentally incompatible schema registers it immediately against production data. Once incompatible data is written to the topic, consumers will crash deserialising it. Always set `auto.register.schemas=false` in production and register schemas explicitly as part of the CI/CD pipeline.

---

**Quick Revision (one line):**
Schema Registry stores Avro schemas by subject and embeds a 4-byte schema ID in every message; BACKWARD compatibility (the safe default) requires new optional fields to carry default values so new consumers can read old data, while FULL compatibility additionally ensures old consumers can read new data — use FULL for rolling deployments with no ordering requirement.

---

## Topic 11: Kafka in Spring Boot

---

#### The Idea

Think of a Kafka consumer in Spring Boot like a cashier at a supermarket. The cashier picks up items from the conveyor belt (polls records), scans each one (processes the message), and only moves the receipt to the "done" pile after the item is successfully bagged (manual acknowledgment). If something goes wrong mid-scan, the item stays on the belt and gets retried — it is never silently dropped.

Spring Boot's `@KafkaListener` annotation wires this loop automatically. Under the hood, Spring creates a `ConcurrentMessageListenerContainer` — a managed thread that runs a Kafka consumer poll loop. You annotate a method, Spring calls it for every record, and you control when the offset is committed.

For production systems you need two more things: a retry strategy for transient failures, and a dead-letter topic (DLT) for records that fail every retry attempt. Spring Kafka gives you two tools: `DefaultErrorHandler` for blocking retry (the consumer thread waits between attempts) and `@RetryableTopic` for non-blocking retry (failed records are re-published to separate retry topics, so the main consumer thread is never stalled waiting for a cooldown).

---

#### How It Works

```
Consumer thread starts polling topic "payment-events"
  → poll() returns a batch of ConsumerRecords
  → for each record:
      call @KafkaListener method
      if success → ack.acknowledge() → offset committed
      if exception thrown:
          DefaultErrorHandler intercepts
          retry up to N times with BackOff delay
          if still failing → DeadLetterPublishingRecoverer sends to "payment-events-dlt"
          offset committed (past the failed record)
```

**AckMode choices (set on the container factory):**
- `RECORD` — commit after every single record. Safest, slowest.
- `BATCH` — commit after the entire poll batch is processed. Good balance.
- `MANUAL_IMMEDIATE` — your code calls `ack.acknowledge()`; commit fires immediately. Use when you need precise control.
- `MANUAL` — your code calls `ack.acknowledge()`; commit fires on next poll. Slightly deferred.

**Non-blocking retry with `@RetryableTopic`:**
```
Original topic: "notification-events"
  → failure on attempt 1 → re-published to "notification-events-retry-0" (delay: 1s)
  → failure on attempt 2 → re-published to "notification-events-retry-1" (delay: 2s)
  → failure on attempt 3 → re-published to "notification-events-retry-2" (delay: 4s)
  → failure on attempt 4 → re-published to "notification-events-dlt"
```
The main consumer thread is free to process new records during each delay window. A separate retry consumer picks up the retry topic after the delay header expires.

**Must-memorise gotcha — manual ack with `@RetryableTopic`:**

```java
// WRONG: mixing AckMode.MANUAL with @RetryableTopic causes unexpected behavior.
// @RetryableTopic manages its own offset lifecycle via re-publishing.
// Do NOT add Acknowledgment ack to the method signature when using @RetryableTopic.

// CORRECT pattern: manual ack for traditional blocking retry
@KafkaListener(topics = "payment-events", groupId = "payment-group")
public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {
    try {
        paymentService.process(record.key(), record.value());
        ack.acknowledge(); // commit AFTER successful processing
    } catch (RuntimeException e) {
        throw e; // do NOT swallow — DefaultErrorHandler must see the exception
    }
}

// CORRECT pattern: @RetryableTopic — no Acknowledgment parameter
@RetryableTopic(
    attempts = "4",
    backoff = @Backoff(delay = 1000, multiplier = 2.0, maxDelay = 30000),
    include = {RuntimeException.class}
)
@KafkaListener(topics = "notification-events", groupId = "notification-group")
public void consume(ConsumerRecord<String, String> record) {
    sendNotification(record.value()); // throws → Spring reroutes to retry topic
}

@DltHandler
public void handleDlt(ConsumerRecord<String, String> record) {
    // exhausted all retries — alert, store to S3, raise incident
    log.error("Permanent failure: key={} topic={}", record.key(), record.topic());
}
```

**Tradeoff — blocking vs non-blocking retry:**
- `DefaultErrorHandler`: simpler setup, but the consumer thread is frozen during retry delays, causing consumer lag to grow.
- `@RetryableTopic`: more moving parts (extra topics, extra consumer groups), but main consumer lag stays healthy during retries.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does `@KafkaListener` work in Spring Boot and how do you ensure at-least-once delivery?"**

**One-line answer:** `@KafkaListener` runs inside a managed consumer loop; you get at-least-once delivery by using `AckMode.MANUAL_IMMEDIATE` and only calling `ack.acknowledge()` after the record is fully processed.

**Full answer to give in an interview:**

> "Spring Boot's `@KafkaListener` creates a `ConcurrentMessageListenerContainer` — a managed thread that owns a Kafka consumer and runs the poll loop continuously. The annotation just tells Spring which method to call for each record.
>
> For at-least-once delivery, I switch the container factory to `AckMode.MANUAL_IMMEDIATE`. The method signature gets an `Acknowledgment` parameter, and I call `ack.acknowledge()` only after the business logic succeeds. If an exception is thrown before the ack, the offset is never committed — so on the next poll or after a rebalance, the record is redelivered. That is at-least-once: I might process the same message twice (if I ack and then crash), but I will never silently drop one.
>
> One critical rule: never catch and swallow exceptions inside the listener. If you do, the error handler never sees the failure, the offset gets committed, and the message is permanently lost even though processing failed."

> *Mention the swallow-exception trap unprompted — interviewers love that you know it.*

**Gotcha follow-up they'll ask:** *"What is the difference between `DefaultErrorHandler` and `@RetryableTopic`?"*

> "Both handle retry and dead-letter routing, but they differ in how they block the consumer. `DefaultErrorHandler` is blocking: when a record fails, the consumer thread sleeps through the backoff delay before retrying. Consumer lag grows during that wait, which can trigger rebalances if `max.poll.interval.ms` is exceeded. `@RetryableTopic` is non-blocking: it re-publishes the failed record to a dedicated retry topic (e.g., `topic-retry-0`) with a delay header, and the main consumer immediately moves on to the next record. A separate retry consumer picks up the record after the delay. The tradeoff is operational complexity — you get extra topics and extra consumer groups to monitor."

---

##### Q2 — Tradeoff Question
**"When would you choose `@RetryableTopic` over `DefaultErrorHandler`?"**

**One-line answer:** Use `@RetryableTopic` when retry delays are long (seconds or more) and you cannot afford consumer lag or rebalance risk; use `DefaultErrorHandler` for simple short-delay retries.

**Full answer to give in an interview:**

> "The core question is whether the retry delay is short enough that blocking the consumer thread is acceptable. If I'm retrying a database call with a 100 ms backoff and two attempts, `DefaultErrorHandler` is fine — the thread pauses briefly and moves on. But if I need exponential backoff of 1s, 5s, 30s — which is realistic for an external payment gateway — blocking the consumer that long will cause lag to spike and may push the consumer past its `max.poll.interval.ms` timeout, triggering an unnecessary rebalance.
>
> In that case I use `@RetryableTopic`. The failed record is re-published to a retry topic with the delay encoded as a header. The main consumer is free. The cost is extra topic overhead and slightly more complex DLT monitoring. For a notification service with millions of messages and a 30-second max backoff, non-blocking retry is the clear winner."

> *State the `max.poll.interval.ms` risk by name — it shows you understand the operational consequence.*

**Gotcha follow-up they'll ask:** *"What happens if you never call `ack.acknowledge()` — will the consumer hang?"*

> "No, it won't hang. The record simply stays uncommitted. On the next restart or rebalance, Kafka delivers that record again from the last committed offset. This is normal at-least-once behavior — the record is redelivered, not stuck. The consumer keeps polling; it just re-reads from the uncommitted position after recovery."

---

##### Q3 — Design Scenario
**"Design a Kafka consumer for a payment processing service that must never silently drop messages and must handle downstream failures gracefully."**

**One-line answer:** Use `AckMode.MANUAL_IMMEDIATE` with `DefaultErrorHandler`, a `DeadLetterPublishingRecoverer` routing to a `payments-dlt` topic, and a separate DLT consumer for alerting and manual reprocessing.

**Full answer to give in an interview:**

> "I'd build it in three layers. First, the main consumer uses `AckMode.MANUAL_IMMEDIATE` — I only commit the offset after `paymentService.process()` returns successfully. If processing throws, I rethrow the exception without catching it, so the `DefaultErrorHandler` intercepts it.
>
> Second, I configure `DefaultErrorHandler` with a `FixedBackOff` of 1 second and 3 attempts, and attach a `DeadLetterPublishingRecoverer` that routes exhausted records to `payments-dlt`. I also register `SerializationException` and `IllegalArgumentException` as non-retryable — no point retrying a malformed message.
>
> Third, a separate DLT consumer reads `payments-dlt`, logs the original topic, partition, offset, and exception headers, stores the raw record in S3 for audit, and fires a PagerDuty alert. An on-call engineer can replay from S3 after the root cause is fixed.
>
> This design guarantees no silent drops: every failure either retries successfully, ends up in the DLT with a full audit trail, or blocks the offset until the consumer restarts — never silently skipped."

> *Explicitly mention the non-retryable exception list — it shows production maturity.*

---

> **Common Mistake — Swallowing Exceptions:** Never catch exceptions inside `@KafkaListener` without rethrowing them. If you catch and swallow, `DefaultErrorHandler` never sees the failure, the offset is committed as though processing succeeded, and the message is permanently lost with no DLT record.

---

**Quick Revision (one line):**
Use `AckMode.MANUAL_IMMEDIATE` + `DefaultErrorHandler` + `DeadLetterPublishingRecoverer` for at-least-once delivery with DLT safety; use `@RetryableTopic` when retry delays are long enough to cause consumer lag or rebalance risk.

---

## Topic 12: Retention and Log Compaction

---

#### The Idea

Imagine a newspaper archive. A deletion-based policy is like a library that throws out all newspapers older than 30 days — it does not matter what they contain, time decides. A log compaction policy is like a reference library that keeps only the most recent edition of each encyclopedia volume — old editions are discarded once a newer one arrives, and the library stays current forever.

Kafka's time-based and size-based retention are the newspaper archive. The broker deletes whole log segments once they are old enough or the partition grows too large. This is ideal for event streams where history eventually stops mattering — analytics events, audit logs, clickstreams.

Log compaction is the reference library. The broker's Log Cleaner thread continuously scans for duplicate keys and discards all but the latest record per key. This is ideal for stateful data — a user's current profile, an account's current balance, a Kafka Streams state store. The topic acts as a key-value store: consumers can always replay from the beginning and reconstruct the latest state of every key.

---

#### How It Works

**Time-based retention (`cleanup.policy=delete`):**
```
log.retention.ms = 259200000  (3 days)

Partition log:
  [Segment A: records 0-999, newest timestamp = 4 days ago]  ← eligible for deletion
  [Segment B: records 1000-1999, newest timestamp = 2 days ago]  ← retained
  [Segment C: records 2000-2499, newest timestamp = 30min ago]  ← active, always retained

Broker deletes Segment A because its NEWEST record is older than retention window.
Segment-level granularity: if even one record in a segment is within the window, the whole segment is kept.
```

**Size-based retention:**
```
log.retention.bytes = 10737418240  (10 GB, per partition)

If total partition size > 10 GB:
  delete oldest segments one by one until total < 10 GB
```

**Log Compaction internals:**
```
Log Cleaner thread wakes up, picks partition where:
  dirtyRatio = dirty_bytes / total_bytes > min.cleanable.dirty.ratio (default 0.5)

Dirty portion = records not yet compacted (may have multiple values per key)
Clean portion = already compacted (only latest value per key)

Cleaner builds offset map: key → latest offset in dirty portion
Copies only the latest record per key into new clean segments
Discards all older records for those keys

Result: topic retains latest value per key; older duplicates are gone
```

**Tombstone records (deletion via compaction):**
```
Producer sends: key="user-123", value=null   ← tombstone

Compaction keeps this tombstone for delete.retention.ms (default 24h)
  → gives downstream consumers time to observe the delete event
After delete.retention.ms expires, the cleaner physically removes the key entirely
  → key "user-123" disappears from the topic
```

**Must-memorise gotcha — `compact,delete` combined policy:**

```java
// Spring Boot topic config: combined policy for a stateful topic with time-bounded history
@Bean
public NewTopic accountBalanceTopic() {
    return TopicBuilder.name("account-balance")
        .partitions(12)
        .replicas(3)
        .config(TopicConfig.CLEANUP_POLICY_CONFIG, "compact,delete")
        // keep latest state per key indefinitely via compaction
        // AND delete segments older than 30 days via retention
        .config(TopicConfig.RETENTION_MS_CONFIG,
            String.valueOf(30L * 24 * 60 * 60 * 1000L))
        .config(TopicConfig.DELETE_RETENTION_MS_CONFIG,
            String.valueOf(48L * 60 * 60 * 1000L)) // tombstones kept 48h
        .config(TopicConfig.MIN_CLEANABLE_DIRTY_RATIO_CONFIG, "0.3") // aggressive cleaning
        .build();
}
```

**When to use which policy:**

| Use Case | Policy |
|---|---|
| Analytics events, audit logs | `delete` (time or size) |
| Current user state, account balance | `compact` |
| Kafka Streams state store changelog | `compact` |
| `__consumer_offsets` internal topic | `compact` |
| Recent events + latest state | `compact,delete` |

**Tradeoff — compaction lag:** The Log Cleaner is a background thread. It can lag minutes to hours on a busy cluster. Do not rely on compaction for immediate storage reduction or real-time deduplication — it is an eventual consistency guarantee, not a synchronous one.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"How does Kafka's time-based retention work, and what is a tombstone record in log compaction?"**

**One-line answer:** Time-based retention deletes entire log segments once their newest record is older than `log.retention.ms`; a tombstone is a record with a null value that signals log compaction to eventually delete all records for that key.

**Full answer to give in an interview:**

> "Kafka's time-based retention works at the segment level, not the record level. A partition log is divided into immutable segments. When the newest record in a segment is older than `log.retention.ms` — the default is 7 days — the broker marks that segment eligible for deletion. The active segment (the one currently being written to) is never deleted, even if it is older than the retention window. This is an important nuance: the last segment always stays.
>
> Log compaction is a completely different cleanup mechanism. Instead of deleting by time, the Log Cleaner thread scans the partition and keeps only the latest record per key, discarding older duplicates. To delete a key entirely, you produce a tombstone: a record with the same key but a null value. The compaction process retains this tombstone for `delete.retention.ms` — 24 hours by default — so that downstream consumers can observe the deletion event. After that window expires, the key is physically removed from the log."

> *The segment-level granularity point is an interview trap — state it proactively.*

**Gotcha follow-up they'll ask:** *"Does log compaction guarantee that a consumer will only ever see one record per key?"*

> "No. Compaction is a background process that may lag. At any given moment, a consumer reading from the beginning of a compacted topic may still see multiple records for the same key in the 'dirty' (not yet compacted) portion of the log. The guarantee is eventual: once compaction catches up, only the latest value per key will remain. But you cannot assume real-time deduplication — if your consumer needs to handle duplicates, it must do so in application logic."

---

##### Q2 — Tradeoff Question
**"When would you choose log compaction over time-based deletion, and when would you use both together?"**

**One-line answer:** Use compaction for stateful data where consumers need the current value of every key; use deletion for event history where old records are simply no longer needed; use both together when you want current state but also need old records to eventually expire.

**Full answer to give in an interview:**

> "I choose compaction when the topic represents current state rather than a history of events. A classic example is a user-profile topic: I only care about each user's current profile, not every historical update. A new consumer can replay from offset zero and reconstruct the full current state of every user. Kafka Streams state store changelogs use compaction for exactly this reason.
>
> I choose time-based or size-based deletion when the data is purely historical and loses value after a window — clickstream events, application logs, metrics. Old events from six months ago have no value, so I just let them expire.
>
> The combined `compact,delete` policy is the right choice when I want both: keep the latest value per key indefinitely via compaction, but also delete records — including those latest values — after a long retention window. A billing topic might use this: keep the latest invoice state per customer forever for active customers, but after 30 days of inactivity and a tombstone, let the key expire entirely. The interaction between compaction and the retention timer means tombstones are cleaned up by both mechanisms, which is exactly what LinkedIn does for its member-profile topic."

> *Naming the `compact,delete` combination by policy string shows you know the exact Kafka config.*

**Gotcha follow-up they'll ask:** *"What happens to records with null keys in a compacted topic?"*

> "Records with null keys are never compacted. Compaction is entirely key-based — the cleaner builds an offset map of key to latest offset, and null-key records cannot be indexed that way. They accumulate in the log indefinitely until the active segment rolls over and a deletion-based retention policy (if also configured) can remove them. This is why compacted topics should always have keyed producers — if your producer sends null-key records to a compacted topic, you have a slow storage leak."

---

##### Q3 — Design Scenario
**"How would you design a Kafka topic for a user account balance service that multiple downstream systems need to be able to replay from scratch?"**

**One-line answer:** Use log compaction so any new consumer can replay from offset zero and reconstruct the current balance for every account, with tombstone records for closed accounts.

**Full answer to give in an interview:**

> "I'd configure the topic with `cleanup.policy=compact,delete`. Compaction ensures that a new downstream service — say, a new reporting system — can consume from offset zero and see only the latest balance per account ID without wading through years of intermediate updates. The key is the account ID, the value is the current balance state as a serialized object.
>
> For account closure, the producer sends a tombstone: same account ID key, null value. I'd set `delete.retention.ms` to 48 hours so downstream consumers have a guaranteed window to observe and process the deletion event before the key is physically purged.
>
> I'd also add a long `log.retention.ms` — say 90 days — so that even with compaction, the topic does not hold data indefinitely for regulators or compliance if needed. The combined `compact,delete` policy handles this: compaction keeps current state, and the time-based deletion eventually removes even the latest records for keys that have not been updated recently after their retention window.
>
> For replication factor I'd use 3 with `min.insync.replicas=2` — balance data is critical and should never be lost to a single broker failure."

> *Mentioning `delete.retention.ms` and the consumer observation window shows depth.*

---

> **Common Mistake — Relying on Real-Time Compaction:** Log compaction is a background process and can lag by minutes to hours on a busy cluster. Never design a system that depends on compaction happening immediately after a record is produced. Immediate deduplication must be handled in application code.

---

**Quick Revision (one line):**
Time-based and size-based retention delete entire log segments past the threshold; log compaction retains only the latest value per key (null-value tombstones delete keys) and is the right choice for stateful changelog, state store, and offset topics.

---

## Topic 13: Kafka vs RabbitMQ vs SQS

---

#### The Idea

Think of three different ways to move packages between warehouses. Kafka is like a conveyor belt with a long memory: every package placed on the belt stays there for days, and any number of warehouses can independently pick up copies of any package at any point in time. The belt is designed for massive volume and for scenarios where you might need to replay what came through yesterday.

RabbitMQ is like a traditional postal sorting office: packages arrive, a routing engine directs each one to the correct destination mailbox based on address labels (routing keys), and a delivery person pushes packages out to recipients. Once delivered and signed for, the package is gone. It is designed for smart routing and prompt individual delivery.

SQS is like a managed cloud drop-box: you throw packages in, and workers pull them out when ready. Amazon runs the whole operation — no servers to manage. Once a worker picks up and confirms a package, it is deleted. Simple, reliable, and low-maintenance, but limited to basic queue semantics.

---

#### How It Works

**Architectural model comparison:**

```
Kafka:
  Producer → Topic (append-only log, partitioned) → Consumer Groups (pull, independent)
  Records retained for retention period — any group can re-read from any offset

RabbitMQ:
  Producer → Exchange (routing logic) → Queue(s) → Consumer(s) (push)
  Message deleted after consumer ACKs — no replay

SQS:
  Producer → Queue → Consumer(s) (pull, competing)
  Message deleted after visibility timeout + delete call — no replay
```

**Full comparison table:**

| Dimension | Apache Kafka | RabbitMQ | Amazon SQS |
|---|---|---|---|
| **Model** | Distributed commit log (pull) | Message broker (push) | Managed queue (pull) |
| **Throughput** | Millions msg/s per cluster | ~50k msg/s typical | ~3000 msg/s (FIFO); unlimited (Standard) |
| **Retention** | Configurable (default 7 days) | Until consumed | Up to 14 days |
| **Replay** | Yes — any consumer group re-reads from any offset | No — consumed messages are deleted | No |
| **Consumer model** | Pull; consumer groups read independently | Push; competing consumers | Pull; competing consumers |
| **Ordering** | Guaranteed per partition | Per-queue (with limitations) | FIFO queue: per `MessageGroupId` |
| **Fan-out** | Multiple independent consumer groups out of the box | Fanout exchange bindings | Requires SNS → multiple SQS queues |
| **Latency** | ~5–50 ms (batched) | ~1–5 ms | ~10–100 ms |
| **Durability** | Replication factor (default 3) | Mirrored/quorum queues | Multi-AZ replicated |
| **Operational complexity** | High (cluster management, tuning) | Medium (plugin ecosystem) | Low (fully managed) |
| **Exactly-once** | Yes (with transactions + idempotent producer) | No (at-least-once) | SQS FIFO only, within deduplication window |
| **Dead letter** | Custom DLT topics (application-level) | Built-in dead-letter exchange | Built-in DLQ |
| **Protocol** | Kafka binary protocol | AMQP, MQTT, STOMP | HTTP/SQS API |

**Decision flow:**
```
Need replay / multiple independent consumers reading the same stream?
  → Kafka

Need complex routing (topic exchanges, header matching, per-message ACK)?
  → RabbitMQ

AWS-native, want zero operational overhead, simple queue semantics?
  → SQS

Need FIFO ordering with exactly-once processing at modest throughput?
  → SQS FIFO (if AWS-native) or Kafka with keyed partitions (if scale required)
```

**Tradeoffs to state out loud:**
- Kafka's throughput advantage only matters at scale. For a service handling 100 msg/s, RabbitMQ or SQS is simpler and equally capable.
- RabbitMQ's push model means the broker holds delivery state per consumer. At very high consumer counts, broker memory pressure grows. Kafka's pull model shifts state to the consumer (offsets stored in `__consumer_offsets`), making broker resource usage predictable.
- SQS Standard is at-least-once with no ordering. SQS FIFO is exactly-once per `MessageGroupId` but capped at 3000 msg/s. Do not conflate the two.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the fundamental architectural difference between Kafka and RabbitMQ?"**

**One-line answer:** Kafka is a durable, replayable, pull-based commit log where records persist after consumption; RabbitMQ is a push-based message broker where messages are deleted after a consumer acknowledges them.

**Full answer to give in an interview:**

> "The core difference is what happens to a message after it is consumed. In RabbitMQ, the broker owns delivery state: it pushes messages to consumers and deletes them once acknowledged. The message is gone — you cannot re-read it. In Kafka, the broker does not track which consumers have read what. Records sit on the commit log for the retention period regardless of whether anyone has read them. Consumers track their own position (called an offset) and can re-read from any point independently.
>
> This makes Kafka fundamentally suitable for different problems. If you have ten different services — analytics, billing, notifications — that all need to react to the same user-signup event, Kafka lets them all read from the same topic with independent consumer groups at their own pace. With RabbitMQ you would need to duplicate the message to ten separate queues via a fanout exchange.
>
> The other difference is throughput model. Kafka batches records and writes them sequentially to disk — it is optimized for sustained high volume, millions of messages per second. RabbitMQ is optimized for per-message routing intelligence and low individual message latency, typically sub-5ms."

> *The 'consumer groups read independently' point is the interview differentiator — lead with it.*

**Gotcha follow-up they'll ask:** *"Can RabbitMQ replay messages?"*

> "No. Once a RabbitMQ message is consumed and acknowledged, it is deleted from the queue. There is no native replay mechanism. If you need replay, you either store messages externally (a database, S3) and replay from there, or you use Kafka. This is one of the clearest signals that your use case calls for Kafka over RabbitMQ."

---

##### Q2 — Tradeoff Question
**"When would you choose SQS over Kafka in an AWS environment?"**

**One-line answer:** Choose SQS when you want fully managed queue semantics with zero operational overhead and do not need replay, multi-consumer fan-out, or throughput beyond tens of thousands of messages per second.

**Full answer to give in an interview:**

> "SQS is the right choice when operational simplicity is the top priority. There are no brokers to manage, no replication factor to tune, no ISR to monitor. AWS handles availability, durability, and scaling automatically. If my team does not have Kafka expertise and the workload is a standard microservices decoupling pattern — service A sends tasks, service B processes them — SQS is the obvious choice.
>
> SQS also integrates natively with AWS Lambda as a trigger, which matters for serverless architectures. And SQS FIFO gives me exactly-once processing within a `MessageGroupId` deduplication window, which is useful for financial workflows where duplicate processing is dangerous.
>
> Where SQS falls short: it has no replay. Once a message is consumed and deleted, it is gone. If I need five different services to all process the same event independently, I need SNS fan-out to five SQS queues — more infrastructure, more complexity. And SQS Standard throughput is effectively unlimited but SQS FIFO is capped at around 3000 messages per second per queue. For true high-throughput event streaming, Kafka or Amazon MSK is the right answer."

> *Naming the SNS fan-out workaround shows you know the SQS limitation in detail.*

**Gotcha follow-up they'll ask:** *"Does SQS guarantee exactly-once delivery?"*

> "SQS Standard does not — it is at-least-once and has no ordering guarantee. SQS FIFO offers exactly-once processing within a 5-minute deduplication window using a `MessageDeduplicationId`. If the same deduplication ID is sent twice within 5 minutes, the second one is dropped. But FIFO throughput is capped at 3000 msg/s, and the deduplication window means it is not truly exactly-once indefinitely — it is a bounded window. For true exactly-once at high throughput, Kafka with idempotent producer and transactions is the more robust solution."

---

##### Q3 — Design Scenario
**"A company uses RabbitMQ for order processing but now needs replay capability for a new fraud detection ML model. What do you recommend?"**

**One-line answer:** Introduce Kafka alongside RabbitMQ — publish order events to both, letting RabbitMQ continue handling task queue routing while Kafka provides the replayable event log the ML pipeline needs.

**Full answer to give in an interview:**

> "I would not replace RabbitMQ — I would add Kafka for the replay requirement specifically. The existing order processing task queue — competing consumers, push delivery, per-message ACK — is exactly what RabbitMQ excels at. Ripping it out introduces migration risk with no benefit.
>
> Instead, the order service publishes each order event to a Kafka topic in addition to the RabbitMQ queue. The fraud detection ML model consumes from Kafka as an independent consumer group. When the model needs to retrain on three months of historical orders, it resets its consumer group offset to the beginning and replays. Neither the RabbitMQ flow nor any other Kafka consumer is affected.
>
> For the Kafka side I'd configure: `replication.factor=3`, `min.insync.replicas=2`, `acks=all`, retention long enough to cover the full replay window needed for model training — say 90 days. This is the dual-write pattern: the same event is published to two systems, each optimized for its consumers' needs."

> *The dual-write pattern name is worth stating explicitly — interviewers recognize it.*

---

> **Common Mistake — Assuming Kafka Always Wins on Throughput:** Kafka's throughput advantage only materializes at significant scale. For a service processing a few hundred messages per second, RabbitMQ or SQS is simpler to operate, has lower latency, and is equally reliable. Using Kafka for a simple task queue adds operational complexity with no benefit.

---

**Quick Revision (one line):**
Choose Kafka for high-throughput, replayable, multi-consumer event streams; RabbitMQ for complex routing, push delivery, and task queues; SQS for AWS-native simplicity with minimal operational overhead.

---

## Topic 14: Replication and Fault Tolerance

---

#### The Idea

Imagine a bank vault with three copies of every document: one master copy and two backups. The master copy (the leader) is the only one customers can read from or write to. The two backup copies (followers) continuously mirror every change the master receives. If the master vault catches fire, one of the two synchronized backups is immediately promoted to master — no documents are lost because the backup was fully up to date.

Now imagine a scenario where the backups fall behind: the backup vault's delivery truck is slow and it has not received the last 200 documents. If the master burns down in this moment, promoting the slow backup means those 200 documents are permanently gone. Kafka's ISR (In-Sync Replicas) is the mechanism that tracks which backups are current enough to be trusted for promotion.

The durability guarantee is: if a write is acknowledged only after all in-sync replicas confirm it (`acks=all`), then even if the leader immediately dies, one of the surviving in-sync replicas has the data and can safely become the new leader without losing anything. The `min.insync.replicas` setting adds an extra layer: it rejects writes when too few replicas are in sync, preventing situations where `acks=all` nominally succeeds but only one slow replica acknowledged it.

---

#### How It Works

**ISR mechanics:**
```
Replication factor = 3: 1 leader + 2 followers
Each follower continuously fetches from the leader's log

ISR (In-Sync Replicas) = { replicas caught up within replica.lag.time.max.ms (default 30s) }

If follower falls behind (slow I/O, GC pause, network congestion):
  → removed from ISR
  → leader continues writing without waiting for the lagging follower
  → when follower catches up, it rejoins the ISR

ISR example:
  Normal:  ISR = { broker1 (leader), broker2, broker3 }
  Broker2 lags: ISR = { broker1 (leader), broker3 }
  Broker1 fails: new leader elected from ISR → broker3 promoted
```

**High Watermark vs Log End Offset:**
```
LEO (Log End Offset): next offset the leader will assign → advances with every appended record
HW (High Watermark):  highest offset replicated to ALL ISR members → consumers can only read up to HW

Why HW matters: after a leader election, the new leader uses HW as its safe point.
Records between old HW and old leader's LEO are truncated → never exposed to consumers → no phantom reads.
```

**Leader election (clean):**
```
Broker failure detected by Kafka Controller (elected via KRaft or Zookeeper)
Controller selects: first member of current ISR as new leader (highest LEO preferred)
Controller broadcasts new leader metadata to all brokers and clients
Producers and consumers transparently reconnect to new leader
Old leader's records above HW are truncated if it rejoins as a follower
```

**Unclean leader election:**
```
unclean.leader.election.enable = true:
  If ALL ISR replicas are unavailable, allow out-of-ISR replica to become leader
  → Topic becomes available but records between old HW and old leader's LEO are PERMANENTLY LOST
  → Use only when availability > durability (e.g., log aggregation, analytics)

unclean.leader.election.enable = false (recommended for production):
  If ALL ISR replicas are unavailable, partition is offline until an ISR replica recovers
  → No data loss, but topic is temporarily unavailable
```

**Must-memorise gotcha — the durability triangle:**

```java
// Production-safe topic configuration: tolerates 1 broker failure without data loss
@Bean
public NewTopic tradeEventsTopic() {
    return TopicBuilder.name("trade-events")
        .partitions(12)
        .replicas(3)                                                  // RF=3: 1 leader + 2 followers
        .config(TopicConfig.MIN_IN_SYNC_REPLICAS_CONFIG, "2")        // reject writes if ISR < 2
        .config(TopicConfig.UNCLEAN_LEADER_ELECTION_ENABLE_CONFIG, "false") // never lose acknowledged data
        .build();
}

// Producer MUST also use acks=all — topic config alone is not enough
// spring.kafka.producer.acks=all
// spring.kafka.producer.properties.enable.idempotence=true

// Result:
//   1 broker fails → ISR=2 ≥ minISR=2 → writes continue, no data loss
//   2 brokers fail → ISR=1 < minISR=2 → writes rejected (NotEnoughReplicasException), no data loss
//   All 3 fail     → topic offline
```

**Fault tolerance matrix:**

| Config | 1 Broker Failure | 2 Broker Failures | Data Loss Risk |
|---|---|---|---|
| RF=3, minISR=2, acks=all, unclean=false | Writes continue | Writes blocked (no data loss) | None |
| RF=3, minISR=1, acks=all, unclean=false | Writes continue | Writes continue | None (but single point of replication) |
| RF=3, minISR=2, acks=1, unclean=false | Writes continue | Writes blocked | Possible (leader may die before replication) |
| RF=3, minISR=1, acks=all, unclean=true | Writes continue | Writes continue | Possible (unclean election may lose records) |

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the ISR in Kafka and why does it matter for durability?"**

**One-line answer:** The ISR (In-Sync Replicas) is the set of replicas caught up within `replica.lag.time.max.ms` of the leader; it matters because only ISR members are eligible for clean leader election, guaranteeing no data loss on failover.

**Full answer to give in an interview:**

> "Every Kafka partition has one leader and N-1 followers, where N is the replication factor. The ISR — In-Sync Replicas — is a dynamic set maintained by the leader that tracks which followers are current: specifically, which have fetched up to the leader's log within `replica.lag.time.max.ms`, defaulting to 30 seconds. If a follower falls behind — due to a GC pause, slow disk, or network issue — it is removed from the ISR, and the leader stops waiting for it when acknowledging producer writes.
>
> Durability depends on the ISR because when the leader fails, the Kafka Controller will only elect a new leader from the current ISR. Since all ISR members have confirmed receipt of the same records up to the High Watermark, promoting any ISR member guarantees zero data loss for acknowledged writes. If we allowed out-of-ISR replicas to be elected — called unclean leader election — we risk losing records that the failed leader acknowledged but the lagging replica never received.
>
> The practical config is `acks=all` on the producer combined with `min.insync.replicas=2` on the topic. `acks=all` means the producer only gets an acknowledgment after all current ISR members confirm the write. `min.insync.replicas=2` means the broker rejects the write entirely if fewer than 2 replicas are in sync, preventing a false sense of safety when the ISR has shrunk to one."

> *The `acks=all` + `min.insync.replicas` pairing is a compound answer — always state both together.*

**Gotcha follow-up they'll ask:** *"What is the difference between the High Watermark and the consumer committed offset?"*

> "They are completely independent concepts that are often confused. The High Watermark is a broker-side replication boundary: it is the highest offset that all ISR members have confirmed receiving. Consumers can only read up to the High Watermark — this prevents reading data that might be rolled back after a leader election. The consumer committed offset is stored in the `__consumer_offsets` internal topic and represents how far a specific consumer group has processed. The HW is about replication safety; the committed offset is about consumer progress. They are tracked separately and can be at very different positions."

---

##### Q2 — Tradeoff Question
**"When would you enable unclean leader election, and what do you trade away?"**

**One-line answer:** Enable unclean leader election only when availability is more important than durability — for log aggregation or analytics topics where losing some records is acceptable; never enable it for financial, audit, or transactional data.

**Full answer to give in an interview:**

> "Unclean leader election allows an out-of-ISR replica to become leader when all ISR replicas are unavailable. The tradeoff is stark: you trade durability for availability. Records that the old leader acknowledged but the new (lagging) leader never received are permanently gone. From the producer's perspective, those writes succeeded — but they have silently vanished.
>
> There are legitimate use cases. A log aggregation pipeline collecting application logs can tolerate losing a few thousand log lines during a simultaneous multi-broker failure — the alternative, a completely offline partition, would cause more harm by backing up producers. Similarly, real-time analytics dashboards where approximate counts are acceptable might prefer some data loss over unavailability.
>
> For anything financial — trade events, payment records, audit logs — `unclean.leader.election.enable=false` is non-negotiable. Goldman Sachs runs trade topics with this set to false precisely because a false acknowledgment followed by silent data loss would be a compliance disaster. The partition goes offline briefly; that is acceptable. Silently losing an acknowledged trade record is not."

> *Framing the decision as a compliance question for financial data shows domain maturity.*

**Gotcha follow-up they'll ask:** *"What happens if you set `min.insync.replicas` equal to the replication factor?"*

> "That is a misconfiguration that makes the topic extremely fragile. If `min.insync.replicas = replication.factor = 3`, then any single broker failure causes the ISR to drop to 2, which is below the minimum, so all writes are immediately rejected with `NotEnoughReplicasException`. The topic becomes read-only until the failed broker recovers. The standard recommendation is to keep `min.insync.replicas` at `replication.factor - 1` — so `2` for `RF=3`. This tolerates one broker failure without write unavailability while still requiring two replicas to confirm each write."

---

##### Q3 — Design Scenario
**"Design the replication strategy for a Kafka cluster handling financial trade events. What configurations would you set and why?"**

**One-line answer:** Use `RF=3`, `min.insync.replicas=2`, `acks=all`, `unclean.leader.election.enable=false`, and idempotent producers to guarantee exactly-once durable writes that tolerate one broker failure.

**Full answer to give in an interview:**

> "For financial trade events, the non-negotiable requirement is that no acknowledged write is ever lost. I would start with `replication.factor=3` — the standard production setting that distributes one leader and two followers across three brokers in different racks or availability zones.
>
> On the topic I'd set `min.insync.replicas=2` and `unclean.leader.election.enable=false`. This means a write is only acknowledged after two replicas confirm it, and if a broker fails, only a replica that was fully in-sync can be promoted as leader. We tolerate one simultaneous broker failure with no write interruption: ISR drops from 3 to 2, which equals minISR, so writes continue. Two simultaneous broker failures block writes temporarily, but no acknowledged data is lost — the partition waits for recovery.
>
> On the producer I'd set `acks=all` and `enable.idempotence=true`. Idempotence (using sequence numbers) prevents duplicate records from producer retries — if a network timeout causes the producer to retry a send, the broker detects the duplicate sequence and discards it.
>
> I'd also monitor ISR shrinkage as a critical alert. An ISR of size 1 means we are one broker failure away from a hard write block. Catching and remediating that before a second failure is the operational discipline that makes this configuration reliable."

> *Mentioning ISR monitoring as an alert condition shows operational thinking beyond config.*

---

> **Common Mistake — `acks=all` Without `min.insync.replicas`:** Setting `acks=all` on the producer alone is not sufficient for durability. If the ISR has shrunk to a single broker (due to two followers lagging), `acks=all` happily acknowledges the write after that one broker confirms it. If that broker then dies, the record is lost. You must combine `acks=all` with `min.insync.replicas=2` to guarantee that at least two independent copies exist before acknowledgment.

---

**Quick Revision (one line):**
ISR tracks replicas within `replica.lag.time.max.ms` of the leader; the production durability standard is `RF=3`, `min.insync.replicas=2`, `acks=all`, and `unclean.leader.election.enable=false` — tolerating one broker failure without data loss.

---

## Topic 15: Kafka Performance Tuning

---

#### The Idea

Think of a Kafka producer like a delivery truck. A naive driver picks up one package, drives to the warehouse, drops it off, and drives back — one at a time. A smart driver fills the truck to capacity, drives once, unloads everything, and drives back. That one change — batching — multiplies throughput by orders of magnitude. Kafka's `batch.size` and `linger.ms` settings control exactly this: how full the truck gets before it leaves, and how long it waits at the loading dock for more packages.

Compression is the next multiplier: compressing the batch before sending is like vacuum-sealing the packages so three times as many fit in the truck. The CPU cost of compression at the producer is almost always worth it because network bandwidth and broker disk I/O are the real bottlenecks.

On the broker side, Kafka's secret weapon is the OS page cache. Kafka writes to disk sequentially and relies on the operating system to cache recently written bytes in RAM. When a consumer reads data that was just produced, it almost never touches the disk — the bytes are already in the page cache and Kafka transfers them directly from cache to the network socket via a system call called `sendfile()` (zero-copy). This is why keeping the JVM heap small — counter-intuitively — makes Kafka faster: a small heap means less JVM memory, but it also means the OS gets more RAM for the page cache, which is far more valuable.

---

#### How It Works

**Producer throughput tuning:**
```
Default batch behavior:
  batch.size = 16 KB, linger.ms = 0
  → sends immediately as records arrive, tiny batches, high per-batch overhead

High-throughput tuning:
  batch.size = 128 KB (131072)   → larger batches, fewer round trips
  linger.ms = 10                 → wait up to 10ms for the batch to fill
  compression.type = lz4         → 3–5x compression ratio, minimal CPU cost
  buffer.memory = 128 MB         → more in-flight data before backpressure
  acks = all                     → durability; drop to acks=1 only for non-critical data
  enable.idempotence = true      → deduplicates retried records; requires acks=all, max.in.flight=5
```

**Consumer throughput tuning:**
```
Default fetch behavior:
  max.poll.records = 500, fetch.min.bytes = 1
  → returns as soon as any data is available, small polls

High-throughput tuning:
  max.poll.records = 2000         → process larger batches per poll loop
  fetch.min.bytes = 1048576       → wait until 1MB is available before returning (batched fetches)
  fetch.max.wait.ms = 500         → max wait even if fetch.min.bytes not reached
  max.partition.fetch.bytes = 4MB → larger per-partition fetch ceiling

Parallelism:
  factory.setConcurrency(6)       → 6 independent consumer threads (one per partition assignment)
  batch listener + thread pool    → within each poll batch, dispatch records to an ExecutorService for parallel I/O
```

**Broker performance:**
```
OS Page Cache (most important):
  Give 50–60% of machine RAM to the OS (not the JVM).
  Consumers reading recently produced data hit page cache, not disk → microsecond reads.
  A 128 GB machine: 6–8 GB JVM heap, ~120 GB for OS page cache.

Zero-copy (sendfile):
  Kafka uses FileChannel.transferTo() → data moves from page cache to socket without copying through user space.
  This is why TLS termination on the broker hurts throughput: TLS breaks zero-copy.

JVM heap:
  Keep at 4–8 GB. Use G1GC: -XX:+UseG1GC -XX:MaxGCPauseMillis=20.
  Large heaps (>8 GB) → long GC pauses → replication lag → ISR shrinkage → reduced throughput.

Disk:
  JBOD (multiple log.dirs pointing to separate disks) for parallelism.
  Avoid RAID — Kafka handles redundancy via replication, not RAID.
  Use XFS or ext4 with noatime mount option.

Thread tuning:
  num.network.threads = 8 (default 3)  → handles socket I/O for producers/consumers
  num.io.threads = 16 (default 8)      → handles disk I/O; target ~2× disk count for JBOD
```

**Must-memorise gotcha — heap size vs page cache:**

```java
// WRONG: allocating most RAM to JVM starves page cache
// JVM start flag: -Xmx64g  ← DO NOT do this on a 128 GB broker

// CORRECT: keep heap small, let OS own the rest
// JVM start flags: -Xmx6g -Xms6g -XX:+UseG1GC -XX:MaxGCPauseMillis=20
// OS gets ~122 GB for page cache → consumer reads almost never hit disk

// High-throughput producer config in Spring Boot
@Bean
public ProducerFactory<String, String> highThroughputProducerFactory() {
    Map<String, Object> props = new HashMap<>();
    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "broker1:9092,broker2:9092,broker3:9092");
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG,   StringSerializer.class);
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);

    props.put(ProducerConfig.BATCH_SIZE_CONFIG,        131072);      // 128 KB
    props.put(ProducerConfig.LINGER_MS_CONFIG,         10);          // wait up to 10 ms
    props.put(ProducerConfig.BUFFER_MEMORY_CONFIG,     134217728L);  // 128 MB
    props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG,  "lz4");

    props.put(ProducerConfig.ACKS_CONFIG,                              "all");
    props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG,                true);
    props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION,    5);

    return new DefaultKafkaProducerFactory<>(props);
}
```

**Tradeoffs to state aloud:**
- `linger.ms` introduces latency: waiting 10ms to fill a batch means the first record in the batch is delayed up to 10ms. For latency-sensitive pipelines, keep `linger.ms` low (0–5ms). For bulk pipelines, 10–50ms is fine.
- Compression saves network and disk but costs CPU. `lz4` has near-zero CPU cost and is the default recommendation. `zstd` gives better compression ratio at slightly higher CPU cost. `gzip` is CPU-heavy and rarely worth it for Kafka.
- Increasing partition count beyond broker capacity degrades cluster metadata performance. Beyond ~4000 partitions per broker, leader election time, metadata propagation, and controller overhead create measurable latency spikes. More partitions is not always better.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Why should Kafka broker JVM heap be kept small, even on machines with 128 GB RAM?"**

**One-line answer:** A small heap leaves most RAM to the OS page cache, which Kafka uses for zero-copy consumer reads — a large heap triggers long GC pauses and starves the cache that makes Kafka fast.

**Full answer to give in an interview:**

> "Kafka's performance model is built around the OS page cache, not JVM memory. When a producer writes a record, Kafka appends it to a log file. The OS caches those bytes in RAM (the page cache). When a consumer reads those same records shortly after, Kafka uses the `sendfile()` system call — called zero-copy — to transfer bytes directly from the page cache to the network socket without ever copying them through JVM heap space. This path is extremely fast and is the reason Kafka can sustain millions of messages per second on modest hardware.
>
> If you give the JVM a 64 GB heap on a 128 GB machine, the OS only has 64 GB left for the page cache. Writes that are not in cache must be read from disk — orders of magnitude slower. Worse, a 64 GB heap means the garbage collector occasionally runs a multi-second full GC pause. During that pause, the broker stops responding, replication falls behind, followers may exit the ISR, and producer writes stall waiting for acknowledgment.
>
> The recommendation is 4–8 GB for the JVM heap with G1GC tuned to a 20ms max pause goal, and let the OS own everything else. LinkedIn's production brokers use 6 GB heap on 128 GB machines — 122 GB of page cache."

> *The `sendfile()` zero-copy mechanism is the technical anchor — name it explicitly.*

**Gotcha follow-up they'll ask:** *"What breaks zero-copy in Kafka?"*

> "TLS/SSL encryption on the broker breaks zero-copy. When TLS is enabled, Kafka cannot use the `sendfile()` system call directly — the data must be decrypted and re-encrypted in user space, which requires copying through JVM memory. This is why high-throughput Kafka clusters often terminate TLS at a load balancer or use hardware TLS offload rather than broker-side SSL, or accept a throughput reduction when compliance requires end-to-end encryption."

---

##### Q2 — Tradeoff Question
**"What is the throughput impact of enabling compression on the producer, and which codec should you choose?"**

**One-line answer:** Compression typically improves throughput 3–5x by reducing both network I/O and broker disk usage; `lz4` is the default recommendation because it has near-zero CPU overhead at good compression ratios.

**Full answer to give in an interview:**

> "Compression in Kafka happens at the batch level on the producer: the entire batch is compressed before being sent. This is important because it means larger batches compress better — it reinforces the value of tuning `batch.size` and `linger.ms` alongside compression.
>
> The impact is dramatic for text-heavy payloads like JSON. A 5x compression ratio means 5x fewer bytes over the network, 5x less broker disk I/O, and therefore roughly 5x higher throughput without changing any infrastructure. The CPU cost on the producer is the only downside.
>
> For codec choice: `lz4` has the best throughput-to-CPU ratio — it compresses and decompresses so fast that the savings almost always outweigh the cost, even for CPU-bound producers. `zstd` (available since Kafka 2.1) gives better compression ratios at slightly higher CPU cost, which is worth it when disk space or bandwidth is the bottleneck. `gzip` is the worst choice for Kafka — high CPU cost, mediocre speed — it only makes sense if compatibility with legacy consumers is required.
>
> One nuance: if the broker is configured with a different compression type than the producer, the broker decompresses and recompresses every batch — adding significant broker CPU overhead. Set `compression.type=producer` on the topic configuration to tell the broker to store batches exactly as the producer sent them."

> *The `compression.type=producer` broker config is a production detail most candidates miss.*

**Gotcha follow-up they'll ask:** *"Does increasing partition count always improve throughput?"*

> "Up to a point, yes — more partitions means more parallelism for both producers and consumers. But there is a ceiling. Each partition requires memory and file handles on the broker. Beyond roughly 4000 partitions per broker, the overhead of managing replica states, participating in leader elections, and propagating metadata updates starts to hurt. The Kafka controller — a single broker responsible for all partition leadership changes — becomes a bottleneck. LinkedIn observed measurable failover time degradation at high partition counts. The rule of thumb is to size partitions based on your actual throughput target (one partition can sustain ~10 MB/s) and your consumer parallelism needs, not to maximize the count."

---

##### Q3 — Design Scenario
**"A Kafka cluster is under-performing: producer throughput is low and consumer lag is growing. Walk through how you would diagnose and fix it."**

**One-line answer:** Profile in layers — producer batching and compression, consumer fetch size and concurrency, then broker page cache hit rate and thread counts — fixing the bottleneck at each layer before moving to the next.

**Full answer to give in an interview:**

> "I'd work from the producer inward. First I check producer metrics: `record-send-rate`, `batch-size-avg`, and `compression-rate-avg`. If batch size is near the default 16 KB and compression is disabled, the producer is sending tiny uncompressed batches — I increase `batch.size` to 128 KB, set `linger.ms` to 10ms, and enable `lz4` compression. These three changes together often 5–10x producer throughput with no infrastructure changes.
>
> If consumer lag is growing despite healthy producer throughput, I check the consumer: `max.poll.records`, fetch size, and concurrency. If `max.poll.records` is 500 and processing each record takes 10ms, one consumer thread can handle at most 50 records per second. I either increase concurrency via `factory.setConcurrency(N)` — adding more consumer threads — or batch the downstream I/O using an ExecutorService within the listener to parallelize DB writes or HTTP calls per poll batch.
>
> On the broker side I check JVM heap usage and GC pause duration via JMX metrics. If GC pauses exceed 500ms, the heap is too large or GC is misconfigured — I tune down to 6 GB with G1GC. I also check page cache hit rate: if broker disk read I/O is high, the page cache is insufficient, which usually means the JVM is consuming too much RAM.
>
> Finally I check `under-replicated-partitions` and ISR shrinkage — if followers are lagging, replication is stealing I/O bandwidth from producers, which can create a feedback loop of degrading throughput."

> *Layered diagnosis — producer, consumer, broker — shows systematic thinking.*

---

> **Common Mistake — Allocating Large JVM Heap on Broker:** Setting `-Xmx64g` or higher on a Kafka broker does not speed it up — it actively slows it down by starving the OS page cache that Kafka's zero-copy mechanism depends on. Keep broker heap at 4–8 GB regardless of total machine RAM. The rest belongs to the OS.

---

**Quick Revision (one line):**
Maximize producer throughput with larger batches (`batch.size`), `linger.ms`, and `lz4` compression; consumer throughput with concurrency and larger fetch sizes; broker efficiency by keeping JVM heap at 4–8 GB to maximize OS page cache for zero-copy reads.
