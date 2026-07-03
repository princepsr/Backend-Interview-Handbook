# Volume 3: Backend Systems
# Chapter 13: Security

---

## Table of Contents

1. Authentication vs Authorization
2. JWT Structure and Signing
3. JWT Validation
4. OAuth2 Roles and Overview
5. OAuth2 Grant Types
6. OpenID Connect (OIDC)
7. Spring Security Architecture
8. Spring Security JWT Integration
9. Spring Security OAuth2 Resource Server
10. Password Storage
11. HTTPS and TLS
12. CORS
13. CSRF
14. OWASP Top 10 for APIs
15. Secrets Management

---

> **How to read this chapter:** Each topic has three layers.
> - **The Idea** — start here, no prior knowledge needed.
> - **How It Works** — the real mechanism, patterns, and tradeoffs.
> - **Interview Lens** — what interviewers actually probe.
>
> Beginners: read all three layers top to bottom.
> SDE2/Senior: skim "The Idea", focus on "How It Works" and "Interview Lens".

---

## Topic 1: Authentication vs Authorization

---

#### The Idea

Imagine you arrive at an office building. The security guard at the front desk checks your photo ID and confirms you are who you claim to be — that is **authentication**. Once inside, you badge into your floor but find the server room door locked because only the IT team can enter — that is **authorization**. Authentication answers "Who are you?" Authorization answers "What are you allowed to do?"

These two concerns are always distinct, even though they work together. A system that skips authentication has no idea who it is talking to. A system that skips authorization lets any authenticated user do anything — including deleting production data. Both must be enforced, and in that order: you cannot enforce permissions for someone whose identity you have not verified.

A third concept sometimes appears in interviews: **accounting** (also called auditing). This is the logging of who did what and when. Together, Authentication + Authorization + Accounting form the **AAA model** used in enterprise security and network protocols (like RADIUS). Most backend interview questions focus on the first two, but knowing AAA shows breadth.

---

#### How It Works

```
Request arrives
  → Authentication: verify identity
      OPTIONS: session cookie, JWT Bearer token, API key, mTLS certificate
      RESULT: principal (who) + credentials (proof)

  → Authorization: enforce permissions
      OPTIONS: RBAC (Role-Based), ABAC (Attribute-Based), ACL (Access Control List)
      INPUT: principal + requested resource + action
      RESULT: PERMIT or DENY

  → If DENY → 403 Forbidden (not 401 — that means unauthenticated)
  → If authentication fails → 401 Unauthorized
```

The most common interview gotcha is confusing HTTP status codes: **401 Unauthorized** actually means "not authenticated" (misleading name — you need to log in). **403 Forbidden** means "authenticated but not permitted." Getting these backwards in an interview is a red flag.

```
HTTP Status Codes:
  401 Unauthorized  → identity not established (authenticate first)
  403 Forbidden     → identity known, permission denied
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between authentication and authorization?"**

**One-line answer:** Authentication verifies identity; authorization determines what that identity is permitted to do.

**Full answer to give in an interview:**

> "Authentication is the process of verifying that a caller is who they claim to be — for example, validating a username and password, checking a JWT signature, or verifying a client certificate. Authorization is a separate step that runs after authentication and asks: given that I know who this caller is, are they allowed to perform this specific action on this specific resource? A user might authenticate successfully but still be denied access to an admin endpoint because they lack the required role. In HTTP, the distinction maps to status codes: a 401 means the request is missing or has invalid credentials — authentication failed. A 403 means credentials are valid but the caller lacks permission — authorization failed. Conflating these two leads to security bugs, like returning 403 when you should return 401 and revealing that a resource exists to unauthenticated callers."

> *Deliver this crisply. The 401 vs 403 detail signals that you have built real APIs.*

**Gotcha follow-up they'll ask:** *"What does the AAA model add on top of authentication and authorization?"*

> "AAA stands for Authentication, Authorization, and Accounting. Accounting — sometimes called auditing — is the logging of who performed which action and when. In practice this means writing an immutable audit trail so you can answer questions like 'who deleted this record?' after the fact. It is important for compliance (SOX, HIPAA, GDPR) and for security incident investigation. Many teams implement it as a cross-cutting concern via a filter or interceptor that writes to an append-only audit log."

---

##### Q2 — Tradeoff Question
**"When would you use role-based access control (RBAC) versus attribute-based access control (ABAC)?"**

**One-line answer:** RBAC is simple and works well when permissions map cleanly to job roles; ABAC is more expressive and handles fine-grained policies based on user attributes, resource attributes, and environment context.

**Full answer to give in an interview:**

> "RBAC — Role-Based Access Control — assigns permissions to roles and then assigns roles to users. For example, a USER role can read their own profile; an ADMIN role can read all profiles and delete accounts. It is easy to reason about and implement, and covers the majority of enterprise use cases. The downside is that it becomes unwieldy when permissions need to vary based on context — for example, 'a user can edit a document only if they are the document owner AND the document is in DRAFT state AND they are accessing from within the corporate network.' That kind of policy requires ABAC — Attribute-Based Access Control — which evaluates rules against attributes of the subject (user), resource (document), and environment (network, time). ABAC is more powerful but harder to audit and debug. In practice, most systems start with RBAC and add ABAC-style checks for specific resources where the logic demands it."

> *This answer shows you understand the engineering tradeoff, not just the definitions.*

**Gotcha follow-up they'll ask:** *"How does Spring Security implement authorization?"*

> "Spring Security uses the `@PreAuthorize` annotation or the `authorizeHttpRequests` DSL in the security filter chain. The DSL approach lets you write rules like `.requestMatchers('/api/admin/**').hasRole('ADMIN')`, which maps incoming request paths to required roles. The `@PreAuthorize` annotation on individual methods allows expression-based rules like `@PreAuthorize('hasRole(\"ADMIN\") or #userId == authentication.name')`, which is closer to ABAC. Under the hood, Spring Security resolves the authenticated principal from the `SecurityContext`, which is populated by a filter earlier in the chain."

---

> **Common Mistake — Returning 403 for unauthenticated requests:** Returning 403 Forbidden when a user is not logged in reveals that the resource exists, which can be a security leak. Always return 401 when credentials are absent or invalid, and 403 only when the identity is confirmed but the permission is denied.

---

**Quick Revision (one line):**
Authentication proves identity (401 if it fails); authorization enforces permissions (403 if denied); AAA adds accounting for audit trails.

---

## Topic 2: JWT Structure and Signing

---

#### The Idea

Think of a JWT — a JSON Web Token — as a tamper-evident sealed envelope. When you sign a letter and put it in an envelope with a wax seal, anyone can read the letter (the envelope is transparent in JWT's case), but they cannot change the contents without breaking the seal. The recipient checks the seal to confirm the letter has not been altered and genuinely came from you.

A JWT does the same thing digitally. The server creates a token containing claims — statements about the user, like their user ID and roles — and signs it with a secret key. Every time the client sends that token back, any server with the corresponding key can verify the signature in microseconds, without asking a central database whether the token is still valid. This is why JWTs are popular for stateless, distributed systems.

The security model depends entirely on the signature. The payload of a JWT is only Base64URL-encoded, not encrypted — anyone can decode and read it. Never put sensitive information (passwords, PII beyond what is needed) in a JWT payload unless you are using JWE (JSON Web Encryption), which adds actual encryption on top.

---

#### How It Works

A JWT is three Base64URL-encoded segments joined by dots:

```
header.payload.signature

header:    {"alg": "RS256", "typ": "JWT"}
payload:   {"sub": "user-123", "roles": ["USER"], "iss": "auth.example.com", "exp": 1720000000, "aud": "api.example.com"}
signature: RSA_SHA256(base64url(header) + "." + base64url(payload), privateKey)
```

**Two signing algorithms matter in interviews:**

```
HS256 (HMAC-SHA256):
  - Symmetric: same secret key signs AND verifies
  - Problem: every service that verifies tokens must know the secret
  - Use case: single-service apps or when all services are fully trusted

RS256 (RSA-SHA256):
  - Asymmetric: auth server signs with PRIVATE key
  - Any service verifies with PUBLIC key (fetched from JWKS endpoint)
  - Public key can be shared freely — no secret exposure
  - Use case: microservices, multi-tenant systems, third-party integrations
```

The must-memorise gotcha for JWT in microservices: use RS256, publish the public key at a JWKS (JSON Web Key Set) endpoint, and have each service fetch and cache it. No service ever sees the private key.

```java
// Spring Boot: configure JWT resource server to fetch public keys automatically
// application.yml:
//   spring.security.oauth2.resourceserver.jwt.jwk-set-uri: https://auth.example.com/.well-known/jwks.json

@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
        .oauth2ResourceServer(oauth2 -> oauth2
            .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthConverter()))
        );
    return http.build();
}
```

Spring auto-fetches the JWKS, caches the public keys, and validates every incoming Bearer token — you do not write the cryptographic code yourself.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Describe the structure of a JWT. What does each part contain?"**

**One-line answer:** A JWT is three Base64URL-encoded sections — header, payload, signature — joined by dots, where the signature cryptographically binds the other two.

**Full answer to give in an interview:**

> "A JWT has three parts separated by dots: header dot payload dot signature. The header is a small JSON object that declares the token type — always 'JWT' — and the signing algorithm, such as RS256 or HS256. The payload is a JSON object containing claims — standard ones like 'sub' for the subject (user ID), 'iss' for the issuer (who created the token), 'exp' for expiry (a Unix timestamp), and 'aud' for audience (which service this token is intended for), plus any custom claims like roles. Both header and payload are only Base64URL-encoded, not encrypted, so anyone can decode and read them. The third part is the signature, computed by taking the Base64URL header plus a dot plus the Base64URL payload and running that string through the signing algorithm with the server's key. This signature is what makes the token tamper-evident: if any bit of the header or payload changes, the signature verification fails."

> *Emphasise that Base64URL is encoding, not encryption — this is a common trap interviewers set.*

**Gotcha follow-up they'll ask:** *"Why would you choose RS256 over HS256 for a microservices architecture?"*

> "HS256 uses a single shared secret for both signing and verifying. In a microservices environment, that means every service that needs to verify tokens must know the secret. If any one service is compromised, the secret is leaked and an attacker can forge tokens for the entire system. RS256 uses an asymmetric key pair: the auth server signs tokens with its private key, which it never shares. Each microservice verifies tokens using the corresponding public key, which can be published openly at a JWKS endpoint. A compromised microservice leaks only the public key — which was already public — and cannot be used to forge new tokens. This is the key security advantage of asymmetric signing in distributed systems."

---

##### Q2 — Design Scenario
**"How would you implement JWT-based authentication across 10 microservices?"**

**One-line answer:** Use a central auth service that signs JWTs with RS256, publishes its public keys at a JWKS endpoint, and have each service validate tokens independently by fetching and caching those keys.

**Full answer to give in an interview:**

> "I would set up a dedicated auth service responsible for issuing tokens. It holds the RSA private key, which never leaves that service. When a user authenticates, the auth service issues a JWT signed with RS256, containing claims like user ID, roles, issuer, audience, and expiry. Each of the 10 microservices is configured as an OAuth2 resource server pointing to the auth service's JWKS endpoint — for example, `https://auth.example.com/.well-known/jwks.json`. On startup, each service fetches and caches the public key. When a request arrives with a Bearer token, the service validates the signature locally using the cached public key, checks expiry and issuer, and grants or denies access. This is fully stateless — no inter-service call is needed for each request. The only coordination is the initial key fetch, which most frameworks like Spring Security do automatically. For key rotation, the JWKS endpoint publishes multiple keys simultaneously so old tokens keep working during the rollover window."

> *This answer demonstrates you understand the full operational picture, not just the JWT spec.*

**Gotcha follow-up they'll ask:** *"What is in the JWKS endpoint response?"*

> "JWKS stands for JSON Web Key Set. The endpoint returns a JSON object with a 'keys' array, where each entry is a JSON Web Key representing one public key. Each key includes the key type (kty, e.g. RSA), the algorithm (alg), the key use (use: sig for signing), a key ID (kid) that matches the kid in the JWT header for efficient lookup, and the key material itself — for RSA, the modulus (n) and public exponent (e). Services cache these keys and use the kid to find the right key when validating a specific token."

---

> **Common Mistake — Treating Base64URL as encryption:** JWT payloads are readable by anyone. Never store passwords, private keys, or sensitive personal data in a JWT payload without using JWE (JSON Web Encryption). A developer who encodes sensitive data in a JWT and calls it "secure" is making a serious mistake.

---

**Quick Revision (one line):**
A JWT is header.payload.signature; use RS256 (asymmetric) over HS256 (symmetric) in microservices so services can verify tokens with a public key without ever seeing the signing secret.

---

## Topic 3: JWT Validation

---

#### The Idea

Receiving a JWT is like receiving a signed cheque. Before you accept it, you run through a mental checklist: Is the signature genuine? Is the cheque still in date? Is it made out to the right person (you)? Is the amount reasonable? If any check fails, you reject it — even if one part looks fine. In security, partial validation is as dangerous as no validation.

JWT validation follows exactly this pattern. A well-implemented validator runs through every check in sequence and rejects the token at the first failure. The goal is to prove four things: the token has not been tampered with (signature), it has not expired (expiry), it was issued by a trusted party (issuer), and it was intended for this specific service (audience). Skipping any of these creates an exploitable vulnerability.

The most commonly skipped check in production is audience validation. Developers configure signature and expiry validation but forget to verify the `aud` claim. This means a valid token issued for Service A can be replayed against Service B — a token substitution attack. Always validate the audience.

---

#### How It Works

```
JWT Validation Checklist (must all pass):

1. SIGNATURE
   - Fetch public key from JWKS using kid in header
   - Verify: base64url(header) + "." + base64url(payload) matches signature
   - Reject if: signature invalid, algorithm is "none", algorithm mismatch

2. EXPIRY (exp claim)
   - Current time must be before exp
   - Allow small clock skew (30–60 seconds) for distributed systems
   - Reject if: current time > exp + skew_tolerance

3. ISSUER (iss claim)
   - Must match the expected auth server URL exactly
   - Reject if: iss missing or does not match configured trusted issuer

4. AUDIENCE (aud claim)
   - Must contain this service's identifier
   - Reject if: aud missing or does not include this service's audience value

5. NOT-BEFORE (nbf claim, optional)
   - Token must not be used before this time
   - Relevant for pre-issued tokens (e.g., scheduled jobs)

Order matters: check signature first (most expensive). If signature fails, skip the rest.
```

