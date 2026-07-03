# Volume 5: System Design & LLD — Study Guide

## Priority Order

| Chapter | Why | Time Budget |
|---|---|---|
| Ch22 System Design HLD | Most common interview round; frameworks apply to any question | 3 hrs |
| Ch21 LLD Case Studies | Translates directly to whiteboard coding rounds | 2.5 hrs |
| Ch19 Design Patterns | Asked in LLD rounds; underpins good class design | 2 hrs |
| Ch20 SOLID / Clean Arch | Asked as follow-up; validates design reasoning | 1.5 hrs |

---

## 1-Week Plan (1 hr/day)

**Day 1 — Ch22 HLD Foundations**
The 7-step framework (clarify scope → capacity → API → data model → HLD → deep dive → trade-offs). Practice capacity estimation: QPS, storage, bandwidth. Identify the key components: load balancer, app servers, cache, DB, message queue, CDN.

**Day 2 — Ch22 HLD Practice**
Design URL shortener end-to-end: hashing strategy, redirect flow, analytics pipeline. Then design a notification system: fan-out models, push vs pull, at-least-once delivery. Time-box each to 25 minutes.

**Day 3 — Ch21 LLD Case Studies**
Pick 2 case studies. Walk each through: gather requirements → identify entities → draw class diagram → write key interfaces + one concrete class. Focus on where you'd use an interface vs abstract class and why.

**Day 4 — Ch19 Design Patterns**
Focus: Strategy (swap algorithms), Observer (event-driven), Factory / Abstract Factory (object creation), Decorator (add behaviour without inheritance), Singleton (thread-safety pitfalls). For each: one-line intent + one Java code example in your head.

**Day 5 — Ch20 SOLID**
Focus: SRP (one reason to change), OCP (extend without modifying), DIP (depend on abstractions). Map each to a Spring example: SRP → service vs repository split, OCP → Spring plugin / strategy beans, DIP → `@Autowired` interface injection. LSP and ISP as quick checks.

**Day 6 — Timed Practice**
45-minute timed system design: Uber ride-sharing (geo matching, surge pricing, driver location streaming) or Twitter feed (fan-out on write vs read, timeline aggregation). Use the 7-step framework strictly.

**Day 7 — Vol 6 Ch27 Revision**
Review Q1–Q20 (HLD), Q41–Q60 (LLD). Cover the full answer, recite the one-liner, speak the full answer aloud. Flag any gaps; re-read only those sections.

---

## 3-Day Crash Plan

**Day 1 — Ch22 HLD 7-step framework**
Read the framework, memorise the steps. Do 2 quick design sketches (URL shortener + rate limiter) — components only, no deep dive. 

**Day 2 — Ch21 LLD**
Walk through 2 case studies: Parking Lot and Library Management (or equivalent). Requirements → class diagram → code skeleton.

**Day 3 — Patterns + Revision**
Ch19 top 5 patterns (Strategy, Observer, Factory, Decorator, Singleton). Then Ch27 Vol 6 Q1–Q20 and Q41–Q60. Speak answers aloud.

---

## What Interviewers Test in System Design Rounds

- **Driving the conversation**: you ask clarifying questions before drawing anything; you set the scope.
- **Stating assumptions explicitly**: QPS, read/write ratio, data size — you name them, you own them.
- **Trade-off articulation**: every choice (SQL vs NoSQL, sync vs async) is followed by "the trade-off is…".
- **Failure scenarios**: what happens when the cache is cold, the message queue backs up, or a node goes down.
- **Not over-engineering**: you acknowledge what you'd defer to Phase 2 rather than designing everything upfront.

---

## What Interviewers Test in LLD Rounds

- **Requirements before diagrams**: you ask functional and non-functional requirements before drawing a single class.
- **Extensibility via interfaces**: classes depend on abstractions; you can add a new type without touching existing code.
- **SOLID violations caught**: you spot and call out a design smell when it appears, even mid-discussion.
- **Relationship clarity**: you distinguish composition vs aggregation vs inheritance and choose the right one.
- **Realistic code snippets**: at least one interface, one concrete class, and the calling code — not just boxes on a board.

---

## Top 10 System Design Questions

1. Design a URL Shortener (TinyURL)
2. Design a Rate Limiter
3. Design Twitter / News Feed
4. Design WhatsApp / Messaging System
5. Design Uber / Ride-Sharing
6. Design YouTube / Video Streaming
7. Design a Notification System
8. Design a Distributed Cache (Redis-like)
9. Design an E-Commerce Order Pipeline (Amazon)
10. Design a Search Autocomplete / Typeahead

---

## Common System Design Interview Mistakes

- **Jumping to the solution**: drawing components before clarifying scale, features, or constraints.
- **Ignoring non-functional requirements**: availability, latency SLA, durability — interviewers expect you to raise these.
- **Forgetting failure scenarios**: no mention of retries, dead-letter queues, or circuit breakers signals a gap.
- **Treating every problem as CRUD**: not all systems are request-response; know when to introduce queues or streaming.
- **No trade-off reasoning**: saying "I'll use Kafka" without explaining why vs RabbitMQ or a simple DB queue loses points.
