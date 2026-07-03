# Company-Specific Interview Guide
## Backend Interview Handbook — Java / Spring / Kafka / Redis / SQL / System Design

> **How to use this guide:** Each section is written as if a senior engineer who has been through these loops is briefing you the night before. The chapter references point to specific chapters in this handbook. Do not treat this as a generic topic list — treat it as a targeting system.

---

## Table of Contents

1. [Amazon / AWS](#amazon--aws)
2. [Google / DeepMind](#google--deepmind)
3. [Meta / Facebook](#meta--facebook)
4. [Microsoft](#microsoft)
5. [Netflix](#netflix)
6. [Uber / Lyft](#uber--lyft)
7. [Stripe](#stripe)
8. [Atlassian](#atlassian)
9. [Salesforce](#salesforce)
10. [Goldman Sachs / FinTech](#goldman-sachs--fintech-jane-street-citadel)
11. [Thoughtworks](#thoughtworks)
12. [Flipkart / Indian Product Companies](#flipkart--indian-product-companies-swiggy-zepto-cred-razorpay)
13. [Quick Comparison Matrix](#quick-comparison-matrix)
14. [Universal Must-Know List](#universal-must-know-list-every-company)
15. [The 10 Questions You MUST Answer Cold](#the-10-questions-you-must-be-able-to-answer-cold)
16. [Mock Interview Simulation Guide](#mock-interview-simulation-guide)

---

## Amazon / AWS

### What They're Actually Hiring For
Amazon wants engineers who think in terms of ownership and scale — someone who will not just build a feature but own it end-to-end, including the 3 AM on-call. The bar is high on distributed systems because at Amazon, nearly everything is a distributed system.

### Interview Format
- **5-6 rounds** virtual onsite (sometimes a phone screen before)
- Typical duration: 4-5 hours total, spread across one day
- You talk to: 2 SDE-IIs, 1 SDE-III, 1 Bar Raiser (a specially trained interviewer who is not on the hiring team), sometimes an Engineering Manager
- A Bar Raiser round exists specifically to maintain the hiring bar — they are the most unpredictable interviewer in the loop

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Phone Screen | Coding + LP | 45 min | One DSA problem + 2 LP questions |
| Coding 1 | DSA | 45 min | Arrays/graphs/DP — must code cleanly |
| Coding 2 | DSA | 45 min | Usually harder — trees, recursion, optimization |
| System Design | HLD | 60 min | Scalable distributed system, AWS services expected |
| Bar Raiser | Mixed (coding or SD + heavy LP) | 60 min | Unpredictable format, very heavy LP focus |
| Hiring Manager | Behavioral | 30-45 min | Team fit, past experience, leadership principles |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Distributed system design with availability vs consistency tradeoffs → Ch17, Ch22
- Kafka for event-driven pipelines (Amazon uses Kinesis, but Kafka concepts apply) → Ch11
- Java concurrency — thread safety, locks, ExecutorService → Ch6
- SQL query optimization and indexes for high-traffic tables → Ch14, Ch15
- Spring Boot microservices with REST, resilience patterns → Ch9, Ch10

**Frequently Asked**
- JVM tuning — GC, heap, memory leaks → Ch5
- Redis for caching and session management → Ch12
- ACID vs BASE, eventual consistency → Ch16, Ch17
- Design patterns: Circuit Breaker, Saga, Outbox → Ch19

**Nice to Have**
- AWS-specific services (DynamoDB, SQS, SNS, RDS) — map to your distributed DB knowledge → Ch17, Ch18
- Clean architecture and hexagonal arch → Ch20

### What Sets Amazon Apart
- **The Leadership Principles are not a formality** — every interviewer is scoring your LP answers against actual principles (Ownership, Bias for Action, Customer Obsession). Prepare 3 real stories per LP.
- **The Bar Raiser can veto an otherwise unanimous hire** — they are looking for the "raise the bar" signal, not just a pass.
- **Amazon expects you to push back** — if you disagree with their design choice during SD, say so with data. Silence reads as having no opinion.
- **They care about operational thinking** — "how would you monitor this?" and "what happens when this service goes down?" are standard follow-ups in SD.
- **Coding must be production-quality** — edge cases, error handling, and mentioning test strategy matter.

### Sample Questions They Actually Ask
1. Design Amazon's order fulfillment system — handle 10M orders/day, eventual consistency across warehouse services.
2. You own a service that is timing out under load. Walk me through your debugging approach from symptom to fix.
3. Implement a distributed rate limiter that works across multiple instances (no single point of failure).
4. Tell me about a time you disagreed with your manager and how you handled it. (LP: Have Backbone)
5. Design a notification system that sends push, email, and SMS — at-least-once delivery guaranteed.
6. Given a Java app with a memory leak in production, how do you diagnose it? (Ch5)
7. You need to process 1 million events/second from IoT devices with ordering guarantees per device — design it.

### Red Flags That Kill Candidates
- Jumping to a solution without clarifying requirements in SD — Amazon is very explicit about requirements gathering.
- Giving vague LP answers ("we worked as a team") — they want YOUR specific action and the measurable result.
- Not knowing what the Bar Raiser round is and treating it like a normal LP interview.
- Ignoring operational concerns — every SD answer needs monitoring, alerting, and failure modes.
- Writing code that has no error handling or ignores edge cases — Amazon's codebase runs at massive scale.

### Preparation Checklist
- [ ] Prepare 15 LP stories (one per principle), using STAR format with measurable outcomes (Ch22 mindset applied to behavior)
- [ ] Practice designing 5 distributed systems from scratch including failure modes (Ch22, Ch17)
- [ ] Be able to explain Kafka consumer groups, offsets, and at-least-once vs exactly-once (Ch11)
- [ ] Know Java's `CompletableFuture`, `ExecutorService`, and deadlock prevention cold (Ch6)
- [ ] Practice reading and optimizing SQL EXPLAIN plans (Ch15)
- [ ] Know Redis eviction policies and when to use Redis vs a DB (Ch12)
- [ ] Code 10 medium/hard LeetCode problems under 30 minutes each — Amazon coding bar is real
- [ ] Understand Circuit Breaker and Saga pattern with a concrete implementation example (Ch19)
- [ ] Review AWS service equivalents for Kafka (Kinesis), Redis (ElastiCache), SQL (RDS/Aurora)
- [ ] Practice the "operational follow-up" — for every SD, add monitoring, alerting, and rollback plan

### Recommended Study Plan
Use **Plan B (4-week)** with extra focus on **Ch11 (Kafka), Ch17 (Distributed DBs), Ch22 (HLD)**, and spend 1 full week on Leadership Principles storytelling separately from technical prep.

---

## Google / DeepMind

### What They're Actually Hiring For
Google hires for intellectual horsepower and the ability to think through ambiguous problems from first principles. They want engineers who love computer science for its own sake, not just engineers who can ship features. The bar on algorithms is the highest in the industry.

### Interview Format
- **5-6 rounds** virtual onsite after a phone screen
- Typical duration: 4.5 hours, all in one day
- You talk to: 2-3 SWEs for coding, 1-2 for system design, 1 Googleyness round
- No dedicated Bar Raiser role, but a hiring committee reviews all feedback independently

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Phone Screen | Coding | 45 min | One DSA problem — must fully solve, no partial credit |
| Coding 1 | DSA | 45 min | Medium/Hard — clean code, time/space complexity stated |
| Coding 2 | DSA | 45 min | Often involves graphs, DP, or strings |
| System Design 1 | HLD | 45 min | Large-scale distributed system |
| System Design 2 | HLD or LLD | 45 min | May be more product-oriented or OOP design |
| Googleyness | Behavioral + culture | 30-45 min | "How do you work with people?" |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Graph algorithms: BFS, DFS, Dijkstra, topological sort → (DSA, referenced in Ch22 context)
- System design at Google scale — Bigtable-style, distributed caching, CDN → Ch17, Ch22
- Java generics, streams, functional programming → Ch4
- Concurrency: happens-before, volatile, lock-free structures → Ch6
- CAP theorem and consistency models → Ch16, Ch17

**Frequently Asked**
- JVM internals — classloading, bytecode, GC algorithms → Ch5
- REST API design and idempotency → Ch9
- SQL joins, window functions, query plan analysis → Ch14, Ch15
- Clean code principles and SOLID → Ch20

**Nice to Have**
- Protocol Buffers / gRPC (Google's internal default)
- MapReduce conceptual understanding → Ch22
- LLD — design a chess game, parking lot, elevator → Ch21

### What Sets Google Apart
- **The coding bar is genuinely higher** — they expect optimal solutions, not just working code. If your solution is O(n²) and O(n) is possible, they will tell you and expect you to find it.
- **Thinking out loud is mandatory** — they score on your reasoning process, not just the final answer. Silence for 3 minutes is a red flag.
- **The Googleyness round is not soft** — they are assessing whether you will be a nightmare to work with. "How did you handle a disagreement?" needs a real nuanced answer.
- **System design at Google scale means truly massive** — design for billions of requests, petabytes of data, global distribution.
- **They hire from a hiring committee that does not know you** — your interviewer's feedback is translated through a rubric, so how you communicate matters as much as what you say.

### Sample Questions They Actually Ask
1. Design Google Docs — collaborative real-time editing for millions of concurrent users.
2. Given an infinite stream of search queries, find the top-K most frequent queries at any point in time.
3. Design a distributed key-value store (Bigtable-inspired) — what does your data model look like?
4. Implement LRU Cache with O(1) get and put. Then make it thread-safe. (Ch6, Ch3)
5. Tell me about a time you had to learn a completely new technology quickly to solve a problem.
6. Design YouTube's video upload and transcoding pipeline.
7. Given a 10GB log file on a machine with 1GB RAM, find the 100 most frequent IP addresses.

### Red Flags That Kill Candidates
- Jumping to code before discussing approach — Google interviewers want to see you think before you type.
- Not stating time/space complexity for every solution — this is table stakes at Google.
- Giving a brute-force solution and not recognizing there's a better approach.
- In SD, not pushing the design to Google-level scale — millions/billions, not thousands.
- Giving corporate non-answers in the Googleyness round — they will probe until they get a real example.

### Preparation Checklist
- [ ] Solve 50+ LeetCode Medium/Hard problems, focusing on graphs, DP, and string manipulation
- [ ] Practice stating Big-O before writing a single line of code (habit formation)
- [ ] Deep dive JVM internals — GC types, G1 vs ZGC, memory model (Ch5)
- [ ] Study Google-scale design papers: Bigtable, Spanner, Chubby — map to Ch17, Ch22
- [ ] Practice "think out loud" by recording yourself solving problems
- [ ] Know Java Streams, Optional, and functional interfaces inside out (Ch4)
- [ ] Prepare 5 real behavioral stories with measurable outcomes for the Googleyness round
- [ ] Design 3 "at Google scale" systems from scratch: search index, maps, ads serving
- [ ] Know CAP theorem well enough to argue both sides in a real trade-off discussion (Ch17)
- [ ] Practice system design with a 45-minute timer — scope, design, deep-dive, wrap-up

### Recommended Study Plan
Use **Plan A (6-week)** with extra focus on **Ch5 (JVM), Ch17 (Distributed DBs), Ch22 (HLD)**, and dedicate Week 1 entirely to DSA re-baseline.

---

## Meta / Facebook

### What They're Actually Hiring For
Meta hires for engineers who move fast, make data-driven decisions, and are comfortable with ambiguity and rapid product change. They value pragmatic engineering — shipping at scale matters more than theoretical purity. Social graph problems are uniquely theirs.

### Interview Format
- **5 rounds** virtual onsite (no phone screen in some markets)
- Typical duration: 4 hours
- You talk to: 2 coding interviewers, 1 system design, 1 behavioral (often hiring manager), 1 optional ML/product round for senior roles

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Coding 1 | DSA | 45 min | Usually graphs or arrays — must get to optimal |
| Coding 2 | DSA | 45 min | Trees, DP, or string manipulation |
| System Design | HLD | 60 min | Social-scale system, feed ranking systems |
| Behavioral | Life story + values | 45 min | "Why Meta?", impact, collaboration |
| Product Sense (senior) | Product + engineering | 45 min | How would you instrument and improve X? |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Graph traversal on social networks — friend-of-friend, shortest path, connected components → Ch22
- Distributed feed systems — fan-out on write vs fan-out on read → Ch22, Ch17
- Java concurrency fundamentals (Meta services are largely JVM-based) → Ch6
- Caching strategies — what to cache, TTL design, cache invalidation → Ch12
- REST API design at scale → Ch9

**Frequently Asked**
- Kafka for activity event pipelines → Ch11
- ACID vs eventual consistency for social data → Ch16, Ch17
- OOP design — clean class hierarchies, design patterns → Ch1, Ch19
- SQL for analytics queries → Ch14, Ch15

**Nice to Have**
- React/GraphQL for full-stack context (mostly backend but SD may touch it)
- Paxos/Raft consensus understanding → Ch17
- LLD design exercises → Ch21

### What Sets Meta Apart
- **"Move fast" is still real** — they want to hear about shipping, not just designing. Say "how I would deploy this incrementally" not just "this is my architecture."
- **Social graph problems are unique** — fan-out, news feed, friend recommendation are signature Meta questions. If you've never thought deeply about them, you will feel it.
- **The behavioral round really matters** — Meta explicitly uses their values (Move Fast, Be Bold, Focus on Impact, Be Open, Build Social Value). Know them and map your stories.
- **Data instrumentation is expected** — for any system you design, they expect you to explain what metrics you'd track and how you'd detect degradation.
- **They push on scale numbers** — "how many requests per second?" at every step of the design.

### Sample Questions They Actually Ask
1. Design Facebook's News Feed — both fan-out-on-write and fan-out-on-read approaches, trade-offs.
2. Design a messaging system like WhatsApp — end-to-end, message ordering, read receipts.
3. Implement a graph BFS that finds all friends within N degrees of separation.
4. You have a service that randomly returns stale data. Walk me through how you'd debug it.
5. Tell me about your most impactful project — what would you do differently?
6. Design a rate limiter that works globally across Meta's data centers.
7. Given an activity stream of 1 billion events/day, design the pipeline to compute DAU/MAU.

### Red Flags That Kill Candidates
- Not engaging with scale numbers — Meta will explicitly ask "how many users?" and expect you to design for it.
- Behavioral answers that lack clear personal ownership — they want "I did X" not "we did X."
- Ignoring cache invalidation — Meta interviewers will probe your caching design until you address invalidation.
- Being dogmatic about consistency — sometimes eventual consistency is correct, and Meta expects you to defend it.
- Not asking clarifying questions in SD — they have specific requirements in mind and are testing if you surface them.

### Preparation Checklist
- [ ] Study fan-out-on-write vs fan-out-on-read deeply — know the exact trade-off points (Ch22)
- [ ] Solve 30+ graph problems on LeetCode — DFS, BFS, union-find, shortest path
- [ ] Practice designing systems at 100M-1B user scale with explicit numbers
- [ ] Know Redis data structures: sorted sets for feed ranking, pub/sub for notifications (Ch12)
- [ ] Prepare impact-focused behavioral stories using Meta's values framework
- [ ] Understand Kafka consumer lag and how you'd monitor a real-time pipeline (Ch11)
- [ ] Know Java's ConcurrentHashMap, BlockingQueue, and ForkJoinPool (Ch6)
- [ ] Design the news feed system from scratch 3 times until you can do it in 10 minutes
- [ ] Practice adding metrics/observability to every system design answer
- [ ] Know cache invalidation patterns: write-through, write-behind, cache-aside (Ch12)

### Recommended Study Plan
Use **Plan B (4-week)** with extra focus on **Ch12 (Redis/Caching), Ch17 (Distributed DBs), Ch22 (HLD)**. Spend 3 days specifically on social graph system design.

---

## Microsoft

### What They're Actually Hiring For
Microsoft hires strong generalists who can work across a large, complex product surface. They value collaborative problem solving — they care about how you think through a problem with someone, not just whether you get the right answer. Azure experience is a plus but not required for non-Azure teams.

### Interview Format
- **4-5 rounds** virtual onsite after a recruiter screen
- Typical duration: 3.5-4.5 hours
- You talk to: SWEs, a Senior SWE, and often the Hiring Manager in the final round
- Some teams use an "As Appropriate" (AA) interview — an independent evaluator

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Recruiter Screen | General fit + experience | 30 min | Background, motivations, rough technical check |
| Coding 1 | DSA | 45 min | Medium-level problem, clean code expected |
| Coding 2 | DSA or OOP | 45 min | May involve object-oriented design problem |
| System Design | HLD or LLD | 60 min | More conversational than Google/Amazon |
| Hiring Manager | Behavioral + vision | 30-45 min | Culture fit, team-specific questions |

### High-Frequency Topics (with chapter refs)

**Must Know**
- OOP design — solid Java class design, inheritance vs composition → Ch1, Ch19, Ch20
- Spring Boot REST APIs with exception handling and validation → Ch7, Ch9
- JPA/Hibernate with lazy loading, N+1 awareness → Ch8
- SQL — joins, aggregations, stored procedures → Ch14
- Basic distributed system concepts — availability, partitioning → Ch22

**Frequently Asked**
- Java Collections — which data structure and why → Ch3
- Design patterns: Factory, Singleton, Observer, Decorator → Ch19
- Microservices patterns — service discovery, API gateway → Ch10
- Redis as cache with TTL strategy → Ch12

**Nice to Have**
- Azure-specific services for SD rounds in Azure teams
- SOLID principles and clean architecture → Ch20
- LLD case studies — elevator, parking lot → Ch21

### What Sets Microsoft Apart
- **The interview is more collaborative** — Microsoft interviewers often guide you if you're stuck. They want to see how you respond to hints.
- **OOP is taken more seriously** — Microsoft has a large C#/Java/C++ codebase culture. Poor class design is a genuine red flag.
- **The LLD round is more common** — unlike Google/Amazon which are HLD-heavy, Microsoft may give you an object design problem.
- **Team-specific variation is high** — Azure vs Office vs Xbox vs Surface all have different bars and focuses. Research your specific team.
- **The Hiring Manager round can make or break you** — if they don't see you fitting the team dynamic, they'll pass even if technical rounds went well.

### Sample Questions They Actually Ask
1. Design an elevator system — class hierarchy, scheduling algorithm, edge cases. (Ch21)
2. How would you build a collaborative document editing system like OneDrive?
3. Implement a thread-safe Singleton in Java — cover double-checked locking. (Ch6, Ch19)
4. Tell me about a time you improved a process or system that was inefficient.
5. You have a Spring Boot service running slowly in production — step through your investigation.
6. Design a notification system for Microsoft Teams — handle 500M users across time zones.
7. What is the N+1 problem in JPA and how do you fix it? (Ch8)

### Red Flags That Kill Candidates
- Getting defensive when the interviewer offers a different approach — Microsoft values collaborative problem solving.
- Weak OOP — Microsoft comes from a strong object-oriented tradition; basic design smell is noticed.
- Not researching the team — "Why Microsoft?" answered with generic answers is spotted immediately.
- Poor error handling in code — try-catch blocks that swallow exceptions, null pointer risks.
- In SD, staying too abstract and never discussing concrete implementation choices.

### Preparation Checklist
- [ ] Practice OOP design from scratch — design 5 real-world systems using class diagrams (Ch1, Ch21)
- [ ] Know every Spring Boot annotation and what it does under the hood (Ch7)
- [ ] Be comfortable with JPA one-to-many, many-to-many, and cascade options (Ch8)
- [ ] Solve 25 LeetCode mediums across arrays, trees, and strings
- [ ] Practice accepting hints gracefully — rehearse responses to "what if you tried X instead?"
- [ ] Research your specific Microsoft team and know their product deeply
- [ ] Prepare behavioral stories mapped to Microsoft's culture (Growth Mindset, Inclusion, Collaboration)
- [ ] Know Java design patterns with code-level examples, not just definitions (Ch19)
- [ ] Practice LLD: parking lot, library management system, ATM (Ch21)
- [ ] Know SQL window functions and when to use them vs subqueries (Ch14)

### Recommended Study Plan
Use **Plan B (4-week)** with extra focus on **Ch1 (OOP), Ch8 (JPA/Hibernate), Ch19 (Design Patterns), Ch21 (LLD)**.

---

## Netflix

### What They're Actually Hiring For
Netflix hires for "highly aligned, loosely coupled" — senior engineers who can operate with extreme autonomy. They value context over control, which means they want engineers who can make the right call independently. The bar on both distributed systems and Java is exceptionally high, and they expect you to have real opinions about architecture.

### Interview Format
- **5-6 rounds** virtual (often spread across 2 days for senior roles)
- Typical duration: 5+ hours total
- You talk to: Senior SWEs, a Staff/Principal engineer, and sometimes a VP
- Take-home coding challenge for some teams before onsite

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Phone Screen | Coding + experience | 60 min | One coding problem + deep experience discussion |
| Coding 1 | Java/DSA | 60 min | Real coding problem — production quality expected |
| System Design 1 | HLD (streaming infra) | 60 min | Video delivery, recommendation, or observability |
| System Design 2 | HLD or architecture | 60 min | Often tests breadth — resiliency, chaos engineering |
| Architecture Review | Deep technical discussion | 60 min | Your past systems — defended like a PhD defense |
| Culture/Values | Netflix culture fit | 45 min | Freedom & Responsibility, high performance |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Microservices resilience: Circuit Breaker, bulkhead, retry with backoff → Ch10, Ch19
- Kafka at scale — consumer groups, lag monitoring, compacted topics → Ch11
- Redis for distributed session and caching → Ch12
- JVM deep dive — GC tuning for low-latency streaming services → Ch5
- Java advanced concurrency — reactive streams, Project Reactor → Ch6

**Frequently Asked**
- CDN design and content delivery optimization → Ch22
- Distributed tracing and observability → Ch10, Ch22
- CQRS and event sourcing patterns → Ch19, Ch22
- Spring Boot with Eureka, Ribbon, Hystrix → Ch7, Ch10

**Nice to Have**
- Chaos engineering principles (Netflix invented it)
- A/B testing system design
- Cassandra and wide-column store concepts → Ch17, Ch18

### What Sets Netflix Apart
- **The autonomy bar is the real filter** — they are not hiring someone to follow instructions. Every answer should demonstrate independent judgment.
- **Chaos engineering is their culture** — expect questions about how your system handles failure, not just how it works when healthy.
- **Senior engineers defend past work like a thesis** — the Architecture Review round means you MUST know your past projects deeply, including every trade-off you made and why.
- **The freedom comes with high accountability** — "we had some issues" is not an answer. They want root cause, your specific decision, and what you'd do differently.
- **They value opinionated engineers** — if you hedge everything, they lose interest. Pick a stance and defend it.

### Sample Questions They Actually Ask
1. Design Netflix's video streaming infrastructure — from upload to play, at 200M subscribers.
2. How would you build a recommendation engine that updates in near real-time with user behavior?
3. Your microservice has a cascading failure issue — walk me through how you'd add resilience.
4. Tell me about the most complex distributed system you've designed or significantly contributed to.
5. Design a global rate limiter with no single point of failure across 5 regions.
6. How does ZGC differ from G1GC and when would you choose one over the other? (Ch5)
7. You need exactly-once processing for payment events in Kafka — how do you achieve it? (Ch11)

### Red Flags That Kill Candidates
- Hedging every technical opinion — Netflix reads this as lacking depth or conviction.
- Not knowing your own past projects well enough to defend trade-offs under pressure.
- Ignoring operational concerns — Netflix lives by operational excellence; pure design without ops is incomplete.
- Not knowing Java/JVM internals at a senior level — they expect deep platform knowledge (Ch5, Ch6).
- Generic culture answers — saying "I work well independently" without a concrete story.

### Preparation Checklist
- [ ] Deep dive JVM GC: G1, ZGC, Shenandoah — know when to use each and how to tune (Ch5)
- [ ] Implement a Circuit Breaker from scratch, not just use Resilience4j (Ch19)
- [ ] Know Kafka exactly-once semantics with transactional producers/consumers (Ch11)
- [ ] Design Netflix streaming architecture from scratch 3 times
- [ ] Prepare to defend every major technical decision you made in your last 3 years of work
- [ ] Study chaos engineering principles — failure injection, steady-state hypothesis
- [ ] Know Project Reactor/RxJava for reactive programming patterns (Ch6)
- [ ] Practice "what would you do differently?" questions about your own past projects
- [ ] Know Cassandra data modeling at a conceptual level (Ch17, Ch18)
- [ ] Prepare 3 stories where you exercised independent technical judgment against popular opinion

### Recommended Study Plan
Use **Plan A (6-week)** with heavy focus on **Ch5 (JVM), Ch6 (Concurrency), Ch10 (Microservices), Ch11 (Kafka)**. Add a dedicated week for past project deep-dive preparation.

---

## Uber / Lyft

### What They're Actually Hiring For
Uber/Lyft need engineers who can handle real-time geospatial systems, high-throughput event pipelines, and the unique challenges of marketplace engineering (two-sided supply/demand). They value engineers who can own a problem end-to-end and think about reliability under traffic spikes.

### Interview Format
- **4-5 rounds** virtual onsite
- Typical duration: 4 hours
- You talk to: 2 SWEs for coding, 1-2 for system design, 1 engineering manager
- Lyft tends to be slightly more collaborative/warmer; Uber is slightly more rigorous

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Phone Screen | Coding | 45 min | One DSA problem, clean implementation |
| Coding 1 | DSA | 45 min | Arrays, graphs, real-world constraint problems |
| Coding 2 | DSA or system | 45 min | Sometimes a mini-system coding problem |
| System Design | HLD | 60 min | Real-time geo, dispatch, surge pricing systems |
| Engineering Manager | Behavioral | 45 min | Impact, collaboration, growth mindset |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Real-time geospatial systems — H3 indexing, proximity queries → Ch22
- Kafka for ride events, driver location updates, pricing pipelines → Ch11
- Redis for real-time state: driver location, ride matching → Ch12
- SQL for analytics — trip data, driver earnings, surge zones → Ch14, Ch15
- Microservices patterns: rate limiting, service mesh → Ch10

**Frequently Asked**
- Distributed transactions — saga pattern for ride lifecycle → Ch16, Ch19
- JVM performance — latency-sensitive services → Ch5
- REST API design for mobile clients with offline support → Ch9
- Concurrency — handling concurrent driver/rider matching → Ch6

**Nice to Have**
- ML pipeline design for surge pricing, ETA prediction
- gRPC vs REST decision for internal services
- Event sourcing for audit trail → Ch19

### What Sets Uber/Lyft Apart
- **Geospatial is their signature** — no other company asks about geohashing, H3 indexing, or proximity search as regularly. If you've never thought about this, spend a day on it.
- **The marketplace problem is unique** — supply (drivers) and demand (riders) are dynamic, creating interesting distributed state management problems.
- **Traffic spike engineering is real** — Uber handles New Year's Eve 10x spikes. Questions about auto-scaling, queue buffering, and backpressure are common.
- **They care about latency** — ride matching happens in <1 second. Latency optimization, not just throughput, is a key concern.
- **Lyft's engineering culture is notably more open** — they publish extensively on their tech blog and often ask about industry trends.

### Sample Questions They Actually Ask
1. Design Uber's driver-rider matching system — real-time, globally distributed, sub-second matching.
2. How would you build surge pricing? What data do you need and how do you compute it in real-time?
3. Design the location tracking system for 1M active drivers updating location every 5 seconds.
4. Implement a leaky bucket rate limiter in Java. Now make it distributed. (Ch6, Ch10)
5. You have a microservice that processes ride completions. It's losing events under traffic spikes — fix it.
6. Tell me about a time you improved system reliability under high load.
7. Design a trip receipt generation system that handles edge cases: cancelled trips, refunds, promos.

### Red Flags That Kill Candidates
- No awareness of geospatial concepts — designing Uber's location system without knowing geo-indexing.
- Over-engineering for average load without discussing peak load and surge capacity.
- Not knowing Kafka consumer lag and how to detect/fix a lagging consumer (Ch11).
- Ignoring idempotency — payment and trip completion events must be idempotent.
- Vague behavioral answers with no quantified impact.

### Preparation Checklist
- [ ] Study H3 geospatial indexing and geohash — understand proximity queries at scale
- [ ] Design the driver location tracking system (1M drivers, 5-second updates) from scratch
- [ ] Know Kafka backpressure, consumer groups, and lag alerting (Ch11)
- [ ] Implement rate limiting — token bucket and leaky bucket — in Java (Ch10)
- [ ] Know Redis sorted sets for leaderboard/location ranking (Ch12)
- [ ] Study Saga pattern for distributed transactions (Ch19)
- [ ] Practice SQL for time-series data — trips per hour, average wait time by zone (Ch14)
- [ ] Know Circuit Breaker and bulkhead patterns with code examples (Ch10, Ch19)
- [ ] Prepare behavioral stories focused on reliability improvements with numbers
- [ ] Study the Uber/Lyft engineering blogs — they publish their actual systems

### Recommended Study Plan
Use **Plan B (4-week)** with extra focus on **Ch11 (Kafka), Ch12 (Redis), Ch22 (HLD)**. Add 3 days on geospatial system design which is not covered extensively in standard prep.

---

## Stripe

### What They're Actually Hiring For
Stripe wants engineers who are obsessive about correctness, API design, and developer experience. They are building financial infrastructure, which means correctness and reliability are non-negotiable. They value engineers who can reason about distributed systems in the context of money movement — idempotency, exactly-once, and auditability are first-class concerns.

### Interview Format
- **5 rounds** virtual onsite (sometimes a take-home first)
- Typical duration: 4.5 hours
- You talk to: 2 coding interviewers, 1 system design, 1 API/product design, 1 behavioral
- Take-home: a real coding problem on their platform, often involves their API

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Take-Home | Coding (Stripe API) | 3-4 hours | Real implementation quality, not DSA |
| Coding 1 | DSA + correctness | 45 min | Production-quality code, edge cases |
| Coding 2 | System implementation | 45 min | Build a small system component correctly |
| System Design | HLD (payments infra) | 60 min | Payment processing, idempotency, reliability |
| API Design | REST API design | 45 min | Stripe-quality API: versioning, errors, pagination |
| Behavioral | Culture + values | 30 min | Curiosity, ownership, user empathy |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Idempotency keys and exactly-once processing → Ch16, Ch9
- Distributed transactions for payment flows → Ch16, Ch17
- REST API design best practices — versioning, error codes, pagination → Ch9
- ACID transactions — isolation levels, optimistic vs pessimistic locking → Ch16
- Event-driven architecture for payment state machines → Ch11, Ch19

**Frequently Asked**
- Redis for idempotency key storage → Ch12
- SQL for financial reporting and reconciliation → Ch14, Ch16
- Java exception handling — custom exceptions, error propagation → Ch2
- Kafka for payment event streaming → Ch11

**Nice to Have**
- Double-entry bookkeeping concepts
- PCI DSS compliance at an architectural level
- Webhook design and delivery guarantees → Ch9, Ch11

### What Sets Stripe Apart
- **Correctness over speed** — this is the company that will fail you for not handling edge cases, not for having an O(n²) solution. If your code has a race condition in a payment flow, that's disqualifying.
- **API design is a first-class interview** — Stripe's public API is considered the gold standard. They expect you to think like an API designer, not just a backend engineer.
- **The take-home is a real test** — they read your code carefully, including commit history, test coverage, and documentation.
- **Financial domain knowledge matters** — you don't need to be an accountant, but idempotency, double-entry accounting, and reconciliation are real topics.
- **They care about developer experience** — when designing APIs, "how does this feel to the person calling it?" is as important as technical correctness.

### Sample Questions They Actually Ask
1. Design Stripe's payment processing system — from card charge to settlement, handling failures idempotently.
2. Your payment service processes a charge and the network times out before you get a response. What do you do?
3. Design a webhook delivery system with at-least-once delivery and retry logic.
4. You're designing a refund API. What edge cases do you consider? Write the API spec first.
5. How do you handle distributed transactions across payment and inventory services? (Saga vs 2PC)
6. Design a rate limiter for Stripe's API — per customer, per endpoint, with burst allowance.
7. Tell me about a time you had to balance shipping fast with getting it exactly right.

### Red Flags That Kill Candidates
- Ignoring idempotency — any payment system design that doesn't address duplicate processing is a hard fail.
- Poor API design — vague error codes, inconsistent naming, no pagination on list endpoints.
- Weak exception handling in code — Stripe's systems cannot silently fail.
- Not knowing SQL isolation levels — phantom reads and dirty reads have real consequences in payments (Ch16).
- Prioritizing clever code over readable, maintainable code — Stripe values clarity.

### Preparation Checklist
- [ ] Study idempotency key patterns — implementation in Java with Redis (Ch12, Ch16)
- [ ] Read Stripe's API documentation and understand their design decisions
- [ ] Know all SQL isolation levels with concrete examples of anomalies each prevents (Ch16)
- [ ] Practice REST API design: design 5 APIs from scratch focusing on error codes, versioning, pagination (Ch9)
- [ ] Know the Outbox pattern for reliable event publishing with exactly-once semantics (Ch11, Ch19)
- [ ] Implement a distributed rate limiter with burst allowance from scratch
- [ ] Study the Saga pattern choreography vs orchestration with payment examples (Ch19)
- [ ] Practice writing production-quality code in take-home setting — tests included
- [ ] Know Java checked vs unchecked exceptions and when to use each (Ch2)
- [ ] Study double-entry bookkeeping at a conceptual level — it comes up in reconciliation design

### Recommended Study Plan
Use **Plan B (4-week)** with heavy focus on **Ch9 (REST APIs), Ch16 (ACID/Transactions), Ch11 (Kafka)**. Reserve one full week for API design practice and Stripe API documentation study.

---

## Atlassian

### What They're Actually Hiring For
Atlassian hires engineers who care deeply about developer productivity and collaboration tooling. They value good software craftsmanship, strong opinions on code quality, and the ability to work across a complex product surface (Jira, Confluence, Bitbucket, Trello). Their interview culture is known for being more conversational and less high-pressure than FAANG.

### Interview Format
- **4-5 rounds** virtual onsite
- Typical duration: 3.5-4 hours
- You talk to: SWEs, a Tech Lead, and an Engineering Manager
- Some teams include a "Values" interview (5 Atlassian values: Open Company, Don't #@!% the Customer, Play as a Team, Be the Change, Build with Heart and Balance)

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Recruiter Screen | Background + fit | 30 min | Experience, motivations, culture check |
| Coding 1 | DSA | 45 min | Clean, working code — medium level |
| System Design | HLD or LLD | 60 min | Collaboration tools, issue tracking, notifications |
| Technical Deep Dive | Past project discussion | 45 min | Architecture decisions you've made |
| Values/Culture | Behavioral | 45 min | Atlassian values — specific stories required |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Spring Boot microservices — standard CRUD + event-driven → Ch7, Ch9, Ch10
- JPA/Hibernate — entity relationships, lazy/eager loading → Ch8
- REST API design — pagination, filtering, versioning → Ch9
- SQL — relational data modeling for project/issue data → Ch14
- Basic distributed system concepts → Ch22

**Frequently Asked**
- Redis for caching with eviction policies → Ch12
- Java OOP and design patterns → Ch1, Ch19
- Clean code and SOLID → Ch20
- Microservices communication patterns → Ch10

**Nice to Have**
- Kafka for real-time notification pipelines → Ch11
- LLD for collaboration tools → Ch21
- GraphQL API design (used in newer Atlassian products)

### What Sets Atlassian Apart
- **The culture bar is genuinely different** — Atlassian will pass on a strong technical candidate who doesn't embody their values. Take the values interview seriously.
- **The technical deep dive is uncommon elsewhere** — they want to understand how you think about past architecture decisions. "We chose X over Y because..." is what they're looking for.
- **They build for developers** — they expect you to have opinions about developer experience, not just implementation details.
- **The interview is more of a conversation** — less trick questions, more "help us think through this problem together."
- **Remote-first culture means written communication is important** — some Atlassian teams assess how well you structure technical explanations.

### Sample Questions They Actually Ask
1. Design Jira's issue tracking system — hierarchy of projects, epics, stories, subtasks; comment threading.
2. How would you build Confluence's real-time collaborative editing?
3. Design a notification system for Jira — users watching issues, @mentions, digest emails.
4. Tell me about a time you advocated for better engineering practices when it wasn't your job to.
5. Your Spring Boot service is getting N+1 query problems at scale — identify and fix it. (Ch8)
6. Design a search system for Jira — full-text search across issues, comments, and attachments.
7. How do you handle breaking API changes when you have 200,000 developer customers?

### Red Flags That Kill Candidates
- Not having genuine stories for the values interview — generic answers are easy to spot.
- Ignoring backwards compatibility in API design — Atlassian's developer ecosystem makes breaking changes catastrophic.
- Poor JPA knowledge — N+1 problems, incorrect cascade types, missing indexes (Ch8).
- Dismissiveness about non-FAANG scale — Atlassian products serve millions of professional developers.
- Not asking questions at the end — Atlassian values curiosity and engagement.

### Preparation Checklist
- [ ] Read Atlassian's 5 values and prepare one specific story per value
- [ ] Know JPA deeply — FetchType, CascadeType, orphanRemoval, and JPQL (Ch8)
- [ ] Design Jira's data model from scratch — issues, hierarchy, comments, watchers
- [ ] Practice API versioning strategies — URL versioning, header versioning, trade-offs (Ch9)
- [ ] Prepare 3 past projects you can discuss at depth including what you'd change
- [ ] Know Spring Boot autoconfiguration and how to customize it (Ch7)
- [ ] Study full-text search design — inverted index concepts → Ch22
- [ ] Solve 20 LeetCode mediums — Atlassian coding bar is real but not FAANG-level
- [ ] Know Redis cache-aside pattern implementation in Spring (Ch12)
- [ ] Practice collaborative problem-solving style — ask questions, think out loud

### Recommended Study Plan
Use **Plan C (2-week intensive)** with focus on **Ch7 (Spring Boot), Ch8 (JPA), Ch9 (REST APIs)**. Spend 3 days on values storytelling — it is not optional at Atlassian.

---

## Salesforce

### What They're Actually Hiring For
Salesforce hires for engineers who can work in a multi-tenant, highly configurable enterprise SaaS environment. They care about data isolation, performance at enterprise scale, and robust API design. Trust is their #1 value, and that manifests as security consciousness and reliability engineering.

### Interview Format
- **4-5 rounds** virtual onsite
- Typical duration: 4 hours
- You talk to: SWEs, an Architect, and often a role-specific leader
- Some orgs include a technical presentation round for senior candidates

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Phone Screen | Technical + background | 45 min | Java, Spring, past experience overview |
| Coding 1 | DSA + Java | 45 min | Medium DSA, Java idioms |
| System Design | HLD — enterprise SaaS | 60 min | Multi-tenancy, metadata-driven architecture |
| Architecture/Deep Dive | Past system or hypothetical | 60 min | Architecture decisions, trade-offs |
| Behavioral/Values | Salesforce V2MOM alignment | 30-45 min | Trailblazer culture, customer success |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Multi-tenant architecture — data isolation strategies (shared schema, row-level security) → Ch22, Ch17
- Spring Boot enterprise patterns — interceptors, AOP, custom annotations → Ch7
- JPA for complex multi-tenant data models → Ch8
- SQL for large-scale reporting with row-level security → Ch14, Ch16
- REST API design with OAuth 2.0 → Ch9, Ch13

**Frequently Asked**
- Redis for tenant-scoped caching → Ch12
- Kafka for CRM event streaming → Ch11
- Security: JWT, OAuth 2.0, RBAC → Ch13
- Microservices in enterprise context → Ch10

**Nice to Have**
- Apex (Salesforce's proprietary language) conceptual awareness
- Heroku/Salesforce platform architecture understanding
- GDPR/data sovereignty implications on multi-tenant design

### What Sets Salesforce Apart
- **Multi-tenancy is the defining technical challenge** — almost everything technical at Salesforce comes back to "how does this work in a multi-tenant context?"
- **Enterprise customers have enterprise SLAs** — 99.99% uptime, zero data leakage between tenants, audit trails are non-negotiable.
- **Trust first** — security considerations are expected in every system design answer. Authentication, authorization, data encryption at rest.
- **The V2MOM culture framework is used for alignment** — understand it before behavioral rounds.
- **Metadata-driven architecture is their competitive moat** — point-and-click configuration drives real products; understanding this shows Salesforce-specific savvy.

### Sample Questions They Actually Ask
1. Design a multi-tenant CRM system — data isolation, performance, and customization at the tenant level.
2. How would you implement row-level security in SQL for a multi-tenant application?
3. Design the Salesforce notification system — 100,000 tenants, each with 100s of users, custom triggers.
4. Your OAuth token validation is adding 50ms to every API call — how do you fix it?
5. Tell me about a time you had to make a security trade-off in system design.
6. Design a workflow automation engine where tenants can define custom triggers and actions.
7. How do you handle schema migrations in a multi-tenant database without downtime?

### Red Flags That Kill Candidates
- Ignoring multi-tenancy in system design answers — every Salesforce SD has a tenancy dimension.
- Weak security knowledge — no understanding of OAuth flows or token validation (Ch13).
- Not understanding row-level security in SQL (Ch14, Ch16).
- Overly academic answers without enterprise pragmatism — "it depends" without concrete enterprise constraints.
- Not having questions for the interviewer — Salesforce culture values curiosity.

### Preparation Checklist
- [ ] Study multi-tenant architecture patterns: schema-per-tenant, shared schema with tenant_id, dedicated DB
- [ ] Know OAuth 2.0 flows — Authorization Code, Client Credentials, Resource Owner (Ch13)
- [ ] Implement row-level security in SQL with tenant_id filtering (Ch14)
- [ ] Know Spring Security for JWT validation and role-based access control (Ch13, Ch7)
- [ ] Understand AOP in Spring for cross-cutting concerns like audit logging (Ch7)
- [ ] Design a multi-tenant notification system from scratch
- [ ] Study GDPR data isolation requirements — right to erasure in multi-tenant context
- [ ] Know Kafka consumer groups for tenant-specific event isolation (Ch11)
- [ ] Prepare behavioral stories aligned with Salesforce's Trust, Customer Success, and Innovation values
- [ ] Solve 25 LeetCode mediums with focus on string processing and tree problems

### Recommended Study Plan
Use **Plan B (4-week)** with extra focus on **Ch7 (Spring Core), Ch13 (Security), Ch22 (HLD)**. Spend 2 dedicated days on multi-tenant architecture patterns — it is Salesforce's signature topic.

---

## Goldman Sachs / FinTech (Jane Street, Citadel)

### What They're Actually Hiring For
Goldman Sachs wants engineers who can build high-performance, mission-critical financial systems where a bug costs real money. Jane Street and Citadel want exceptional computer scientists — the algorithmic and systems bar is FAANG-level or higher, with additional quantitative reasoning expectations. Correctness, performance, and risk awareness are the north stars.

### Interview Format

**Goldman Sachs:**
- **4-5 rounds** virtual onsite
- Coding + system design + behavioral + culture fit
- Emphasis on low-latency systems, data pipelines, and regulatory compliance

**Jane Street:**
- **5-6 rounds** — heavily algorithmic, often OCaml/functional (but Java/C++ acceptable)
- Take-home problem + onsite technical marathon
- Expect deep CS fundamentals, probabilistic reasoning, and trading-context problems

**Citadel:**
- **4-5 rounds** — mix of DSA, quantitative problems, and system design
- Very high bar on both algorithms and distributed systems

### Round-by-Round Breakdown (Goldman Sachs)
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Online Assessment | Coding | 90 min | 2-3 DSA problems on HackerRank |
| Technical Phone | Coding + experience | 60 min | Java, OOP, system concepts |
| System Design | HLD — financial systems | 60 min | Trade processing, risk systems, market data |
| Architecture Review | Deep dive | 60 min | Past system + trade-offs |
| Partner/MD Interview | Culture + vision | 30 min | Business acumen, communication |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Java concurrency — thread-safe data structures, lock strategies for financial data → Ch6
- ACID and isolation levels — financial transactions must be correct → Ch16
- High-throughput, low-latency system design → Ch22, Ch5
- SQL for financial reporting — aggregations, time-series queries, reconciliation → Ch14, Ch16
- Message queues and event streaming for trade events → Ch11

**Frequently Asked**
- JVM tuning for low-latency — GC pauses are catastrophic in trading → Ch5
- Redis for market data caching → Ch12
- Design patterns for financial systems: CQRS, Event Sourcing → Ch19
- REST APIs with audit trail requirements → Ch9

**Nice to Have**
- FIX protocol conceptual awareness
- Double-entry accounting
- Regulatory frameworks: MiFID II, Dodd-Frank (at a conceptual level)

### What Sets Goldman/FinTech Apart
- **Money errors are never acceptable** — your system design answers must address failure modes more carefully than anywhere else. "Retry" is not enough; you need idempotency, audit trails, and reconciliation.
- **Regulatory compliance is a real constraint** — audit logging, data retention policies, and trade surveillance are real architectural concerns.
- **Low latency is a first-class concern** — market data systems process millions of events per second. GC pause tuning is not academic here (Ch5).
- **Jane Street's bar is CS-research level** — they care deeply about algorithmic correctness and functional programming approaches.
- **Quantitative reasoning appears** — at Jane Street/Citadel, expect probability questions: expected value, binomial distributions, basic option pricing intuition.

### Sample Questions They Actually Ask
1. Design a real-time trade processing system that handles 1M trades/second with zero data loss.
2. How would you implement a rate limiter for an order management system that must be globally consistent?
3. Your financial batch reconciliation job is running too slowly — what do you investigate first?
4. Design a market data feed system — multiple exchanges, conflicting prices, last-writer-wins vs timestamp ordering.
5. What are the trade-offs between optimistic and pessimistic locking in a high-contention order book? (Ch16)
6. You have a Java service that has occasional 500ms GC pauses in production — diagnose and fix it. (Ch5)
7. Tell me about a time you found and fixed a critical bug before it went to production.

### Red Flags That Kill Candidates
- Not addressing data loss scenarios — "at-most-once" is not acceptable for financial systems.
- Weak SQL — financial data is highly relational; poor query skills are noticed (Ch14).
- Not knowing Java concurrency deeply — race conditions in trading systems lose money (Ch6).
- Generic system design answers without financial domain awareness.
- Not knowing GC tuning for low-latency requirements (Ch5).

### Preparation Checklist
- [ ] Deep dive Java `synchronized`, `ReentrantLock`, `StampedLock`, and lock-free structures (Ch6)
- [ ] Know SQL isolation levels with financial transaction examples: dirty read, phantom read (Ch16)
- [ ] Study CQRS and Event Sourcing with financial use cases (Ch19)
- [ ] Design a trade processing system end-to-end with audit trail and reconciliation
- [ ] Know JVM GC tuning: G1GC, heap sizing, GC log analysis (Ch5)
- [ ] Understand the Outbox pattern for financial event publishing (Ch11, Ch19)
- [ ] Practice quantitative reasoning: expected value, basic probability (for Jane Street/Citadel)
- [ ] Know double-entry accounting concepts — debits/credits, ledger design
- [ ] Prepare behavioral stories focused on catching defects and preventing production incidents
- [ ] Solve 40 LeetCode problems — FinTech coding bar is comparable to FAANG

### Recommended Study Plan
Use **Plan A (6-week)** with heavy focus on **Ch5 (JVM), Ch6 (Concurrency), Ch16 (ACID/Transactions)**. FinTech companies reward the depth that other companies don't reward — do not skip the deep JVM and concurrency chapters.

---

## Thoughtworks

### What They're Actually Hiring For
Thoughtworks is a consultancy that places exceptional emphasis on software craftsmanship, agile engineering, and clean code. They hire for TDD practitioners, clean code advocates, and engineers who have strong opinions about how software should be built. The technical bar is deliberately different from product companies — less about distributed systems at Google-scale, more about code quality and XP practices.

### Interview Format
- **3-4 rounds** — more process-oriented than FAANG
- Often starts with a take-home coding exercise
- Includes pair programming (unusual in industry)
- Behavioral/culture round is very important

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Online Application | CV + written answers | — | Communication, self-awareness |
| Take-Home Coding | Full implementation | 4-6 hours | TDD, clean code, SOLID, design quality |
| Pair Programming | Collaborative coding | 60 min | How you code with others, TDD habit |
| Technical Discussion | Code review + design | 60 min | Architecture choices, refactoring instincts |
| Thoughtworks Values | Culture + ethics | 45 min | Social impact, diversity, agile beliefs |

### High-Frequency Topics (with chapter refs)

**Must Know**
- TDD — writing tests before code, red-green-refactor cycle
- SOLID principles — be able to identify violations and fix them → Ch20
- Clean code — meaningful names, small functions, no magic numbers → Ch20
- OOP design — good class hierarchies, appropriate patterns → Ch1, Ch19
- Refactoring patterns → Ch20

**Frequently Asked**
- Java design patterns with real examples → Ch19
- Spring Boot fundamentals → Ch7
- REST API design principles → Ch9
- Basic SQL → Ch14

**Nice to Have**
- Domain-Driven Design concepts
- Continuous Integration/Delivery pipeline design
- Hexagonal architecture (Ports and Adapters) → Ch20

### What Sets Thoughtworks Apart
- **TDD is not optional** — it is a filter. If you cannot write a test before writing code, you will not get through the pair programming round.
- **Pair programming is in the interview** — this is unique. They are assessing how you communicate, receive feedback, and collaborate in real time.
- **The take-home is the most important round** — they read every line of your code, every commit message, every test. Code quality matters more than the algorithm used.
- **Social and ethical views matter** — Thoughtworks has a strong stance on diversity, ethics in technology, and social impact. Vague answers on these topics are noticed.
- **Consulting context shapes the role** — you will work with clients, which means communication skills, not just coding skills, are evaluated.

### Sample Questions They Actually Ask
1. In the pair programming session: "Add a feature to this existing codebase using TDD."
2. Code review exercise: "What issues do you see in this code? How would you refactor it?"
3. Tell me about a time you pushed back on a technical decision because it was the wrong approach.
4. How do you introduce TDD and clean code practices into a team that has never done them?
5. Design a simple object model for a library management system with SOLID principles. (Ch20, Ch21)
6. What does the Dependency Inversion Principle mean to you? Give a concrete Java example. (Ch20)
7. Tell me about a technology or tool you think is overused or misapplied in the industry.

### Red Flags That Kill Candidates
- Not practicing TDD before the pair programming round — it shows immediately.
- Messy commit history on the take-home — commit messages, code organization, and test coverage are read.
- Being defensive in code review — Thoughtworks expects you to take feedback graciously.
- Vague or inauthentic answers on the values/ethics round — they will probe.
- Long functions, poor naming, and no tests in the take-home coding exercise.

### Preparation Checklist
- [ ] Practice TDD for 2 weeks before interviewing — write no production code without a failing test first
- [ ] Study and internalize all 5 SOLID principles with Java examples (Ch20)
- [ ] Read "Clean Code" by Robert Martin — at least the naming, functions, and comments chapters
- [ ] Practice pair programming with someone — get comfortable coding while explaining
- [ ] Study the Strangler Fig, Extract Method, Replace Conditional with Polymorphism refactoring patterns (Ch20)
- [ ] Prepare views on technology ethics, diversity in tech, and responsible AI
- [ ] Review your take-home before submission — ensure tests cover edge cases and are readable
- [ ] Know hexagonal architecture with a concrete Java Spring example (Ch20)
- [ ] Practice writing commit messages that tell a story: "feat: add rate limiting to payment endpoint"
- [ ] Know when NOT to use design patterns — overuse is an anti-pattern (Ch19)

### Recommended Study Plan
Use **Plan C (2-week intensive)** focusing on **Ch1 (OOP), Ch19 (Design Patterns), Ch20 (SOLID/Clean Arch)**. Unlike other companies, add a dedicated week of TDD practice — it is their most important filter.

---

## Flipkart / Indian Product Companies (Swiggy, Zepto, CRED, Razorpay)

### What They're Actually Hiring For
Indian product companies are maturing rapidly and now run some of the most complex distributed systems in the world. Flipkart, Swiggy, and Zepto operate at real hyperscale (hundreds of millions of users, sub-second delivery). CRED and Razorpay have FinTech rigor. The bar is increasingly FAANG-comparable, and they value engineers who understand the Indian market's unique constraints: low bandwidth users, payment diversity, and aggressive cost optimization.

### Interview Format (Flipkart / Swiggy / Zepto)
- **4-5 rounds** virtual
- Typical duration: 3.5-4.5 hours
- Machine coding round is standard (unique to Indian companies)
- You talk to: SDE-IIs, Senior SDE, Hiring Manager
- Machine coding is 90 minutes — a real implementation problem

### Round-by-Round Breakdown
| Round | Type | Duration | What They Assess |
|---|---|---|---|
| Coding Round | DSA | 60 min | Arrays, graphs, DP — medium/hard level |
| Machine Coding | Full implementation | 90 min | OOP design, clean code, working system |
| System Design HLD | Distributed systems | 60 min | Scale, trade-offs, India-specific constraints |
| LLD (sometimes) | Object design | 45 min | Clean class design, extensibility |
| Hiring Manager | Behavioral + fitment | 30 min | Growth, impact, why this company |

### High-Frequency Topics (with chapter refs)

**Must Know**
- Machine coding proficiency — clean OOP, working code in 90 minutes → Ch1, Ch19, Ch21
- Spring Boot CRUD with proper exception handling → Ch7, Ch9
- JPA with complex relationships → Ch8
- System design for Indian-scale: 100M users, Tier 2/3 city bandwidth → Ch22
- Kafka for order events, delivery tracking, payment events → Ch11

**Frequently Asked**
- Redis for cart, session, OTP storage → Ch12
- SQL for transactional and reporting queries → Ch14, Ch15
- Java Collections — performance trade-offs → Ch3
- Microservices patterns: API gateway, service registry → Ch10

**Nice to Have (CRED/Razorpay FinTech)**
- Payment gateway internals → Ch16 (idempotency, retry logic)
- UPI integration architecture
- PCI DSS awareness → Ch13

### What Sets Indian Product Companies Apart
- **The Machine Coding round is unique** — no other country's companies do this as standardly. 90 minutes, build a working system with clean OOP. This is not a whiteboard exercise — your code must run.
- **Indian-scale has unique constraints** — 2G/3G users, UPI payments, vernacular language handling, massive traffic spikes on sale days (Flipkart Big Billion Days = Amazon Prime Day but more intense).
- **Cost optimization is a real concern** — AWS costs matter in India; engineers are expected to think about cost efficiency in design.
- **Rapid growth means architectural flexibility matters** — Zepto went from 0 to 3M orders/month in 18 months. They want engineers who can build for today and evolve for tomorrow.
- **For FinTech (CRED/Razorpay): correctness over features** — payment bugs are existential for these companies.

### Sample Questions They Actually Ask
1. Machine Coding: Build a food delivery system with restaurants, menus, ordering, and delivery assignment in 90 minutes.
2. Design Flipkart's Flash Sale system — 1M users hitting "buy" in the first second of a sale.
3. Design Swiggy's real-time delivery tracking — driver location, customer ETA, re-routing on traffic.
4. How would you design a UPI payment system for 500M transactions/day with Razorpay?
5. Design Zepto's inventory management — 10-minute delivery means real-time inventory sync across dark stores.
6. Your Spring Boot service is throwing `LazyInitializationException` — what caused it and how do you fix it? (Ch8)
7. Implement a parking lot system in 90 minutes using clean OOP principles. (Ch21)

### Red Flags That Kill Candidates
- Machine coding output that doesn't compile — they test your code.
- Messy OOP in machine coding: God classes, no separation of concerns, no interfaces (Ch1, Ch20).
- Not knowing JPA LazyInitializationException — it is the most common Hibernate bug in Spring apps (Ch8).
- Treating the HLD round as generic — not addressing India-specific constraints.
- Weak behavioral answers — Indian product companies have grown up on startup culture and want ownership mindset.

### Preparation Checklist
- [ ] Practice Machine Coding: build 5 systems in 90 minutes — parking lot, splitwise, chess, food delivery, movie booking (Ch21)
- [ ] Clean OOP habits: always use interfaces, follow SOLID in machine coding (Ch20)
- [ ] Know JPA Lazy vs Eager loading and when each causes problems (Ch8)
- [ ] Design Flash Sale system: inventory reservation, Redis distributed locks, Kafka order events (Ch12, Ch11)
- [ ] Study India-specific constraints: CDN at edge, OTP via Redis, UPI payment design
- [ ] Know Kafka for order lifecycle events end-to-end (Ch11)
- [ ] Solve 30 LeetCode mediums — Indian companies are raising their DSA bar to match FAANG
- [ ] Practice explaining system designs with cost optimization in mind
- [ ] Know Spring Boot exception handling: @ControllerAdvice, custom error responses (Ch7, Ch9)
- [ ] Prepare stories around impact, scale, and ownership — startup culture values this

### Recommended Study Plan
Use **Plan B (4-week)** with extra focus on **Ch1 (OOP), Ch8 (JPA), Ch21 (LLD Case Studies)**. Indian product companies are uniquely heavy on Machine Coding — dedicate 1 week entirely to 90-minute implementation practice.

---

## Quick Comparison Matrix

| Company | Coding | System Design | LLD | Behavioral | Java Depth | Kafka/Messaging | DB Depth | Difficulty |
|---|---|---|---|---|---|---|---|---|
| Amazon | 4 | 5 | 2 | 5 | 3 | 4 | 4 | 5 |
| Google | 5 | 5 | 3 | 3 | 4 | 2 | 3 | 5 |
| Meta | 4 | 5 | 2 | 4 | 3 | 3 | 4 | 4 |
| Microsoft | 3 | 3 | 4 | 3 | 4 | 2 | 3 | 3 |
| Netflix | 4 | 5 | 2 | 4 | 5 | 5 | 4 | 5 |
| Uber / Lyft | 3 | 5 | 2 | 3 | 3 | 4 | 4 | 4 |
| Stripe | 4 | 4 | 3 | 3 | 3 | 4 | 5 | 4 |
| Atlassian | 3 | 3 | 3 | 4 | 4 | 2 | 3 | 3 |
| Salesforce | 3 | 4 | 2 | 3 | 3 | 3 | 4 | 3 |
| Goldman Sachs | 4 | 4 | 2 | 3 | 5 | 4 | 5 | 4 |
| Jane Street | 5 | 4 | 1 | 2 | 4 | 2 | 3 | 5 |
| Thoughtworks | 2 | 2 | 5 | 4 | 3 | 1 | 2 | 3 |
| Flipkart | 4 | 4 | 5 | 3 | 3 | 4 | 3 | 4 |
| Swiggy/Zepto | 3 | 4 | 5 | 3 | 3 | 3 | 3 | 3 |
| CRED/Razorpay | 3 | 4 | 4 | 3 | 3 | 3 | 4 | 4 |

*Scale: 1 (barely tested) to 5 (critical/deep assessment)*

---

## Universal Must-Know List (Every Company)

These 15 topics appear in every product company interview regardless of the company. Master all 15 before targeting any specific company.

| # | Topic | Why It's Universal | Chapter |
|---|---|---|---|
| 1 | Java Collections internals | Every coding problem uses ArrayList, HashMap, or a tree. They will ask why you chose one over another. | Ch3 |
| 2 | OOP fundamentals — inheritance, polymorphism, encapsulation | LLD rounds exist at every company. Without solid OOP, you cannot design classes cleanly. | Ch1 |
| 3 | Java 8 Streams and Lambdas | Modern Java code uses Streams. Inability to use them reads as outdated. | Ch4 |
| 4 | Java Concurrency — synchronized, locks, thread pools | Every high-traffic service is concurrent. Thread safety questions appear everywhere. | Ch6 |
| 5 | Spring Boot fundamentals — DI, beans, AOP | If you use Java professionally, you use Spring. No exceptions. | Ch7 |
| 6 | JPA / Hibernate basics — lazy loading, N+1 | The #1 cause of production performance bugs in Java apps. Every team knows it. | Ch8 |
| 7 | REST API design — idempotency, status codes, pagination | You will design or critique an API in every interview. | Ch9 |
| 8 | SQL — joins, aggregations, indexing | Data lives in databases. SQL competence is assumed. | Ch14, Ch15 |
| 9 | ACID properties and isolation levels | Every company that handles data cares about correctness. | Ch16 |
| 10 | Microservices patterns — circuit breaker, service discovery | Modern backend is microservices. Understanding the failure modes is expected. | Ch10, Ch19 |
| 11 | Redis as cache — patterns, eviction, TTL | Redis appears in 80% of system designs as a caching layer. | Ch12 |
| 12 | Kafka fundamentals — topics, partitions, consumer groups | Event-driven architecture is the default. Kafka is the reference implementation. | Ch11 |
| 13 | CAP theorem and consistency trade-offs | System design rounds always hit this. It frames every distributed system decision. | Ch17 |
| 14 | JVM memory model — heap, GC, memory leaks | "My service is slow in production" is a universal question. JVM knowledge is expected. | Ch5 |
| 15 | Design patterns — at least Factory, Observer, Strategy, Circuit Breaker | They appear in both code and system design. Naming them correctly signals seniority. | Ch19 |

> **Important:** Do not treat these as "nice to know." These are the table stakes. Arriving at an interview without confidence in all 15 is equivalent to arriving underprepared.

---

## The 10 Questions You MUST Be Able to Answer Cold

These questions come up across virtually every company at every level. "Answering cold" means you can give a confident, correct, complete answer without hesitation — not a perfect answer, but a minimum acceptable answer that shows you know the territory.

---

**1. How does a HashMap work internally in Java?**

*Minimum acceptable answer:* HashMap uses an array of linked lists (or trees for large buckets since Java 8). `hashCode()` determines the bucket index via `hash % capacity`. Collisions are handled by chaining. When load factor (default 0.75) is exceeded, it resizes by doubling capacity and rehashing. Keys must implement `equals()` and `hashCode()` consistently. → Ch3

---

**2. What is the difference between `@Transactional` propagation types REQUIRED and REQUIRES_NEW?**

*Minimum acceptable answer:* REQUIRED joins an existing transaction or creates one if none exists. REQUIRES_NEW always creates a new transaction, suspending the current one. Use REQUIRES_NEW when you need the inner operation to commit or rollback independently — for example, writing an audit log that should persist even if the outer transaction rolls back. → Ch7, Ch16

---

**3. Explain the N+1 problem in JPA and how you solve it.**

*Minimum acceptable answer:* N+1 occurs when you fetch N parent entities and then execute 1 additional query per parent to load a lazily-loaded child collection — resulting in N+1 total queries. Fix it with `JOIN FETCH` in JPQL, `@EntityGraph`, or setting the fetch type to EAGER strategically. Always check query count in development with query logging enabled. → Ch8

---

**4. What happens when a Kafka consumer falls behind? How do you fix it?**

*Minimum acceptable answer:* Consumer lag accumulates. If lag grows unboundedly, the consumer will eventually fall off the beginning of the retention window and lose messages. Fix by: scaling consumer instances up to the partition count, increasing batch size, optimizing the processing logic, or adding more partitions to the topic. Monitor consumer lag with tools like Kafka Consumer Group commands or Burrow. → Ch11

---

**5. Design a URL shortener like bit.ly — high-level.**

*Minimum acceptable answer:* Write API generates a short hash (base62 of a counter or MD5 truncation), stores long-to-short mapping in a DB (or Redis for hot links). Read API does a DB lookup and returns a 301/302 redirect. Scale reads with Redis cache. For globally unique IDs, use a distributed ID generator (Snowflake). Handle custom aliases and expiry. → Ch22, Ch12

---

**6. What is the difference between optimistic and pessimistic locking?**

*Minimum acceptable answer:* Pessimistic locking acquires a lock before reading data, preventing concurrent modification — uses `SELECT FOR UPDATE`. Optimistic locking reads without a lock, but checks a version/timestamp before writing; if another transaction modified the record, the update fails and must retry. Use optimistic for low-contention reads, pessimistic for high-contention writes where retries are expensive. → Ch16

---

**7. How would you make a REST API endpoint idempotent?**

*Minimum acceptable answer:* The client sends a unique `Idempotency-Key` header with each request. The server stores the key and the response in a cache (Redis with TTL). Before processing, check if the key exists — if yes, return the cached response without reprocessing. This ensures duplicate retries due to network failures produce the same result without side effects. → Ch9, Ch12

---

**8. What are the SOLID principles? Give one Java example for each.**

*Minimum acceptable answer:* S — Single Responsibility (a class that handles only Order logic, not Order + Email). O — Open/Closed (add new discount types via subclassing, not modifying existing code). L — Liskov Substitution (a Square extending Rectangle violates this — use composition instead). I — Interface Segregation (split a fat interface into smaller, focused interfaces). D — Dependency Inversion (inject dependencies via constructor rather than instantiating inside the class). → Ch20

---

**9. Explain the Circuit Breaker pattern — when does it open, and what happens when it's open?**

*Minimum acceptable answer:* A Circuit Breaker wraps calls to a downstream service. In CLOSED state, calls go through normally. When failure rate exceeds a threshold, it trips to OPEN state — subsequent calls immediately return a fallback response without hitting the service. After a timeout, it enters HALF-OPEN and allows a probe request. If the probe succeeds, it closes; if not, it opens again. This prevents cascade failures under downstream outages. → Ch10, Ch19

---

**10. Describe the difference between process and thread, and when you'd use a thread pool in Java.**

*Minimum acceptable answer:* A process has its own memory space; threads share memory within a process. Threads are lightweight — creating a thread is cheaper than a process but still has overhead. A thread pool (`ExecutorService`) reuses a fixed set of threads for multiple tasks, avoiding the cost of creation/destruction on each request. Use it for concurrent I/O (HTTP calls, DB queries) where tasks are short-lived and you want bounded parallelism to avoid resource exhaustion. → Ch6

---

## Mock Interview Simulation Guide

Use this guide to run a self-contained 1-hour practice session. Do this at least 10 times before your target interviews. Record yourself — audio at minimum, video is better.

---

### The 1-Hour Solo Mock Interview

**Setup before starting:**
- Pick a company from this guide — run all 1-hour sessions with that company in mind
- Choose a system design topic (use the "Sample Questions" for that company)
- Set a timer — do not pause it

---

### 0–5 min: Behavioral Opener

Start every mock with a behavioral question. This sets tone and warms up your verbal communication.

Use one of these prompts:
- "Tell me about the most complex system you've built."
- "Describe a time you disagreed with your team's technical direction."
- "Walk me through a production incident you personally resolved."

**What to assess in your recording:**
- Did you give a specific, measured outcome? ("Reduced p99 latency from 800ms to 120ms")
- Did you use "I" vs "we" appropriately?
- Was it under 3 minutes?

---

### 5–45 min: System Design or Coding Problem

Pick one:

**Option A — System Design (40 min)**

1. **Requirements gathering (5 min):** State assumptions out loud. "I'll assume 10M daily active users, writes are infrequent relative to reads, consistency can be eventual..."
2. **High-level design (15 min):** Draw the major components. Name every service, queue, and data store.
3. **Deep dive (15 min):** Pick the hardest component. Go to API level, data model level, and failure mode level.
4. **Operational concerns (5 min):** What do you monitor? How do you scale? What's the first thing to fail under 10x load?

> **Important:** Use the chapter references from this guide for the company you chose. Amazon SD should explicitly address Kafka, Redis, and distributed consistency. Stripe SD must address idempotency.

**Option B — Coding Problem (40 min)**

1. **Read the problem (2 min):** Restate it in your own words before writing any code.
2. **Brute force approach (5 min):** State it verbally with complexity.
3. **Optimal approach (5 min):** State it with complexity before coding.
4. **Implement (20 min):** Write production-quality code — error handling, edge cases.
5. **Test with examples (8 min):** Walk through 2-3 test cases including edge cases.

> **Important:** Say every thought out loud. Google and Meta in particular score on your reasoning process.

---

### 45–55 min: Follow-Up Questions

These test depth. Do not skip this section — most candidates get caught here.

Pick 3 follow-up questions from this list:
- "How does this change if we need 10x the load?"
- "What breaks first under failure?"
- "How would you monitor this in production?"
- "Can you explain the time complexity of that algorithm more precisely?"
- "What would you do differently if you were starting over?"
- "How does your design handle duplicate events?"

**Rule:** Give a direct answer immediately, then justify. Do not hedge before committing to a position.

---

### 55–60 min: Your Questions to Ask

Every interview ends with "Do you have questions for us?" — most candidates ask generic questions. Practice asking specific, informed questions.

**Strong question templates (adapt to company):**
- "What's the hardest distributed systems problem your team is working on right now?"
- "How do you handle the trade-off between shipping fast and maintaining system reliability?"
- "What does the oncall experience look like for a new engineer on this team?"
- "Where does the team feel its technical debt is most acute?"
- "What would make someone exceptional in this role vs just successful?"

**Bad questions to avoid:**
- "What does your company do?" (Shows no preparation)
- "What's the salary?" (Save for recruiter)
- "How many vacation days?" (Wrong time)

---

### After the Mock: Self-Scoring

Score yourself on this rubric immediately after (while memory is fresh):

| Dimension | 1 (Poor) | 3 (Acceptable) | 5 (Strong) |
|---|---|---|---|
| Communication | Silence, vague | Explains most steps | Narrates clearly at all times |
| Technical Correctness | Significant errors | Minor errors | Correct and justified |
| Edge Cases | Ignored | Mentioned but not addressed | Fully handled |
| Scale Awareness | Didn't address | Mentioned numbers | Designed for numbers |
| Time Management | Ran out of time | Finished under pressure | Natural pacing |
| Follow-Up Response | Stumped | Partially answered | Direct and confident |

**Target: average 4+ across all dimensions before your real interview.**

---

> **Final note:** This guide is a targeting system, not a syllabus. The companies in this guide have told you what they care about. Your job is to close the gap between where you are and what they need. Every hour of preparation should be traceable back to a specific company, a specific chapter, or a specific skill in this guide. Unfocused prep is the #1 reason candidates with strong fundamentals still fail loops.

---

*Backend Interview Handbook — Company Guide*
*Chapters 1–27 across 6 volumes*