The must-memorise gotcha: the `alg: none` attack. An early JWT library bug allowed tokens with `"alg": "none"` in the header to bypass signature validation entirely — the library would skip verification when the algorithm was declared as none. Always check that the algorithm in the header matches the expected algorithm, and never accept `none`.

```java
// Spring Boot: custom audience validator wired into the JWT decoder
@Bean
public JwtDecoder jwtDecoder() {
    NimbusJwtDecoder decoder = NimbusJwtDecoder
        .withJwkSetUri("https://auth.example.com/.well-known/jwks.json")
        .build();

    OAuth2TokenValidator<Jwt> audienceValidator = token -> {
        List<String> audiences = token.getAudience();
        if (audiences.contains("api.example.com")) {
            return OAuth2TokenValidatorResult.success();
        }
        return OAuth2TokenValidatorResult.failure(
            new OAuth2Error("invalid_token", "Invalid audience", null));
    };

    OAuth2TokenValidator<Jwt> withDefaults = JwtValidators.createDefaultWithIssuer(
        "https://auth.example.com");
    OAuth2TokenValidator<Jwt> combined = new DelegatingOAuth2TokenValidator<>(
        withDefaults, audienceValidator);

    decoder.setJwtValidator(combined);
    return decoder;
}
```

This is the pattern to memorise: Spring's default validators cover signature, expiry, and issuer. Audience validation requires a custom validator wired explicitly — it is not included by default.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Walk me through every check you perform when validating a JWT."**

**One-line answer:** Validate the signature, then check expiry, then verify the issuer matches a trusted auth server, then confirm the audience claim targets this service — all four must pass.

**Full answer to give in an interview:**

> "When a service receives a JWT as a Bearer token, I validate it in this order. First, signature: I look at the 'kid' field in the token header, fetch the corresponding public key from the auth server's JWKS endpoint, and cryptographically verify that the signature was produced by that key. If the signature is invalid, I stop and reject immediately — nothing else matters. Second, expiry: I check the 'exp' claim, which is a Unix timestamp, against the current time, allowing a small clock skew of around 30 seconds to tolerate distributed system clock drift. Third, issuer: I check the 'iss' claim to confirm the token was issued by the expected auth server, not by some other system. Fourth, audience: I check the 'aud' claim to confirm this token was intended for my service specifically. If the audience does not include my service's identifier, I reject the token even if everything else is valid — this prevents token substitution attacks where a token issued for one service is replayed against another. Finally, if the token has an 'nbf' (not-before) claim, I check that the current time is past that threshold."

> *Listing the checks in order and naming the attack that audience validation prevents will impress most interviewers.*

**Gotcha follow-up they'll ask:** *"What is the 'alg: none' attack and how do you prevent it?"*

> "Early JWT libraries had a vulnerability where if the 'alg' field in the token header was set to 'none', the library would skip signature verification entirely — any payload would be accepted. An attacker could take a real token, modify the payload (changing their user ID or roles), set 'alg' to 'none', and the server would accept it as valid. The fix is to always specify the expected algorithm explicitly in your validator configuration and reject any token whose header algorithm does not match. Never allow the client to dictate which algorithm is used for verification."

---

##### Q2 — Design Scenario
**"How would you handle JWT revocation? Tokens are stateless but sometimes you need to invalidate one immediately."**

**One-line answer:** Use short token lifetimes combined with a token denylist (Redis-backed set of revoked JTI claims) checked on each request — accepting the small stateful cost for security-critical revocation scenarios.

**Full answer to give in an interview:**

> "JWT's stateless nature means the token is valid until expiry, with no built-in revocation mechanism. There are a few strategies depending on the security requirement. The simplest is short expiry — access tokens that expire in 5 to 15 minutes limit the damage window if a token is stolen. Pair this with a longer-lived refresh token stored server-side; revocation means deleting the refresh token, so the user cannot obtain new access tokens after the current one expires. For cases where you cannot wait for expiry — such as revoking a compromised admin token immediately — you need a denylist: a Redis set of revoked JTI claims (the 'jti' is a unique token identifier claim). Every validation adds a Redis lookup to check if the JTI is in the denylist. This reintroduces a network call per request, partially losing the stateless benefit, but the Redis lookup is sub-millisecond and the denylist stays small if you evict entries after the token's expiry time passes. The tradeoff is explicit: pure statelessness versus immediate revocation capability."

> *This answer shows you understand the architectural tradeoff, not just the JWT spec.*

**Gotcha follow-up they'll ask:** *"Where should a browser SPA store its tokens?"*

> "The recommended storage for access tokens in a browser SPA is memory — a JavaScript variable or React state. This makes them inaccessible to XSS attacks that can read localStorage or sessionStorage. The downside is that tokens are lost on page refresh, requiring a silent re-authentication flow. Refresh tokens should never be stored in localStorage in a high-security context; the preferred pattern is an HttpOnly, Secure, SameSite=Strict cookie managed by a backend-for-frontend (BFF) server, which proxies requests to the API and attaches tokens server-side, keeping them out of JavaScript entirely."

---

> **Common Mistake — Skipping audience validation:** Many implementations validate signature and expiry but omit audience validation. This allows a valid token issued for a low-privilege service (e.g., a public read-only API) to be replayed against a high-privilege service (e.g., an admin API), as long as both accept the same auth server's tokens. Always configure and enforce audience validation explicitly.

---

**Quick Revision (one line):**
Validate JWTs in this order: signature → expiry → issuer → audience; audience validation is the most commonly skipped check and enables token substitution attacks when absent.

---

## Topic 4: OAuth2 Roles and Overview

---

#### The Idea

Imagine you want a photo-printing app to access your Google Photos. You do not want to give the printing app your Google password — if the app is compromised, your entire Google account is exposed. OAuth2 solves this by introducing a trusted middleman (Google) that issues a limited-access pass to the printing app, without ever revealing your password to it.

OAuth2 defines four roles to model this delegation cleanly. The **Resource Owner** is you — the user who owns the data. The **Resource Server** is Google Photos — the API that holds your data. The **Client** is the photo-printing app — the application that wants access to your data on your behalf. The **Authorization Server** is Google's auth system — it authenticates you, gets your consent, and issues a time-limited access token to the client. The client then presents that token to the resource server to get your photos.

This separation is powerful: the client never learns your password, the access token is scoped (it can only read photos, not access your Gmail), and you can revoke it at any time from Google's security settings. OAuth2 is an authorization framework — it grants delegated access. It is not an authentication protocol (that is OpenID Connect, which is built on top of OAuth2).

---

#### How It Works

```
OAuth2 Roles:
  Resource Owner      → the user (human) who owns the protected data
  Resource Server     → the API holding the data (validates access tokens)
  Client              → the app requesting access on behalf of the user
  Authorization Server → issues tokens after authenticating the user and getting consent

Key distinction:
  OAuth2  = authorization (access delegation) — "this app may read your photos"
  OIDC    = authentication (identity) — "this is who the user is"
  OIDC adds: id_token (JWT with user identity claims) + /userinfo endpoint
```

A client registered with the authorization server receives a `client_id` (public identifier) and optionally a `client_secret` (shared secret for confidential clients — server-side apps that can keep a secret). Public clients (SPAs, mobile apps) use PKCE instead of a client secret.

```
Token types:
  Access Token  → short-lived (5–60 min), presented to resource server as Bearer token
  Refresh Token → longer-lived, used to obtain new access tokens without re-authenticating
  ID Token      → OIDC only, JWT containing user identity claims (sub, email, name)
```

The important operational distinction: **confidential clients** (backend servers) can store a client secret securely. **Public clients** (browsers, mobile) cannot store secrets safely and use PKCE (Proof Key for Code Exchange) to prove they initiated the auth flow.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Describe the four OAuth2 roles. What problem does OAuth2 solve that basic authentication cannot?"**

**One-line answer:** OAuth2 separates the user (Resource Owner), their data API (Resource Server), the requesting app (Client), and the trust broker (Authorization Server) to enable delegated access without sharing passwords.

**Full answer to give in an interview:**

> "OAuth2 solves the password anti-pattern: before OAuth2, if you wanted a third-party app to access your data on another service, you had to give that app your password. If the app was breached, your account was compromised. OAuth2 replaces this with delegated authorization. The Resource Owner — the user — owns the data. The Resource Server — the API like Google Photos or GitHub — holds the data and validates access tokens. The Client — the third-party app — requests access on the user's behalf. The Authorization Server — Google's auth system, Okta, Keycloak — authenticates the user, shows them a consent screen describing what access is requested, and if approved, issues a scoped, time-limited access token to the client. The client presents this access token to the resource server. The client never sees the user's password. The token is scoped to specific permissions (like 'read:photos') and can be revoked independently of the user's account. This is the core value of OAuth2: fine-grained, revocable, delegated authorization."

> *The word "delegated" is the key concept — OAuth2 lets a user delegate a specific subset of their permissions to an application, without sharing credentials.*

**Gotcha follow-up they'll ask:** *"What is the difference between OAuth2 and OpenID Connect?"*

> "OAuth2 is purely an authorization framework — it defines how to grant an application access to resources, but says nothing about user identity. OpenID Connect, or OIDC, is an authentication layer built on top of OAuth2. It adds an ID token — a JWT containing identity claims like 'sub' (the user's unique ID), 'email', and 'name' — and a standardised '/userinfo' endpoint. The access token grants access to resources; the ID token proves who the user is. If you are doing 'Sign in with Google', you are using OIDC. If you are just allowing an app to access a Google API on behalf of a user without caring about their identity, you are using OAuth2 alone. In practice, most modern identity flows use both together."

---

##### Q2 — Design Scenario
**"You are building a multi-service platform. How do you decide which OAuth2 component each service plays?"**

**One-line answer:** Each service plays one or more roles: the auth service is the Authorization Server, APIs with user data are Resource Servers, and any service calling another service's API is a Client.

**Full answer to give in an interview:**

> "I start by mapping the data flows. The Authorization Server is the identity backbone — typically a dedicated service like Keycloak, Auth0, or a custom Spring Authorization Server. It owns user accounts, issues tokens, and manages consent. Every API that protects user data is a Resource Server — it validates incoming Bearer tokens against the auth server's public keys. Any service or application that calls a protected API is a Client — it must register with the auth server and obtain tokens. In a typical e-commerce platform: the frontend app is a public Client using Authorization Code with PKCE. The order-service, inventory-service, and user-service are all Resource Servers validating JWTs. When the order-service needs to call the inventory-service internally, the order-service is also a Client using the Client Credentials grant to obtain a service-to-service token. The key insight is that a single service can play multiple roles — resource server for inbound requests, client for outbound calls."

> *This answer demonstrates systems thinking and real-world OAuth2 architecture experience.*

**Gotcha follow-up they'll ask:** *"What is the difference between a confidential client and a public client?"*

> "A confidential client is an application that can securely store a client secret — typically a server-side backend application where the secret lives in a protected environment variable and is never exposed to end users. A public client cannot securely store secrets — browser-based SPAs and mobile apps fall in this category because their code is accessible to end users who can extract any embedded secret. Public clients use PKCE — Proof Key for Code Exchange — instead of a client secret to prove to the authorization server that the entity requesting the token is the same one that initiated the authorization flow. PKCE works by generating a random code verifier, hashing it to produce a code challenge, sending the challenge at the start of the flow, and proving possession of the original verifier when exchanging the code for a token."

---

> **Common Mistake — Treating OAuth2 as an authentication protocol:** OAuth2 grants access to resources; it does not authenticate users. An access token tells you "this client is allowed to access this resource" but not "this is user Alice." For user identity, you need OpenID Connect (OIDC), which adds the ID token. Building a login system on raw OAuth2 without OIDC is a common architectural mistake that leads to identity confusion bugs.

---

**Quick Revision (one line):**
OAuth2's four roles are Resource Owner (user), Resource Server (data API), Client (requesting app), and Authorization Server (trust broker that issues tokens) — it solves delegated access without password sharing.

---

## Topic 5: OAuth2 Grant Types

---

#### The Idea

OAuth2 defines several "grant types" — each one is a different recipe for how a client obtains an access token, suited to different situations. Think of grant types as different ways to prove you are entitled to a key: sometimes you show your ID in person (interactive login), sometimes you present a pre-approved service badge (machine-to-machine), sometimes you type a code shown on a TV screen (device with no browser). Each scenario needs a different ceremony.

The grant type you choose depends on two questions: Is there a human user involved? Can the client store a secret? Interactive user flows use Authorization Code (with PKCE for public clients). Background service-to-service calls use Client Credentials. Devices without browsers use Device Code. The older Implicit and Resource Owner Password Credentials grants are deprecated because they have security weaknesses — knowing why they were deprecated shows interview maturity.

Every grant type ends the same way: the client holds an access token it can present to a resource server. The differences are only in how that token is obtained.

---

#### How It Works

```
Authorization Code + PKCE flow (most important):
  1. Client generates random code_verifier, computes code_challenge = SHA256(code_verifier)
  2. Browser redirects to Authorization Server:
       GET /authorize?response_type=code&client_id=X&redirect_uri=Y
                     &code_challenge=Z&code_challenge_method=S256
  3. User authenticates and consents
  4. Authorization Server redirects to redirect_uri with one-time ?code=AUTH_CODE
  5. Client backend POSTs to token endpoint:
       POST /token  { grant_type=authorization_code, code=AUTH_CODE,
                      code_verifier=ORIGINAL_VERIFIER, redirect_uri=Y }
  6. Authorization Server verifies SHA256(code_verifier) == code_challenge → issues token
  
  Why PKCE: if code is intercepted in step 4, attacker cannot exchange it without code_verifier
```

**Grant Type Comparison Table:**

