# Volume 5: System Design & LLD
# Chapter 21: LLD Case Studies

---

# Chapter 21 — Low-Level Design (LLD) Case Studies: Part A

> **Target audience:** SDE2 / Senior engineers preparing for FAANG+ interviews.
> **Java version:** Java 17. **Framework:** Spring Boot 3.x where applicable.
> **Approach:** Each case study follows Requirements → Entities → Class Design → Patterns → Full Implementation → Interview Q&A.

---

## Table of Contents

- [LLD 1: Parking Lot System](#lld-1-parking-lot-system)
- [LLD 2: URL Shortener](#lld-2-url-shortener)
- [LLD 3: Rate Limiter](#lld-3-rate-limiter)

---

# LLD 1: Parking Lot System

## 1. Requirements Clarification

### Functional Requirements

| # | Requirement |
|---|---|
| FR-1 | The parking lot has multiple floors, each with multiple spots. |
| FR-2 | Spots are typed: **Compact**, **Large**, **Handicapped**, **Motorcycle**. |
| FR-3 | Vehicles are typed: **Car**, **Truck**, **Motorcycle**, **Electric**. |
| FR-4 | A vehicle can be parked in a spot compatible with its size. |
| FR-5 | On entry, issue a **Ticket** with entry timestamp, spot, and vehicle info. |
| FR-6 | On exit, calculate **fee** based on duration and vehicle type, process **Payment**. |
| FR-7 | An **Admin** can add/remove floors and spots. |
| FR-8 | A **ParkingAttendant** can manually assign spots. |
| FR-9 | System must track available spot count per floor per type in real time. |
| FR-10 | Support multiple **payment methods**: Cash, Credit Card, UPI. |

### Non-Functional Requirements

| # | Requirement |
|---|---|
| NFR-1 | High availability — the lot management service must not be a single point of failure. |
| NFR-2 | Throughput — handle hundreds of concurrent entry/exit transactions. |
| NFR-3 | Consistency — spot availability count must never go negative. |
| NFR-4 | Extensibility — adding a new vehicle or spot type must not require changing core logic. |
| NFR-5 | Observability — emit events when a spot becomes occupied/free. |

### Clarifying Questions to Ask in an Interview

1. Is this a single-building lot or distributed across locations?
2. Do electric vehicles need dedicated charging spots or just any large spot?
3. Is the fee model flat-rate, hourly, or dynamic (surge pricing)?
4. Should we model monthly passes / reserved spots?
5. Is payment synchronous (inline with exit) or async (pay-on-foot kiosks)?

---

## 2. Entities and Class Design

### Core Entities

```
ParkingLot          — Singleton; top-level aggregate
ParkingFloor        — One floor; owns a list of ParkingSpot
ParkingSpot         — Leaf; holds SpotType, status, optional Vehicle
Vehicle             — Abstract; subtypes Car, Truck, MotorcycleVehicle, ElectricCar
Ticket              — Issued on entry; links Vehicle ↔ ParkingSpot
Payment             — Settles a Ticket; amount, method, status
ParkingAttendant    — Actor; can parkVehicle / unparkVehicle
Admin               — Actor; can addFloor, addSpot, removeSpot
ParkingFeeStrategy  — Interface for pluggable fee calculation
DisplayBoard        — Observer; reflects available spot counts
```

### Key Attributes and Methods

**`ParkingLot` (Singleton)**
- `String id`, `String name`, `String address`
- `List<ParkingFloor> floors`
- `Map<String, Ticket> activeTickets`
- `+getInstance(): ParkingLot`
- `+issueTicket(Vehicle): Ticket`
- `+processExit(String ticketId, PaymentMethod): Payment`
- `+getAvailableSpots(SpotType): List<ParkingSpot>`

**`ParkingFloor`**
- `int floorNumber`, `Map<SpotType, List<ParkingSpot>> spotsByType`
- `Map<SpotType, Integer> availableCount`
- `+getFirstAvailable(SpotType): Optional<ParkingSpot>`
- `+notifyObservers(SpotType, int delta)`

**`ParkingSpot`**
- `String id`, `SpotType type`, `SpotStatus status`, `Vehicle parkedVehicle`
- `+park(Vehicle): void`
- `+unpark(): Vehicle`
- `+isAvailable(): boolean`

**`Vehicle` (Abstract)**
- `String licensePlate`, `VehicleType type`, `String color`
- `+getVehicleType(): VehicleType`
- `+getRequiredSpotType(): SpotType`

**`Ticket`**
- `String ticketId`, `Vehicle vehicle`, `ParkingSpot spot`, `LocalDateTime entryTime`, `LocalDateTime exitTime`, `TicketStatus status`

**`Payment`**
- `String paymentId`, `Ticket ticket`, `double amount`, `PaymentMethod method`, `PaymentStatus status`, `LocalDateTime timestamp`

**`ParkingFeeStrategy` (Interface)**
- `+calculateFee(Ticket): double`

---

## 3. Design Patterns

| Pattern | Where Applied | Why |
|---|---|---|
| **Singleton** | `ParkingLot` | One lot instance; global access point for all operations. |
| **Factory Method** | `VehicleFactory`, `SpotFactory` | Decouple creation of Vehicle/Spot subtypes from business logic. |
| **Strategy** | `ParkingFeeStrategy` | Swap fee algorithms (hourly, flat, EV discount) without touching exit flow. |
| **Observer** | `DisplayBoard` observes `ParkingFloor` | Display boards update automatically when spot availability changes. |

---

## 4. Complete Java 17 Implementation

```java
// ─────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────

package com.interview.lld.parking;

public enum SpotType {
    MOTORCYCLE, COMPACT, LARGE, HANDICAPPED, ELECTRIC
}

public enum VehicleType {
    MOTORCYCLE, CAR, TRUCK, ELECTRIC
}

public enum SpotStatus {
    AVAILABLE, OCCUPIED, OUT_OF_SERVICE
}

public enum TicketStatus {
    ACTIVE, PAID, LOST
}

public enum PaymentMethod {
    CASH, CREDIT_CARD, UPI
}

public enum PaymentStatus {
    PENDING, COMPLETED, FAILED, REFUNDED
}
```

```java
// ─────────────────────────────────────────────
// VEHICLE HIERARCHY
// ─────────────────────────────────────────────

package com.interview.lld.parking;

public abstract class Vehicle {
    protected final String licensePlate;
    protected final VehicleType vehicleType;
    protected final String color;

    protected Vehicle(String licensePlate, VehicleType vehicleType, String color) {
        this.licensePlate = licensePlate;
        this.vehicleType  = vehicleType;
        this.color        = color;
    }

    public String getLicensePlate() { return licensePlate; }
    public VehicleType getVehicleType() { return vehicleType; }

    /** Returns the minimum spot type this vehicle requires. */
    public abstract SpotType getRequiredSpotType();

    @Override
    public String toString() {
        return vehicleType + "[" + licensePlate + "]";
    }
}

public class MotorcycleVehicle extends Vehicle {
    public MotorcycleVehicle(String licensePlate, String color) {
        super(licensePlate, VehicleType.MOTORCYCLE, color);
    }
    @Override public SpotType getRequiredSpotType() { return SpotType.MOTORCYCLE; }
}

public class Car extends Vehicle {
    public Car(String licensePlate, String color) {
        super(licensePlate, VehicleType.CAR, color);
    }
    @Override public SpotType getRequiredSpotType() { return SpotType.COMPACT; }
}

public class Truck extends Vehicle {
    public Truck(String licensePlate, String color) {
        super(licensePlate, VehicleType.TRUCK, color);
    }
    @Override public SpotType getRequiredSpotType() { return SpotType.LARGE; }
}

public class ElectricCar extends Vehicle {
    private final int batteryPercent;

    public ElectricCar(String licensePlate, String color, int batteryPercent) {
        super(licensePlate, VehicleType.ELECTRIC, color);
        this.batteryPercent = batteryPercent;
    }
    @Override public SpotType getRequiredSpotType() { return SpotType.ELECTRIC; }
    public int getBatteryPercent() { return batteryPercent; }
}
```

```java
// ─────────────────────────────────────────────
// VEHICLE FACTORY
// ─────────────────────────────────────────────

package com.interview.lld.parking;

public class VehicleFactory {
    public static Vehicle create(VehicleType type, String plate, String color) {
        return switch (type) {
            case MOTORCYCLE -> new MotorcycleVehicle(plate, color);
            case CAR        -> new Car(plate, color);
            case TRUCK      -> new Truck(plate, color);
            case ELECTRIC   -> new ElectricCar(plate, color, 80);
        };
    }
}
```

```java
// ─────────────────────────────────────────────
// PARKING SPOT
// ─────────────────────────────────────────────

package com.interview.lld.parking;

public class ParkingSpot {
    private final String spotId;
    private final SpotType spotType;
    private SpotStatus status;
    private Vehicle parkedVehicle;

    public ParkingSpot(String spotId, SpotType spotType) {
        this.spotId   = spotId;
        this.spotType = spotType;
        this.status   = SpotStatus.AVAILABLE;
    }

    public synchronized boolean isAvailable() {
        return status == SpotStatus.AVAILABLE;
    }

    public synchronized void park(Vehicle vehicle) {
        if (!isAvailable()) throw new IllegalStateException("Spot " + spotId + " is not available");
        this.parkedVehicle = vehicle;
        this.status        = SpotStatus.OCCUPIED;
    }

    public synchronized Vehicle unpark() {
        if (status != SpotStatus.OCCUPIED) throw new IllegalStateException("Spot " + spotId + " is not occupied");
        Vehicle v          = this.parkedVehicle;
        this.parkedVehicle = null;
        this.status        = SpotStatus.AVAILABLE;
        return v;
    }

    public String getSpotId()       { return spotId; }
    public SpotType getSpotType()   { return spotType; }
    public SpotStatus getStatus()   { return status; }
    public Vehicle getParkedVehicle() { return parkedVehicle; }

    public void setOutOfService()   { this.status = SpotStatus.OUT_OF_SERVICE; }
}
```

```java
// ─────────────────────────────────────────────
// OBSERVER PATTERN — Display Board
// ─────────────────────────────────────────────

package com.interview.lld.parking;

public interface SpotAvailabilityObserver {
    void onAvailabilityChanged(int floorNumber, SpotType type, int available);
}

public class DisplayBoard implements SpotAvailabilityObserver {
    private final String boardId;

    public DisplayBoard(String boardId) { this.boardId = boardId; }

    @Override
    public void onAvailabilityChanged(int floorNumber, SpotType type, int available) {
        System.out.printf("[DisplayBoard %s] Floor %d | %s spots available: %d%n",
                boardId, floorNumber, type, available);
    }
}
```

```java
// ─────────────────────────────────────────────
// TICKET
// ─────────────────────────────────────────────

package com.interview.lld.parking;

import java.time.LocalDateTime;
import java.util.UUID;

public class Ticket {
    private final String ticketId;
    private final Vehicle vehicle;
    private final ParkingSpot spot;
    private final LocalDateTime entryTime;
    private LocalDateTime exitTime;
    private TicketStatus status;

    public Ticket(Vehicle vehicle, ParkingSpot spot) {
        this.ticketId  = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        this.vehicle   = vehicle;
        this.spot      = spot;
        this.entryTime = LocalDateTime.now();
        this.status    = TicketStatus.ACTIVE;
    }

    public void markPaid() {
        this.exitTime = LocalDateTime.now();
        this.status   = TicketStatus.PAID;
    }

    public String getTicketId()           { return ticketId; }
    public Vehicle getVehicle()           { return vehicle; }
    public ParkingSpot getSpot()          { return spot; }
    public LocalDateTime getEntryTime()   { return entryTime; }
    public LocalDateTime getExitTime()    { return exitTime; }
    public TicketStatus getStatus()       { return status; }
}
```

```java
// ─────────────────────────────────────────────
// PAYMENT
// ─────────────────────────────────────────────

package com.interview.lld.parking;

import java.time.LocalDateTime;
import java.util.UUID;

public class Payment {
    private final String paymentId;
    private final Ticket ticket;
    private final double amount;
    private final PaymentMethod method;
    private PaymentStatus status;
    private final LocalDateTime timestamp;

    public Payment(Ticket ticket, double amount, PaymentMethod method) {
        this.paymentId = UUID.randomUUID().toString();
        this.ticket    = ticket;
        this.amount    = amount;
        this.method    = method;
        this.status    = PaymentStatus.PENDING;
        this.timestamp = LocalDateTime.now();
    }

    /** Simulate payment processing */
    public boolean process() {
        // In production: call payment gateway
        this.status = PaymentStatus.COMPLETED;
        return true;
    }

    public String getPaymentId()      { return paymentId; }
    public double getAmount()         { return amount; }
    public PaymentStatus getStatus()  { return status; }
    public PaymentMethod getMethod()  { return method; }
}
```

```java
// ─────────────────────────────────────────────
// STRATEGY PATTERN — Fee Calculation
// ─────────────────────────────────────────────

package com.interview.lld.parking;

import java.time.Duration;

public interface ParkingFeeStrategy {
    double calculateFee(Ticket ticket);
}

/** Hourly rate: first hour flat, then per-hour thereafter. */
public class HourlyFeeStrategy implements ParkingFeeStrategy {
    private final double firstHourRate;
    private final double subsequentHourRate;

    public HourlyFeeStrategy(double firstHourRate, double subsequentHourRate) {
        this.firstHourRate      = firstHourRate;
        this.subsequentHourRate = subsequentHourRate;
    }

    @Override
    public double calculateFee(Ticket ticket) {
        Duration duration = Duration.between(ticket.getEntryTime(), ticket.getExitTime());
        long minutes      = duration.toMinutes();
        if (minutes <= 60) return firstHourRate;
        long extraHours = (long) Math.ceil((minutes - 60) / 60.0);
        return firstHourRate + (extraHours * subsequentHourRate);
    }
}

/** Electric vehicle discount: 50% off hourly rate. */
public class ElectricVehicleFeeStrategy implements ParkingFeeStrategy {
    private final ParkingFeeStrategy base;

    public ElectricVehicleFeeStrategy(ParkingFeeStrategy base) {
        this.base = base;
    }

    @Override
    public double calculateFee(Ticket ticket) {
        return base.calculateFee(ticket) * 0.5;
    }
}

/** Flat rate for motorcycles regardless of duration. */
public class MotorcycleFlatRateStrategy implements ParkingFeeStrategy {
    private final double flatRate;

    public MotorcycleFlatRateStrategy(double flatRate) {
        this.flatRate = flatRate;
    }

    @Override
    public double calculateFee(Ticket ticket) {
        return flatRate;
    }
}

/** Fee strategy resolver — picks the right strategy by vehicle type. */
public class FeeStrategyResolver {
    public static ParkingFeeStrategy resolve(VehicleType type) {
        ParkingFeeStrategy hourly = new HourlyFeeStrategy(20.0, 15.0);
        return switch (type) {
            case MOTORCYCLE -> new MotorcycleFlatRateStrategy(10.0);
            case ELECTRIC   -> new ElectricVehicleFeeStrategy(hourly);
            default         -> hourly;
        };
    }
}
```

```java
// ─────────────────────────────────────────────
// PARKING FLOOR
// ─────────────────────────────────────────────

package com.interview.lld.parking;

import java.util.*;

public class ParkingFloor {
    private final int floorNumber;
    private final Map<SpotType, List<ParkingSpot>> spotsByType = new EnumMap<>(SpotType.class);
    private final Map<SpotType, Integer> availableCount        = new EnumMap<>(SpotType.class);
    private final List<SpotAvailabilityObserver> observers     = new ArrayList<>();

    public ParkingFloor(int floorNumber) {
        this.floorNumber = floorNumber;
        for (SpotType t : SpotType.values()) {
            spotsByType.put(t, new ArrayList<>());
            availableCount.put(t, 0);
        }
    }

    public void addObserver(SpotAvailabilityObserver observer) {
        observers.add(observer);
    }

    public void addSpot(ParkingSpot spot) {
        spotsByType.get(spot.getSpotType()).add(spot);
        if (spot.isAvailable()) {
            availableCount.merge(spot.getSpotType(), 1, Integer::sum);
            notifyObservers(spot.getSpotType());
        }
    }

    public synchronized Optional<ParkingSpot> getFirstAvailable(SpotType type) {
        return spotsByType.getOrDefault(type, List.of())
                .stream()
                .filter(ParkingSpot::isAvailable)
                .findFirst();
    }

    public synchronized void onSpotOccupied(SpotType type) {
        availableCount.merge(type, -1, Integer::sum);
        notifyObservers(type);
    }

    public synchronized void onSpotFreed(SpotType type) {
        availableCount.merge(type, 1, Integer::sum);
        notifyObservers(type);
    }

    private void notifyObservers(SpotType type) {
        int count = availableCount.get(type);
        observers.forEach(o -> o.onAvailabilityChanged(floorNumber, type, count));
    }

    public int getFloorNumber()                      { return floorNumber; }
    public int getAvailableCount(SpotType type)      { return availableCount.getOrDefault(type, 0); }
    public Map<SpotType, List<ParkingSpot>> getAllSpots() { return Collections.unmodifiableMap(spotsByType); }
}
```

```java
// ─────────────────────────────────────────────
// PARKING LOT — SINGLETON
// ─────────────────────────────────────────────

package com.interview.lld.parking;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public class ParkingLot {

    // ── Singleton ─────────────────────────────────────────────────────────────
    private static volatile ParkingLot instance;

    public static ParkingLot getInstance() {
        if (instance == null) {
            synchronized (ParkingLot.class) {
                if (instance == null) instance = new ParkingLot("LOT-001", "Main Street Parking");
            }
        }
        return instance;
    }

    // ── State ──────────────────────────────────────────────────────────────────
    private final String id;
    private final String name;
    private final List<ParkingFloor> floors              = new ArrayList<>();
    private final Map<String, Ticket> activeTickets      = new ConcurrentHashMap<>();

    private ParkingLot(String id, String name) {
        this.id   = id;
        this.name = name;
    }

    public void addFloor(ParkingFloor floor) { floors.add(floor); }

    // ── Entry ──────────────────────────────────────────────────────────────────
    public Ticket issueTicket(Vehicle vehicle) {
        SpotType required = vehicle.getRequiredSpotType();

        for (ParkingFloor floor : floors) {
            Optional<ParkingSpot> spot = floor.getFirstAvailable(required);
            if (spot.isPresent()) {
                ParkingSpot ps = spot.get();
                ps.park(vehicle);
                floor.onSpotOccupied(required);

                Ticket ticket = new Ticket(vehicle, ps);
                activeTickets.put(ticket.getTicketId(), ticket);
                System.out.printf("[ENTRY] %s → Spot %s (Floor %d) | Ticket: %s%n",
                        vehicle, ps.getSpotId(), floor.getFloorNumber(), ticket.getTicketId());
                return ticket;
            }
        }
        throw new IllegalStateException("No available spot for " + required);
    }

    // ── Exit ───────────────────────────────────────────────────────────────────
    public Payment processExit(String ticketId, PaymentMethod method) {
        Ticket ticket = activeTickets.get(ticketId);
        if (ticket == null) throw new IllegalArgumentException("Invalid ticket: " + ticketId);

        ticket.markPaid();

        ParkingFeeStrategy strategy = FeeStrategyResolver.resolve(ticket.getVehicle().getVehicleType());
        double fee    = strategy.calculateFee(ticket);
        Payment payment = new Payment(ticket, fee, method);
        payment.process();

        // Free the spot
        ParkingSpot spot = ticket.getSpot();
        spot.unpark();
        findFloorForSpot(spot).ifPresent(f -> f.onSpotFreed(spot.getSpotType()));

        activeTickets.remove(ticketId);
        System.out.printf("[EXIT] Ticket %s | Fee: ₹%.2f | Method: %s%n",
                ticketId, fee, method);
        return payment;
    }

    private Optional<ParkingFloor> findFloorForSpot(ParkingSpot target) {
        return floors.stream()
                .filter(f -> f.getAllSpots().values().stream()
                        .flatMap(List::stream)
                        .anyMatch(s -> s.getSpotId().equals(target.getSpotId())))
                .findFirst();
    }

    public List<ParkingFloor> getFloors()  { return Collections.unmodifiableList(floors); }
    public String getId()                  { return id; }
    public String getName()                { return name; }
}
```

```java
// ─────────────────────────────────────────────
// ACTORS: Admin, ParkingAttendant
// ─────────────────────────────────────────────

package com.interview.lld.parking;

public class Admin {
    private final String adminId;
    private final String name;

    public Admin(String adminId, String name) {
        this.adminId = adminId;
        this.name    = name;
    }

    public ParkingFloor addFloor(int floorNumber) {
        ParkingFloor floor = new ParkingFloor(floorNumber);
        ParkingLot.getInstance().addFloor(floor);
        System.out.println("[Admin] Floor " + floorNumber + " added.");
        return floor;
    }

    public ParkingSpot addSpot(ParkingFloor floor, String spotId, SpotType type) {
        ParkingSpot spot = new ParkingSpot(spotId, type);
        floor.addSpot(spot);
        System.out.println("[Admin] Spot " + spotId + " (" + type + ") added to floor " + floor.getFloorNumber());
        return spot;
    }

    public void removeSpot(ParkingSpot spot) {
        spot.setOutOfService();
        System.out.println("[Admin] Spot " + spot.getSpotId() + " marked out-of-service.");
    }
}

public class ParkingAttendant {
    private final String attendantId;
    private final String name;

    public ParkingAttendant(String attendantId, String name) {
        this.attendantId = attendantId;
        this.name        = name;
    }

    public Ticket parkVehicle(Vehicle vehicle) {
        return ParkingLot.getInstance().issueTicket(vehicle);
    }

    public Payment unparkVehicle(String ticketId, PaymentMethod method) {
        return ParkingLot.getInstance().processExit(ticketId, method);
    }
}
```

```java
// ─────────────────────────────────────────────
// DEMO / MAIN
// ─────────────────────────────────────────────

package com.interview.lld.parking;

public class ParkingLotDemo {

    public static void main(String[] args) throws InterruptedException {
        // Setup
        Admin admin      = new Admin("A001", "Raj");
        ParkingFloor f1  = admin.addFloor(1);
        ParkingFloor f2  = admin.addFloor(2);

        // Wire display board (observer)
        DisplayBoard board = new DisplayBoard("ENTRANCE");
        f1.addObserver(board);
        f2.addObserver(board);

        // Add spots
        admin.addSpot(f1, "F1-M1",  SpotType.MOTORCYCLE);
        admin.addSpot(f1, "F1-M2",  SpotType.MOTORCYCLE);
        admin.addSpot(f1, "F1-C1",  SpotType.COMPACT);
        admin.addSpot(f1, "F1-C2",  SpotType.COMPACT);
        admin.addSpot(f2, "F2-L1",  SpotType.LARGE);
        admin.addSpot(f2, "F2-EV1", SpotType.ELECTRIC);

        // Vehicles
        Vehicle bike  = VehicleFactory.create(VehicleType.MOTORCYCLE, "MH01AB1234", "Red");
        Vehicle car   = VehicleFactory.create(VehicleType.CAR,        "MH02CD5678", "Blue");
        Vehicle ev    = VehicleFactory.create(VehicleType.ELECTRIC,   "MH03EF9012", "White");
        Vehicle truck = VehicleFactory.create(VehicleType.TRUCK,      "MH04GH3456", "Black");

        ParkingAttendant attendant = new ParkingAttendant("AT001", "Suresh");

        // Park
        Ticket t1 = attendant.parkVehicle(bike);
        Ticket t2 = attendant.parkVehicle(car);
        Ticket t3 = attendant.parkVehicle(ev);
        Ticket t4 = attendant.parkVehicle(truck);

        Thread.sleep(2000); // simulate 2 seconds parked

        // Exit
        attendant.unparkVehicle(t1.getTicketId(), PaymentMethod.CASH);
        attendant.unparkVehicle(t2.getTicketId(), PaymentMethod.UPI);
        attendant.unparkVehicle(t3.getTicketId(), PaymentMethod.CREDIT_CARD);
        attendant.unparkVehicle(t4.getTicketId(), PaymentMethod.CASH);
    }
}
```

---

## 5. Key Interview Questions — Parking Lot

### Q1. Why is ParkingLot a Singleton? What are the thread-safety concerns?

**Answer:** There is exactly one parking lot per deployment. Making it a Singleton ensures that all actors (attendants, admins, displays) share the same state. Thread-safety is achieved with double-checked locking using `volatile` on the instance field. The `activeTickets` map is a `ConcurrentHashMap`. Spot-level operations use `synchronized` methods on `ParkingSpot` so two threads cannot park in the same spot simultaneously.

### Q2. How would you support multiple payment methods without an if-else chain?

**Answer:** The `PaymentMethod` enum identifies the method, but actual processing is delegated to a **Strategy** or a payment gateway abstraction. In production, define a `PaymentProcessor` interface with implementations `CashProcessor`, `CreditCardProcessor`, `UPIProcessor`, each injected by a factory keyed on `PaymentMethod`. The exit flow calls `processor.charge(amount)` without knowing the method.

### Q3. How do you prevent double-parking (two threads parking in the same spot)?

**Answer:** The `ParkingSpot.park()` method is `synchronized` on the spot instance. The floor's `getFirstAvailable()` is also `synchronized`. However, there is still a TOCTOU (time-of-check-time-of-use) window between finding a free spot and parking in it. The proper fix is to acquire the spot's lock before adding it to the ticket, or to use `compareAndSet` on an `AtomicReference<Vehicle>` inside `ParkingSpot`.

### Q4. How would you scale this to a multi-building, distributed parking system?

**Answer:**
- Each building runs its own `ParkingLot` service.
- A central **Aggregator Service** queries all buildings for availability.
- Spot state changes are published to a message bus (Kafka topic `parking.spot.events`).
- Display boards subscribe to the topic.
- Distributed locking (Redis `SETNX`) prevents two users in different regions from claiming the same spot.

### Q5. Where would you add persistence?

**Answer:** `Ticket` and `Payment` are the primary write entities. Use an RDBMS (PostgreSQL) with:
- `tickets(ticket_id, vehicle_plate, spot_id, entry_time, exit_time, status)`
- `payments(payment_id, ticket_id, amount, method, status, timestamp)`
- `spots(spot_id, floor, type, status)` updated on park/unpark events.

Active tickets also live in Redis with a TTL for fast lookup.

### Q6. How would you add a monthly pass feature?

**Answer:** Introduce a `Pass` entity with `userId`, `vehiclePlate`, `validFrom`, `validUntil`, `spotType`. On entry, before assigning a dynamic spot, check if the vehicle has a valid pass. If yes, assign the pre-reserved spot directly and skip fee calculation (or apply flat monthly billing done separately via a scheduler).

---

# LLD 2: URL Shortener (like bit.ly)

## 1. Requirements Clarification

### Functional Requirements

| # | Requirement |
|---|---|
| FR-1 | Given a long URL, generate a unique short URL (e.g., `https://shr.ly/aB3dE7`). |
| FR-2 | Redirect from short URL to original long URL (HTTP 301/302). |
| FR-3 | Support **custom alias** (user provides their own short code). |
| FR-4 | Support **expiry** — short URLs can expire after N days or a fixed date. |
| FR-5 | Track **click analytics**: count, timestamp, referrer, geo. |
| FR-6 | Allow authenticated users to manage their URLs (list, delete, update). |
| FR-7 | Return an error if a custom alias is already taken. |

### Non-Functional Requirements

| # | Requirement |
|---|---|
| NFR-1 | **Read-heavy**: redirects vastly outnumber creation (100:1 ratio). |
| NFR-2 | Redirect latency < 10 ms (use cache). |
| NFR-3 | Short codes must be collision-free and not guessable/enumerable. |
| NFR-4 | Horizontal scale for both creation and redirect services. |
| NFR-5 | Analytics write should be async (fire-and-forget, non-blocking). |

### Clarifying Questions

1. What is the expected QPS for redirect vs. creation?
2. Should deleted/expired URLs return 404 or redirect to an error page?
3. Are analytics real-time dashboards or eventual-consistency reports?
4. Do we need click-level deduplication (unique visitors)?
5. Max length of long URL? (handle URLs > 2000 chars in database, not URL params)

---

## 2. Entities

```
ShortUrl         — Core entity: shortCode, longUrl, userId, createdAt, expiresAt, customAlias, active
User             — Authenticated creator of short URLs
ClickAnalytics   — One record per click: shortCode, clickedAt, ipAddress, referrer, userAgent
```

### Attributes

**`ShortUrl`**
- `String shortCode` (PK, 6–8 chars, Base62)
- `String longUrl`
- `String userId` (nullable for anonymous)
- `LocalDateTime createdAt`
- `LocalDateTime expiresAt` (nullable = never expires)
- `boolean active`
- `long clickCount` (denormalized for fast display)

**`ClickAnalytics`**
- `Long id` (auto-increment)
- `String shortCode`
- `LocalDateTime clickedAt`
- `String ipAddress`
- `String referrer`
- `String userAgent`

---

## 3. Core Algorithm — Base62 Encoding

### Why Base62?

Base62 uses characters `[0-9a-zA-Z]` (62 chars). A 6-character code gives 62^6 ≈ **56.8 billion** unique URLs. A 7-character code gives 62^7 ≈ 3.5 trillion.

### Approaches Compared

| Approach | Pros | Cons |
|---|---|---|
| **Counter-based** (auto-increment ID → Base62) | No collision, predictable length | Enumerable — sequential IDs expose traffic volume |
| **Random 6-char** | Not enumerable | Collision probability increases as dataset grows; need DB uniqueness check |
| **MD5/SHA hash** | Deterministic — same URL = same code | Collision on truncation; same long URL always maps to same short code (no multi-tenant isolation) |
| **Counter with padding** (used below) | Combines predictability with non-enumerable output | Slightly more complex |

**Best for interviews:** Distributed counter (e.g., Snowflake ID or Redis `INCR`) → convert to Base62. Prevents collisions without retry loops.

```
ID: 12345678
Base62 encoding: 12345678 in base 62 = "FXho"
Pad to 6 chars: "00FXho"
```

---

## 4. Design Patterns

| Pattern | Where Applied | Why |
|---|---|---|
| **Strategy** | `IdGenerationStrategy` | Swap between counter-based, random, and hash-based ID generation without touching service. |
| **Facade** | `UrlShortenerService` | Single entry point hides Redis caching, DB, analytics publisher, expiry checks. |
| **Builder** | `ShortUrl` construction | Many optional fields (expiry, alias, userId); avoids telescoping constructors. |
| **Decorator** | Analytics wrapping redirect | `AnalyticsRecordingRedirectService` wraps `BasicRedirectService` transparently. |

---

## 5. Complete Java 17 + Spring Boot 3.x Implementation

```java
// ─────────────────────────────────────────────
// DOMAIN ENTITY
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.domain;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "short_urls")
public class ShortUrl {

    @Id
    @Column(name = "short_code", length = 10)
    private String shortCode;

    @Column(name = "long_url", nullable = false, length = 2048)
    private String longUrl;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    @Column(name = "active", nullable = false)
    private boolean active = true;

    @Column(name = "click_count", nullable = false)
    private long clickCount = 0;

    protected ShortUrl() {} // JPA

    private ShortUrl(Builder b) {
        this.shortCode  = b.shortCode;
        this.longUrl    = b.longUrl;
        this.userId     = b.userId;
        this.createdAt  = b.createdAt;
        this.expiresAt  = b.expiresAt;
        this.active     = true;
        this.clickCount = 0;
    }

    public boolean isExpired() {
        return expiresAt != null && LocalDateTime.now().isAfter(expiresAt);
    }

    public void incrementClickCount()  { this.clickCount++; }
    public void deactivate()           { this.active = false; }

    // Getters
    public String getShortCode()        { return shortCode; }
    public String getLongUrl()          { return longUrl; }
    public String getUserId()           { return userId; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public boolean isActive()           { return active; }
    public long getClickCount()         { return clickCount; }

    // ── Builder ──────────────────────────────────────────────────────────────
    public static Builder builder(String shortCode, String longUrl) {
        return new Builder(shortCode, longUrl);
    }

    public static final class Builder {
        private final String shortCode;
        private final String longUrl;
        private String userId;
        private LocalDateTime createdAt = LocalDateTime.now();
        private LocalDateTime expiresAt;

        private Builder(String shortCode, String longUrl) {
            this.shortCode = shortCode;
            this.longUrl   = longUrl;
        }

        public Builder userId(String userId)             { this.userId    = userId;    return this; }
        public Builder expiresAt(LocalDateTime exp)      { this.expiresAt = exp;       return this; }
        public Builder createdAt(LocalDateTime created)  { this.createdAt = created;   return this; }
        public ShortUrl build()                          { return new ShortUrl(this); }
    }
}
```

```java
// ─────────────────────────────────────────────
// CLICK ANALYTICS ENTITY
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.domain;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "click_analytics", indexes = {
    @Index(name = "idx_ca_shortcode", columnList = "short_code"),
    @Index(name = "idx_ca_clicked",   columnList = "clicked_at")
})
public class ClickAnalytics {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "short_code", nullable = false, length = 10)
    private String shortCode;

    @Column(name = "clicked_at", nullable = false)
    private LocalDateTime clickedAt;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "referrer",   length = 512)
    private String referrer;

    @Column(name = "user_agent", length = 512)
    private String userAgent;

    protected ClickAnalytics() {}

    public ClickAnalytics(String shortCode, String ipAddress, String referrer, String userAgent) {
        this.shortCode  = shortCode;
        this.clickedAt  = LocalDateTime.now();
        this.ipAddress  = ipAddress;
        this.referrer   = referrer;
        this.userAgent  = userAgent;
    }

    public String getShortCode()          { return shortCode; }
    public LocalDateTime getClickedAt()   { return clickedAt; }
    public String getIpAddress()          { return ipAddress; }
}
```

```java
// ─────────────────────────────────────────────
// BASE62 ENCODER
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.util;

import org.springframework.stereotype.Component;

@Component
public class Base62Encoder {

    private static final String ALPHABET =
            "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final int BASE     = 62;
    private static final int MIN_LEN  = 6;

    /** Encode a non-negative long to a Base62 string, left-padded to MIN_LEN. */
    public String encode(long number) {
        if (number < 0) throw new IllegalArgumentException("Number must be non-negative");
        if (number == 0) return "0".repeat(MIN_LEN);

        StringBuilder sb = new StringBuilder();
        while (number > 0) {
            sb.append(ALPHABET.charAt((int)(number % BASE)));
            number /= BASE;
        }
        sb.reverse();

        // Left-pad with '0' to ensure minimum length
        while (sb.length() < MIN_LEN) sb.insert(0, '0');
        return sb.toString();
    }

    /** Decode a Base62 string back to a long. */
    public long decode(String code) {
        long result = 0;
        for (char c : code.toCharArray()) {
            result = result * BASE + ALPHABET.indexOf(c);
        }
        return result;
    }
}
```

```java
// ─────────────────────────────────────────────
// STRATEGY PATTERN — ID Generation
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.strategy;

public interface IdGenerationStrategy {
    String generateCode(String longUrl);
}
```

```java
package com.interview.lld.urlshortener.strategy;

import com.interview.lld.urlshortener.util.Base62Encoder;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

@Component("counterStrategy")
public class CounterBasedStrategy implements IdGenerationStrategy {

    private static final String COUNTER_KEY = "url:shortener:global:counter";

    private final StringRedisTemplate redis;
    private final Base62Encoder encoder;

    public CounterBasedStrategy(StringRedisTemplate redis, Base62Encoder encoder) {
        this.redis   = redis;
        this.encoder = encoder;
    }

    @Override
    public String generateCode(String longUrl) {
        Long id = redis.opsForValue().increment(COUNTER_KEY);
        if (id == null) throw new IllegalStateException("Redis counter unavailable");
        return encoder.encode(id);
    }
}
```

```java
package com.interview.lld.urlshortener.strategy;

import org.springframework.stereotype.Component;
import java.security.SecureRandom;

@Component("randomStrategy")
public class RandomCodeStrategy implements IdGenerationStrategy {

    private static final String CHARS  = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final int CODE_LEN  = 6;
    private final SecureRandom rng     = new SecureRandom();

    @Override
    public String generateCode(String longUrl) {
        StringBuilder sb = new StringBuilder(CODE_LEN);
        for (int i = 0; i < CODE_LEN; i++) sb.append(CHARS.charAt(rng.nextInt(CHARS.length())));
        return sb.toString();
    }
}
```

```java
// ─────────────────────────────────────────────
// REPOSITORIES
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.repository;

import com.interview.lld.urlshortener.domain.ShortUrl;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import java.util.Optional;

public interface ShortUrlRepository extends JpaRepository<ShortUrl, String> {
    Optional<ShortUrl> findByShortCodeAndActiveTrue(String shortCode);

    @Modifying
    @Query("UPDATE ShortUrl s SET s.clickCount = s.clickCount + 1 WHERE s.shortCode = :code")
    void incrementClickCount(String code);
}
```

```java
package com.interview.lld.urlshortener.repository;

import com.interview.lld.urlshortener.domain.ClickAnalytics;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.time.LocalDateTime;
import java.util.List;

public interface ClickAnalyticsRepository extends JpaRepository<ClickAnalytics, Long> {

    @Query("SELECT c FROM ClickAnalytics c WHERE c.shortCode = :code AND c.clickedAt >= :since")
    List<ClickAnalytics> findByShortCodeSince(String code, LocalDateTime since);

    long countByShortCode(String shortCode);
}
```

```java
// ─────────────────────────────────────────────
// REQUEST / RESPONSE DTOs
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.dto;

import java.time.LocalDateTime;

public record ShortenRequest(
    String longUrl,
    String customAlias,     // nullable
    LocalDateTime expiresAt // nullable
) {}

public record ShortenResponse(
    String shortCode,
    String shortUrl,
    String longUrl,
    LocalDateTime expiresAt
) {}

public record AnalyticsResponse(
    String shortCode,
    long totalClicks,
    List<ClickDataPoint> recent
) {
    public record ClickDataPoint(LocalDateTime clickedAt, String ipAddress) {}
}
```

```java
// ─────────────────────────────────────────────
// SERVICE — FACADE PATTERN
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.service;

import com.interview.lld.urlshortener.domain.*;
import com.interview.lld.urlshortener.dto.*;
import com.interview.lld.urlshortener.repository.*;
import com.interview.lld.urlshortener.strategy.IdGenerationStrategy;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class UrlShortenerService {

    private static final String BASE_URL      = "https://shr.ly/";
    private static final int    MAX_RETRIES   = 5;

    private final ShortUrlRepository urlRepo;
    private final ClickAnalyticsRepository analyticsRepo;
    private final IdGenerationStrategy idStrategy;

    public UrlShortenerService(
            ShortUrlRepository urlRepo,
            ClickAnalyticsRepository analyticsRepo,
            @Qualifier("counterStrategy") IdGenerationStrategy idStrategy) {
        this.urlRepo       = urlRepo;
        this.analyticsRepo = analyticsRepo;
        this.idStrategy    = idStrategy;
    }

    // ── CREATE ─────────────────────────────────────────────────────────────
    @Transactional
    public ShortenResponse shorten(ShortenRequest req, String userId) {
        String code = resolveCode(req);

        ShortUrl shortUrl = ShortUrl.builder(code, req.longUrl())
                .userId(userId)
                .expiresAt(req.expiresAt())
                .build();

        urlRepo.save(shortUrl);

        return new ShortenResponse(code, BASE_URL + code, req.longUrl(), req.expiresAt());
    }

    private String resolveCode(ShortenRequest req) {
        if (req.customAlias() != null && !req.customAlias().isBlank()) {
            if (urlRepo.existsById(req.customAlias())) {
                throw new IllegalArgumentException("Alias already taken: " + req.customAlias());
            }
            return req.customAlias();
        }
        // Counter-based — guaranteed unique; random needs retry loop
        return idStrategy.generateCode(req.longUrl());
    }

    // ── REDIRECT ───────────────────────────────────────────────────────────
    @Cacheable(value = "shortUrls", key = "#code", unless = "#result == null")
    @Transactional(readOnly = true)
    public Optional<String> getLongUrl(String code) {
        return urlRepo.findByShortCodeAndActiveTrue(code)
                .filter(u -> !u.isExpired())
                .map(ShortUrl::getLongUrl);
    }

    /** Fire-and-forget analytics recording — does not block the redirect. */
    @Async
    @Transactional
    public void recordClick(String code, String ip, String referrer, String ua) {
        analyticsRepo.save(new ClickAnalytics(code, ip, referrer, ua));
        urlRepo.incrementClickCount(code);
    }

    // ── DELETE ─────────────────────────────────────────────────────────────
    @CacheEvict(value = "shortUrls", key = "#code")
    @Transactional
    public void deactivate(String code, String requestingUserId) {
        ShortUrl su = urlRepo.findByShortCodeAndActiveTrue(code)
                .orElseThrow(() -> new IllegalArgumentException("Not found: " + code));
        if (!su.getUserId().equals(requestingUserId)) {
            throw new SecurityException("Not authorized to delete this URL");
        }
        su.deactivate();
        urlRepo.save(su);
    }

    // ── ANALYTICS ──────────────────────────────────────────────────────────
    public AnalyticsResponse getAnalytics(String code) {
        long total = analyticsRepo.countByShortCode(code);
        var recent = analyticsRepo.findByShortCodeSince(code, LocalDateTime.now().minusDays(7))
                .stream()
                .map(c -> new AnalyticsResponse.ClickDataPoint(c.getClickedAt(), c.getIpAddress()))
                .toList();
        return new AnalyticsResponse(code, total, recent);
    }
}
```

```java
// ─────────────────────────────────────────────
// REST CONTROLLER
// ─────────────────────────────────────────────

package com.interview.lld.urlshortener.controller;

import com.interview.lld.urlshortener.dto.*;
import com.interview.lld.urlshortener.service.UrlShortenerService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.net.URI;

@RestController
public class UrlShortenerController {

    private final UrlShortenerService service;

    public UrlShortenerController(UrlShortenerService service) {
        this.service = service;
    }

    /** POST /api/shorten — create a short URL */
    @PostMapping("/api/shorten")
    public ResponseEntity<ShortenResponse> shorten(
            @RequestBody ShortenRequest req,
            @AuthenticationPrincipal String userId) {

        ShortenResponse response = service.shorten(req, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /** GET /{code} — redirect to long URL */
    @GetMapping("/{code}")
    public ResponseEntity<Void> redirect(
            @PathVariable String code,
            HttpServletRequest httpReq) {

        return service.getLongUrl(code)
                .map(longUrl -> {
                    // Async analytics — non-blocking
                    service.recordClick(
                            code,
                            httpReq.getRemoteAddr(),
                            httpReq.getHeader("Referer"),
                            httpReq.getHeader("User-Agent")
                    );
                    // 302 = temporary redirect (allows analytics to keep firing)
                    // 301 = permanent (browser caches; analytics miss future clicks)
                    return ResponseEntity.status(HttpStatus.FOUND)
                            .location(URI.create(longUrl))
                            .<Void>build();
                })
                .orElse(ResponseEntity.notFound().build());
    }

    /** GET /api/analytics/{code} */
    @GetMapping("/api/analytics/{code}")
    public ResponseEntity<AnalyticsResponse> analytics(@PathVariable String code) {
        return ResponseEntity.ok(service.getAnalytics(code));
    }

    /** DELETE /api/shorten/{code} */
    @DeleteMapping("/api/shorten/{code}")
    public ResponseEntity<Void> delete(
            @PathVariable String code,
            @AuthenticationPrincipal String userId) {
        service.deactivate(code, userId);
        return ResponseEntity.noContent().build();
    }
}
```

```yaml
# application.yml (Spring Boot 3.x)
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/urlshortener
    username: ${DB_USER}
    password: ${DB_PASS}
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
  data:
    redis:
      host: localhost
      port: 6379
  cache:
    type: redis
    redis:
      time-to-live: 3600000   # 1 hour TTL for cached short URLs

server:
  port: 8080
```

---

## 6. Key Interview Questions — URL Shortener

### Q1. Why use 302 (temporary) redirect instead of 301 (permanent)?

**Answer:** A 301 redirect is cached by the browser indefinitely, meaning future clicks go directly to the long URL without hitting your server. This kills analytics — you never see those clicks. A 302 forces the browser to re-request your shortener on every click, allowing you to count it. The trade-off: 302 adds ~10 ms latency per click. Mitigate this with CDN-level caching of the mapping (not the redirect itself) to cut latency without losing analytics.

### Q2. How do you handle the same long URL being shortened multiple times?

**Answer:** It depends on the product requirement:
- **Deduplicate** (hash the long URL as lookup key): same long URL always returns same short code. Simpler, but breaks multi-tenant isolation (two users' URLs become shared).
- **Allow duplicates** (counter-based): each request gets a new code. Cleaner per-user ownership and analytics isolation. Most production systems (bit.ly) allow duplicates.

The counter-based approach in this implementation allows duplicates by design.

### Q3. How would you scale the redirect service to 1 million RPS?

**Answer:**
1. **Redis cache** for the shortCode → longUrl mapping (TTL = 1 hour). Cache hit rate should be > 99% for popular URLs.
2. **CDN** (Cloudflare / CloudFront) in front of the redirect endpoint. Cache 302 responses at the edge for URLs where analytics is not needed (or use a server-sent pixel for analytics instead).
3. **Read replicas** for the PostgreSQL instance.
4. **Stateless redirect service** — horizontally scale behind a load balancer.

### Q4. How do you prevent short code collisions with the random strategy?

**Answer:** On collision (INSERT fails with unique constraint violation), retry with a new random code up to `MAX_RETRIES` times. If all retries fail, increase code length from 6 to 7 chars. To avoid this entirely, use the counter-based strategy: Redis `INCR` is atomic, so every call gets a globally unique integer which encodes to a unique Base62 string.

### Q5. What is the capacity estimate for a 6-character Base62 code?

**Answer:** Base62 uses characters `[0-9A-Za-z]` (62 symbols), so a 6-character code gives 62^6 = 56,800,235,584 ≈ **56.8 billion unique codes**. At a rate of 1 billion new URLs shortened per year, this namespace lasts roughly 57 years before exhaustion. Extending to 7 characters multiplies capacity to 62^7 ≈ 3.5 trillion codes, effectively eliminating the concern. The trade-off is URL length: 6 characters is the sweet spot between brevity and longevity, which is why services like bit.ly use exactly 6. If you adopt a counter-based ID generation strategy (Redis INCR), IDs are assigned sequentially so you never waste namespace from random collisions.

### Q6. How do you handle URL expiry efficiently without scanning the whole table?

**Answer:** A scheduled job (`@Scheduled(cron = "0 0 * * * *")`) runs hourly and marks expired URLs inactive: `UPDATE short_urls SET active = false WHERE expires_at < NOW() AND active = true`. Add an index on `(active, expires_at)`. Alternatively, store TTLs in Redis — when a key expires, a keyspace notification triggers the deactivation in the DB.

### Q7. What are the security concerns with a URL shortener?

**Answer:**
1. **Phishing** — short URLs hide the destination. Mitigate: scan long URLs against Google Safe Browsing API on creation.
2. **Enumeration** — sequential codes leak volume. Mitigate: use random codes or add a hidden salt to the counter before encoding.
3. **Open redirect abuse** — anyone can redirect to malicious sites. Mitigate: allowlist domains or require CAPTCHA for anonymous creation.
4. **DDoS via creation** — rate-limit the `/api/shorten` endpoint per IP/user.

---

# LLD 3: Rate Limiter

## 1. Requirements Clarification

### Functional Requirements

| # | Requirement |
|---|---|
| FR-1 | Limit the number of requests a user/IP can make in a time window. |
| FR-2 | Return HTTP 429 (Too Many Requests) with a `Retry-After` header when limit is exceeded. |
| FR-3 | Support per-user, per-IP, and per-API-key limiting. |
| FR-4 | Support multiple algorithms selectable per endpoint. |
| FR-5 | Allow configuring different limits for different endpoints or user tiers. |
| FR-6 | Expose a `RateLimitInfo` header to clients (`X-RateLimit-Remaining`, `X-RateLimit-Reset`). |

### Non-Functional Requirements

| # | Requirement |
|---|---|
| NFR-1 | Decision latency < 5 ms (Redis Lua script for atomicity without extra RTT). |
| NFR-2 | Distributed — multiple service instances share state via Redis. |
| NFR-3 | Failure mode: if Redis is down, choose between fail-open (allow all) or fail-closed (deny all). |
| NFR-4 | Accurate — avoid race conditions that let bursts through. |

---

## 2. Algorithms

### 2.1 Token Bucket

A bucket holds up to `capacity` tokens. Tokens are added at `refillRate` tokens/second. Each request consumes 1 token. If the bucket is empty, the request is rejected.

- **Pro:** Handles bursts (consume saved tokens), smooths traffic over time.
- **Con:** Requires precise timestamp bookkeeping for partial refills.

```
capacity = 10, refillRate = 2/sec
Time 0s: bucket = 10 tokens. 10 requests → bucket = 0.
Time 1s: refill 2 → bucket = 2. 2 requests allowed.
```

### 2.2 Leaky Bucket

Requests enter a queue (the "bucket"). They are processed at a fixed `outflowRate`. If the queue is full, excess requests are dropped.

- **Pro:** Smooth, predictable outflow — no bursts downstream.
- **Con:** Queuing adds latency; bursts are penalized immediately even if downstream can handle them.

### 2.3 Fixed Window Counter

Divide time into fixed windows (e.g., 1-minute buckets). Count requests per key per window. Reset counter at the start of each new window.

- **Pro:** Simple, memory-efficient.
- **Con:** Boundary attack: a user can make `2 * limit` requests by sending `limit` at the end of window N and `limit` at the start of window N+1.

```
limit = 10/min
Window [00:00–01:00]: 10 requests at 00:59 → ALLOWED
Window [01:00–02:00]: 10 requests at 01:00 → ALLOWED
Total 20 requests in 1 second — boundary exploit.
```

### 2.4 Sliding Window Log

Maintain a sorted log of all request timestamps for each key. On each request, remove timestamps older than the window, then count remaining. Allow if count < limit.

- **Pro:** Accurate, no boundary attack.
- **Con:** High memory usage — stores every timestamp. Expensive at high QPS.

### 2.5 Sliding Window Counter (Approximate)

Blend the previous window's count with the current window's count using a weighted formula:

```
weight = (windowSize - timeElapsedInCurrentWindow) / windowSize
estimate = prevWindowCount * weight + currentWindowCount
```

- **Pro:** Accurate approximation, O(1) memory, handles boundary issue.
- **Con:** Approximate (not exact) — allows a small overshoot (~1% at the boundary).

**Recommendation for interviews:** Token Bucket for most APIs (handles burst), Sliding Window Counter for strict per-user quota enforcement.

---

## 3. Entities and Class Design

```
RateLimiter             — Interface: tryConsume(key) → RateLimitResult
TokenBucketRateLimiter  — In-memory token bucket (single node)
RedisTokenBucketRateLimiter — Distributed token bucket via Lua script
SlidingWindowRateLimiter — Sliding window counter via Redis sorted set
RateLimitResult         — allowed, remaining, resetAt, retryAfter
RateLimitConfig         — capacity, refillRate, windowSizeSeconds
RateLimiterFactory      — Creates the right implementation by algorithm name
RateLimitFilter         — Spring OncePerRequestFilter; decorates all requests
```

---

## 4. Design Patterns

| Pattern | Where Applied | Why |
|---|---|---|
| **Strategy** | `RateLimiter` interface + multiple implementations | Swap algorithm (token bucket, sliding window) without changing the filter. |
| **Decorator** | `RateLimitFilter` wraps the servlet filter chain | Adds rate limiting to any service without modifying its code. |
| **Factory** | `RateLimiterFactory` | Create the right `RateLimiter` based on config (`algorithm: TOKEN_BUCKET`). |
| **Template Method** | `AbstractRateLimiter` handles key building; subclasses implement check logic | Avoids code duplication for key construction and header population. |

---

## 5. Complete Java 17 Implementation

```java
// ─────────────────────────────────────────────
// DOMAIN: Config and Result
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import java.time.Instant;

public record RateLimitConfig(
    int capacity,           // max tokens / max requests per window
    int refillRatePerSecond,// for token bucket: tokens added per second
    int windowSizeSeconds,  // for window-based algorithms
    String algorithm        // TOKEN_BUCKET | FIXED_WINDOW | SLIDING_WINDOW
) {}

public record RateLimitResult(
    boolean allowed,
    long remaining,         // tokens/requests remaining
    Instant resetAt,        // when the limit resets
    long retryAfterSeconds  // how long to wait if denied
) {
    public static RateLimitResult allow(long remaining, Instant resetAt) {
        return new RateLimitResult(true, remaining, resetAt, 0);
    }
    public static RateLimitResult deny(Instant resetAt, long retryAfter) {
        return new RateLimitResult(false, 0, resetAt, retryAfter);
    }
}
```

```java
// ─────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

public interface RateLimiter {
    /**
     * Attempt to consume one token for the given key.
     * @param key  rate limit key — e.g. "user:42" or "ip:1.2.3.4"
     * @return RateLimitResult
     */
    RateLimitResult tryConsume(String key);
}
```

```java
// ─────────────────────────────────────────────
// IN-MEMORY TOKEN BUCKET (single-node, thread-safe)
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

public class TokenBucketRateLimiter implements RateLimiter {

    private final RateLimitConfig config;
    private final ConcurrentHashMap<String, BucketState> buckets = new ConcurrentHashMap<>();

    public TokenBucketRateLimiter(RateLimitConfig config) {
        this.config = config;
    }

    @Override
    public RateLimitResult tryConsume(String key) {
        BucketState state = buckets.computeIfAbsent(key, k -> new BucketState(config.capacity()));
        return state.tryConsume(config);
    }

    // ── Inner state ────────────────────────────────────────────────────────
    private static class BucketState {
        private double tokens;
        private long lastRefillNanos;

        BucketState(int capacity) {
            this.tokens          = capacity;
            this.lastRefillNanos = System.nanoTime();
        }

        synchronized RateLimitResult tryConsume(RateLimitConfig cfg) {
            refill(cfg);

            Instant resetAt = Instant.now().plusSeconds(
                    (long) Math.ceil((cfg.capacity() - tokens) / (double) cfg.refillRatePerSecond()));

            if (tokens >= 1.0) {
                tokens--;
                return RateLimitResult.allow((long) tokens, resetAt);
            } else {
                long retryAfter = (long) Math.ceil((1.0 - tokens) / cfg.refillRatePerSecond());
                return RateLimitResult.deny(resetAt, retryAfter);
            }
        }

        private void refill(RateLimitConfig cfg) {
            long nowNanos     = System.nanoTime();
            double elapsed    = (nowNanos - lastRefillNanos) / 1_000_000_000.0; // seconds
            double newTokens  = elapsed * cfg.refillRatePerSecond();
            tokens            = Math.min(cfg.capacity(), tokens + newTokens);
            lastRefillNanos   = nowNanos;
        }
    }
}
```

```java
// ─────────────────────────────────────────────
// REDIS TOKEN BUCKET — ATOMIC via Lua Script
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.List;

/**
 * Distributed token bucket using a Lua script for atomicity.
 * Single Redis call ensures no race between refill-check-decrement.
 */
@Component
public class RedisTokenBucketRateLimiter implements RateLimiter {

    private static final String LUA_SCRIPT = """
            local key            = KEYS[1]
            local capacity       = tonumber(ARGV[1])
            local refill_rate    = tonumber(ARGV[2])   -- tokens per second
            local now            = tonumber(ARGV[3])   -- epoch seconds (float)
            local requested      = tonumber(ARGV[4])   -- usually 1
            
            local data           = redis.call('HMGET', key, 'tokens', 'last_refill')
            local tokens         = tonumber(data[1]) or capacity
            local last_refill    = tonumber(data[2]) or now
            
            -- Refill
            local elapsed        = now - last_refill
            tokens               = math.min(capacity, tokens + elapsed * refill_rate)
            
            local allowed        = 0
            local remaining      = tokens
            
            if tokens >= requested then
                tokens    = tokens - requested
                remaining = tokens
                allowed   = 1
            end
            
            local ttl = math.ceil(capacity / refill_rate) + 1
            redis.call('HSET', key, 'tokens', tokens, 'last_refill', now)
            redis.call('EXPIRE', key, ttl)
            
            return { allowed, math.floor(remaining) }
            """;

    private final StringRedisTemplate redis;
    private final RateLimitConfig config;
    private final DefaultRedisScript<List> script;

    public RedisTokenBucketRateLimiter(StringRedisTemplate redis, RateLimitConfig config) {
        this.redis  = redis;
        this.config = config;
        this.script = new DefaultRedisScript<>(LUA_SCRIPT, List.class);
    }

    @Override
    public RateLimitResult tryConsume(String key) {
        double now = System.currentTimeMillis() / 1000.0;

        List result = redis.execute(
                script,
                List.of("ratelimit:" + key),
                String.valueOf(config.capacity()),
                String.valueOf(config.refillRatePerSecond()),
                String.valueOf(now),
                "1"
        );

        if (result == null) {
            // Redis unavailable — fail-open
            return RateLimitResult.allow(config.capacity(), Instant.now().plusSeconds(config.windowSizeSeconds()));
        }

        boolean allowed   = ((Number) result.get(0)).intValue() == 1;
        long remaining    = ((Number) result.get(1)).longValue();
        Instant resetAt   = Instant.now().plusSeconds(
                (long) Math.ceil((config.capacity() - remaining) / (double) config.refillRatePerSecond()));

        return allowed
                ? RateLimitResult.allow(remaining, resetAt)
                : RateLimitResult.deny(resetAt, (long) Math.ceil(1.0 / config.refillRatePerSecond()));
    }
}
```

```java
// ─────────────────────────────────────────────
// SLIDING WINDOW COUNTER via Redis Sorted Set
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;

import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

public class SlidingWindowLogRateLimiter implements RateLimiter {

    private final StringRedisTemplate redis;
    private final RateLimitConfig config;

    public SlidingWindowLogRateLimiter(StringRedisTemplate redis, RateLimitConfig config) {
        this.redis  = redis;
        this.config = config;
    }

    @Override
    public RateLimitResult tryConsume(String key) {
        String redisKey  = "ratelimit:sw:" + key;
        long nowMs       = System.currentTimeMillis();
        long windowMs    = config.windowSizeSeconds() * 1000L;
        long windowStart = nowMs - windowMs;

        ZSetOperations<String, String> zset = redis.opsForZSet();

        // Remove old entries
        zset.removeRangeByScore(redisKey, 0, windowStart);

        // Count current
        Long count = zset.zCard(redisKey);
        if (count == null) count = 0L;

        Instant resetAt = Instant.ofEpochMilli(nowMs + windowMs);

        if (count < config.capacity()) {
            // Add current request
            String member = UUID.randomUUID().toString();
            zset.add(redisKey, member, nowMs);
            redis.expire(redisKey, config.windowSizeSeconds() + 1, TimeUnit.SECONDS);
            return RateLimitResult.allow(config.capacity() - count - 1, resetAt);
        } else {
            return RateLimitResult.deny(resetAt, config.windowSizeSeconds());
        }
    }
}
```

```java
// ─────────────────────────────────────────────
// FIXED WINDOW COUNTER
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import org.springframework.data.redis.core.StringRedisTemplate;

import java.time.Instant;
import java.util.concurrent.TimeUnit;

public class FixedWindowRateLimiter implements RateLimiter {

    private final StringRedisTemplate redis;
    private final RateLimitConfig config;

    public FixedWindowRateLimiter(StringRedisTemplate redis, RateLimitConfig config) {
        this.redis  = redis;
        this.config = config;
    }

    @Override
    public RateLimitResult tryConsume(String key) {
        long windowId   = System.currentTimeMillis() / (config.windowSizeSeconds() * 1000L);
        String redisKey = "ratelimit:fw:" + key + ":" + windowId;

        Long count = redis.opsForValue().increment(redisKey);
        if (count == null) count = 1L;

        if (count == 1) {
            redis.expire(redisKey, config.windowSizeSeconds(), TimeUnit.SECONDS);
        }

        Instant resetAt   = Instant.ofEpochMilli(
                (windowId + 1) * config.windowSizeSeconds() * 1000L);
        long remaining    = config.capacity() - count;

        if (remaining >= 0) {
            return RateLimitResult.allow(remaining, resetAt);
        } else {
            return RateLimitResult.deny(resetAt, config.windowSizeSeconds());
        }
    }
}
```

```java
// ─────────────────────────────────────────────
// FACTORY
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

@Component
public class RateLimiterFactory {

    private final StringRedisTemplate redis;

    public RateLimiterFactory(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public RateLimiter create(RateLimitConfig config) {
        return switch (config.algorithm()) {
            case "TOKEN_BUCKET"     -> new RedisTokenBucketRateLimiter(redis, config);
            case "FIXED_WINDOW"     -> new FixedWindowRateLimiter(redis, config);
            case "SLIDING_WINDOW"   -> new SlidingWindowLogRateLimiter(redis, config);
            case "LOCAL_TOKEN_BUCKET" -> new TokenBucketRateLimiter(config);
            default -> throw new IllegalArgumentException("Unknown algorithm: " + config.algorithm());
        };
    }
}
```

```java
// ─────────────────────────────────────────────
// SPRING FILTER — DECORATOR PATTERN
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Applies rate limiting transparently to every HTTP request.
 * Implements the Decorator pattern: wraps the filter chain without
 * modifying any business logic.
 */
public class RateLimitFilter extends OncePerRequestFilter {

    private final RateLimiter rateLimiter;
    private final KeyExtractor keyExtractor;

    public RateLimitFilter(RateLimiter rateLimiter, KeyExtractor keyExtractor) {
        this.rateLimiter   = rateLimiter;
        this.keyExtractor  = keyExtractor;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {

        String key              = keyExtractor.extract(request);
        RateLimitResult result  = rateLimiter.tryConsume(key);

        // Always set informational headers
        response.setHeader("X-RateLimit-Remaining", String.valueOf(result.remaining()));
        response.setHeader("X-RateLimit-Reset",     String.valueOf(result.resetAt().getEpochSecond()));

        if (!result.allowed()) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("Retry-After", String.valueOf(result.retryAfterSeconds()));
            response.setContentType("application/json");
            response.getWriter().write("""
                    {"error":"Too Many Requests","retryAfter":%d}
                    """.formatted(result.retryAfterSeconds()));
            return;
        }

        chain.doFilter(request, response);
    }
}
```

```java
// ─────────────────────────────────────────────
// KEY EXTRACTOR — Strategy for key building
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import jakarta.servlet.http.HttpServletRequest;

@FunctionalInterface
public interface KeyExtractor {
    String extract(HttpServletRequest request);
}

/** Extract by authenticated user ID from JWT, fallback to IP. */
public class UserOrIpKeyExtractor implements KeyExtractor {
    @Override
    public String extract(HttpServletRequest request) {
        String userId = request.getHeader("X-User-Id");
        if (userId != null && !userId.isBlank()) return "user:" + userId;

        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return "ip:" + forwardedFor.split(",")[0].trim();
        }
        return "ip:" + request.getRemoteAddr();
    }
}
```

```java
// ─────────────────────────────────────────────
// SPRING BOOT CONFIGURATION
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.StringRedisTemplate;

@Configuration
public class RateLimiterConfig {

    @Bean
    public RateLimitConfig defaultRateLimitConfig() {
        // 100 requests per minute per user, token bucket algorithm
        return new RateLimitConfig(100, 2, 60, "TOKEN_BUCKET");
    }

    @Bean
    public RateLimiter rateLimiter(RateLimiterFactory factory, RateLimitConfig config) {
        return factory.create(config);
    }

    @Bean
    public KeyExtractor keyExtractor() {
        return new UserOrIpKeyExtractor();
    }

    @Bean
    public FilterRegistrationBean<RateLimitFilter> rateLimitFilter(
            RateLimiter rateLimiter,
            KeyExtractor keyExtractor) {

        FilterRegistrationBean<RateLimitFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(new RateLimitFilter(rateLimiter, keyExtractor));
        registration.addUrlPatterns("/api/*");
        registration.setOrder(1); // run before other filters
        return registration;
    }
}
```

```java
// ─────────────────────────────────────────────
// UNIT TESTS
// ─────────────────────────────────────────────

package com.interview.lld.ratelimiter;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TokenBucketRateLimiterTest {

    @Test
    void allowsRequestsWithinCapacity() {
        RateLimitConfig cfg = new RateLimitConfig(5, 1, 60, "LOCAL_TOKEN_BUCKET");
        RateLimiter limiter = new TokenBucketRateLimiter(cfg);

        for (int i = 0; i < 5; i++) {
            assertTrue(limiter.tryConsume("user:1").allowed(),
                    "Request " + (i + 1) + " should be allowed");
        }
    }

    @Test
    void deniesRequestWhenBucketEmpty() {
        RateLimitConfig cfg = new RateLimitConfig(2, 1, 60, "LOCAL_TOKEN_BUCKET");
        RateLimiter limiter = new TokenBucketRateLimiter(cfg);

        limiter.tryConsume("user:1");
        limiter.tryConsume("user:1");

        RateLimitResult result = limiter.tryConsume("user:1");
        assertFalse(result.allowed(), "Third request should be denied");
        assertEquals(0, result.remaining());
    }

    @Test
    void differentKeysHaveIndependentBuckets() {
        RateLimitConfig cfg = new RateLimitConfig(1, 1, 60, "LOCAL_TOKEN_BUCKET");
        RateLimiter limiter = new TokenBucketRateLimiter(cfg);

        assertTrue(limiter.tryConsume("user:1").allowed());
        assertFalse(limiter.tryConsume("user:1").allowed());
        assertTrue(limiter.tryConsume("user:2").allowed(), "Different user should have own bucket");
    }

    @Test
    void tokensRefillOverTime() throws InterruptedException {
        RateLimitConfig cfg = new RateLimitConfig(1, 2, 60, "LOCAL_TOKEN_BUCKET");
        RateLimiter limiter = new TokenBucketRateLimiter(cfg);

        limiter.tryConsume("user:1");
        assertFalse(limiter.tryConsume("user:1").allowed());

        Thread.sleep(600); // 0.6s * 2 tokens/s = 1.2 tokens refilled

        assertTrue(limiter.tryConsume("user:1").allowed(), "Should be allowed after refill");
    }
}
```

---

## 6. Key Interview Questions — Rate Limiter

### Q1. Why use a Lua script for the Redis token bucket instead of multiple Redis commands?

**Answer:** Redis is single-threaded, but multiple client commands are not atomic as a unit. Without atomicity, two concurrent requests can both read `tokens = 1`, both decide to allow, both decrement — resulting in `tokens = -1`, effectively bypassing the limit. A Lua script runs atomically on the Redis server (no other client commands execute mid-script), eliminating this race condition without needing a distributed lock.

### Q2. Compare Token Bucket vs. Sliding Window Log for a payment API.

**Answer:**

| Criterion | Token Bucket | Sliding Window Log |
|---|---|---|
| Burst handling | Allows bursts up to `capacity` | Strict — every request is timestamped |
| Memory | O(1) per key | O(requests in window) per key |
| Accuracy | Accurate, continuous time | Perfectly accurate |
| Best for | Public APIs where occasional burst is OK | Payment/sensitive APIs where exact limits are critical |

For a payment API, use **Sliding Window Log** — the added memory cost is worth the accuracy. For a public search API, **Token Bucket** is preferred.

### Q3. What happens to your rate limiter if Redis goes down?

**Answer:** Two options:
- **Fail-open** (allow all): Service stays up, protection is temporarily removed. Suitable when availability > security.
- **Fail-closed** (deny all): Return 503. Suitable when the protected resource is sensitive (financial API).

The `RedisTokenBucketRateLimiter` above uses **fail-open** (`return RateLimitResult.allow(...)` when `result == null`). Add a circuit breaker (Resilience4j) to detect Redis failure quickly and fall back to the in-memory `TokenBucketRateLimiter`.

### Q4. How do you implement tiered rate limits (Free: 100/hr, Pro: 10,000/hr)?

**Answer:** Make `RateLimitConfig` per-user-tier rather than global:
1. Resolve the user's tier from the JWT claim or a user service lookup.
2. Key the `RateLimitConfig` lookup by tier: `Map<Tier, RateLimitConfig> tierConfigs`.
3. In `RateLimitFilter`, call `configResolver.resolve(userId)` to get the appropriate config before calling `rateLimiter.tryConsume(key)`.
4. Optionally, create separate `RateLimiter` instances per tier or parameterise the Lua script with capacity/rate from the request context.

### Q5. How would you rate-limit by endpoint rather than globally per user?

**Answer:** Use a composite Redis key combining user identity and the endpoint: e.g., `"ratelimit:user:42:POST:/api/payments"`. A `KeyExtractor` interface concatenates the user ID, HTTP method, and normalized path; the `RateLimitFilter` calls it to derive the key before checking the bucket. Configure a `Map<String, RateLimitConfig>` keyed by path pattern (supporting wildcards like `/api/payments/**`) so each endpoint can have its own limit — for example, the payment endpoint allows 10 req/min while the search endpoint allows 200 req/min. The filter matches the incoming request path against the map using longest-prefix wins and falls back to a global per-user default if no endpoint-specific rule is found. This approach is fully additive: adding a new endpoint limit requires only a config entry, not a code change.

### Q6. What is the Leaky Bucket's advantage over Token Bucket for downstream services?

**Answer:** Token Bucket allows bursts — if tokens have accumulated, many requests pass through simultaneously, potentially overwhelming a downstream service. Leaky Bucket enforces a **constant outflow rate**, protecting downstream from spikes. Use Leaky Bucket when the downstream service (e.g., a legacy mainframe) cannot handle variable load.

### Q7. How do you prevent a user from bypassing per-IP rate limiting using proxies?

**Answer:**
1. Rate-limit by **authenticated user ID** (JWT sub claim) as the primary key — proxies don't help if auth is required.
2. For unauthenticated endpoints, require CAPTCHA after a soft threshold.
3. Use **composite keys**: `ip + user-agent + TLS fingerprint` to raise the cost of spoofing.
4. Integrate with a **fraud detection service** that correlates multiple IPs resolving to the same user pattern.

---

*End of Chapter 21 Part A — LLD Case Studies: Parking Lot, URL Shortener, Rate Limiter.*

*Part B will cover: Library Management System, Chess Game, and Elevator System.*


---

# Chapter 21 — Part B: LLD Case Studies (BookMyShow, Splitwise, Elevator System)

> **Target Audience:** SDE2 / Senior Engineers preparing for FAANG+ backend interviews  
> **Java Version:** Java 17 + Spring Boot 3.x  
> **Prerequisites:** Part A (LLD fundamentals, SOLID principles, common patterns)

---

## LLD 4: BookMyShow — Movie Ticket Booking System

### 4.1 Requirements

**Functional Requirements**
- Search movies by city, date, genre, language
- View theatres showing a movie and available shows
- Select seats on a visual seat map (Silver / Gold / Platinum tiers)
- Book tickets (single or multiple seats per booking)
- Process payment (Credit Card, UPI, Wallet)
- Receive booking confirmation (Email / SMS / Push)
- Cancel booking and receive refund

**Non-Functional Requirements**
- Handle 1,000+ concurrent users trying to book the same show
- Seat must not be double-booked under any circumstances
- Seat lock must expire (e.g., 10 minutes) if payment is abandoned
- Sub-second seat availability queries

---

### 4.2 Core Entities

```
Movie         ──< Show >──  Screen  ──belongs──  Theatre
                               │
                            ShowSeat (Silver/Gold/Platinum)
                               │
Booking ──holds──> BookingSeat ──references──> ShowSeat
   │
Payment
   │
Notification ──sends to──> User
```

```java
// ─────────────────────────────────────────────
// Enumerations
// ─────────────────────────────────────────────

public enum SeatType   { SILVER, GOLD, PLATINUM }
public enum SeatStatus { AVAILABLE, LOCKED, BOOKED }
public enum BookingStatus { PENDING, CONFIRMED, CANCELLED, EXPIRED }
public enum PaymentStatus { INITIATED, SUCCESS, FAILED, REFUNDED }
public enum PaymentMethod { CREDIT_CARD, DEBIT_CARD, UPI, WALLET }

// ─────────────────────────────────────────────
// Domain Entities
// ─────────────────────────────────────────────

@Entity
@Table(name = "movies")
public class Movie {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String title;
    private String language;
    private String genre;
    private int durationMinutes;
    private LocalDate releaseDate;
    private String description;
    // getters/setters omitted for brevity
}

@Entity
@Table(name = "theatres")
public class Theatre {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String city;
    private String address;

    @OneToMany(mappedBy = "theatre", cascade = CascadeType.ALL)
    private List<Screen> screens = new ArrayList<>();
}

@Entity
@Table(name = "screens")
public class Screen {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;          // "Screen 1", "Screen 2"
    private int totalSeats;

    @ManyToOne
    @JoinColumn(name = "theatre_id")
    private Theatre theatre;

    @OneToMany(mappedBy = "screen", cascade = CascadeType.ALL)
    private List<Seat> seats = new ArrayList<>();
}

@Entity
@Table(name = "seats")
public class Seat {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String rowLabel;       // A, B, C …
    private int seatNumber;        // 1, 2, 3 …

    @Enumerated(EnumType.STRING)
    private SeatType seatType;

    @ManyToOne
    @JoinColumn(name = "screen_id")
    private Screen screen;
}

@Entity
@Table(name = "shows")
public class Show {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private LocalDateTime startTime;
    private LocalDateTime endTime;

    @ManyToOne @JoinColumn(name = "movie_id")
    private Movie movie;

    @ManyToOne @JoinColumn(name = "screen_id")
    private Screen screen;

    @OneToMany(mappedBy = "show", cascade = CascadeType.ALL)
    private List<ShowSeat> showSeats = new ArrayList<>();
}

/**
 * ShowSeat represents one physical seat for one specific show.
 * The @Version field enables OPTIMISTIC LOCKING — this is the
 * key mechanism that prevents double-booking.
 */
@Entity
@Table(name = "show_seats",
       indexes = { @Index(columnList = "show_id,status") })
public class ShowSeat {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne @JoinColumn(name = "show_id")
    private Show show;

    @ManyToOne @JoinColumn(name = "seat_id")
    private Seat seat;

    @Enumerated(EnumType.STRING)
    private SeatStatus status = SeatStatus.AVAILABLE;

    private BigDecimal price;

    /**
     * OPTIMISTIC LOCK VERSION — incremented on every UPDATE.
     * If two transactions read version=5 and both try to UPDATE,
     * one succeeds (version becomes 6) and the other gets
     * ObjectOptimisticLockingFailureException because it still
     * holds version=5, which is now stale.
     */
    @Version
    private Long version;

    private LocalDateTime lockedAt;          // when the lock was acquired
    private String lockedByBookingId;        // which pending booking holds lock
}

@Entity
@Table(name = "bookings")
public class Booking {
    @Id
    private String id;            // UUID, used as booking reference

    @ManyToOne @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne @JoinColumn(name = "show_id")
    private Show show;

    @Enumerated(EnumType.STRING)
    private BookingStatus status = BookingStatus.PENDING;

    private BigDecimal totalAmount;
    private LocalDateTime createdAt;
    private LocalDateTime expiresAt;   // lock expiry (createdAt + 10 min)

    @OneToMany(mappedBy = "booking", cascade = CascadeType.ALL)
    private List<BookingSeat> seats = new ArrayList<>();

    @OneToOne(mappedBy = "booking", cascade = CascadeType.ALL)
    private Payment payment;
}

@Entity
@Table(name = "booking_seats")
public class BookingSeat {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne @JoinColumn(name = "booking_id")
    private Booking booking;

    @ManyToOne @JoinColumn(name = "show_seat_id")
    private ShowSeat showSeat;
}

@Entity
@Table(name = "payments")
public class Payment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne @JoinColumn(name = "booking_id")
    private Booking booking;

    @Enumerated(EnumType.STRING)
    private PaymentMethod method;

    @Enumerated(EnumType.STRING)
    private PaymentStatus status = PaymentStatus.INITIATED;

    private BigDecimal amount;
    private String transactionId;
    private LocalDateTime processedAt;
}

@Entity
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String email;
    private String phone;
}
```

---

### 4.3 Key Design Challenges

#### Challenge 1 — Concurrent Seat Booking (Race Conditions)

**The Problem:** 1,000 users simultaneously try to book seat A1 for the same show.

**Wrong approach:** Read seat status → check if AVAILABLE → update to LOCKED  
This has a classic TOCTOU (Time-of-Check-Time-of-Use) race condition.

**Correct approach: Optimistic Locking with `@Version`**

```
User A reads ShowSeat(id=42, status=AVAILABLE, version=5)
User B reads ShowSeat(id=42, status=AVAILABLE, version=5)

User A updates: SET status=LOCKED, version=6 WHERE id=42 AND version=5  → SUCCESS
User B updates: SET status=LOCKED, version=6 WHERE id=42 AND version=5  → FAILS (version is now 6)
  └─> Spring throws ObjectOptimisticLockingFailureException
  └─> Service layer catches it → returns "Seat no longer available"
```

**Alternative: Pessimistic Locking** — `SELECT ... FOR UPDATE` locks the row at DB level.  
Use pessimistic when contention is very high (>80% conflict rate). Use optimistic otherwise (less overhead, better throughput).

#### Challenge 2 — Seat Lock Expiry

When a user selects seats but abandons payment, those seats must be released.

**Solution:** Scheduled job scans for expired locks.

```java
@Scheduled(fixedDelay = 60_000)   // every 60 seconds
@Transactional
public void releaseExpiredLocks() {
    LocalDateTime cutoff = LocalDateTime.now();
    List<ShowSeat> expired = showSeatRepository
        .findByStatusAndLockedAtBefore(SeatStatus.LOCKED, cutoff.minusMinutes(10));
    expired.forEach(seat -> {
        seat.setStatus(SeatStatus.AVAILABLE);
        seat.setLockedAt(null);
        seat.setLockedByBookingId(null);
    });
    showSeatRepository.saveAll(expired);

    // also expire the bookings themselves
    bookingRepository.expireOldPendingBookings(cutoff.minusMinutes(10));
}
```

#### Challenge 3 — Show Seat Availability (Performance)

Fetching all seat statuses for a show on every request is expensive.

**Solution:** Cache the seat map in Redis with a short TTL (5 seconds). Invalidate on every booking or lock change.

```java
@Cacheable(value = "showSeats", key = "#showId")
public List<ShowSeatDTO> getSeatsForShow(Long showId) {
    return showSeatRepository.findByShowId(showId)
        .stream()
        .map(ShowSeatDTO::from)
        .toList();
}
```

---

### 4.4 Design Patterns Applied

#### Observer Pattern — Booking Notifications

```java
// Event published after successful booking
public record BookingConfirmedEvent(Booking booking) {}

// Publisher in service
@Autowired ApplicationEventPublisher eventPublisher;
eventPublisher.publishEvent(new BookingConfirmedEvent(booking));

// Listeners (each notification channel is a separate Observer)
@Component
public class EmailNotificationListener {
    @EventListener
    public void onBookingConfirmed(BookingConfirmedEvent event) {
        emailService.sendBookingConfirmation(event.booking());
    }
}

@Component
public class SmsNotificationListener {
    @EventListener
    @Async   // don't block the booking thread
    public void onBookingConfirmed(BookingConfirmedEvent event) {
        smsService.sendSms(event.booking().getUser().getPhone(),
            "Booking confirmed! Ref: " + event.booking().getId());
    }
}
```

#### Strategy Pattern — Payment Processing

```java
public interface PaymentStrategy {
    PaymentResult process(Payment payment);
    PaymentMethod supports();
}

@Component
public class CreditCardPaymentStrategy implements PaymentStrategy {
    @Override
    public PaymentResult process(Payment payment) {
        // integrate with Stripe/Razorpay
        return PaymentResult.success(UUID.randomUUID().toString());
    }
    @Override public PaymentMethod supports() { return PaymentMethod.CREDIT_CARD; }
}

@Component
public class UpiPaymentStrategy implements PaymentStrategy {
    @Override
    public PaymentResult process(Payment payment) {
        // integrate with UPI gateway
        return PaymentResult.success(UUID.randomUUID().toString());
    }
    @Override public PaymentMethod supports() { return PaymentMethod.UPI; }
}

@Service
public class PaymentService {
    private final Map<PaymentMethod, PaymentStrategy> strategies;

    public PaymentService(List<PaymentStrategy> strategyList) {
        this.strategies = strategyList.stream()
            .collect(Collectors.toMap(PaymentStrategy::supports, s -> s));
    }

    public PaymentResult processPayment(Payment payment) {
        PaymentStrategy strategy = strategies.get(payment.getMethod());
        if (strategy == null) throw new UnsupportedPaymentMethodException(payment.getMethod());
        return strategy.process(payment);
    }
}
```

#### Factory Pattern — Notification Channel

```java
public interface NotificationChannel {
    void send(User user, String message);
}

@Component("EMAIL")
public class EmailChannel implements NotificationChannel { /* ... */ }

@Component("SMS")
public class SmsChannel implements NotificationChannel { /* ... */ }

@Component("PUSH")
public class PushChannel implements NotificationChannel { /* ... */ }

@Service
public class NotificationFactory {
    @Autowired
    private Map<String, NotificationChannel> channels;   // Spring auto-populates by bean name

    public NotificationChannel getChannel(String type) {
        NotificationChannel channel = channels.get(type.toUpperCase());
        if (channel == null) throw new IllegalArgumentException("Unknown channel: " + type);
        return channel;
    }
}
```

---

### 4.5 Complete Spring Boot Implementation — Booking Flow

```java
// ─────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────

@Repository
public interface ShowSeatRepository extends JpaRepository<ShowSeat, Long> {

    @Lock(LockModeType.OPTIMISTIC)
    @Query("SELECT s FROM ShowSeat s WHERE s.show.id = :showId AND s.id IN :seatIds")
    List<ShowSeat> findByShowIdAndIdInWithLock(
            @Param("showId") Long showId,
            @Param("seatIds") List<Long> seatIds);

    List<ShowSeat> findByShowId(Long showId);

    List<ShowSeat> findByStatusAndLockedAtBefore(SeatStatus status, LocalDateTime before);
}

@Repository
public interface BookingRepository extends JpaRepository<Booking, String> {

    @Modifying
    @Query("""
        UPDATE Booking b SET b.status = 'EXPIRED'
        WHERE b.status = 'PENDING' AND b.expiresAt < :cutoff
        """)
    void expireOldPendingBookings(@Param("cutoff") LocalDateTime cutoff);
}

// ─────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────

public record BookingRequest(
    Long showId,
    List<Long> showSeatIds,
    PaymentMethod paymentMethod
) {}

public record BookingResponse(
    String bookingId,
    BookingStatus status,
    BigDecimal totalAmount,
    String message
) {}

// ─────────────────────────────────────────────
// Service — Core booking logic with seat locking
// ─────────────────────────────────────────────

@Service
@Slf4j
public class BookingService {

    private final ShowSeatRepository showSeatRepo;
    private final BookingRepository bookingRepo;
    private final ShowRepository showRepo;
    private final UserRepository userRepo;
    private final PaymentService paymentService;
    private final ApplicationEventPublisher eventPublisher;

    public BookingService(ShowSeatRepository showSeatRepo,
                          BookingRepository bookingRepo,
                          ShowRepository showRepo,
                          UserRepository userRepo,
                          PaymentService paymentService,
                          ApplicationEventPublisher eventPublisher) {
        this.showSeatRepo   = showSeatRepo;
        this.bookingRepo    = bookingRepo;
        this.showRepo       = showRepo;
        this.userRepo       = userRepo;
        this.paymentService = paymentService;
        this.eventPublisher = eventPublisher;
    }

    /**
     * STEP 1 — Lock requested seats (optimistic locking).
     * STEP 2 — Create a PENDING booking.
     * STEP 3 — Process payment.
     * STEP 4 — Confirm booking (or rollback seat locks on failure).
     */
    @Transactional
    public BookingResponse createBooking(Long userId, BookingRequest request) {

        // ── 1. Load the show ──────────────────────────────────────────────
        Show show = showRepo.findById(request.showId())
            .orElseThrow(() -> new NotFoundException("Show not found: " + request.showId()));

        User user = userRepo.findById(userId)
            .orElseThrow(() -> new NotFoundException("User not found: " + userId));

        // ── 2. Lock seats with optimistic locking ─────────────────────────
        //    findByShowIdAndIdInWithLock uses @Lock(OPTIMISTIC) — JPA will
        //    add a version-check on flush/commit.
        List<ShowSeat> seats = showSeatRepo
            .findByShowIdAndIdInWithLock(request.showId(), request.showSeatIds());

        if (seats.size() != request.showSeatIds().size()) {
            throw new InvalidRequestException("One or more seats not found for this show");
        }

        // Validate ALL seats are AVAILABLE (fail fast before any mutation)
        List<ShowSeat> unavailable = seats.stream()
            .filter(s -> s.getStatus() != SeatStatus.AVAILABLE)
            .toList();
        if (!unavailable.isEmpty()) {
            throw new SeatsUnavailableException(
                "Seats already taken: " + unavailable.stream()
                    .map(s -> s.getSeat().getRowLabel() + s.getSeat().getSeatNumber())
                    .toList());
        }

        // ── 3. Create pending booking ─────────────────────────────────────
        String bookingId = UUID.randomUUID().toString();
        BigDecimal total = seats.stream()
            .map(ShowSeat::getPrice)
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        Booking booking = new Booking();
        booking.setId(bookingId);
        booking.setUser(user);
        booking.setShow(show);
        booking.setStatus(BookingStatus.PENDING);
        booking.setTotalAmount(total);
        booking.setCreatedAt(LocalDateTime.now());
        booking.setExpiresAt(LocalDateTime.now().plusMinutes(10));
        bookingRepo.save(booking);

        // ── 4. Mark seats as LOCKED ──────────────────────────────────────
        //    If version mismatch occurs here, @Transactional rolls back
        //    and ObjectOptimisticLockingFailureException propagates.
        LocalDateTime now = LocalDateTime.now();
        List<BookingSeat> bookingSeats = new ArrayList<>();
        for (ShowSeat seat : seats) {
            seat.setStatus(SeatStatus.LOCKED);
            seat.setLockedAt(now);
            seat.setLockedByBookingId(bookingId);

            BookingSeat bs = new BookingSeat();
            bs.setBooking(booking);
            bs.setShowSeat(seat);
            bookingSeats.add(bs);
        }
        showSeatRepo.saveAll(seats);
        booking.setSeats(bookingSeats);

        // ── 5. Process payment ────────────────────────────────────────────
        Payment payment = new Payment();
        payment.setBooking(booking);
        payment.setMethod(request.paymentMethod());
        payment.setAmount(total);
        payment.setStatus(PaymentStatus.INITIATED);

        PaymentResult result = paymentService.processPayment(payment);

        if (!result.isSuccess()) {
            // Roll back seat locks on payment failure
            seats.forEach(s -> {
                s.setStatus(SeatStatus.AVAILABLE);
                s.setLockedAt(null);
                s.setLockedByBookingId(null);
            });
            showSeatRepo.saveAll(seats);
            booking.setStatus(BookingStatus.CANCELLED);
            bookingRepo.save(booking);
            return new BookingResponse(bookingId, BookingStatus.CANCELLED, total,
                "Payment failed: " + result.getMessage());
        }

        // ── 6. Confirm booking ────────────────────────────────────────────
        payment.setStatus(PaymentStatus.SUCCESS);
        payment.setTransactionId(result.getTransactionId());
        payment.setProcessedAt(LocalDateTime.now());
        booking.setPayment(payment);
        booking.setStatus(BookingStatus.CONFIRMED);

        seats.forEach(s -> s.setStatus(SeatStatus.BOOKED));
        showSeatRepo.saveAll(seats);
        bookingRepo.save(booking);

        // ── 7. Notify (async via Observer/EventListener) ──────────────────
        eventPublisher.publishEvent(new BookingConfirmedEvent(booking));

        return new BookingResponse(bookingId, BookingStatus.CONFIRMED, total,
            "Booking confirmed!");
    }

    /**
     * Cancel a booking and refund the payment.
     */
    @Transactional
    public void cancelBooking(String bookingId, Long userId) {
        Booking booking = bookingRepo.findById(bookingId)
            .orElseThrow(() -> new NotFoundException("Booking not found"));

        if (!booking.getUser().getId().equals(userId))
            throw new UnauthorizedException("Not your booking");

        if (booking.getStatus() != BookingStatus.CONFIRMED)
            throw new InvalidRequestException("Only confirmed bookings can be cancelled");

        // Release seats
        booking.getSeats().forEach(bs -> {
            ShowSeat ss = bs.getShowSeat();
            ss.setStatus(SeatStatus.AVAILABLE);
        });

        // Initiate refund
        booking.getPayment().setStatus(PaymentStatus.REFUNDED);
        booking.setStatus(BookingStatus.CANCELLED);
        bookingRepo.save(booking);
    }
}

// ─────────────────────────────────────────────
// Exception handler for optimistic lock failures
// ─────────────────────────────────────────────

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ObjectOptimisticLockingFailureException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public Map<String, String> handleOptimisticLock(ObjectOptimisticLockingFailureException ex) {
        return Map.of("error", "One or more seats were just taken. Please try again.");
    }

    @ExceptionHandler(SeatsUnavailableException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public Map<String, String> handleSeatsUnavailable(SeatsUnavailableException ex) {
        return Map.of("error", ex.getMessage());
    }
}

// ─────────────────────────────────────────────
// REST Controller
// ─────────────────────────────────────────────

@RestController
@RequestMapping("/api/v1/bookings")
public class BookingController {

    private final BookingService bookingService;

    public BookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    @PostMapping
    public ResponseEntity<BookingResponse> createBooking(
            @RequestBody BookingRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = ((AppUserDetails) userDetails).getUserId();
        BookingResponse response = bookingService.createBooking(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @DeleteMapping("/{bookingId}")
    public ResponseEntity<Void> cancelBooking(
            @PathVariable String bookingId,
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = ((AppUserDetails) userDetails).getUserId();
        bookingService.cancelBooking(bookingId, userId);
        return ResponseEntity.noContent().build();
    }
}
```

---

### 4.6 Key Interview Questions

**Q1: How do you handle 1,000 concurrent users trying to book the same seat?**

> **Answer:** Optimistic locking via JPA `@Version`. All 1,000 requests read the seat row with `version=5`. The first transaction that executes `UPDATE show_seats SET status='LOCKED', version=6 WHERE id=? AND version=5` wins. The remaining 999 transactions see a stale version and JPA throws `ObjectOptimisticLockingFailureException`. The service layer catches this and returns HTTP 409 Conflict with a user-friendly message. This approach avoids row-level DB locks, which would serialize all 1,000 requests and cause massive contention.
>
> **Follow-up:** When would you use pessimistic locking instead?  
> When contention is near 100% (flash sales, limited inventory items). Use `@Lock(LockModeType.PESSIMISTIC_WRITE)` + `SELECT ... FOR UPDATE`. Trade-off: lower throughput but zero retries.

**Q2: How do you prevent seat locks from being held forever?**

> **Answer:** Every `Booking` has an `expiresAt` timestamp (10 minutes after creation). A `@Scheduled` job runs every 60 seconds and queries for `ShowSeat` records with `status=LOCKED AND lockedAt < now-10min`, resets them to `AVAILABLE`, and marks the corresponding `Booking` as `EXPIRED`. This ensures abandoned payment flows don't permanently block seats.

**Q3: How do you design the seat map for high read throughput?**

> **Answer:** Cache seat statuses in Redis with a TTL of 5–10 seconds using Spring Cache (`@Cacheable`). On every booking or lock change, evict the cache (`@CacheEvict`). For even higher scale, use Redis Pub/Sub to push seat status changes to all connected browser clients via WebSocket, eliminating repeated polling.

**Q4: What is the overall booking flow?**

> **Answer:** (1) User selects seats → lock seats optimistically + create PENDING booking → (2) Payment page shown (10-min timer) → (3) User pays → (4) If payment succeeds: mark seats BOOKED, booking CONFIRMED, fire async notification events → (5) If payment fails or times out: release locks, expire booking.

---

## LLD 5: Splitwise — Expense Sharing System

### 5.1 Requirements

**Functional Requirements**
- Create groups and add members
- Add an expense (one person paid; split among some/all members)
- Split types: Equal, Exact amount, Percentage, Shares
- View net balance for each user (who owes whom, how much)
- Settle up: simplify debts to minimize the number of transactions
- Expense history and audit trail

**Non-Functional Requirements**
- Balance calculations must be consistent (no floating-point drift)
- Support groups with up to 50 members
- Simplification algorithm should run in O(N log N) for N members

---

### 5.2 Core Entities

```
User ──member of──> Group
                      │
                   Expense (paid by one User, split among many)
                      │
               ExpenseSplit (one per participant)
                      │
              [EqualSplit | ExactSplit | PercentageSplit | ShareSplit]

Balance  — net amount User A owes User B (aggregated view)
Transaction — a settlement payment
```

```java
public enum SplitType { EQUAL, EXACT, PERCENTAGE, SHARES }

@Entity
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private String email;
    private String phone;
}

@Entity
@Table(name = "groups")
public class Group {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;

    @ManyToMany
    @JoinTable(name = "group_members",
               joinColumns = @JoinColumn(name = "group_id"),
               inverseJoinColumns = @JoinColumn(name = "user_id"))
    private Set<User> members = new HashSet<>();
}

@Entity
@Table(name = "expenses")
public class Expense {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String description;
    private BigDecimal totalAmount;
    private LocalDateTime createdAt;

    @ManyToOne @JoinColumn(name = "paid_by_user_id")
    private User paidBy;

    @ManyToOne @JoinColumn(name = "group_id")
    private Group group;   // null for non-group expenses

    @Enumerated(EnumType.STRING)
    private SplitType splitType;

    @OneToMany(mappedBy = "expense", cascade = CascadeType.ALL)
    private List<ExpenseSplit> splits = new ArrayList<>();
}

/**
 * One record per participant in an expense.
 * amountOwed = how much THIS user owes toward this expense.
 */
@Entity
@Table(name = "expense_splits")
public class ExpenseSplit {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne @JoinColumn(name = "expense_id")
    private Expense expense;

    @ManyToOne @JoinColumn(name = "user_id")
    private User user;

    private BigDecimal amountOwed;    // always stored in absolute currency units

    // For display purposes only:
    private BigDecimal percentage;    // set when SplitType=PERCENTAGE
    private Integer shares;           // set when SplitType=SHARES
}

@Entity
@Table(name = "transactions")
public class Transaction {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne @JoinColumn(name = "from_user_id")
    private User from;    // the person paying

    @ManyToOne @JoinColumn(name = "to_user_id")
    private User to;      // the person receiving

    private BigDecimal amount;
    private LocalDateTime settledAt;
}
```

---

### 5.3 Core Algorithm — Balance Simplification

**Problem:** After many expenses in a group, the raw debts are a dense graph.  
**Goal:** Produce a minimal set of transactions to clear all debts.

**Example:**
```
Raw debts (from expenses):
  A owes B: 50
  B owes C: 30
  C owes A: 20

Net balances:
  A: -50 + 20 = -30   (net owes 30)
  B: +50 - 30 = +20   (net is owed 20)
  C: +30 - 20 = +10   (net is owed 10)

Simplified (greedy, max-heap for creditors, min-heap for debtors):
  A pays B: 20  (B cleared)
  A pays C: 10  (C cleared, A owes 0)
  → 2 transactions instead of 3
```

**Algorithm: Greedy with Two Priority Queues**

```java
public class BalanceSimplifier {

    /**
     * Given a map of userId → net balance (positive = owed money, negative = owes money),
     * returns the minimum list of transactions to settle all debts.
     *
     * Time: O(N log N)  Space: O(N)
     */
    public List<SettlementTransaction> simplify(Map<Long, BigDecimal> netBalances) {
        // Max-heap for creditors (those who are owed money — positive balance)
        PriorityQueue<Map.Entry<Long, BigDecimal>> creditors =
            new PriorityQueue<>((a, b) -> b.getValue().compareTo(a.getValue()));

        // Max-heap of absolute values for debtors (those who owe — negative balance)
        PriorityQueue<Map.Entry<Long, BigDecimal>> debtors =
            new PriorityQueue<>((a, b) -> b.getValue().compareTo(a.getValue()));

        for (Map.Entry<Long, BigDecimal> entry : netBalances.entrySet()) {
            int cmp = entry.getValue().compareTo(BigDecimal.ZERO);
            if (cmp > 0) {
                creditors.offer(entry);
            } else if (cmp < 0) {
                // Store absolute value for easier comparison
                debtors.offer(Map.entry(entry.getKey(), entry.getValue().negate()));
            }
            // zero balance: skip
        }

        List<SettlementTransaction> result = new ArrayList<>();

        while (!creditors.isEmpty() && !debtors.isEmpty()) {
            Map.Entry<Long, BigDecimal> creditor = creditors.poll();
            Map.Entry<Long, BigDecimal> debtor   = debtors.poll();

            BigDecimal credit = creditor.getValue();
            BigDecimal debt   = debtor.getValue();

            BigDecimal transfer = credit.min(debt);
            result.add(new SettlementTransaction(debtor.getKey(), creditor.getKey(), transfer));

            BigDecimal remainingCredit = credit.subtract(transfer);
            BigDecimal remainingDebt   = debt.subtract(transfer);

            if (remainingCredit.compareTo(BigDecimal.ZERO) > 0)
                creditors.offer(Map.entry(creditor.getKey(), remainingCredit));

            if (remainingDebt.compareTo(BigDecimal.ZERO) > 0)
                debtors.offer(Map.entry(debtor.getKey(), remainingDebt));
        }

        return result;
    }
}

public record SettlementTransaction(Long fromUserId, Long toUserId, BigDecimal amount) {}
```

---

### 5.4 Design Patterns Applied

#### Strategy Pattern — Split Type Calculation

```java
/**
 * Each split strategy validates inputs and computes the amountOwed
 * for each participant.
 */
public interface SplitStrategy {
    /**
     * Validate that the provided split data is internally consistent
     * (e.g., percentages sum to 100, exact amounts sum to totalAmount).
     */
    void validate(BigDecimal totalAmount, List<SplitData> splitData);

    /**
     * Compute the exact amountOwed for each participant.
     * Returns a map of userId → amountOwed.
     */
    Map<Long, BigDecimal> compute(BigDecimal totalAmount, List<SplitData> splitData);

    SplitType supports();
}

// ── Equal Split ─────────────────────────────────────────────────────────────

@Component
public class EqualSplitStrategy implements SplitStrategy {

    @Override
    public void validate(BigDecimal totalAmount, List<SplitData> splitData) {
        if (splitData == null || splitData.isEmpty())
            throw new InvalidSplitException("At least one participant required");
    }

    @Override
    public Map<Long, BigDecimal> compute(BigDecimal totalAmount, List<SplitData> splitData) {
        int n = splitData.size();
        // Use HALF_UP rounding; last person absorbs rounding remainder
        BigDecimal share = totalAmount.divide(
            BigDecimal.valueOf(n), 2, RoundingMode.HALF_UP);
        BigDecimal remainder = totalAmount.subtract(share.multiply(BigDecimal.valueOf(n)));

        Map<Long, BigDecimal> result = new LinkedHashMap<>();
        for (int i = 0; i < n; i++) {
            BigDecimal amount = (i == n - 1) ? share.add(remainder) : share;
            result.put(splitData.get(i).userId(), amount);
        }
        return result;
    }

    @Override public SplitType supports() { return SplitType.EQUAL; }
}

// ── Exact Split ──────────────────────────────────────────────────────────────

@Component
public class ExactSplitStrategy implements SplitStrategy {

    @Override
    public void validate(BigDecimal totalAmount, List<SplitData> splitData) {
        BigDecimal sum = splitData.stream()
            .map(SplitData::exactAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (sum.compareTo(totalAmount) != 0)
            throw new InvalidSplitException(
                "Exact amounts must sum to total. Got: " + sum + ", expected: " + totalAmount);
    }

    @Override
    public Map<Long, BigDecimal> compute(BigDecimal totalAmount, List<SplitData> splitData) {
        return splitData.stream()
            .collect(Collectors.toMap(SplitData::userId, SplitData::exactAmount,
                (a, b) -> a, LinkedHashMap::new));
    }

    @Override public SplitType supports() { return SplitType.EXACT; }
}

// ── Percentage Split ─────────────────────────────────────────────────────────

@Component
public class PercentageSplitStrategy implements SplitStrategy {
    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);

    @Override
    public void validate(BigDecimal totalAmount, List<SplitData> splitData) {
        BigDecimal totalPct = splitData.stream()
            .map(SplitData::percentage)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (totalPct.compareTo(HUNDRED) != 0)
            throw new InvalidSplitException(
                "Percentages must sum to 100. Got: " + totalPct);
    }

    @Override
    public Map<Long, BigDecimal> compute(BigDecimal totalAmount, List<SplitData> splitData) {
        Map<Long, BigDecimal> result = new LinkedHashMap<>();
        List<SplitData> sorted = new ArrayList<>(splitData);

        BigDecimal assigned = BigDecimal.ZERO;
        for (int i = 0; i < sorted.size() - 1; i++) {
            SplitData sd = sorted.get(i);
            BigDecimal amount = totalAmount
                .multiply(sd.percentage())
                .divide(HUNDRED, 2, RoundingMode.HALF_UP);
            result.put(sd.userId(), amount);
            assigned = assigned.add(amount);
        }
        // Last person absorbs rounding residue
        SplitData last = sorted.get(sorted.size() - 1);
        result.put(last.userId(), totalAmount.subtract(assigned));
        return result;
    }

    @Override public SplitType supports() { return SplitType.PERCENTAGE; }
}

// ── Shares Split ─────────────────────────────────────────────────────────────

@Component
public class SharesSplitStrategy implements SplitStrategy {

    @Override
    public void validate(BigDecimal totalAmount, List<SplitData> splitData) {
        int totalShares = splitData.stream().mapToInt(SplitData::shares).sum();
        if (totalShares <= 0)
            throw new InvalidSplitException("Total shares must be positive");
    }

    @Override
    public Map<Long, BigDecimal> compute(BigDecimal totalAmount, List<SplitData> splitData) {
        int totalShares = splitData.stream().mapToInt(SplitData::shares).sum();
        Map<Long, BigDecimal> result = new LinkedHashMap<>();
        BigDecimal assigned = BigDecimal.ZERO;

        for (int i = 0; i < splitData.size() - 1; i++) {
            SplitData sd = splitData.get(i);
            BigDecimal amount = totalAmount
                .multiply(BigDecimal.valueOf(sd.shares()))
                .divide(BigDecimal.valueOf(totalShares), 2, RoundingMode.HALF_UP);
            result.put(sd.userId(), amount);
            assigned = assigned.add(amount);
        }
        SplitData last = splitData.get(splitData.size() - 1);
        result.put(last.userId(), totalAmount.subtract(assigned));
        return result;
    }

    @Override public SplitType supports() { return SplitType.SHARES; }
}

// ── Split data carrier ───────────────────────────────────────────────────────

public record SplitData(
    Long userId,
    BigDecimal exactAmount,     // used by EXACT
    BigDecimal percentage,      // used by PERCENTAGE
    int shares                  // used by SHARES
) {
    // Convenience factories
    public static SplitData forEqual(Long userId) {
        return new SplitData(userId, null, null, 0);
    }
    public static SplitData forExact(Long userId, BigDecimal amount) {
        return new SplitData(userId, amount, null, 0);
    }
    public static SplitData forPercentage(Long userId, BigDecimal pct) {
        return new SplitData(userId, null, pct, 0);
    }
    public static SplitData forShares(Long userId, int shares) {
        return new SplitData(userId, null, null, shares);
    }
}
```

#### Template Method Pattern — Expense Processing Pipeline

```java
/**
 * Defines the invariant skeleton for processing any expense.
 * Subclasses only override the steps that differ.
 */
public abstract class ExpenseProcessor {

    // Template method — defines the algorithm skeleton
    public final Expense processExpense(ExpenseRequest request) {
        validateRequest(request);                         // Step 1: validate
        Map<Long, BigDecimal> amounts = calculateSplits(request);  // Step 2: calculate
        Expense expense = persistExpense(request, amounts);       // Step 3: persist
        updateBalances(expense);                          // Step 4: update balances
        notifyParticipants(expense);                      // Step 5: notify
        return expense;
    }

    protected abstract void validateRequest(ExpenseRequest request);
    protected abstract Map<Long, BigDecimal> calculateSplits(ExpenseRequest request);

    // Default implementations for common steps
    protected Expense persistExpense(ExpenseRequest req, Map<Long, BigDecimal> amounts) {
        // default persistence logic — subclasses can override
        throw new UnsupportedOperationException("Must be implemented");
    }

    protected void updateBalances(Expense expense) {
        // default: no-op (balances computed on-the-fly)
    }

    protected void notifyParticipants(Expense expense) {
        // default: send push notifications — subclasses can suppress
    }
}

@Service
public class StandardExpenseProcessor extends ExpenseProcessor {

    private final Map<SplitType, SplitStrategy> strategies;
    private final ExpenseRepository expenseRepo;
    private final UserRepository userRepo;

    public StandardExpenseProcessor(List<SplitStrategy> strategyList,
                                    ExpenseRepository expenseRepo,
                                    UserRepository userRepo) {
        this.strategies  = strategyList.stream()
            .collect(Collectors.toMap(SplitStrategy::supports, s -> s));
        this.expenseRepo = expenseRepo;
        this.userRepo    = userRepo;
    }

    @Override
    protected void validateRequest(ExpenseRequest request) {
        if (request.totalAmount().compareTo(BigDecimal.ZERO) <= 0)
            throw new InvalidRequestException("Amount must be positive");
        if (request.splitData().isEmpty())
            throw new InvalidRequestException("At least one participant required");
    }

    @Override
    protected Map<Long, BigDecimal> calculateSplits(ExpenseRequest request) {
        SplitStrategy strategy = strategies.get(request.splitType());
        if (strategy == null)
            throw new InvalidRequestException("Unknown split type: " + request.splitType());
        strategy.validate(request.totalAmount(), request.splitData());
        return strategy.compute(request.totalAmount(), request.splitData());
    }

    @Override
    @Transactional
    protected Expense persistExpense(ExpenseRequest req, Map<Long, BigDecimal> amounts) {
        User paidBy = userRepo.findById(req.paidByUserId())
            .orElseThrow(() -> new NotFoundException("User not found"));

        Expense expense = new Expense();
        expense.setDescription(req.description());
        expense.setTotalAmount(req.totalAmount());
        expense.setPaidBy(paidBy);
        expense.setSplitType(req.splitType());
        expense.setCreatedAt(LocalDateTime.now());

        List<ExpenseSplit> splits = amounts.entrySet().stream().map(e -> {
            User participant = userRepo.getReferenceById(e.getKey());
            ExpenseSplit split = new ExpenseSplit();
            split.setExpense(expense);
            split.setUser(participant);
            split.setAmountOwed(e.getValue());
            return split;
        }).toList();

        expense.setSplits(splits);
        return expenseRepo.save(expense);
    }
}
```

---

### 5.5 Balance Service

```java
@Service
public class BalanceService {

    private final ExpenseRepository expenseRepo;
    private final TransactionRepository transactionRepo;
    private final BalanceSimplifier simplifier;

    public BalanceService(ExpenseRepository expenseRepo,
                          TransactionRepository transactionRepo,
                          BalanceSimplifier simplifier) {
        this.expenseRepo      = expenseRepo;
        this.transactionRepo  = transactionRepo;
        this.simplifier       = simplifier;
    }

    /**
     * Compute net balances for all members of a group.
     * Returns userId → net (positive = owed, negative = owes).
     */
    public Map<Long, BigDecimal> getGroupNetBalances(Long groupId) {
        Map<Long, BigDecimal> net = new HashMap<>();

        List<Expense> expenses = expenseRepo.findByGroupId(groupId);
        for (Expense expense : expenses) {
            Long payerId = expense.getPaidBy().getId();
            // Payer gets credited the full amount
            net.merge(payerId, expense.getTotalAmount(), BigDecimal::add);

            // Each participant is debited their share
            for (ExpenseSplit split : expense.getSplits()) {
                Long participantId = split.getUser().getId();
                net.merge(participantId, split.getAmountOwed().negate(), BigDecimal::add);
            }
        }

        // Apply already-completed settlement transactions
        List<Transaction> settlements = transactionRepo.findByGroupId(groupId);
        for (Transaction t : settlements) {
            net.merge(t.getFrom().getId(), t.getAmount().negate(), BigDecimal::add);
            net.merge(t.getTo().getId(),   t.getAmount(),          BigDecimal::add);
        }

        return net;
    }

    /**
     * Get the simplified settlement plan for a group.
     */
    public List<SettlementTransaction> getSimplifiedSettlement(Long groupId) {
        Map<Long, BigDecimal> netBalances = getGroupNetBalances(groupId);
        return simplifier.simplify(netBalances);
    }

    /**
     * Net balance between exactly two users (across all shared groups and direct expenses).
     */
    public BigDecimal getBalanceBetween(Long userAId, Long userBId) {
        // Positive → A is owed money by B
        // Negative → A owes money to B
        return expenseRepo.computeNetBalanceBetween(userAId, userBId);
    }
}
```

---

### 5.6 Key Interview Questions

**Q1: Walk me through the balance simplification algorithm.**

> **Answer:** Compute each user's net balance (sum of all amounts they're owed minus all amounts they owe). This gives a vector that sums to zero. Use two max-heaps — one for creditors (positive net) and one for debtors (absolute negative net). Greedily match the largest creditor with the largest debtor. The transfer amount is `min(credit, debt)`. The one that hits zero exits the heap; the remainder re-enters with the reduced balance. Continue until both heaps are empty. This produces O(N) transactions for N users, which is optimal. Time complexity: O(N log N).

**Q2: How do you handle floating point precision in financial calculations?**

> **Answer:** Always use `BigDecimal` with explicit scale (2 decimal places for currency) and `RoundingMode.HALF_UP`. Never use `double` or `float` for money. For rounding residues when splitting, assign the remainder to the last participant. Store amounts in the database as `DECIMAL(19,4)` columns, not `FLOAT`.

**Q3: How would you scale Splitwise to millions of groups?**

> **Answer:** (1) Partition expense data by groupId. (2) Precompute and cache net balances in Redis, invalidating on each new expense or settlement. (3) For the simplification algorithm, it runs per-group in-memory — O(N log N) for N members, which is fast even for groups of 50. (4) Use async event-driven updates: when an expense is added, publish a `GroupBalanceInvalidated` event that triggers cache eviction and optional WebSocket push to all group members.

**Q4: How do you implement the "you owe X to Y" notification?**

> **Answer:** After every expense, compare net balances before and after. Publish a `BalanceChangedEvent`. Listeners compute the human-readable delta ("Rahul added 'Dinner', and you owe ₹150 to Rahul") and send via push/email. Never block the expense creation on notification delivery — use `@Async` listeners.

---

## LLD 6: Elevator System

### 6.1 Requirements

**Functional Requirements**
- N elevators operating in a building with M floors
- External request: person on floor F presses UP or DOWN button
- Internal request: person inside elevator presses destination floor button
- Elevator moves to serve requests; doors open/close at target floor
- Elevators can be taken out of service (MAINTENANCE mode)

**Non-Functional Requirements**
- Minimize average wait time
- Fairness: no request starves indefinitely
- Support pluggable scheduling algorithms (FCFS, SCAN, LOOK)
- Thread-safe: multiple elevators operate concurrently

---

### 6.2 Core Entities

```
Building
  └── ElevatorController (1 per building) ← ExternalRequest (floor + direction)
         │ assigns to
         ▼
     Elevator (N instances)  ← InternalRequest (destination floor)
         │
    [ElevatorState: IDLE | MOVING_UP | MOVING_DOWN | MAINTENANCE]
         │
       Floor (M instances) — has UP button, DOWN button, Door indicator
```

---

### 6.3 Algorithms

| Algorithm | Description | Pros | Cons |
|-----------|-------------|------|------|
| **FCFS** | Serve requests in the order received | Simple to implement | High average wait time |
| **SCAN** | Move in one direction until end, then reverse | Fair to all floors | Floors near reversal point wait long |
| **LOOK** | Like SCAN but only goes as far as the last request | Better than SCAN | Slightly more complex |

**LOOK Algorithm (used in this implementation):**
- If moving UP: serve all pending floors above current floor in ascending order
- If moving DOWN: serve all pending floors below current floor in descending order
- When no more in current direction: switch direction (if requests exist) or become IDLE

---

### 6.4 Design Patterns Applied

#### State Pattern — Elevator States

```java
public enum ElevatorState { IDLE, MOVING_UP, MOVING_DOWN, MAINTENANCE }

/**
 * State interface — each concrete state encodes allowed transitions
 * and behaviour for that state.
 */
public interface ElevatorStateHandler {
    void handleInternalRequest(Elevator elevator, int floor);
    void moveToNextFloor(Elevator elevator);
    ElevatorState getState();
}
```

#### Strategy Pattern — Scheduling Algorithm

```java
public interface SchedulingStrategy {
    /**
     * Choose the best elevator from the available pool to serve an external request.
     */
    Elevator selectElevator(List<Elevator> elevators, ExternalRequest request);
}
```

#### Observer Pattern — Floor Button Events

```java
public record ExternalRequestEvent(int floor, Direction direction) {}

// Floor button press is an event; the ElevatorController is the observer
@Component
public class ElevatorController implements ApplicationListener<ExternalRequestEvent> {
    @Override
    public void onApplicationEvent(ExternalRequestEvent event) {
        dispatchRequest(event.floor(), event.direction());
    }
}
```

---

### 6.5 Complete Java 17 Implementation

```java
// ─────────────────────────────────────────────
// Enumerations
// ─────────────────────────────────────────────

public enum Direction { UP, DOWN, IDLE }
public enum ElevatorState { IDLE, MOVING_UP, MOVING_DOWN, MAINTENANCE }

// ─────────────────────────────────────────────
// Request types
// ─────────────────────────────────────────────

public record ExternalRequest(int floor, Direction direction) {}
public record InternalRequest(int destinationFloor) {}

// ─────────────────────────────────────────────
// Elevator — State machine with LOOK algorithm
// ─────────────────────────────────────────────

public class Elevator {
    private final int id;
    private volatile int currentFloor;
    private volatile ElevatorState state;

    /**
     * Pending destination floors stored in a sorted set for O(log N) insertion
     * and O(1) access to min/max (for LOOK algorithm direction decisions).
     */
    private final TreeSet<Integer> pendingFloors = new TreeSet<>();
    private final Object lock = new Object();

    public Elevator(int id, int initialFloor) {
        this.id           = id;
        this.currentFloor = initialFloor;
        this.state        = ElevatorState.IDLE;
    }

    /**
     * Add a destination floor (called for both internal and external requests).
     */
    public void addDestination(int floor) {
        synchronized (lock) {
            if (floor < 0) throw new IllegalArgumentException("Floor must be >= 0");
            pendingFloors.add(floor);
            if (state == ElevatorState.IDLE) {
                state = (floor >= currentFloor) ? ElevatorState.MOVING_UP
                                                : ElevatorState.MOVING_DOWN;
            }
            lock.notifyAll();
        }
    }

    /**
     * LOOK algorithm step — move one floor toward the next destination.
     * Called by the elevator's worker thread in a loop.
     */
    public void step() {
        synchronized (lock) {
            while (pendingFloors.isEmpty() && state != ElevatorState.MAINTENANCE) {
                state = ElevatorState.IDLE;
                try { lock.wait(); } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
            if (state == ElevatorState.MAINTENANCE || pendingFloors.isEmpty()) return;

            // LOOK: determine next floor to visit based on current direction
            Integer nextFloor = getNextFloorByLook();
            if (nextFloor == null) return;

            // Simulate movement (one floor per step)
            if (nextFloor > currentFloor) {
                currentFloor++;
                state = ElevatorState.MOVING_UP;
            } else if (nextFloor < currentFloor) {
                currentFloor--;
                state = ElevatorState.MOVING_DOWN;
            }

            // Arrived at destination
            if (currentFloor == nextFloor) {
                pendingFloors.remove(nextFloor);
                openDoors();   // simulate door open/close
                closeDoors();

                // Reassess direction after reaching a destination
                if (pendingFloors.isEmpty()) {
                    state = ElevatorState.IDLE;
                } else {
                    Integer higher = pendingFloors.ceiling(currentFloor);
                    Integer lower  = pendingFloors.floor(currentFloor);
                    if (state == ElevatorState.MOVING_UP && higher != null) {
                        // continue up
                    } else if (state == ElevatorState.MOVING_DOWN && lower != null) {
                        // continue down
                    } else {
                        // flip direction
                        state = (higher != null) ? ElevatorState.MOVING_UP
                                                 : ElevatorState.MOVING_DOWN;
                    }
                }
            }
        }
    }

    /**
     * LOOK: if moving up, pick smallest floor above current;
     *       if moving down, pick largest floor below current;
     *       if IDLE, pick closest floor.
     */
    private Integer getNextFloorByLook() {
        return switch (state) {
            case MOVING_UP -> {
                Integer above = pendingFloors.ceiling(currentFloor);
                yield (above != null) ? above : pendingFloors.last();  // reverse at top
            }
            case MOVING_DOWN -> {
                Integer below = pendingFloors.floor(currentFloor);
                yield (below != null) ? below : pendingFloors.first(); // reverse at bottom
            }
            default -> {   // IDLE: pick closest
                Integer above = pendingFloors.ceiling(currentFloor);
                Integer below = pendingFloors.floor(currentFloor);
                if (above == null) yield below;
                if (below == null) yield above;
                yield (above - currentFloor <= currentFloor - below) ? above : below;
            }
        };
    }

    private void openDoors() {
        System.out.printf("Elevator %d: doors OPEN at floor %d%n", id, currentFloor);
        try { Thread.sleep(2000); } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private void closeDoors() {
        System.out.printf("Elevator %d: doors CLOSED at floor %d%n", id, currentFloor);
    }

    public void setMaintenance(boolean on) {
        synchronized (lock) {
            state = on ? ElevatorState.MAINTENANCE : ElevatorState.IDLE;
            if (!on) lock.notifyAll();
        }
    }

    // ── Getters for controller ────────────────────────────────────────────
    public int getId()            { return id; }
    public int getCurrentFloor()  { return currentFloor; }
    public ElevatorState getState() { return state; }
    public boolean isAvailable()  { return state != ElevatorState.MAINTENANCE; }
    public int getPendingCount()  { synchronized (lock) { return pendingFloors.size(); } }
}

// ─────────────────────────────────────────────
// Scheduling Strategies
// ─────────────────────────────────────────────

/**
 * LOOK-based strategy: pick the available elevator that can serve
 * this request with the fewest additional stops (load-based).
 * Falls back to nearest-floor tie-break.
 */
@Component("LOOK")
public class LookSchedulingStrategy implements SchedulingStrategy {

    @Override
    public Elevator selectElevator(List<Elevator> elevators, ExternalRequest request) {
        return elevators.stream()
            .filter(Elevator::isAvailable)
            .min(Comparator
                .comparingInt(e -> scoringFunction(e, request)))
            .orElseThrow(() -> new NoElevatorAvailableException("All elevators in maintenance"));
    }

    /**
     * Lower score = better candidate.
     * Score = distance to requested floor + penalty if direction mismatch.
     */
    private int scoringFunction(Elevator e, ExternalRequest req) {
        int distance = Math.abs(e.getCurrentFloor() - req.floor());
        int directionPenalty = 0;

        if (e.getState() == ElevatorState.MOVING_UP && req.direction() == Direction.DOWN)
            directionPenalty = 10;
        if (e.getState() == ElevatorState.MOVING_DOWN && req.direction() == Direction.UP)
            directionPenalty = 10;

        return distance + directionPenalty + e.getPendingCount();
    }
}

@Component("FCFS")
public class FcfsSchedulingStrategy implements SchedulingStrategy {

    private final Queue<Long> requestQueue = new ConcurrentLinkedQueue<>();

    @Override
    public Elevator selectElevator(List<Elevator> elevators, ExternalRequest request) {
        // Simply pick the elevator with the fewest pending requests (round-robin on tie)
        return elevators.stream()
            .filter(Elevator::isAvailable)
            .min(Comparator.comparingInt(Elevator::getPendingCount))
            .orElseThrow(() -> new NoElevatorAvailableException("All elevators in maintenance"));
    }
}

// ─────────────────────────────────────────────
// Elevator Controller
// ─────────────────────────────────────────────

@Service
public class ElevatorController {

    private final List<Elevator> elevators;
    private final SchedulingStrategy schedulingStrategy;
    private final List<Thread> elevatorThreads = new ArrayList<>();

    public ElevatorController(
            @Value("${elevator.count:4}") int elevatorCount,
            @Value("${elevator.floors:20}") int floors,
            @Qualifier("LOOK") SchedulingStrategy schedulingStrategy) {
        this.schedulingStrategy = schedulingStrategy;
        this.elevators = new ArrayList<>();

        for (int i = 0; i < elevatorCount; i++) {
            Elevator elevator = new Elevator(i + 1, 0);
            elevators.add(elevator);

            // Each elevator runs its step() loop in a dedicated thread
            Thread t = Thread.ofVirtual()   // Java 21 virtual thread; use new Thread() for Java 17
                .name("elevator-" + (i + 1))
                .start(() -> {
                    while (!Thread.currentThread().isInterrupted()) {
                        elevator.step();
                    }
                });
            elevatorThreads.add(t);
        }
    }

    /**
     * Called when a person on a floor presses the UP or DOWN button.
     */
    public void handleExternalRequest(int floor, Direction direction) {
        ExternalRequest request = new ExternalRequest(floor, direction);
        Elevator chosen = schedulingStrategy.selectElevator(elevators, request);
        chosen.addDestination(floor);
        System.out.printf("Dispatched elevator %d to floor %d (%s)%n",
            chosen.getId(), floor, direction);
    }

    /**
     * Called when a person inside an elevator presses a floor button.
     */
    public void handleInternalRequest(int elevatorId, int destinationFloor) {
        Elevator elevator = elevators.stream()
            .filter(e -> e.getId() == elevatorId)
            .findFirst()
            .orElseThrow(() -> new NotFoundException("Elevator not found: " + elevatorId));

        if (elevator.getState() == ElevatorState.MAINTENANCE)
            throw new InvalidRequestException("Elevator " + elevatorId + " is in maintenance");

        elevator.addDestination(destinationFloor);
        System.out.printf("Elevator %d: internal request for floor %d%n",
            elevatorId, destinationFloor);
    }

    /**
     * Take an elevator in/out of maintenance.
     */
    public void setMaintenance(int elevatorId, boolean on) {
        elevators.stream()
            .filter(e -> e.getId() == elevatorId)
            .findFirst()
            .ifPresent(e -> e.setMaintenance(on));
    }

    public List<ElevatorStatus> getStatus() {
        return elevators.stream()
            .map(e -> new ElevatorStatus(e.getId(), e.getCurrentFloor(),
                                         e.getState(), e.getPendingCount()))
            .toList();
    }
}

public record ElevatorStatus(int id, int floor, ElevatorState state, int pendingRequests) {}

// ─────────────────────────────────────────────
// REST API
// ─────────────────────────────────────────────

@RestController
@RequestMapping("/api/v1/elevator")
public class ElevatorController_REST {

    private final ElevatorController controller;

    public ElevatorController_REST(ElevatorController controller) {
        this.controller = controller;
    }

    @PostMapping("/external")
    public ResponseEntity<String> externalRequest(
            @RequestParam int floor,
            @RequestParam Direction direction) {
        controller.handleExternalRequest(floor, direction);
        return ResponseEntity.ok("Request dispatched");
    }

    @PostMapping("/{elevatorId}/internal")
    public ResponseEntity<String> internalRequest(
            @PathVariable int elevatorId,
            @RequestParam int floor) {
        controller.handleInternalRequest(elevatorId, floor);
        return ResponseEntity.ok("Floor " + floor + " added to queue");
    }

    @PutMapping("/{elevatorId}/maintenance")
    public ResponseEntity<String> setMaintenance(
            @PathVariable int elevatorId,
            @RequestParam boolean on) {
        controller.setMaintenance(elevatorId, on);
        return ResponseEntity.ok("Elevator " + elevatorId +
            (on ? " in MAINTENANCE" : " back in SERVICE"));
    }

    @GetMapping("/status")
    public ResponseEntity<List<ElevatorStatus>> status() {
        return ResponseEntity.ok(controller.getStatus());
    }
}

// ─────────────────────────────────────────────
// Spring Boot Application Entry Point
// ─────────────────────────────────────────────

@SpringBootApplication
public class ElevatorSystemApplication {
    public static void main(String[] args) {
        SpringApplication.run(ElevatorSystemApplication.class, args);
    }
}
```

---

### 6.6 State Transition Diagram

```
         addDestination(above)              addDestination(below)
IDLE ─────────────────────────> MOVING_UP ──────────────────────> MOVING_DOWN
 ^                                  │   ^                               │
 │         no pending floors        │   │  still floors above           │
 └────────────────────────────────  │   └───────────────────────────────┘
                                    │
              setMaintenance(true)  │
                 ┌──────────────────┘
                 ▼
           MAINTENANCE
                 │  setMaintenance(false)
                 └──────────────────────> IDLE
```

---

### 6.7 Key Interview Questions

**Q1: Explain the LOOK algorithm and why it is better than SCAN.**

> **Answer:** SCAN moves the elevator from bottom to top and back, like a typewriter head — it reverses only at the absolute top/bottom floor. LOOK is smarter: it reverses as soon as there are no more requests in the current direction, not at the building boundary. This reduces unnecessary travel when requests cluster in the middle floors. Average wait time is lower for LOOK.

**Q2: How do you handle concurrent requests thread-safely?**

> **Answer:** Each `Elevator` has an internal `Object lock` (monitor). The `pendingFloors` `TreeSet` is only mutated inside `synchronized(lock)` blocks. The `step()` method calls `lock.wait()` when idle and `lock.notifyAll()` is called in `addDestination()` to wake the sleeping elevator thread. For the controller's dispatch decision, `schedulingStrategy.selectElevator()` reads elevator state but does not mutate it — it's a read-only scoring function, so it only needs the elevator's volatile fields to be visible (handled by `volatile` keyword on `currentFloor` and `state`).

**Q3: How would you modify the system to minimize wait time further?**

> **Answer:** (1) **Destination dispatch** — show passengers a keypad in the lobby, assign elevator before they board (like modern KONE/Schindler systems). This groups passengers going to nearby floors into one elevator. (2) **Predictive scheduling** — use historical data (morning rush: most people going up from floor 1; evening rush: going down). (3) **Express elevators** — in a skyscraper, designate some elevators to serve only floors 1–20, others 21–40 etc., reducing average travel distance.

**Q4: How does the State pattern help here?**

> **Answer:** The State pattern makes state-specific behavior explicit and prevents invalid transitions. For example, `addDestination()` on a `MAINTENANCE` elevator should throw an exception — rather than scattering `if (state == MAINTENANCE)` checks everywhere, each concrete state handler encapsulates its own behavior. Adding a new state (e.g., `DOOR_OPEN`) only requires a new class, not modifying all existing logic (Open/Closed Principle).

---

## Cheat Sheet: LLD Interview Quick Reference

### LLD Interview Approach Checklist

Follow this step-by-step process in every LLD interview:

```
Step 1 — REQUIREMENTS (5 min)
  □ Ask clarifying questions: scale, users, edge cases
  □ Separate functional requirements from NFRs
  □ Confirm: "I'll focus on [core flow], we can extend later"

Step 2 — ENTITIES (5 min)
  □ Identify the nouns in requirements → candidates for classes
  □ Define attributes for each entity
  □ Identify relationships: has-a, is-a, many-to-many
  □ Draw ER diagram on whiteboard

Step 3 — CLASS RELATIONSHIPS (5 min)
  □ Composition vs. Aggregation vs. Association
  □ Inheritance hierarchy (prefer composition)
  □ Define interfaces for key abstractions

Step 4 — DESIGN PATTERNS (5 min)
  □ Is there a family of algorithms? → Strategy
  □ Are there state transitions? → State
  □ One-to-many notifications? → Observer
  □ Object creation logic? → Factory / Builder
  □ Wrapping with extra behavior? → Decorator
  □ Incompatible interfaces? → Adapter

Step 5 — CODE KEY CLASSES (15 min)
  □ Write the most important entity class with fields
  □ Write the interface for the key abstraction
  □ Write the core service method (booking, expense, dispatch)
  □ Handle the key challenge (concurrency, algorithm, state machine)

Step 6 — DISCUSS TRADE-OFFS (5 min)
  □ What would break at 10x scale?
  □ What would you cache? (Redis)
  □ What would you make async? (messaging queue)
  □ What would you index differently in the DB?
```

---

### Common Design Patterns in LLD

| Pattern | Intent | Used In (this handbook) |
|---------|--------|------------------------|
| **Strategy** | Swap algorithms at runtime | Payment methods, Split types, Scheduling algorithms |
| **Observer** | One-to-many event notification | Booking notifications, Floor button events, Balance updates |
| **State** | Object behaviour varies by state | Elevator states (IDLE/MOVING/MAINTENANCE) |
| **Factory / Factory Method** | Decouple object creation | Notification channels, Split strategy lookup |
| **Builder** | Construct complex objects step by step | Query builders, Request objects |
| **Singleton** | One instance per JVM | Spring `@Service` beans (default scope) |
| **Decorator** | Add behaviour without inheritance | Logging wrappers, Retry decorators |
| **Template Method** | Invariant algorithm skeleton, variable steps | Expense processing pipeline |
| **Adapter** | Make incompatible interfaces work together | Third-party payment gateway adapters |
| **Proxy** | Lazy loading, access control, caching | JPA lazy relationships, Spring AOP |
| **Command** | Encapsulate a request as an object | Undo/redo, request queuing |
| **Repository** | Decouple domain from data access | Spring Data JPA repositories |

---

### LLD Designs Quick Reference

| Design | Key Entities | Key Patterns | Key Challenge |
|--------|-------------|--------------|---------------|
| **Parking Lot** | ParkingLot, Level, Spot (Compact/Large/Handicapped), Vehicle, Ticket, Payment | Strategy (fee), Factory (vehicle type), Observer (spot availability) | Thread-safe spot allocation |
| **Library Management** | Book, BookItem, Member, Librarian, Reservation, Fine, BookLending | Observer (reservation), Strategy (fine calculation) | Multiple copies, reservation queue |
| **BookMyShow** | Movie, Theatre, Screen, Show, ShowSeat, Booking, Payment, User | Observer (notifications), Strategy (payment), Factory (notification channel) | Concurrent seat booking — `@Version` optimistic lock |
| **Splitwise** | User, Group, Expense, ExpenseSplit, Balance, Transaction | Strategy (split type), Template Method (expense pipeline) | Balance simplification — greedy 2-heap O(N log N) |
| **Elevator System** | Elevator, ElevatorController, Floor, Request (internal/external) | State (elevator states), Strategy (scheduling), Observer (floor button) | LOOK algorithm, thread-safe step() with `synchronized` |
| **Ride Sharing (Uber)** | Driver, Rider, Trip, Vehicle, Location, Pricing, Rating | Strategy (pricing surge), Observer (location updates), State (trip states) | Geo-spatial driver matching |
| **ATM** | ATM, Card, Account, Transaction, CashDispenser, Receipt | State (ATM states), Chain of Responsibility (auth steps), Command (transactions) | Transaction atomicity, hardware failure |
| **Chess / Tic-Tac-Toe** | Board, Piece (subclasses), Player, Game, Move | Strategy (AI player), State (game states), Command (move history/undo) | Move validation, win detection |

---

### Key Concurrency Patterns for LLD Interviews

```java
// 1. Optimistic Locking (low contention — best default)
@Version private Long version;  // JPA handles conflict detection

// 2. Pessimistic Locking (high contention — flash sale, limited inventory)
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("SELECT s FROM ShowSeat s WHERE s.id = :id")
ShowSeat findByIdForUpdate(@Param("id") Long id);

// 3. synchronized block (single JVM — elevators, in-memory state machines)
synchronized (lock) { pendingFloors.add(floor); lock.notifyAll(); }

// 4. ConcurrentHashMap (high-concurrency reads, low-contention writes)
private final Map<Long, BigDecimal> balanceCache = new ConcurrentHashMap<>();

// 5. Atomic operations (counters, flags)
private final AtomicInteger availableSpots = new AtomicInteger(capacity);
availableSpots.decrementAndGet();  // thread-safe
```

---

## Quick Revision — LLD Case Studies

### Parking Lot
- **Key entities:** ParkingLot (Singleton), ParkingFloor, ParkingSpot (Compact/Large/Handicapped/Motorcycle), Vehicle (Car/Truck/Motorcycle/Electric), Ticket, Payment
- **Patterns:** Singleton (one lot), Factory (vehicle creation), Strategy (fee: hourly/flat/EV), Observer (display board updates)
- **Key challenge:** Thread-safe spot allocation — use `synchronized` on `findAvailableSpot()` or optimistic CAS
- **Fee calculation:** Strategy pattern allows adding new fee types without changing ParkingLot

### URL Shortener
- **Key entities:** ShortUrl (id, originalUrl, shortCode, expiresAt, createdBy), ClickAnalytics
- **Core algorithm:** Base62 encoding — 62^6 = 56.8 billion unique codes; use Redis INCR for counter-based ID generation
- **301 vs 302:** 301 (permanent, browser caches — saves server load); 302 (temporary, every request hits server — enables analytics)
- **Patterns:** Strategy (ID gen: counter vs random vs hash), Facade (UrlShortenerService), @Cacheable on redirect

### Rate Limiter
- **Algorithms:** Token Bucket (allows burst), Leaky Bucket (smooth output), Fixed Window (simple but boundary attack), Sliding Window Log (accurate, memory heavy), Sliding Window Counter (hybrid — accurate + efficient)
- **Distributed:** Lua script on Redis for atomic token check + decrement
- **Pattern:** Strategy (algorithm), Decorator (OncePerRequestFilter wraps any endpoint)
- **Headers:** X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset, Retry-After (429)

### BookMyShow
- **Key entities:** Show, ShowSeat (@Version for optimistic lock), Booking (states: PENDING/CONFIRMED/CANCELLED), Payment
- **Concurrency:** `@Version` on ShowSeat — SELECT + UPDATE WHERE version=? — throws OptimisticLockException on conflict → retry or show "seat taken"
- **Patterns:** Observer (booking confirmation → email/SMS via Spring Events), Strategy (payment methods), Factory (notification channels)
- **Seat lock expiry:** @Scheduled job to release PENDING bookings older than 10 minutes

### Splitwise
- **Split types:** EqualSplit (amount/n), ExactSplit (explicit amounts), PercentageSplit (%, must sum to 100), ShareSplit (proportional)
- **Balance simplification:** Net balance per user → max-heap for creditors, min-heap for debtors → greedy O(N log N) minimizes transactions
- **Pattern:** Strategy (split calculation), Template Method (ExpenseProcessor skeleton)
- **Key invariant:** Sum of all splits must equal total expense amount (validated in `validate()`)

### Elevator
- **States:** IDLE, MOVING_UP, MOVING_DOWN, MAINTENANCE — State pattern FSM
- **LOOK algorithm:** Move in current direction, serve all requests in that direction, then reverse — O(1) per step
- **Data structure:** `TreeSet<Integer> pendingFloors` for O(log N) next-floor lookup with `higher()`/`lower()`
- **Coordination:** ElevatorController assigns external requests to closest available elevator (min distance + direction penalty)

### LLD Interview Approach (6 steps)
1. **Clarify requirements** — functional (what it does) + non-functional (scale, latency, consistency)
2. **Identify core entities** — nouns in requirements = classes; verbs = methods
3. **Define relationships** — has-a (composition/aggregation) vs is-a (inheritance)
4. **Apply design patterns** — identify which patterns solve the key challenges
5. **Write the code** — start with interfaces/enums, then core classes, then service layer
6. **Discuss trade-offs** — thread safety, extensibility, scalability

---

*End of Chapter 21 — LLD Case Studies | Volume 5: System Design & LLD*

> **Next:** Chapter 22 — System Design Deep Dives (URL Shortener, Rate Limiter, Distributed Cache)