| Grant Type | User Involved | Client Type | Use Case | Status |
|---|---|---|---|---|
| Authorization Code + PKCE | Yes | Public (SPA, mobile) or Confidential | User login in web/mobile apps | **Recommended** |
| Authorization Code (no PKCE) | Yes | Confidential (server-side) | Traditional server-side web apps with client secret | Active |
| Client Credentials | No | Confidential | Service-to-service (M2M) calls | **Recommended** |
| Device Code | Yes | Public (limited input) | Smart TVs, CLIs, IoT devices without browser | Active |
| Implicit | Yes | Public | Deprecated SPA flow (token in URL fragment) | **Deprecated** |
| Resource Owner Password Credentials (ROPC) | Yes | Any | Deprecated direct username/password to client | **Deprecated** |

```
Client Credentials flow (service-to-service):
  POST /token
    { grant_type=client_credentials,
      client_id=SERVICE_A,
      client_secret=SECRET,
      scope=inventory:read }
  → Access token returned directly (no user redirect)
  
  Use when: order-service calls inventory-service internally with no user context
```

The must-memorise gotcha for grant types: **why Implicit was deprecated**. Implicit returned the access token directly in the URL fragment after redirect (`#access_token=...`). This exposed the token in browser history, server logs, and referrer headers. Authorization Code + PKCE replaced it — even for SPAs — because the token is never in the URL.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Which OAuth2 grant type would you use for a React SPA, a backend microservice calling another, and a CLI tool running on a developer's machine?"**

**One-line answer:** Authorization Code with PKCE for the SPA, Client Credentials for service-to-service, and Device Code for the CLI.

**Full answer to give in an interview:**

> "For the React SPA, I use Authorization Code with PKCE. A SPA is a public client — the code runs in the browser and cannot safely store a client secret. PKCE replaces the client secret by having the app generate a one-time code verifier before starting the flow. The authorization code returned after user login is useless to an attacker who intercepts it, because they do not have the code verifier needed to exchange it for a token. For a backend microservice calling another — say, order-service calling inventory-service — there is no user involved, so I use Client Credentials. The calling service authenticates directly with the auth server using its own client ID and secret, obtains a service token scoped to the permissions it needs, and presents that to the target service. For a CLI tool on a developer's machine, I use Device Code. The CLI displays a short code and a URL; the developer opens the URL in their browser, authenticates, and the CLI polls the token endpoint until the auth completes. This works on machines without a browser accessible from the CLI or in headless environments."

> *Mapping the three real-world scenarios to the correct grants is a classic interview structure for this topic.*

**Gotcha follow-up they'll ask:** *"Why was the Implicit grant deprecated?"*

> "The Implicit grant was designed for browser-based apps before PKCE existed. It returned the access token directly in the URL fragment after redirect — something like `https://app.example.com/callback#access_token=xyz`. This meant the token appeared in browser history, could be leaked via the Referrer header to third-party scripts on the page, and was accessible to any JavaScript running on the page including third-party analytics scripts. Authorization Code with PKCE is strictly better: the authorization code in the URL is short-lived and single-use, and the actual access token is obtained server-side (or in a backend-for-frontend) via a POST to the token endpoint, never appearing in the URL. The OAuth2 Security Best Current Practices RFC explicitly prohibits Implicit for new implementations."

---

##### Q2 — Tradeoff Question
**"What is PKCE and why is it necessary for public clients?"**

**One-line answer:** PKCE (Proof Key for Code Exchange) is a mechanism that proves the entity redeeming an authorization code is the same one that requested it, replacing the need for a client secret in public clients.

**Full answer to give in an interview:**

> "PKCE was originally designed to protect mobile apps from a specific attack: a malicious app on the same device intercepting the OAuth2 callback URL and stealing the authorization code. Without PKCE, whoever has the authorization code can exchange it for a token. Public clients — SPAs and mobile apps — cannot use a client secret to prove their identity when redeeming the code, because the secret would be visible in the app's source. PKCE solves this with a one-time cryptographic proof. Before starting the flow, the client generates a random high-entropy string called the code verifier. It computes the code challenge as the SHA-256 hash of the verifier. It sends the code challenge to the auth server when requesting authorization. Later, when exchanging the authorization code for a token, it sends the original code verifier. The auth server hashes the verifier and checks it matches the challenge it stored earlier. An attacker who intercepts the authorization code does not have the code verifier, so they cannot redeem the code. PKCE is now recommended for all clients — including confidential clients — as defence in depth."

> *Walking through the two-step hash-then-verify logic shows you understand the cryptographic intent.*

**Gotcha follow-up they'll ask:** *"What is the difference between an access token and a refresh token in terms of lifetime and storage?"*

> "Access tokens are short-lived — typically 5 to 60 minutes — and are presented as Bearer tokens in every API request. Because they are transmitted frequently, the blast radius of a stolen access token is limited by the short expiry. Refresh tokens are longer-lived — hours to days — and are used only to obtain new access tokens from the auth server when the current one expires. They are never sent to resource servers, only to the auth server's token endpoint. Because of their longer lifetime and higher sensitivity, refresh token storage requires more care: in a backend server, store in an encrypted database field; in a browser SPA, store in an HttpOnly Secure cookie managed by a backend-for-frontend; never in localStorage. If a refresh token is compromised, it should be immediately revocable server-side — unlike access tokens, which remain valid until expiry."

---

##### Q3 — Design Scenario
**"Design the token strategy for a mobile banking app."**

**One-line answer:** Authorization Code with PKCE for initial login, short-lived access tokens (15 minutes), refresh tokens stored in the device secure enclave with refresh token rotation and immediate revocation on suspicious activity.

**Full answer to give in an interview:**

> "A mobile banking app is a high-security public client. For the authentication flow, I use Authorization Code with PKCE — the app redirects to the bank's auth server in an ASWebAuthenticationSession (iOS) or Custom Tab (Android), which isolates the authentication from the app and prevents the app from intercepting the user's credentials. Access tokens should be short-lived — 15 minutes maximum — to limit the damage window if a token is stolen from device memory. Refresh tokens are stored in the device's secure enclave or Keychain, which is hardware-protected and inaccessible to other apps. I implement refresh token rotation: every time a refresh token is used to get a new access token, a new refresh token is issued and the old one is invalidated. This means that if a refresh token is stolen and used by an attacker, the legitimate client's next use of their token will fail, alerting the system to a potential compromise. The auth server should also implement refresh token family tracking — if a previously invalidated token from a family is used, revoke the entire family immediately. For step-up authentication (transferring large amounts), the app triggers a re-authentication flow rather than relying on the existing session."

> *This answer demonstrates awareness of mobile-specific security considerations beyond the basic grant type selection.*

---

> **Common Mistake — Using Client Credentials when a user is involved:** Client Credentials is for service-to-service calls with no user context. If you use it to authenticate on behalf of a user, the resulting token carries no user identity, and downstream services cannot enforce per-user permissions. Use Authorization Code (with PKCE for public clients) whenever a human user is part of the flow; reserve Client Credentials for purely automated, background service interactions.

---

**Quick Revision (one line):**
Use Authorization Code + PKCE for any user-facing app, Client Credentials for service-to-service calls, Device Code for browserless devices — Implicit and ROPC are deprecated and should never be used in new systems.

---

## Topic 6: OpenID Connect (OIDC)

---

#### The Idea

Imagine you want to log in to a new app using your Google account. Google needs to do two distinct things: prove to the app that you are who you claim to be, and optionally allow the app to call Google APIs on your behalf. OAuth2 was designed only for the second part — delegating access to resources. It says "here is a token that lets you read this user's calendar," but it says nothing about who the user actually is.

OpenID Connect (OIDC) is a thin identity layer built on top of OAuth2 to solve the first part. When you add the scope `openid` to an OAuth2 request, the authorization server returns an extra token called the **ID token** alongside the usual access token. The ID token is a signed JWT that contains identity claims — who you are — and is meant to be consumed by the client app, not sent to any API.

Think of it this way: the **access token** is a hotel key card that opens a specific door (it grants access to a resource). The **ID token** is your passport — it proves your identity to the front desk (your client app). You would never hand your passport to the vending machine; similarly you should never send the ID token to a backend API.

---

#### How It Works

```
Client                    Authorization Server              Resource Server
  |                               |                               |
  |-- GET /authorize?             |                               |
  |   scope=openid profile email  |                               |
  |   &response_type=code         |                               |
  |   &nonce=abc123 ------------>  |                               |
  |                               |                               |
  |<-- authorization code --------|                               |
  |                               |                               |
  |-- POST /token                 |                               |
  |   code=... -----------------> |                               |
  |                               |                               |
  |<-- { access_token,            |                               |
  |      id_token (JWT),          |                               |
  |      refresh_token } ---------|                               |
  |                               |                               |
  | Client validates id_token:    |                               |
  |   - verify signature          |                               |
  |   - check iss, aud, exp       |                               |
  |   - check nonce == abc123     |                               |
  |                               |                               |
  |-- GET /api/orders             |                               |
  |   Authorization: Bearer <access_token> --------------------> |
  |                               |                               |
  |<-- orders data ------------------------------------------------|
```

The must-memorise gotcha is the **ID token claims**. Every OIDC ID token contains these standard fields:

```java
// ID token payload (decoded JWT)
{
  "sub":   "google-user-123",          // Subject: stable, unique user identifier
  "iss":   "https://accounts.google.com", // Issuer: who signed this token
  "aud":   "your-client-id",           // Audience: MUST match your app's client_id
  "exp":   1720000000,                 // Expiry: reject token after this Unix timestamp
  "iat":   1719996400,                 // Issued At
  "nonce": "abc123",                   // Echo of your nonce: prevents replay attacks
  "email": "user@gmail.com",
  "name":  "Jane Smith"
}
```

The `nonce` is generated fresh by your client for each login attempt. When the returned ID token echoes the same `nonce`, you know this token was issued specifically for this login attempt and cannot be a replayed token from a previous session.

The **discovery document** at `/.well-known/openid-configuration` is a machine-readable JSON that lists all OIDC endpoints, supported scopes, signing algorithms, and the JWKS URI — allowing clients to auto-configure without hardcoding URLs.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is OpenID Connect and how does it differ from OAuth2?"**

**One-line answer:** OAuth2 handles authorization (access delegation); OIDC extends it with authentication by adding a signed ID token that proves user identity.

**Full answer to give in an interview:**

> "OAuth2 is a framework for delegating access — it lets a user authorize an app to call APIs on their behalf, producing an access token. But OAuth2 deliberately says nothing about who the user is; the access token is opaque to the client. OpenID Connect fixes this by adding a second token called the ID token, which is always a JWT signed by the authorization server and contains identity claims: `sub` for the stable user ID, `iss` for the issuer, `aud` for the intended audience, `exp` for expiry, and optionally `email`, `name`, and so on. The client application validates the ID token locally — checking the signature, the `iss`, the `aud`, and that the `exp` has not passed — and uses it to establish a login session. The access token is still used for calling APIs; the ID token never leaves the client. OIDC also defines a discovery document at `/.well-known/openid-configuration` so clients can auto-discover all endpoints, and a `/userinfo` endpoint for fetching additional claims when the ID token doesn't include them."

> *Pause after the one-liner. Only expand into token details if the interviewer nods.*

**Gotcha follow-up they'll ask:** *"Can you send the ID token to your backend API instead of the access token?"*

> "No — and this is a common mistake. The ID token's `aud` claim is set to your client's `client_id`, meaning it was issued for your front-end app to consume, not for a backend API. If a resource server tries to validate an ID token, the audience check will fail. The access token is what you send to APIs; the ID token is for establishing identity on the client side."

---

##### Q2 — Gotcha / Security Detail
**"What is the `nonce` claim in an ID token and why does it matter?"**

**One-line answer:** The nonce is a random value the client includes in the authorization request and must verify in the returned ID token — it prevents replay attacks where an attacker reuses a captured token.

**Full answer to give in an interview:**

> "When starting a login flow, the client generates a cryptographically random string called a nonce and includes it as a parameter in the authorization request sent to the authorization server. The authorization server embeds that exact nonce value into the ID token it returns. The client then checks that the nonce in the token matches the one it sent. This breaks replay attacks: if an attacker intercepts an ID token and tries to submit it to your app later, your app will notice the nonce doesn't match the one stored in the current session and reject it. Without nonce verification, a stolen ID token could be used to impersonate the victim on any session. In practice, the nonce is stored server-side or in a secure session cookie between the auth request and the callback."

---

##### Q3 — Design / `sub` vs `email`
**"Which claim should you use as the primary user identifier when linking an OIDC login to a database record?"**

**One-line answer:** Always use `sub` (subject), not `email` — `sub` is the provider's stable, immutable user ID, while email addresses can change.

**Full answer to give in an interview:**

> "The `sub` claim is the authorization server's permanent, unique identifier for the user — it never changes. The `email` claim is convenient for display but users can change their email addresses, and some providers allow email reuse after account deletion. If you build your user lookup on `email`, you risk account takeover: user A changes their email to user B's old address and inherits B's account. The correct approach is to store a composite key of `iss` plus `sub` — the issuer URL plus the subject ID — because the same `sub` value can appear across different identity providers. For example, `iss=https://accounts.google.com, sub=12345` is distinct from `iss=https://login.microsoftonline.com/..., sub=12345`."

---

> **Common Mistake — Sending the ID token to your API:** The ID token's audience is your client app, not your resource server. Sending it to your API will cause audience validation to fail, and even if it passes, it signals a design confusion between authentication tokens and access tokens.

---

**Quick Revision (one line):**
OIDC = OAuth2 + identity: the ID token (JWT, audience = your app, contains `sub/iss/aud/exp/nonce`) proves who the user is; the access token (audience = your API) grants what they can do.

---

## Topic 7: Spring Security Architecture

---

#### The Idea

Every web framework needs a way to intercept incoming HTTP requests and decide whether to let them through. Spring Security does this with a chain of filters — think of it like a series of security checkpoints at an airport. Each checkpoint does one specific job: one checks if you are carrying credentials, another checks your boarding pass against the flight manifest, another handles what happens if your pass is invalid. Requests pass through every checkpoint in a fixed order, and the first checkpoint that blocks you stops the request entirely.

The key insight is that these filters are not tangled together — they are loosely coupled, each reading from and writing to a shared object called the `SecurityContext`. A filter early in the chain authenticates you (places your identity into the `SecurityContext`), and a filter late in the chain reads that identity to decide whether you are authorized to proceed.

Spring Security's `SecurityContextHolder` stores the `SecurityContext` as a thread-local variable, meaning the authentication for request A is completely isolated from the authentication for request B running on a different thread. The `Authentication` object inside the context is the central data structure: it holds the principal (who you are), credentials (usually cleared after authentication), and a list of `GrantedAuthority` objects (what you are allowed to do).

---

#### How It Works

```
HTTP Request arrives at the Servlet container
     |
     v
DelegatingFilterProxy  
  (a standard Servlet filter that delegates to a Spring-managed bean)
     |
     v
FilterChainProxy  
  (selects the matching SecurityFilterChain based on the request path)
     |
     v
SecurityFilterChain — ordered list of filters:

  1. SecurityContextPersistenceFilter
     — loads SecurityContext from session (stateful) or creates empty one (stateless)

  2. [BearerTokenAuthenticationFilter / UsernamePasswordAuthenticationFilter]
     — extracts credentials, calls AuthenticationManager

  3. ExceptionTranslationFilter
     — catches AuthenticationException -> 401, AccessDeniedException -> 403

  4. FilterSecurityInterceptor / AuthorizationFilter
     — final access decision: does this Authentication have the required authority?

     |
     v
DispatcherServlet -> Controller method
```

Authentication flow inside the filter chain:

```
Filter extracts credentials
  -> creates unauthenticated Authentication token (e.g. UsernamePasswordAuthenticationToken)
  -> calls AuthenticationManager.authenticate(token)
       -> ProviderManager iterates AuthenticationProvider list
            -> DaoAuthenticationProvider: loads UserDetails, checks password
            -> JwtAuthenticationProvider: validates JWT signature + claims
  -> returns authenticated Authentication (isAuthenticated() == true)
  -> SecurityContextHolder.getContext().setAuthentication(authenticated)
```

The must-memorise gotcha is the **filter order**. Knowing these four in sequence is what interviewers test:

```
SecurityContextPersistenceFilter        (loads context — must be first)
  -> UsernamePasswordAuthenticationFilter  (or BearerTokenAuthenticationFilter for JWT)
     -> ExceptionTranslationFilter          (translates security exceptions to HTTP responses)
        -> FilterSecurityInterceptor        (makes the final authorization decision — must be last)
```

If you insert a custom filter in the wrong position — for example, after `FilterSecurityInterceptor` — your custom logic runs after the access decision has already been made, which means it has no effect on authorization.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Architecture Walkthrough
**"Describe the Spring Security filter chain. What happens when a JWT request comes in?"**

**One-line answer:** Every request passes through an ordered `SecurityFilterChain`; filters authenticate (populate `SecurityContextHolder`) and authorize (check the stored `Authentication`), with exceptions translated to 401/403 by `ExceptionTranslationFilter`.

**Full answer to give in an interview:**

> "Spring Security wraps the servlet container's filter pipeline. `DelegatingFilterProxy` is a plain Servlet filter registered with the container; it delegates to `FilterChainProxy`, a Spring bean that selects the matching `SecurityFilterChain` for the incoming URL. The chain is an ordered list of filters. For a JWT request, `BearerTokenAuthenticationFilter` runs early — it extracts the `Authorization: Bearer` header, creates an unauthenticated token, and hands it to `AuthenticationManager`. `ProviderManager` iterates its list of `AuthenticationProvider`s until it finds `JwtAuthenticationProvider`, which validates the token's signature, issuer, audience, and expiry using public keys from the JWKS endpoint. On success, it creates a fully populated `JwtAuthenticationToken` containing the user's name and `GrantedAuthority` list, and stores it in `SecurityContextHolder`. Later, `AuthorizationFilter` reads that `Authentication` and checks whether the required authority is present — if not, it throws `AccessDeniedException`. `ExceptionTranslationFilter`, which wraps the later filters, catches that exception and writes a 403 response."

> *If the interviewer asks about async threads, mention that `SecurityContextHolder` is thread-local by default — child threads do not inherit the context unless you configure `InheritableThreadLocalSecurityContextHolderStrategy` or use Spring's `DelegatingSecurityContextExecutor`.*

**Gotcha follow-up they'll ask:** *"What does `ExceptionTranslationFilter` actually do?"*

> "It sits in the filter chain and wraps everything downstream in a try-catch. If `AuthorizationFilter` throws `AccessDeniedException` and the user is not authenticated, it redirects to the login page or triggers the `AuthenticationEntryPoint` — which for a REST API typically writes a 401 JSON response. If the user is authenticated but lacks the required authority, it invokes the `AccessDeniedHandler`, which writes a 403. Without `ExceptionTranslationFilter`, those exceptions would bubble all the way up to the container and produce an ugly 500 error page."

---

##### Q2 — Component Roles
**"What is the relationship between `AuthenticationManager`, `ProviderManager`, and `AuthenticationProvider`?"**

**One-line answer:** `AuthenticationManager` is the interface; `ProviderManager` is the standard implementation that delegates to a list of `AuthenticationProvider`s, each handling a different credential type.

**Full answer to give in an interview:**

> "`AuthenticationManager` is a single-method interface — `authenticate(Authentication)` — that represents the entry point to Spring Security's authentication machinery. `ProviderManager` is the standard implementation; it holds an ordered list of `AuthenticationProvider` instances and calls each one in turn, stopping at the first that can handle the given token type. For example, `DaoAuthenticationProvider` handles `UsernamePasswordAuthenticationToken` — it calls `UserDetailsService.loadUserByUsername()` to fetch the stored user, then uses `PasswordEncoder.matches()` to check the password. `JwtAuthenticationProvider` handles `BearerTokenAuthenticationToken` — it validates the JWT signature and claims. You can add a custom `AuthenticationProvider` for other credential types, like API keys, by implementing the `supports(Class)` method to match your custom token class and the `authenticate` method to perform the verification."

---

> **Common Mistake — Wrong filter insertion order:** If you add a custom filter after `AuthorizationFilter` (the final access-decision filter), authentication has already happened and your filter cannot affect authorization. Always use `.addFilterBefore(myFilter, UsernamePasswordAuthenticationFilter.class)` or `.addFilterAfter` with awareness of what each position means.

---

**Quick Revision (one line):**
`FilterChainProxy` routes to `SecurityFilterChain`; filters run in order — `SecurityContextPersistenceFilter` → authentication filter → `ExceptionTranslationFilter` → `FilterSecurityInterceptor`; `ProviderManager` delegates credential checking to `AuthenticationProvider`s; the result is stored in `SecurityContextHolder`.

---

## Topic 8: Spring Security JWT Integration

---

#### The Idea

When you build a stateless REST API, you cannot rely on server-side sessions. Instead, each request carries its own credentials in the form of a JWT (JSON Web Token) in the `Authorization: Bearer` header. Spring Security needs a component that intercepts every request, extracts that token, validates it, and — if valid — places the user's identity into the `SecurityContextHolder` so that the rest of the filter chain and your controllers know who is making the request.

The mechanism is a custom filter extending `OncePerRequestFilter`, which guarantees it runs exactly once per request even in dispatched requests (forwards, error dispatches). The filter is inserted into the Spring Security filter chain just before `UsernamePasswordAuthenticationFilter` — at the point where credentials are normally checked. If the JWT is valid, the filter sets the authentication so the downstream `AuthorizationFilter` can enforce access rules.

Once authentication is established, Spring Security's `@PreAuthorize` annotation lets you put access rules directly on controller methods using Spring Expression Language (SpEL). The expression can reference the current `Authentication` object, method parameters, or even call methods on Spring beans — enabling rich, fine-grained authorization without cluttering your business logic.

---

#### How It Works

```
Request: GET /api/documents/user/alice
         Authorization: Bearer eyJhbGci...

JwtAuthenticationFilter.doFilterInternal():
  1. Check if SecurityContext already has Authentication -> skip if yes
  2. Read Authorization header; return if missing or not "Bearer "
  3. Extract JWT string (substring after "Bearer ")
  4. jwtService.extractUsername(jwt)  -> parse claims, get "sub"
  5. userDetailsService.loadUserByUsername(username)
  6. jwtService.isTokenValid(jwt, userDetails)  -> check sub match + expiry
  7. Create UsernamePasswordAuthenticationToken(userDetails, null, authorities)
  8. SecurityContextHolder.getContext().setAuthentication(token)
  9. filterChain.doFilter(request, response)  <- ALWAYS call this, even on error

@PreAuthorize SpEL evaluation (happens in AuthorizationFilter):
  "hasRole('ADMIN') or #userId == authentication.name"
    -> authentication  = SecurityContextHolder's Authentication
    -> #userId         = method parameter named "userId" (needs -parameters compiler flag)
    -> @beanName.method() = delegates to a Spring bean for complex checks
```

The must-memorise gotcha is the **JWT filter implementation** — specifically the three things that are most often wrong in interviews:

```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        // GOTCHA 1: skip if already authenticated (e.g. set by a prior filter)
        if (SecurityContextHolder.getContext().getAuthentication() != null) {
            filterChain.doFilter(request, response);
            return;
        }

        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);  // GOTCHA 2: always call doFilter
            return;
        }

        String jwt = authHeader.substring(7);
        try {
            String username = jwtService.extractUsername(jwt);
            if (username != null) {
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                if (jwtService.isTokenValid(jwt, userDetails)) {
                    var authToken = new UsernamePasswordAuthenticationToken(
                        userDetails, null, userDetails.getAuthorities());
                    authToken.setDetails(
                        new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            }
        } catch (JwtException e) {
            log.warn("Invalid JWT: {}", e.getMessage());
            // GOTCHA 3: still call doFilter — let ExceptionTranslationFilter handle the 401
        }
        filterChain.doFilter(request, response);
    }
}
```

`@PostAuthorize` is `@PreAuthorize`'s complement: it runs *after* the method returns and can access `returnObject`. Use it when you need to verify the returned data belongs to the caller — for example `@PostAuthorize("returnObject.ownerId == authentication.name")`.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Implementation Walkthrough
**"Walk me through implementing a JWT authentication filter in Spring Boot 3."**

**One-line answer:** Extend `OncePerRequestFilter`, extract and validate the Bearer token, set `SecurityContextHolder`, then always call `filterChain.doFilter()` — register it with `.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)`.

**Full answer to give in an interview:**

> "I create a component extending `OncePerRequestFilter`. In `doFilterInternal`, the first thing I check is whether the `SecurityContextHolder` already has an `Authentication` — if so, skip processing, because an earlier filter may have already authenticated the request. Then I read the `Authorization` header: if it's missing or doesn't start with 'Bearer ', I call `filterChain.doFilter()` and return — the request continues unauthenticated and will either hit a public endpoint or get rejected by `AuthorizationFilter`. Otherwise, I extract the token, parse the `sub` claim using my `JwtService`, load `UserDetails` from `UserDetailsService`, and call `isTokenValid` which checks the username match and expiry. On success, I construct a `UsernamePasswordAuthenticationToken` with the user's authorities and set it on the `SecurityContextHolder`. The critical thing is that I always call `filterChain.doFilter()` at the end — even inside the catch block — because if I don't, the request hangs and never gets a response. The filter is registered in `SecurityConfig` with `.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)` so it runs before Spring's default form-login processing."

> *Be ready to explain why `OncePerRequestFilter` rather than `Filter` — in Servlet dispatching, error dispatches and forwards can invoke filters multiple times; `OncePerRequestFilter` uses a request attribute to guarantee single execution.*

**Gotcha follow-up they'll ask:** *"What's the difference between `@PreAuthorize` and `@PostAuthorize`?"*

> "`@PreAuthorize` runs before the method executes — it's a gate. If the SpEL expression returns false, Spring throws `AccessDeniedException` before your method body runs at all. `@PostAuthorize` runs after the method returns and has access to `returnObject`. It's useful when the authorization decision depends on the return value — for example, `@PostAuthorize(\"returnObject.ownerId == authentication.name\")` lets the method run but throws 403 if the returned document doesn't belong to the caller. The trade-off: `@PostAuthorize` still executes the method even if it will ultimately be denied, so avoid it for expensive operations where you can encode the check before the call."

---

##### Q2 — Design / SpEL
**"How would you implement a multi-tenant authorization check where users can only access their own tenant's data?"**

**One-line answer:** Use `@PreAuthorize` with a bean reference — `@PreAuthorize("@tenantService.isMember(#tenantId, authentication.name)")` — to delegate the check to a Spring service that queries membership.

**Full answer to give in an interview:**

> "For simple cases I can put the check inline in the SpEL expression: `@PreAuthorize(\"#tenantId == authentication.details['tenant_id']\")` if the tenant ID is stored in the JWT claims and surfaced via `Authentication.getDetails()`. But for anything non-trivial — like checking a database-backed membership table, handling org hierarchies, or caching the result — I delegate to a Spring bean. I annotate the method with `@PreAuthorize(\"@tenantService.isMember(#tenantId, authentication.name)\")`. Spring resolves `@tenantService` as the `tenantService` bean, calls `isMember(tenantId, username)` at request time, and only proceeds if it returns true. The `#tenantId` SpEL syntax binds to the method parameter of that name — this requires compiling with the `-parameters` flag so parameter names are preserved in bytecode, or using `@P(\"tenantId\")` as an alternative. Admins can bypass the check with `hasRole('ADMIN') or @tenantService.isMember(#tenantId, authentication.name)`."

---

> **Common Mistake — Not calling `filterChain.doFilter()` in the catch block:** If a `JwtException` is thrown and your catch block returns without calling `doFilter`, the response is never completed and the client hangs or gets a connection reset. Always call `filterChain.doFilter(request, response)` as the last statement regardless of the code path taken.

---

**Quick Revision (one line):**
`OncePerRequestFilter` extracts the Bearer token, validates it, sets `SecurityContextHolder`, and always calls `filterChain.doFilter()`; `@PreAuthorize` with SpEL (including `@bean.method(#param)`) gates method execution before it runs.

---

## Topic 9: Spring Security OAuth2 Resource Server

---

#### The Idea

When you build a microservice that should be called by other services or frontends on behalf of a user, your service is a **resource server** — it owns the protected resources (orders, profiles, documents) and needs to validate the access token on every incoming request. You did not issue the token; a separate authorization server did. Your job is only to verify it.

Spring Boot's `spring-security-oauth2-resource-server` auto-configuration does most of the heavy lifting. You tell it where the authorization server's public keys live (via `jwk-set-uri`) or where the authorization server's discovery document is (via `issuer-uri`), and Spring Security automatically fetches those public keys, caches them, and uses them to validate the signature, expiry, issuer, and audience of every Bearer token that arrives.

The interesting part is mapping the token's custom claims to Spring Security's `GrantedAuthority` objects — the things your `@PreAuthorize` expressions and `hasAuthority()` checks read. An authorization server might store roles as `"roles": ["admin", "user"]` or fine-grained permissions as `"permissions": ["orders:read", "orders:write"]`. Spring Security does not know your claim names, so you provide a `JwtAuthenticationConverter` that teaches it how to extract those claims and convert them into `SimpleGrantedAuthority` objects.

---

#### How It Works

```
Request: GET /api/orders
         Authorization: Bearer eyJhbGci...

BearerTokenAuthenticationFilter (auto-configured by oauth2ResourceServer())
  |
  v
JwtAuthenticationProvider
  |-- JwtDecoder.decode(token)
  |     |-- fetch JWKS from jwk-set-uri (cached, refreshed on key rotation)
  |     |-- verify RS256 signature
  |     |-- validate: exp, iat, iss == configured issuer, aud contains audience
  |     `-- returns Jwt object (parsed claims)
  |
  `-- JwtAuthenticationConverter.convert(jwt)
        |-- extract "roles" claim -> ROLE_admin, ROLE_user
        |-- extract "permissions" claim -> orders:read, orders:write
        `-- return JwtAuthenticationToken(jwt, authorities, principal=sub)

SecurityContextHolder.getContext().setAuthentication(jwtAuthToken)

AuthorizationFilter checks @PreAuthorize("hasAuthority('orders:read')")  -> pass
```

The must-memorise gotcha is the **`JwtDecoder` with custom validators** — the part interviewers probe:

```java
@Bean
public JwtDecoder jwtDecoder() {
    NimbusJwtDecoder decoder = NimbusJwtDecoder
        .withJwkSetUri("https://auth.example.com/.well-known/jwks.json")
        .jwsAlgorithm(SignatureAlgorithm.RS256)
        .build();

    // Validator 1: checks iss claim matches, validates exp/nbf/iat
    OAuth2TokenValidator<Jwt> withIssuer =
        JwtValidators.createDefaultWithIssuer("https://auth.example.com");

    // Validator 2: audience check — token must be intended for THIS service
    OAuth2TokenValidator<Jwt> withAudience =
        new JwtClaimValidator<List<String>>(JwtClaimNames.AUD,
            aud -> aud != null && aud.contains("https://api.example.com"));

    decoder.setJwtValidator(
        new DelegatingOAuth2TokenValidator<>(withIssuer, withAudience));
    return decoder;
}
```

Without the audience validator, a token issued for your frontend app (audience = `client-app`) could be replayed against your API. The audience claim should identify the specific service this token was issued for.

JWT vs opaque token trade-offs:

```
JWT (self-contained):
  + validation is local — no network call to auth server per request
  + low latency, works if auth server is temporarily down
  - revocation requires a token blacklist (JWT is valid until exp)
  - claims are visible to anyone who decodes the base64

Opaque token:
  + revocation is immediate — introspect endpoint returns active: false
  - every request hits the introspection endpoint (network latency)
  - auth server unavailability = all requests fail
```

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Configuration
**"How do you configure Spring Boot as an OAuth2 resource server that validates JWTs?"**

**One-line answer:** Set `spring.security.oauth2.resourceserver.jwt.issuer-uri` in `application.yml` and call `.oauth2ResourceServer(oauth2 -> oauth2.jwt(...))` in your `SecurityFilterChain` — Spring auto-discovers JWKS and validates every Bearer token.

**Full answer to give in an interview:**

> "In `application.yml` I set `spring.security.oauth2.resourceserver.jwt.issuer-uri` to the authorization server's base URL — for example `https://auth.example.com`. At startup, Spring Security performs a GET to `https://auth.example.com/.well-known/openid-configuration`, reads the discovery document, and from it discovers the `jwks_uri`. It fetches and caches the public keys from that JWKS endpoint. On every request, `BearerTokenAuthenticationFilter` extracts the Bearer token, and `JwtDecoder` verifies the RS256 signature, checks that the `iss` claim matches, and validates `exp`. In the `SecurityFilterChain` I add `.oauth2ResourceServer(oauth2 -> oauth2.jwt(jwt -> jwt.jwtAuthenticationConverter(myConverter())))` to map custom claims to `GrantedAuthority` objects. One thing to be aware of: because `issuer-uri` triggers an HTTP call at startup, the authorization server must be reachable when the application boots — or you need to configure lazy initialization, which is a common production gotcha."

> *If asked about the difference between `issuer-uri` and `jwk-set-uri`: `jwk-set-uri` directly specifies the JWKS URL and does not perform issuer validation automatically. `issuer-uri` is preferred for OIDC-compliant servers because it does discovery and automatically validates the `iss` claim.*

**Gotcha follow-up they'll ask:** *"What happens if the authorization server rotates its signing key?"*

> "Spring Security's `NimbusJwtDecoder` caches the JWKS keys in memory. When it receives a JWT signed with a key ID (`kid`) not present in the cache, it triggers an automatic refresh of the JWKS endpoint to fetch the new public key set. This is transparent to the application — requests with tokens signed by the new key will work immediately after the cache refresh, while tokens signed by the old key continue to work as long as the authorization server includes both keys in its JWKS during the rotation window. This is why authorization servers should always publish both old and new keys during a key rotation period, not switch abruptly."

---

##### Q2 — Claims Mapping
**"How do you extract a custom `permissions` claim from a JWT and make it available for `@PreAuthorize`?"**

**One-line answer:** Provide a `JwtAuthenticationConverter` bean that reads the custom claim from the `Jwt` object and converts each value into a `SimpleGrantedAuthority`.

**Full answer to give in an interview:**

> "By default, `JwtAuthenticationConverter` only reads the `scope` and `scp` claims and maps them to authorities prefixed with `SCOPE_`. For custom claims, I override the granted-authorities converter. I create a `JwtAuthenticationConverter` bean and call `setJwtGrantedAuthoritiesConverter` with a lambda that receives the parsed `Jwt` object. In the lambda, I call `jwt.getClaimAsStringList(\"permissions\")` to get a list like `[\"orders:read\", \"orders:write\"]`, then map each string to a `new SimpleGrantedAuthority(permission)`. I can also map a `roles` claim similarly, prefixing each with `ROLE_` so that `hasRole('admin')` checks work. After this, `@PreAuthorize(\"hasAuthority('orders:write')\")` on a controller method works as expected because the authority name exactly matches what I stored. I also call `converter.setPrincipalClaimName(JwtClaimNames.SUB)` so that `authentication.getName()` returns the subject, not the default."

---

> **Common Mistake — Missing audience validation:** Without a custom `JwtClaimValidator` checking the `aud` claim, a token issued for your single-page app (audience = `my-spa`) can be submitted to your API and will pass signature and issuer checks. Always add an audience validator scoped to the specific API's identifier.

---

**Quick Revision (one line):**
`issuer-uri` auto-discovers JWKS and validates `iss`/`exp`; `JwtAuthenticationConverter` maps custom claims like `permissions` or `roles` to `GrantedAuthority` objects; always add an audience validator to prevent token replay across services.

---

## Topic 10: Password Storage

---

#### The Idea

Databases get breached. This is a fact of the industry — LinkedIn, Adobe, RockYou, and thousands of others have had their user tables stolen. The question is not whether your database will be exposed, but whether the passwords stored in it are recoverable when it is.

If you store passwords as plaintext, every user's password is immediately compromised when the database is stolen. If you store them as MD5 or SHA256 hashes, attackers can crack most of them in hours using a GPU — modern hardware can compute billions of MD5 hashes per second, and precomputed tables (rainbow tables) make it even faster. These algorithms were designed for speed and integrity checking, not for protecting secrets.

The solution is a class of algorithms designed to be deliberately, tunably slow: bcrypt, Argon2id, and scrypt. Bcrypt, for example, is configured with a cost factor (also called the work factor) that controls how many iterations of the hashing algorithm are performed. At cost 12, a single bcrypt hash takes roughly 250 milliseconds on modern hardware. That is perfectly acceptable for a login endpoint, but it means an attacker trying to brute-force a stolen hash can only test about 4 passwords per second per GPU — compared to billions per second for MD5. Additionally, bcrypt automatically generates and embeds a random salt per password, so two users with the same password produce completely different hashes, defeating rainbow tables.

---

#### How It Works

```
Registration:
  raw password "hunter2"
    -> BCryptPasswordEncoder.encode("hunter2")
         -> generate random 22-char salt
         -> run 2^12 rounds of Blowfish-based hashing
         -> return "$2a$12$<22-char-salt><31-char-hash>"  (always 60 chars)
    -> store encoded string in database
    -> discard raw password immediately

Login verification:
  user submits "hunter2"
    -> BCryptPasswordEncoder.matches("hunter2", storedHash)
         -> extract salt from first 29 chars of storedHash
         -> run same 2^12 rounds with that salt on the candidate
         -> compare result to last 31 chars of storedHash
         -> return true/false
    -> NEVER compare plaintext to hash; NEVER decrypt; always re-hash and compare
```

Why MD5 and SHA1 are wrong:

```
MD5("hunter2") = "2ab96390c7dbe3439de74d0c9b0b1545"  -- same for every user with that password
SHA256("hunter2") = "f52fbd..."                        -- same; no salt; fast to compute billions/sec

BCrypt("hunter2", cost=12) = "$2a$12$RANDOMSALT22.HASH31CHARS"
  - different every time (random salt embedded)
  - ~250ms per hash on modern hardware
  - cost factor is adjustable as hardware improves
```

The must-memorise gotcha is the **`PasswordEncoder` bean configuration**:

```java
// CORRECT: BCrypt with explicit cost factor >= 12
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);  // ~250ms per hash; increase to 13-14 as hardware improves
}

// BETTER for new systems: Argon2id (winner of Password Hashing Competition 2015)
@Bean
public PasswordEncoder passwordEncoder() {
    return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
    // memory-hard: resistant to GPU and ASIC attacks; no 72-byte truncation limit
}

// MIGRATION-SAFE: DelegatingPasswordEncoder — supports multiple algorithms simultaneously
@Bean
public PasswordEncoder passwordEncoder() {
    Map<String, PasswordEncoder> encoders = new HashMap<>();
    encoders.put("bcrypt", new BCryptPasswordEncoder(12));
    encoders.put("argon2", Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8());
    // Stored format: {argon2}$argon2id$v=19$... — the prefix tells the encoder which algorithm to use
    return new DelegatingPasswordEncoder("argon2", encoders);
}

// WRONG: no-argument constructor uses default strength 10 (~100ms) — may be too fast on 2025+ hardware
// new BCryptPasswordEncoder()

// WRONG: MD5 or SHA — never use for passwords
// MessageDigest.getInstance("MD5").digest(password.getBytes())
```

`DelegatingPasswordEncoder` stores a prefix like `{bcrypt}` or `{argon2}` at the start of every encoded value. When verifying, it reads the prefix to choose the right encoder. This enables live migrations: new passwords are encoded with Argon2, while old bcrypt hashes still verify correctly. When Spring Security detects a deprecated encoding on a successful login, it calls `UserDetailsPasswordService.updatePassword()` to silently re-encode and update the stored value — a background upgrade with no user disruption.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Why are MD5 and SHA1 wrong for password storage? What should you use instead?"**

**One-line answer:** MD5 and SHA1 are fast (billions of hashes/sec on a GPU) and lack per-user salt, making them trivially brute-forceable; use bcrypt (cost ≥ 12) or Argon2id instead — they are slow by design and auto-salt.

**Full answer to give in an interview:**

> "MD5 and SHA1 were designed for speed — their purpose is to hash large files for integrity checking, not to protect secrets. A modern GPU can compute over a billion MD5 hashes per second. If you hash 'password123' with MD5, you always get the same output regardless of which user it belongs to. Attackers can precompute a table mapping common passwords to their MD5 hashes — a rainbow table — and then simply look up a stolen hash to find the original password in milliseconds. Even without rainbow tables, brute-forcing a 8-character lowercase password at a billion hashes per second takes seconds. SHA256 has the same problem — it is deterministic, fast, and designed for speed. Bcrypt is different: it is deliberately slow because it runs a configurable number of rounds — at cost factor 12, it performs 2 to the power of 12 iterations of its internal algorithm, taking roughly 250 milliseconds. It also automatically generates and embeds a random 128-bit salt per password, so identical passwords produce completely different hashes, defeating rainbow tables. The cost factor is tunable — you increase it as hardware gets faster, maintaining the 250ms target. Argon2id is the modern recommendation: it is memory-hard, meaning it requires large amounts of RAM per computation, making GPU and ASIC attacks impractical even with massive parallelism."

> *If asked about the LinkedIn breach: in 2012, 117 million unsalted SHA1 password hashes were stolen and most were cracked within days. Bcrypt at cost 12 would have made the same attack take millions of CPU-years.*

**Gotcha follow-up they'll ask:** *"Can you reverse a bcrypt hash to get the original password?"*

> "No — bcrypt is a one-way function. You cannot decrypt it. Verification works by taking the candidate password, extracting the salt embedded in the stored hash, running the same number of bcrypt rounds with that salt on the candidate, and comparing the result to the stored hash. If they match, the password is correct. This is why `PasswordEncoder.matches(rawPassword, encodedPassword)` returns a boolean — it never returns the original password. One gotcha: bcrypt silently truncates inputs longer than 72 bytes — if a user submits a very long passphrase, only the first 72 bytes are hashed. Argon2 has no such truncation limit, which is another reason to prefer it for new systems."

---

##### Q2 — Design / Migration
**"How would you migrate a legacy system storing MD5 hashes to bcrypt without forcing all users to reset their passwords?"**

**One-line answer:** Use `DelegatingPasswordEncoder` with the legacy encoder registered — on each successful MD5 login, re-encode with bcrypt and update the stored value transparently.

**Full answer to give in an interview:**

> "You cannot convert the existing MD5 hashes to bcrypt directly — bcrypt is one-way, so you can't hash the MD5 hash. The migration has to happen lazily at login time. I would configure `DelegatingPasswordEncoder` with both `md5` and `bcrypt` registered. Existing users have `{md5}` prefixed to their stored hash. When a user logs in, `PasswordEncoder.matches()` uses the `{md5}` encoder to verify — the raw password is still known at that point because the user just submitted it. On success, I implement `UserDetailsPasswordService.updatePassword()`, which Spring Security calls automatically when it detects the encoding is deprecated — it re-encodes the raw password with bcrypt and updates the stored value to `{bcrypt}$2a$12$...`. The next time the user logs in, the `{bcrypt}` encoder is used. Over time, active users migrate silently. Users who never log in keep the old hash — you may want to force a password reset for those after a grace period, or accept that inactive accounts retain weaker protection."

---

##### Q3 — Tradeoff / Tuning
**"How do you choose the bcrypt cost factor, and when would you switch to Argon2?"**

**One-line answer:** Target 200–300ms per hash on your production hardware for bcrypt (typically cost 12–13); switch to Argon2id for new systems where you want memory-hardness and no 72-byte truncation limit.

**Full answer to give in an interview:**

> "The bcrypt cost factor is an exponent: cost 12 means 2 to the 12th power (4096) iterations; cost 13 doubles that to 8192 iterations, roughly doubling the time. OWASP recommends targeting 100–300 milliseconds per hash on production hardware as a practical target that is acceptably slow for attackers but imperceptible to users who log in once. I would benchmark on my actual production hardware with `new BCryptPasswordEncoder(12).encode(\"test\")` in a loop and increase the cost factor until I'm in the 200–300ms range. I'd set it in application config rather than hardcoding, so I can tune without a code deploy. For new systems, I prefer Argon2id: it has three tunable parameters — memory (in KB), iterations, and parallelism — allowing much finer-grained control. More importantly, it is memory-hard: each hash computation requires allocating the configured amount of memory, which makes massive GPU parallelism impractical because GPUs have limited per-core memory. `Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8()` gives you sensible defaults — 16MB memory, 3 iterations, 1 thread — which you can tune upward. In Spring Security, both are available as `PasswordEncoder` implementations and are interchangeable from the application's perspective."

---

> **Common Mistake — Using `new BCryptPasswordEncoder()` with no argument:** The no-argument constructor defaults to cost factor 10, which produces hashes in roughly 100ms on modern hardware. As hardware improves, this becomes inadequate. Always specify the cost factor explicitly — `new BCryptPasswordEncoder(12)` — and document it so future engineers know to increase it as hardware improves.

---

**Quick Revision (one line):**
MD5/SHA1 are fast and unsalted — attackers crack them in hours with GPUs; bcrypt (cost ≥ 12, ~250ms, auto-salted) or Argon2id (memory-hard, no length limit) make brute-forcing impractical; Spring's `PasswordEncoder` bean abstracts the algorithm, and `DelegatingPasswordEncoder` enables live migration between algorithms.

---

## Topic 11: HTTPS and TLS

---

#### The Idea

Imagine you want to pass a secret note to a friend across a crowded room. If you just shout it, everyone hears it. Instead, you and your friend agree on a secret code before the conversation starts — anyone watching only sees gibberish. HTTPS is exactly this: it wraps ordinary HTTP traffic in a security layer called TLS (Transport Layer Security) so that every byte travelling between browser and server is encrypted and cannot be read or tampered with by anyone in between.

TLS also solves a second problem: how do you know you are really talking to your bank and not an impostor? It uses **certificates** — digital identity documents issued by trusted authorities (called Certificate Authorities, or CAs). Your browser ships with a list of CAs it trusts. When a server presents a certificate, the browser verifies it was signed by one of those trusted CAs. If the chain checks out, the padlock appears.

Mutual TLS (mTLS) extends this further: not only does the client verify the server, but the server also verifies the client. This is used in service-to-service communication inside microservice architectures — each service presents its own certificate, so a rogue process that somehow gets onto the network cannot impersonate a legitimate service.

---

#### How It Works

```
TLS 1.2 Handshake (2 round trips = 2-RTT):
  Client → Server : ClientHello (supported cipher suites, random nonce)
  Server → Client : ServerHello (chosen cipher, certificate, random nonce)
  Client          : verifies certificate chain
  Client → Server : PreMasterSecret (encrypted with server's public key)
  Both            : derive session keys from nonces + PreMasterSecret
  Client → Server : Finished (MAC of entire handshake)
  Server → Client : Finished
  -- Now encrypted data can flow --

TLS 1.3 Handshake (1 round trip = 1-RTT):
  Client → Server : ClientHello + key_share (Diffie-Hellman public value)
  Server → Client : ServerHello + key_share + Certificate + Finished
  -- Keys derived immediately, encrypted data can flow after 1 RTT --
  Client → Server : Finished
```

TLS 1.3 eliminates a full round trip by merging the key exchange into the Hello messages. It also drops legacy cipher suites (RSA key exchange, RC4, 3DES), making it both faster and more secure.

Certificate chain verification: the server sends its **leaf certificate** (its own identity) plus any **intermediate CA certificates**. The browser walks the chain upward until it reaches a root CA it already trusts. A missing intermediate is one of the most common TLS misconfiguration bugs — the browser can't build the chain and the connection fails.

```
Certificate Chain:
  Root CA (trusted, in browser's store)
    └── Intermediate CA (signed by Root)
          └── Leaf Certificate (your server, signed by Intermediate)
```

For mTLS, both sides present certificates during the handshake:

```
mTLS additions to handshake:
  Server → Client : CertificateRequest
  Client → Server : Client Certificate + CertificateVerify (signature)
  Server          : verifies client cert against trusted CA list
```

**Must-memorise gotcha — TLS 1.3 reduces handshake from 2-RTT to 1-RTT:**

```java
// Spring Boot: enforce TLS 1.3 minimum in application.properties
// server.ssl.enabled-protocols=TLSv1.3
// server.ssl.protocol=TLS

// Programmatic check (useful in integration tests or diagnostics):
SSLContext ctx = SSLContext.getInstance("TLS");
ctx.init(null, null, null);
SSLEngine engine = ctx.createSSLEngine();
String[] supported = engine.getSupportedProtocols();
// Force only TLS 1.3:
engine.setEnabledProtocols(new String[]{"TLSv1.3"});
```

TLS 1.2 requires 2-RTT: one round trip to negotiate parameters, a second to exchange keys and finish. TLS 1.3 collapses this to 1-RTT by sending the Diffie-Hellman key share in the very first ClientHello. For latency-sensitive APIs this halves the handshake overhead.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"Walk me through what happens during a TLS handshake."**

**One-line answer:** The client and server negotiate a cipher, exchange keys, verify the server's identity via its certificate, and derive a shared session key — all before any application data is sent.

**Full answer to give in an interview:**

> "When a browser connects to an HTTPS server, the first thing that happens is a TLS handshake — no application data moves until this completes. In TLS 1.2 this takes two round trips. In the first, the client sends a ClientHello listing the cipher suites it supports and a random nonce. The server replies with its chosen cipher, its certificate — which is a signed document proving its identity — and its own nonce. The client then verifies the certificate by walking the chain from the server's leaf cert up through any intermediate CAs to a root CA it already trusts. If the chain is valid, the client uses the server's public key to send a pre-master secret, both sides derive the same symmetric session key from the two nonces and the pre-master secret, and they exchange Finished messages to confirm the handshake. TLS 1.3 improves on this by sending the Diffie-Hellman key share inside the ClientHello itself, so the server can derive keys and respond with its certificate and Finished in a single reply — cutting from 2-RTT down to 1-RTT. After the handshake, all traffic is encrypted with the symmetric session key, which is much faster than public-key operations."

> *Mention the 1-RTT improvement unprompted — interviewers love it.*

**Gotcha follow-up they'll ask:** *"What is certificate pinning and when would you use it?"*

> "Certificate pinning means hard-coding the expected certificate or its public key hash inside the client application. Instead of trusting any cert signed by any root CA, the client only accepts a specific cert or public key it already knows. This protects against a compromised or rogue CA issuing a fraudulent certificate for your domain — a real attack vector called a CA compromise. The downside is operational: if you rotate your certificate, every client must be updated simultaneously or it breaks. For this reason, pinning is mostly used in high-security mobile apps rather than web browsers, and you typically pin the intermediate CA's public key rather than the leaf cert to give yourself some rotation flexibility."

---

##### Q2 — Design Scenario
**"Why would you use mTLS for service-to-service communication instead of API keys?"**

**One-line answer:** mTLS provides cryptographic identity verification at the transport layer without secret distribution — the certificate itself is the credential, and compromise of one service's key doesn't expose others.

**Full answer to give in an interview:**

> "API keys are shared secrets — they can be leaked in logs, environment variables, or config files, and once leaked, an attacker can impersonate that service indefinitely until you rotate the key. mTLS, mutual TLS, takes a different approach: each service has its own certificate issued by an internal CA. During the TLS handshake, the server not only presents its certificate to the client, but also requests the client's certificate. The server verifies the client's cert was signed by the trusted internal CA, so the client's identity is proven cryptographically. There's no secret to leak — the private key never leaves the service. This is the model used by service meshes like Istio and Linkerd: they automatically provision and rotate short-lived certificates for every pod, and every inter-service call is mutually authenticated with zero developer effort. The tradeoff is operational complexity — you need a functioning internal CA and certificate lifecycle management. For simple internal APIs, API keys may be fine. For regulated environments or zero-trust architectures, mTLS is the right default."

> *Mentioning Istio/Linkerd shows production awareness.*

**Gotcha follow-up they'll ask:** *"What is HSTS and how does it relate to TLS?"*

> "HSTS — HTTP Strict Transport Security — is an HTTP response header that tells the browser: for this domain, only ever connect over HTTPS, and cache this instruction for a defined period. Once a browser has seen the HSTS header, it will automatically upgrade any future HTTP requests to HTTPS before they even leave the machine, and it will refuse to connect if the TLS certificate is invalid — no click-through warning. This prevents protocol-downgrade attacks, where an attacker intercepts the very first HTTP request before the server can redirect to HTTPS. The HSTS preload list goes even further: browsers ship with a hard-coded list of domains that must always be HTTPS, so even the first-ever connection is protected."

---

> **Common Mistake — Missing Intermediate Certificate:** Deploying only the leaf certificate without the intermediate CA certificates is one of the most common TLS setup errors. The server works for browsers that happen to have cached the intermediate, but fails for others — including many API clients and mobile apps. Always configure your server to send the full chain.

---

**Quick Revision (one line):**
TLS authenticates the server via certificate chains and derives a symmetric session key during a handshake; TLS 1.3 cuts this from 2-RTT to 1-RTT; mTLS adds client certificate verification for mutual service-to-service authentication.

---

## Topic 12: CORS

---

#### The Idea

Imagine your bank's website at `bank.com` runs JavaScript that reads your account balance. Now imagine a malicious page at `evil.com` also tries to run JavaScript that fetches `bank.com/api/balance` using your browser's cookies. Without any restriction, the evil page could silently read your bank data just because your browser sends cookies automatically. To prevent this, browsers enforce the **Same-Origin Policy**: JavaScript on one origin (scheme + host + port) cannot read responses from a different origin. `evil.com` cannot read `bank.com`'s responses.

But this creates a legitimate problem: modern applications are split across origins. Your frontend at `app.example.com` needs to call your API at `api.example.com`. These are different origins, so the browser would block every request. **CORS — Cross-Origin Resource Sharing** — is the mechanism that lets the *server* explicitly grant permission to specific foreign origins. The server adds response headers like `Access-Control-Allow-Origin: https://app.example.com` and the browser allows the JavaScript to read the response.

CORS is entirely a browser enforcement. Server-to-server calls, curl, Postman — none of these are subject to CORS. It only exists to protect users from malicious JavaScript running in their browser tab.

---

#### How It Works

```
Same-Origin Policy: requests are blocked if origin differs in scheme, host, or port.
  https://app.example.com  ≠  https://api.example.com   (different subdomain)
  https://example.com      ≠  http://example.com         (different scheme)
  https://example.com      ≠  https://example.com:8080   (different port)

Simple request (GET, HEAD, POST with plain text/form content-type):
  Browser → Server: GET /data  Origin: https://app.example.com
  Server  → Browser: 200 OK  Access-Control-Allow-Origin: https://app.example.com
  Browser: origin matches header → JavaScript can read the response

Preflight request (triggered by: PUT/DELETE/PATCH, custom headers, JSON body):
  Browser → Server: OPTIONS /data
                    Origin: https://app.example.com
                    Access-Control-Request-Method: DELETE
                    Access-Control-Request-Headers: Content-Type, Authorization
  Server  → Browser: 204 No Content
                    Access-Control-Allow-Origin: https://app.example.com
                    Access-Control-Allow-Methods: GET, POST, DELETE
                    Access-Control-Allow-Headers: Content-Type, Authorization
                    Access-Control-Max-Age: 3600   (cache preflight for 1 hour)
  Browser: preflight approved → sends actual DELETE request
```

**Spring Boot CORS configuration (the must-memorise gotcha — wildcard `*` breaks credentialed requests):**

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    // NEVER use setAllowedOrigins("*") with setAllowCredentials(true) —
    // the spec forbids it; browsers will block the response.
    config.setAllowedOriginPatterns(List.of("https://*.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);   // needed for cookie/session auth
    config.setMaxAge(3600L);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}

@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.cors(cors -> cors.configurationSource(corsConfigurationSource()));
    return http.build();
}
```

The wildcard `Access-Control-Allow-Origin: *` is fine for public, unauthenticated APIs. But the moment you add `Access-Control-Allow-Credentials: true` (required for cookie-based sessions or `Authorization` headers), the browser spec explicitly prohibits the wildcard — the browser will block the response even if the server sends both headers. You must name specific origins.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the Same-Origin Policy and why does CORS exist?"**

**One-line answer:** The Same-Origin Policy prevents JavaScript from reading cross-origin responses to protect users; CORS lets servers selectively relax that restriction for trusted origins.

**Full answer to give in an interview:**

> "Browsers enforce the Same-Origin Policy: JavaScript running at one origin — defined as the combination of scheme, hostname, and port — cannot read responses from a different origin. This exists to stop a malicious page from using your browser's cookies to silently read data from your bank or email. The browser will still send the request, but it will block the JavaScript from reading the response. CORS — Cross-Origin Resource Sharing — is the protocol that lets a server opt in to being read from other origins. The server adds `Access-Control-Allow-Origin` headers to its responses, and the browser allows the JavaScript to proceed. Crucially, CORS is a browser-only enforcement — it doesn't protect APIs from direct server-to-server calls, curl, or Postman. It's purely about protecting users from malicious JavaScript in their own browser tab."

> *Emphasising that CORS is browser-only shows you understand the threat model.*

**Gotcha follow-up they'll ask:** *"What triggers a preflight request and why does it exist?"*

> "A preflight is an automatic OPTIONS request the browser sends before the real request whenever the call is considered 'non-simple' — this means anything other than a plain GET, HEAD, or POST with a basic content type. PUT, DELETE, PATCH always trigger a preflight. So does adding custom headers like Authorization or Content-Type: application/json. The preflight exists because the browser needs to check whether the server will actually accept this kind of cross-origin request before committing to sending the full payload, which might have side effects. The server either approves or denies the preflight with CORS headers, and the browser then allows or blocks the real request. You can cache the preflight result with Access-Control-Max-Age to avoid the extra round trip on every call."

---

##### Q2 — Tradeoff Question
**"Why is `Access-Control-Allow-Origin: *` dangerous for authenticated APIs?"**

**One-line answer:** The wildcard allows any origin to read the response, but the spec prohibits using it together with `Allow-Credentials: true`, so it either breaks auth or leaves the API readable by any malicious site.

**Full answer to give in an interview:**

> "The wildcard `Access-Control-Allow-Origin: *` is perfectly fine for truly public APIs that don't use cookies or auth headers — think a public weather API. But for authenticated APIs, there are two problems. First, if you set both `Access-Control-Allow-Origin: *` and `Access-Control-Allow-Credentials: true`, the browser specification explicitly forbids it — the browser will block the response regardless of what the server sends, because allowing all origins to send credentials would let any website use your logged-in user's session. Second, even without credentials, a broad wildcard means any website in the world can read your API responses from a user's browser. The correct approach is to explicitly enumerate allowed origins using a pattern like `*.example.com`, set `Allow-Credentials: true` only if you're using cookie or session auth, and make sure your CORS configuration runs as a filter before Spring Security's authentication filter — otherwise preflight OPTIONS requests get rejected with 401 before the CORS headers are ever added."

> *The ordering point — CORS filter before auth filter — is a common production gotcha.*

**Gotcha follow-up they'll ask:** *"Does CORS protect the server from CSRF attacks?"*

> "No — and this is a critical distinction. CORS restricts which origins can read responses. It does not prevent a browser from sending the request in the first place. A forged form POST from a malicious site triggers a browser request that CORS won't stop — the response is blocked from being read by the evil page's JavaScript, but the server still processed the state-changing request. CSRF protection is a separate concern handled by CSRF tokens or SameSite cookies."

---

> **Common Mistake — CORS in the Wrong Filter Order:** Registering CORS configuration in Spring Security but not ensuring the CORS filter runs before authentication means preflight OPTIONS requests (which carry no credentials) get rejected with 401. Always wire CORS as the first filter in the chain, or use Spring's built-in `cors()` DSL which handles ordering automatically.

---

**Quick Revision (one line):**
CORS is a browser mechanism that lets servers grant cross-origin read access via response headers; never combine `Allow-Origin: *` with `Allow-Credentials: true`, and ensure CORS is configured before authentication filters.

---

## Topic 13: CSRF

---

#### The Idea

Imagine you are logged in to your bank at `bank.com`. Your session is stored in a cookie the browser sends automatically on every request. Now you visit `evil.com`, which contains a hidden HTML form that posts to `bank.com/transfer?to=attacker&amount=5000`. When the page loads, the form submits silently — your browser automatically attaches the `bank.com` cookie, the server sees a valid authenticated request, and the transfer goes through. You never clicked anything. This attack is **Cross-Site Request Forgery (CSRF)**: an attacker tricks your browser into making a state-changing request to a site where you are already authenticated.

CSRF is distinct from XSS (Cross-Site Scripting). XSS injects malicious JavaScript *into* the target site — the attacker runs code in the victim's origin. CSRF exploits the browser's automatic cookie behaviour to forge a request from a *different* site. XSS is about injecting code; CSRF is about forging requests. A site can be CSRF-vulnerable without being XSS-vulnerable, and vice versa.

The three main defences are: (1) **CSRF tokens** — a secret value embedded in each form that the server validates, which the attacker cannot read due to the Same-Origin Policy; (2) **SameSite cookies** — a modern cookie attribute telling the browser to not send the cookie on cross-site requests; and (3) checking the **Origin/Referer header** as a lightweight check. For stateless APIs using JWT in the Authorization header rather than cookies, CSRF does not apply at all.

---

#### How It Works

```
CSRF Attack Flow:
  User logs in to bank.com → browser stores session cookie (HttpOnly)
  User visits evil.com
  evil.com HTML:
    <form action="https://bank.com/transfer" method="POST">
      <input name="to" value="attacker">
      <input name="amount" value="5000">
    </form>
    <script>document.forms[0].submit()</script>
  Browser automatically sends bank.com cookie with the POST
  Server cannot distinguish this from a legitimate user action

CSRF Token Defence:
  Server embeds a unique, unguessable token in every form:
    <input type="hidden" name="_csrf" value="abc123xyz">
  Server stores the same token in the user's session
  On POST: server checks form token matches session token
  Attacker cannot read the token (Same-Origin Policy blocks reads from evil.com)

SameSite Cookie Defence (modern, preferred):
  Set-Cookie: sessionId=abc; SameSite=Strict; HttpOnly; Secure
    Strict → cookie never sent on any cross-site request (strongest)
    Lax    → cookie sent on top-level GET navigations but not POST/iframe/img
    None   → always sent (requires Secure; needed for third-party cookies)
```

**Spring Boot: disabling CSRF for a stateless JWT API (the must-memorise gotcha):**

```java
@Bean
@Order(1)
public SecurityFilterChain apiChain(HttpSecurity http) throws Exception {
    http
        .securityMatcher("/api/**")
        .csrf(AbstractHttpConfigurer::disable)  // safe: JWT in Authorization header, no cookies
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
    return http.build();
}

@Bean
@Order(2)
public SecurityFilterChain webChain(HttpSecurity http) throws Exception {
    http
        .securityMatcher("/**")
        // CSRF enabled by default — protects browser-facing form endpoints
        .csrf(csrf -> csrf
            .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse()))
        .formLogin(Customizer.withDefaults());
    return http.build();
}
```

The key insight: CSRF only matters when the browser automatically sends credentials (session cookies). JWT-based APIs where the client explicitly sets the `Authorization: Bearer <token>` header are immune — an attacker's forged request from `evil.com` cannot set arbitrary headers, so it cannot include the JWT. Disabling CSRF on these endpoints is correct and intentional.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between CSRF and XSS?"**

**One-line answer:** XSS injects malicious code into the target site's origin; CSRF exploits the browser's automatic cookie sending to forge authenticated requests from a different site.

**Full answer to give in an interview:**

> "They're two completely different attack classes that are often confused. XSS — Cross-Site Scripting — means an attacker manages to inject malicious JavaScript into the legitimate site itself, so when a victim visits the site, the attacker's code runs inside the victim's browser session with full access to cookies, DOM, and can make requests as the user. CSRF — Cross-Site Request Forgery — doesn't inject any code anywhere. Instead, it exploits the fact that browsers automatically attach cookies to every request to a domain, regardless of which site initiated the request. So if a victim is logged in to bank.com and visits evil.com, evil.com can cause the browser to send a POST to bank.com with the victim's cookie attached, forging a legitimate-looking request. The server can't tell it wasn't the user. The defence against XSS is input sanitisation and Content Security Policy. The defence against CSRF is CSRF tokens or SameSite cookies. A site hardened against XSS can still be CSRF-vulnerable."

> *The one-sentence contrast at the start lands well in interviews.*

**Gotcha follow-up they'll ask:** *"When is it safe to disable CSRF protection entirely?"*

> "It's safe to disable CSRF when the API is stateless and uses token-based authentication where the token is sent in an explicit header, not a cookie. Specifically, if every authenticated request requires an `Authorization: Bearer <jwt>` header, an attacker's forged request from evil.com cannot succeed — the browser's Same-Origin Policy prevents a cross-site page from setting arbitrary request headers, so the forged request arrives without the JWT and gets rejected as unauthenticated. Session-cookie-based APIs absolutely need CSRF protection because the cookie is sent automatically. In Spring Security you see this pattern in microservices: the /api/** chain disables CSRF and uses JWT resource server config, while a /admin UI chain keeps CSRF enabled with a cookie token repository for the browser-rendered forms."

---

##### Q2 — Tradeoff Question
**"Compare SameSite=Strict, SameSite=Lax, and SameSite=None. When would you use each?"**

**One-line answer:** Strict blocks the cookie on all cross-site requests; Lax allows it on safe top-level navigations; None sends it everywhere and requires the Secure flag.

**Full answer to give in an interview:**

> "SameSite is a cookie attribute that tells the browser when to include the cookie on cross-site requests. Strict means the cookie is never sent when the request originates from a different site — even if the user clicks a link from their email to your site, the first request arrives without the cookie and they get sent to a login page. This is the strongest CSRF protection but breaks some legitimate flows. Lax is the middle ground and is now the browser default: the cookie is sent on top-level GET navigations — clicking a link — but not on cross-site POST requests, iframes, or images. This stops the most common CSRF attack, the forged form POST, while keeping normal link navigation working. None means always send the cookie, required for third-party use cases like embedding your site in an iframe on a partner's domain — but it must be paired with Secure, meaning HTTPS only. My default for session cookies is Lax, which eliminates the most impactful CSRF vectors without breaking user experience. I add explicit CSRF tokens for any especially sensitive operations like account deletion or fund transfers."

> *Mentioning browser-default Lax shows you track spec evolution.*

**Gotcha follow-up they'll ask:** *"Does SameSite=Lax fully replace CSRF tokens?"*

> "For most applications, Lax provides very strong practical protection. But there are edge cases: older browsers don't support SameSite, some CDN or proxy configurations strip cookie attributes, and certain patterns like OAuth redirect flows legitimately use top-level POST. CSRF tokens remain the belt-and-suspenders defence for high-sensitivity operations. In practice, modern Spring Security's default of combining a CSRF token with SameSite=Lax gives defence in depth."

---

> **Common Mistake — Disabling CSRF on Cookie-Based APIs:** Developers sometimes disable CSRF protection across the board because they see examples doing it for REST APIs, without realising their API still uses session cookies for authentication. If your frontend stores the session in a cookie, you need CSRF protection regardless of whether the API returns JSON.

---

**Quick Revision (one line):**
CSRF forges cookie-authenticated requests from a foreign site; defend with SameSite=Lax cookies and CSRF tokens for sensitive endpoints; stateless JWT APIs with explicit Authorization headers are immune and can safely disable CSRF.

---

## Topic 14: OWASP Top 10 for APIs

---

#### The Idea

Every year the Open Web Application Security Project publishes a list of the most critical security risks for APIs. Rather than a theoretical catalogue, it is distilled from real breach data — the categories that actually caused production incidents at companies worldwide. Understanding the list means you can design APIs that don't have the same holes.

The most impactful category for backend developers is **Broken Object Level Authorization (BOLA)**, also called IDOR — Insecure Direct Object Reference. The idea is simple: your API accepts a resource ID from the caller, but never checks whether the caller actually owns that resource. An attacker changes the ID in the URL from their own to someone else's and gets the other person's data. Facebook's 2018 breach involved a variant of this. It is the single most commonly exploited API flaw.

Beyond BOLA, the list covers broken authentication, excessive data exposure, missing rate limiting, security misconfiguration, and injection. Each represents a class of mistake that is easy to make when moving fast and easy to fix when you know to look for it.

---

#### How It Works

```
BOLA / IDOR — The most common API flaw:
  GET /api/orders/12345   → attacker changes to /api/orders/12346
  Server returns order 12346 (belongs to another user) without checking ownership

Correct fix:
  if (!order.getUserId().equals(currentUser.getId())) {
      throw new AccessDeniedException("Not your order");
  }

Broken Authentication:
  - Weak JWT validation (not checking signature, accepting "alg: none")
  - Missing token expiry checks
  - Passwords stored in plain text or with fast hash (MD5, SHA-1)

Excessive Data Exposure:
  - API returns full User object including passwordHash, internalNotes
  - Client filters — relies on frontend to hide sensitive fields
  - Fix: use DTOs/projections, return only what the caller needs

Rate Limiting Missing:
  POST /api/login — no limit → brute-force attack on passwords
  POST /api/otp/verify — no limit → brute-force 6-digit OTP in 1M requests

Security Misconfiguration:
  - CORS: Access-Control-Allow-Origin: *  on authenticated endpoints
  - HTTP instead of HTTPS in production
  - Stack traces returned in error responses (exposes class names, paths)
  - Default credentials (admin/admin) not changed

Injection:
  - SQL: "SELECT * FROM users WHERE name = '" + userInput + "'"
  - Fix: always use parameterized queries / PreparedStatement
```

**Must-memorise pattern — BOLA check with Spring Security:**

```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @GetMapping("/{orderId}")
    @PreAuthorize("isAuthenticated()")
    public OrderDTO getOrder(@PathVariable Long orderId,
                              Authentication auth) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));

        // BOLA check: verify the caller owns this resource
        String currentUserId = auth.getName();
        if (!order.getUserId().equals(currentUserId)) {
            // Return 404, not 403 — don't confirm the resource exists
            throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
        return toDTO(order);
    }

    @PostMapping
    public UserDTO createUser(@RequestBody CreateUserRequest req) {
        // Never use user-supplied URL for redirect — SSRF risk
        // Never build SQL with string concat — use parameterized queries
        String sql = "SELECT * FROM users WHERE email = ?";  // correct
        // String sql = "SELECT * FROM users WHERE email = '" + req.getEmail() + "'"; // WRONG
        return userRepository.save(toEntity(req));
    }
}
```

Return 404, not 403, when a resource ID exists but doesn't belong to the caller — a 403 confirms the resource exists and helps an attacker enumerate valid IDs.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is BOLA and why is it the most common API vulnerability?"**

**One-line answer:** BOLA means the API accepts a resource ID without verifying the caller owns it — trivial to exploit, easy to miss in code review, and in almost every API that handles user-owned data.

**Full answer to give in an interview:**

> "BOLA stands for Broken Object Level Authorization — it's OWASP API Security's number one risk and the root cause of a huge proportion of real API breaches. The pattern is this: an API endpoint accepts a resource identifier like an order ID, a user ID, or a document ID as a URL parameter or request body field. The code fetches the object from the database and returns it, but never checks whether the authenticated caller actually has permission to access that specific object. An attacker who has a valid account simply changes the ID — going from their order 12345 to a neighbour's order 12346 — and receives data they shouldn't see. It's called Insecure Direct Object Reference in older OWASP docs. It's the most common vulnerability because it's an authorization logic gap, not a library misconfiguration — automated scanners often miss it, code reviewers miss it because the code looks normal, and it exists in every API that manages user-owned resources. The fix is always the same: after fetching the object, compare the object's owner ID to the authenticated user's ID. If they don't match, return 404 — not 403, because 403 tells the attacker the resource exists."

> *The 404 vs 403 detail is frequently asked as an immediate follow-up.*

**Gotcha follow-up they'll ask:** *"What is Broken Function Level Authorization and how is it different from BOLA?"*

> "Broken Object Level Authorization is about accessing the wrong instance of a resource — the right type of object, wrong owner. Broken Function Level Authorization is about calling functions you shouldn't be allowed to call at all — for example, a regular user calling a DELETE endpoint that should be admin-only. BOLA is row-level access control: can this user see this specific row? BFLA is operation-level access control: can this user perform this type of operation? Both are authorization failures, but they require different fixes. BOLA is fixed by ownership checks inside endpoint logic. BFLA is fixed by role-based access control — annotating endpoints with @PreAuthorize('hasRole(ADMIN)') in Spring and ensuring every sensitive endpoint is explicitly secured rather than relying on deny-by-default."

---

##### Q2 — Design Scenario
**"You are designing an API for a multi-tenant SaaS. What OWASP risks are most relevant and how do you address them?"**

**One-line answer:** BOLA (tenants accessing each other's data), Excessive Data Exposure (returning internal fields), and Security Misconfiguration (missing rate limiting, verbose errors) are the top three.

**Full answer to give in an interview:**

> "For a multi-tenant SaaS, BOLA is the first thing I'd harden. Every data-access endpoint must verify not just that the caller is authenticated, but that the resource they're requesting belongs to their tenant. I'd add a tenant ID to the security context and enforce it at the repository layer — for example, all queries include `WHERE tenant_id = ?` — so it's impossible to forget the check at the controller level. Second, Excessive Data Exposure: APIs often return full entity objects that include internal fields — created_by admin, internal notes, password hashes, pricing cost data. I'd define explicit DTO projections for every API response and review them with the principle of minimum disclosure. Third, Security Misconfiguration: stack traces in production error responses hand attackers class names, file paths, and framework versions. I'd configure a global exception handler that maps all unhandled exceptions to a generic 500 body in production. Rate limiting is also essential — authentication endpoints without limits are trivially brute-forced. I'd apply rate limiting at the API gateway for /login, /register, and OTP verification. Finally, injection: all database access through parameterized queries or ORM — never string concatenation."

> *Layering the answer by risk category shows structured thinking.*

**Gotcha follow-up they'll ask:** *"What is Security Misconfiguration in the OWASP context specifically?"*

> "OWASP defines Security Misconfiguration broadly: it includes any configuration that leaves the system in an insecure state by default or through omission. Common examples: CORS wildcard on authenticated endpoints, HTTP enabled alongside HTTPS in production, default credentials not changed on databases or admin consoles, verbose error messages exposing internals, unnecessary HTTP methods enabled — like TRACE or DELETE on endpoints that should be read-only, debug endpoints left open in production, and missing security headers like Content-Security-Policy or X-Frame-Options. The common thread is that these aren't coding bugs — they're deployment and configuration gaps, which is why security review should include infrastructure and config, not just source code."

---

> **Common Mistake — Trusting Client-Side Filtering for Sensitive Fields:** Returning the full database entity and relying on the frontend to hide sensitive fields is Excessive Data Exposure — a top-10 OWASP risk. Any attacker calling the API directly receives all fields regardless of what the UI hides. Always use server-side DTOs to control what is returned.

---

**Quick Revision (one line):**
OWASP API Top 10 covers BOLA (no ownership check), Broken Auth (weak tokens/passwords), Excessive Data Exposure (returning internal fields), missing Rate Limiting, Security Misconfiguration (verbose errors, open CORS), and Injection — address each at the design stage, not as an afterthought.

---

## Topic 15: Secrets Management

---

#### The Idea

Every application needs secrets: database passwords, API keys, encryption keys, service account credentials. The naive approach is to put them in configuration files or environment variables and commit them to source control. This fails catastrophically when repos are exposed, when developers copy config files, or when secrets need to be rotated — you have to find and update every place the secret lives.

A secrets manager solves this by treating secrets as a separate, audited, access-controlled system. **HashiCorp Vault** is the most widely used: it stores secrets encrypted at rest, provides fine-grained access policies, maintains a full audit log of every secret access, and — most powerfully — can generate **dynamic secrets**. Instead of giving every service the same static database password, Vault creates a unique, short-lived database credential for each service on demand. When the credential's lease expires, it is automatically revoked. Even if an attacker intercepts a credential, it expires in minutes or hours.

For Spring Boot applications, **Spring Cloud Vault** integrates Vault transparently — your code uses familiar `@Value("${db.password}")` annotations and the actual secret is fetched from Vault at startup (and optionally refreshed at runtime). This means developers never see or touch production secrets.

---

#### How It Works

```
Static Secrets (naive approach — avoid):
  Vault KV store:
    vault kv put secret/myapp db.password=staticP@ss123
  Application reads once at startup, uses forever.
  Problem: same credential everywhere, long-lived, hard to rotate.

Dynamic Secrets (Vault's power feature):
  Vault Database Secrets Engine configured for PostgreSQL:
    vault write database/roles/myapp-role \
      db_name=mydb \
      creation_statements="CREATE USER {{name}} WITH PASSWORD '{{password}}' ..." \
      default_ttl=1h \
      max_ttl=24h

  At runtime:
    Application asks Vault: GET /v1/database/creds/myapp-role
    Vault creates a new PostgreSQL user with a unique password, TTL 1 hour
    Returns: { username: "v-myapp-abc123", password: "A1b2C3d4...", lease_duration: 3600 }
    Application uses this credential for its connection pool.
    After 1 hour, Vault automatically revokes the PostgreSQL user.

  Benefits:
    - Each instance gets a unique credential
    - Compromise of one credential expires on its own
    - Full audit log: which instance got which credential, when
```

**Must-memorise gotcha — Spring Cloud Vault `@Value` injection pattern:**

```java
// pom.xml dependencies:
// spring-cloud-starter-vault-config
// spring-cloud-vault-config-databases (for dynamic DB secrets)

// bootstrap.yml (loaded before application context):
// spring:
//   cloud:
//     vault:
//       host: vault.internal.example.com
//       port: 8200
//       scheme: https
//       authentication: KUBERNETES   # uses pod's service account token
//       kv:
//         enabled: true
//         default-context: myapp

// In your Spring component — no Vault SDK code needed:
@Component
public class DatabaseConfig {

    // Spring Cloud Vault populates this from Vault KV secret/myapp/db.url
    @Value("${db.url}")
    private String dbUrl;

    // For dynamic secrets, Spring Cloud Vault fetches from database/creds/myapp-role
    // and maps to spring.datasource.username / spring.datasource.password automatically
    @Value("${spring.datasource.username}")
    private String dbUsername;

    @Value("${spring.datasource.password}")
    private String dbPassword;
}

// Secret rotation without restart (requires Spring Cloud Config + @RefreshScope):
@RefreshScope
@Component
public class ApiKeyHolder {
    @Value("${external.api.key}")
    private String apiKey;
    // POST /actuator/refresh triggers Vault re-fetch and bean re-initialisation
}
```

The critical distinction: **static secrets** (KV engine) are just stored key-value pairs — better than env vars but still long-lived. **Dynamic secrets** (Database, AWS, PKI engines) are generated per-request with a TTL and automatically revoked — this is the model that makes credential theft largely useless. For interview purposes, be able to explain this difference and name the lease/renewal lifecycle.

---

#### Interview Lens

> **How to use this section:** Each question is self-contained — read it the night before an interview and walk in prepared. Every concept is explained inline.

> *Tip: Lead with the one-line answer. Pause. Expand only if the interviewer nods or probes.*

---

##### Q1 — Concept Check
**"What is the difference between static secrets and dynamic secrets in HashiCorp Vault?"**

**One-line answer:** Static secrets are stored key-value pairs you read and use indefinitely; dynamic secrets are generated on demand with a short TTL and automatically revoked — making stolen credentials expire harmlessly.

**Full answer to give in an interview:**

> "Vault's KV secrets engine is essentially an encrypted key-value store — you write a secret in, applications read it out. This is a significant improvement over environment variables or config files because you get encryption at rest, access control policies, and an audit log. But the secret itself is static and long-lived — if it leaks, an attacker has it until someone manually rotates it. Vault's dynamic secrets engines are fundamentally different. With the Database secrets engine, Vault is configured with a privileged connection to your database. When an application requests credentials, Vault creates a brand new database user with a unique username and password and a TTL — say, one hour. It returns those credentials to the application. When the TTL expires, Vault automatically drops that database user. Even if an attacker intercepts the credential in transit, it expires in at most one hour. Every application instance gets its own unique credential, so a breach of one instance doesn't compromise others. The same model exists for AWS IAM credentials, PKI certificates, and SSH keys. This is what people mean when they say 'secrets that expire on their own' — it shifts security from prevention-only to prevention-plus-blast-radius-limitation."

> *The blast-radius framing shows security engineering maturity.*

**Gotcha follow-up they'll ask:** *"How does Vault authentication work in a Kubernetes environment?"*

> "In Kubernetes, Vault uses the Kubernetes auth method. Each pod has a service account, and Kubernetes automatically mounts a JWT token for that service account into the pod's filesystem. When the application starts, it presents this token to Vault along with the name of its Kubernetes role. Vault calls the Kubernetes API to verify the token is valid and that the pod's service account matches the expected role, then issues a Vault token with the policies attached to that role. This means no static Vault token needs to be injected into the pod — the pod's Kubernetes identity is the credential. Spring Cloud Vault with KUBERNETES authentication handles this automatically: it reads the service account token from the standard mount path and performs the auth exchange before the application context loads."

---

##### Q2 — Design Scenario
**"How would you handle secret rotation in a production system without downtime?"**

**One-line answer:** Use Vault's lease renewal so running applications extend their dynamic credential TTL, while new instances get fresh credentials — rotation is continuous rather than a coordinated cutover.

**Full answer to give in an interview:**

> "For dynamic secrets, rotation is largely automatic — each credential has a TTL, and the application uses Vault's lease renewal API to extend it before it expires. Spring Cloud Vault handles this with a background thread that renews leases at roughly two-thirds of the TTL. If the lease can't be renewed — because the max TTL was reached — the application requests a new credential. With a properly configured connection pool that can refresh credentials, this is transparent. For static secrets — a third-party API key that can't be dynamically generated — the pattern is versioned secrets. You write the new key to Vault at a new version, then do a rolling restart of your pods: Kubernetes brings up new pods that read the new key, and old pods drain and shut down. Because you're rolling, not all-at-once, there's always traffic flowing. The key is the old version remains valid during the rollout window — you revoke it only after all pods have moved to the new key. AWS Secrets Manager has built-in rotation support that handles this window automatically for RDS credentials: it writes the new password to the database, updates the secret, and only then revokes the old one."

> *Mentioning the rollout window and revocation timing shows operational depth.*

**Gotcha follow-up they'll ask:** *"How do you prevent secrets from leaking into logs or heap dumps?"*

> "Three practices. First, never log request bodies or configuration properties that might contain secrets — use structured logging frameworks that explicitly allowlist fields rather than logging everything. Second, wrap secret values in types that override toString() to return a masked value — Spring Security's PasswordEncoder does this, and you can do it for custom secret types. Third, for heap dump safety, store secrets in byte arrays rather than Strings: Strings are immutable and interned in the JVM's string pool, potentially persisting longer than expected. Byte arrays can be zeroed out after use. This matters most for cryptographic keys handled inside the application. For configuration properties like database passwords, there's less you can do once they're loaded into a DataSource — the real defence is restricting who can take heap dumps in production."

---

> **Common Mistake — Committing Secrets to Source Control:** Even in private repositories, secrets committed to git are permanent — they exist in the full commit history and in every clone ever made. Tools like git-secrets, truffleHog, or GitHub's secret scanning can detect this, but the correct fix is to rotate every exposed secret immediately and use a pre-commit hook to prevent future accidents. Vault or a cloud secrets manager eliminates this risk entirely by ensuring secrets never appear in config files.

---

**Quick Revision (one line):**
Use HashiCorp Vault dynamic secrets (auto-generated, short-TTL, auto-revoked credentials) over static KV secrets wherever possible; Spring Cloud Vault's `@Value` injection and Kubernetes auth method make integration transparent without any secret ever touching a config file or environment variable.
