# Volume 3: Backend Systems
# Chapter 13: Security — JWT, OAuth2, Spring Security

---

## Table of Contents

1. [Authentication vs Authorization](#topic-1-authentication-vs-authorization)
2. [JWT Structure and Signing](#topic-2-jwt-structure-and-signing)
3. [JWT Validation](#topic-3-jwt-validation)
4. [OAuth2 Roles and Overview](#topic-4-oauth2-roles-and-overview)
5. [OAuth2 Grant Types](#topic-5-oauth2-grant-types)
6. [OpenID Connect (OIDC)](#topic-6-openid-connect-oidc)
7. [Spring Security Architecture](#topic-7-spring-security-architecture)
8. [Spring Security JWT Integration](#topic-8-spring-security-jwt-integration)
9. [Spring Security OAuth2 Resource Server](#topic-9-spring-security-oauth2-resource-server)
10. [Password Storage](#topic-10-password-storage)
11. [HTTPS and TLS](#topic-11-https-and-tls)
12. [CORS](#topic-12-cors)
13. [CSRF](#topic-13-csrf)
14. [OWASP Top 10 for APIs](#topic-14-owasp-top-10-for-apis)
15. [Secrets Management](#topic-15-secrets-management)

---

### Topic 1: Authentication vs Authorization

**Difficulty:** Easy | **Frequency:** High | **Companies:** Google, Amazon, Goldman Sachs, Stripe, Okta, Meta

**Q: What is the difference between Authentication and Authorization? How does the AAA framework relate to them?**

**Short Answer (2-3 sentences):**
Authentication (AuthN) is the process of verifying *who* a user is — confirming identity via credentials like username/password or tokens. Authorization (AuthZ) is the process of determining *what* an authenticated user is allowed to do — checking permissions and roles. The AAA framework extends this with Accounting (auditing/logging), completing the security triad used in enterprise and network security.

**Deep Explanation:**
Authentication answers "Who are you?" and typically involves one or more factors:
- Something you know (password, PIN)
- Something you have (OTP device, hardware key)
- Something you are (biometrics)

Authorization answers "What are you allowed to do?" and is evaluated *after* authentication. Common models include:
- **RBAC (Role-Based Access Control):** Permissions assigned to roles, users assigned to roles. E.g., `ROLE_ADMIN` can delete users.
- **ABAC (Attribute-Based Access Control):** Fine-grained policies based on user attributes, resource attributes, environment. E.g., "user in department=HR can read salary records during business hours."
- **PBAC (Policy-Based Access Control):** Centralized policy engine (like OPA) evaluates decisions.

**AAA Framework:**
- **Authentication:** Identity verification
- **Authorization:** Permission checks
- **Accounting:** Logging who did what, when, for audit trails, billing, forensics

In Spring Security, authentication is handled by `AuthenticationManager` + `AuthenticationProvider`, and authorization by `AccessDecisionManager` / `AuthorizationManager`. The `SecurityContext` holds the authenticated principal, which downstream authorization checks interrogate.

**Real-World Example:**
At Stripe, when you call the API:
1. **Authentication:** Your API key is validated — Stripe confirms you are the account owner.
2. **Authorization:** Stripe checks whether your key has permission to perform the requested operation (e.g., a restricted key may be authorized only to create charges, not issue refunds).
3. **Accounting:** Every API call is logged with timestamp, IP, and outcome for fraud detection and audit.

**Code Example:**
```java
// Spring Security 6.x — separating AuthN vs AuthZ

@Configuration
@EnableWebSecurity
@EnableMethodSecurity   // enables @PreAuthorize, @PostAuthorize
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // Authentication: every request must present a valid JWT
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            // Authorization: role-based access rules
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/users/**").hasAnyRole("USER", "ADMIN")
                .anyRequest().authenticated()
            );
        return http.build();
    }
}

// Service layer — fine-grained authorization via SpEL
@Service
public class OrderService {

    // AuthN already done by filter; this is AuthZ
    @PreAuthorize("hasRole('ADMIN') or #userId == authentication.name")
    public Order getOrder(String userId, Long orderId) {
        return orderRepository.findByIdAndUserId(orderId, userId)
            .orElseThrow(() -> new AccessDeniedException("Order not found"));
    }
}
```

**Follow-up Questions:**
1. How does Spring Security propagate the authenticated principal across a multi-threaded application?
2. What is the difference between RBAC and ABAC, and when would you choose one over the other?
3. How would you implement row-level security (e.g., a user can only see their own records) in Spring?

**Common Mistakes:**
- Confusing authentication failure (401 Unauthorized) with authorization failure (403 Forbidden) — they have distinct HTTP status codes for a reason.
- Performing authorization checks only at the API gateway layer and skipping them in the service layer, creating a bypass risk.

**Interview Traps:**
- Interviewers sometimes ask "What does a 401 response mean?" — the correct answer is "unauthenticated" (not "unauthorized"), despite the HTTP spec naming it "Unauthorized."
- "Can authorization happen without authentication?" — yes, for public resources (`permitAll()`), but any access to protected resources requires prior authentication.

**Quick Revision (1-liner):**
Authentication = proving identity; Authorization = enforcing permissions; AAA adds Accounting for auditability.

---

### Topic 2: JWT Structure and Signing

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Stripe, Okta, Netflix, Goldman Sachs

**Q: Explain the structure of a JWT. What is the difference between HS256 and RS256 signing algorithms, and when would you use each?**

**Short Answer (2-3 sentences):**
A JWT is three Base64URL-encoded segments separated by dots: `header.payload.signature`. The header declares the token type and algorithm; the payload carries claims (user data); the signature ensures tamper-proofing. HS256 uses a shared symmetric secret (one key for both signing and verification), while RS256 uses an asymmetric RSA key pair (private key signs, public key verifies) — use RS256 when multiple services need to verify tokens without trusting each other with a shared secret.

**Deep Explanation:**

**Header:**
```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "key-id-2024"   // key ID for rotation support
}
```

**Payload (Claims):**
```json
{
  "iss": "https://auth.example.com",      // issuer
  "sub": "user-12345",                     // subject (user ID)
  "aud": "https://api.example.com",        // audience
  "exp": 1720000000,                       // expiry (Unix timestamp)
  "iat": 1719996400,                       // issued at
  "nbf": 1719996400,                       // not before
  "jti": "unique-token-id",               // JWT ID (for revocation)
  "roles": ["USER", "BILLING"],           // custom claim
  "email": "user@example.com"
}
```

**Signature (RS256):**
```
RSA_SIGN(
  SHA256(base64url(header) + "." + base64url(payload)),
  privateKey
)
```

**HS256 vs RS256:**

| Aspect | HS256 | RS256 |
|---|---|---|
| Algorithm | HMAC-SHA256 (symmetric) | RSA-SHA256 (asymmetric) |
| Key | Single shared secret | Private key (sign) + Public key (verify) |
| Use case | Single service owns both issuing and verifying | Multiple verifying services, distributed systems |
| Key distribution risk | High — every verifier must know the secret | Low — only public key shared |
| Performance | Faster | Slower (RSA math) |
| Key rotation | Must update all services simultaneously | Rotate private key; publish new public key via JWKS endpoint |

**ES256 (ECDSA):** An increasingly preferred alternative to RS256 — smaller keys, faster computation, equivalent security.

**JWKS (JSON Web Key Set):** Authorization Servers publish public keys at a `.well-known/jwks.json` endpoint so Resource Servers can auto-fetch and cache them for RS256/ES256 verification.

**Real-World Example:**
Okta (an identity provider) issues RS256-signed JWTs. Your API server fetches Okta's JWKS endpoint (`https://dev-xxx.okta.com/oauth2/default/v1/keys`) at startup and caches the public keys. When a request arrives, the API server verifies the JWT signature using the cached public key — Okta's private key never leaves Okta's infrastructure.

**Code Example:**
```java
// Spring Boot 3.x — RS256 JWT verification via JWKS endpoint
// application.yml:
// spring:
//   security:
//     oauth2:
//       resourceserver:
//         jwt:
//           jwk-set-uri: https://auth.example.com/.well-known/jwks.json

@Configuration
@EnableWebSecurity
public class ResourceServerConfig {

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

    @Bean
    public JwtAuthenticationConverter jwtAuthConverter() {
        JwtGrantedAuthoritiesConverter converter = new JwtGrantedAuthoritiesConverter();
        converter.setAuthoritiesClaimName("roles");          // custom claim name
        converter.setAuthorityPrefix("ROLE_");              // Spring Security prefix

        JwtAuthenticationConverter authConverter = new JwtAuthenticationConverter();
        authConverter.setJwtGrantedAuthoritiesConverter(converter);
        return authConverter;
    }
}

// Manual JWT creation (e.g., for testing or custom auth server)
@Service
public class JwtService {
    private final RSAPrivateKey privateKey;
    private final RSAPublicKey publicKey;

    public String generateToken(UserDetails user) {
        return JWT.create()
            .withIssuer("https://auth.example.com")
            .withSubject(user.getUsername())
            .withAudience("https://api.example.com")
            .withIssuedAt(Instant.now())
            .withExpiresAt(Instant.now().plusSeconds(3600))
            .withClaim("roles", user.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority).toList())
            .sign(Algorithm.RSA256(publicKey, privateKey));  // auth0/java-jwt
    }
}
```

**Follow-up Questions:**
1. What is the `kid` (Key ID) header claim used for, and how does it support key rotation?
2. Why is the JWT payload not encrypted by default — is it safe to store user data in it?
3. What is the difference between JWT and JWE (JSON Web Encryption)?

**Common Mistakes:**
- Storing sensitive data (SSN, credit card numbers) in JWT payload — the payload is Base64-encoded, not encrypted, and is trivially readable.
- Using `alg: none` — some early libraries allowed unsigned tokens; always explicitly whitelist allowed algorithms.

**Interview Traps:**
- "Is JWT secure?" — the token itself provides integrity (signature), not confidentiality. Sensitive claims need JWE or should not be in the token.
- The `alg: none` attack: an attacker strips the signature and sets `alg: none`. Libraries that blindly trust the header's algorithm claim will accept the unsigned token. Always validate the algorithm server-side.

**Quick Revision (1-liner):**
JWT = header.payload.signature; HS256 uses a shared secret, RS256 uses asymmetric keys — prefer RS256 for distributed systems.

---

### Topic 3: JWT Validation

**Difficulty:** Medium | **Frequency:** High | **Companies:** Stripe, Okta, Amazon, Goldman Sachs, Atlassian

**Q: What steps must a server perform to fully validate an incoming JWT? Describe the token refresh strategy.**

**Short Answer (2-3 sentences):**
Full JWT validation involves: (1) verifying the signature using the correct key, (2) checking the `exp` claim (not expired), (3) checking `nbf` (not-before), (4) validating `iss` (issuer) and `aud` (audience) to prevent token misuse across services. A refresh strategy uses a short-lived access token paired with a longer-lived refresh token — when the access token expires, the client presents the refresh token to get a new access token without re-authenticating.

**Deep Explanation:**

**Validation Checklist (in order):**

1. **Parse:** Decode the three Base64URL segments without error.
2. **Algorithm:** Confirm `alg` header matches your allowed list (never accept `none`).
3. **Signature:** Verify using the key identified by `kid` header (fetched from JWKS or config).
4. **`exp` (Expiry):** `current_time < exp`. Reject if expired. Allow small clock skew (e.g., ±30s).
5. **`nbf` (Not Before):** `current_time >= nbf`. Token not yet valid if before this time.
6. **`iat` (Issued At):** Optionally reject tokens issued too far in the past (defense-in-depth).
7. **`iss` (Issuer):** Must match the expected issuer URL exactly.
8. **`aud` (Audience):** Must contain your service's identifier. Prevents token reuse across services.
9. **`jti` (JWT ID):** Check against a revocation list (Redis blacklist) if token revocation is required.

**Token Refresh Strategy:**

```
Access Token:  short-lived (5-15 minutes)
Refresh Token: longer-lived (hours to days), stored securely, rotated on use
```

**Refresh Token Rotation:** Each time a refresh token is used, issue a new one and invalidate the old one. If an old refresh token is replayed, it indicates theft — invalidate the entire token family.

**Silent Refresh:** The client proactively refreshes the access token before it expires (e.g., at 80% of TTL) to avoid visible latency.

**Real-World Example:**
Google's OAuth2 issues access tokens valid for 1 hour. When the access token expires, the client app uses a stored refresh token to call `https://oauth2.googleapis.com/token`. Google validates the refresh token, issues a new access token (and sometimes a new refresh token), and the user never sees a login prompt. If the refresh token is compromised and used twice, Google detects the replay and revokes the entire session.

**Code Example:**
```java
// Spring Security 6.x — custom JWT validation with audience and issuer checks
@Configuration
public class JwtDecoderConfig {

    @Value("${spring.security.oauth2.resourceserver.jwt.jwk-set-uri}")
    private String jwkSetUri;

    @Bean
    public JwtDecoder jwtDecoder() {
        NimbusJwtDecoder decoder = NimbusJwtDecoder
            .withJwkSetUri(jwkSetUri)
            .jwsAlgorithm(SignatureAlgorithm.RS256)   // whitelist algorithm
            .build();

        // Compose multiple validators
        OAuth2TokenValidator<Jwt> defaults = JwtValidators.createDefaultWithIssuer(
            "https://auth.example.com"
        );
        OAuth2TokenValidator<Jwt> audienceValidator = new AudienceValidator(
            List.of("https://api.example.com")
        );
        OAuth2TokenValidator<Jwt> combined =
            new DelegatingOAuth2TokenValidator<>(defaults, audienceValidator);

        decoder.setJwtValidator(combined);
        return decoder;
    }
}

// Custom audience validator
public class AudienceValidator implements OAuth2TokenValidator<Jwt> {
    private final List<String> allowedAudiences;

    public AudienceValidator(List<String> allowedAudiences) {
        this.allowedAudiences = allowedAudiences;
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        List<String> tokenAudiences = jwt.getAudience();
        boolean valid = tokenAudiences.stream()
            .anyMatch(allowedAudiences::contains);
        if (valid) {
            return OAuth2TokenValidatorResult.success();
        }
        OAuth2Error error = new OAuth2Error("invalid_token",
            "Token audience does not match expected audience", null);
        return OAuth2TokenValidatorResult.failure(error);
    }
}

// Token refresh endpoint (simplified)
@RestController
@RequestMapping("/auth")
public class AuthController {

    @PostMapping("/refresh")
    public ResponseEntity<TokenResponse> refresh(
            @RequestBody RefreshRequest request) {
        String refreshToken = request.getRefreshToken();

        // 1. Validate refresh token (signature, expiry, not revoked)
        RefreshTokenEntity entity = refreshTokenService.validate(refreshToken);

        // 2. Rotate: invalidate old refresh token
        refreshTokenService.invalidate(refreshToken);

        // 3. Issue new tokens
        String newAccessToken = jwtService.generateAccessToken(entity.getUserId());
        String newRefreshToken = refreshTokenService.issue(entity.getUserId());

        return ResponseEntity.ok(new TokenResponse(newAccessToken, newRefreshToken));
    }
}
```

**Follow-up Questions:**
1. How do you implement JWT revocation without losing the stateless benefits of JWT?
2. What is the recommended storage location for refresh tokens in a browser-based SPA?
3. How would you handle clock skew between the issuer and your validation server?

**Common Mistakes:**
- Not validating the `aud` claim — a JWT issued for service A could be replayed against service B.
- Storing refresh tokens in `localStorage` — they are vulnerable to XSS; prefer `HttpOnly` cookies.

**Interview Traps:**
- "JWT is stateless — can you revoke a JWT?" — strictly, no, without a blacklist. Short expiry + refresh token rotation is the practical answer. A blacklist (Redis) allows revocation but reintroduces statefulness.
- Ignoring the `nbf` claim can allow tokens to be used before their intended validity window.

**Quick Revision (1-liner):**
Validate: signature → algorithm → exp → nbf → iss → aud → jti; use short-lived access tokens + rotating refresh tokens.

---

### Topic 4: OAuth2 Roles and Overview

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Okta, Stripe, Amazon, Meta

**Q: Describe the four OAuth2 roles. What problem does OAuth2 solve that basic authentication cannot?**

**Short Answer (2-3 sentences):**
OAuth2 defines four roles: Resource Owner (user), Client (the app requesting access), Authorization Server (issues tokens), and Resource Server (hosts protected resources). OAuth2 solves the "credential sharing" problem — instead of giving a third-party app your password, you grant it a scoped, revocable access token. This enables fine-grained delegation without exposing credentials.

**Deep Explanation:**

**The Four OAuth2 Roles (RFC 6749):**

| Role | Description | Example |
|---|---|---|
| **Resource Owner** | The entity that owns the data and can grant access | End user (you) |
| **Client** | Application requesting access on behalf of the Resource Owner | A calendar app wanting Google Calendar access |
| **Authorization Server** | Authenticates the Resource Owner and issues tokens | Google Auth (`accounts.google.com`) |
| **Resource Server** | Hosts the protected resources, accepts tokens | Google Calendar API |

**The Core Problem OAuth2 Solves:**

*Before OAuth2:* To let a third-party app access your Gmail, you had to give it your Google password. This was dangerous:
- The app stored your password
- The app had full access to your entire account
- Revoking access required changing your password

*With OAuth2:*
- You authenticate to Google (not the app)
- You grant the app a scoped token (e.g., `read:calendar` only)
- The token is revocable without changing your password
- The app never sees your password

**Token Types in OAuth2:**
- **Access Token:** Short-lived credential for API access (opaque string or JWT)
- **Refresh Token:** Long-lived, used to get new access tokens
- **Authorization Code:** Short-lived, one-time code exchanged for tokens (in Authorization Code flow)

**Scopes:** OAuth2 uses scopes to limit access. E.g., `scope=read:emails write:calendar` grants only those specific permissions.

**Real-World Example:**
Slack integrates with Google Drive. When you connect them:
1. **Resource Owner:** You (the user)
2. **Client:** Slack
3. **Authorization Server:** Google (`accounts.google.com`)
4. **Resource Server:** Google Drive API

You authenticate to Google (not Slack), approve Slack's requested scopes (`drive.readonly`), and Google issues Slack an access token. Slack never learns your Google password, and you can revoke Slack's access from Google's security settings at any time.

**Code Example:**
```java
// Spring Boot 3.x — OAuth2 Client (the Client role)
// application.yml:
// spring:
//   security:
//     oauth2:
//       client:
//         registration:
//           google:
//             client-id: ${GOOGLE_CLIENT_ID}
//             client-secret: ${GOOGLE_CLIENT_SECRET}
//             scope: openid, profile, email, https://www.googleapis.com/auth/calendar.readonly

@Configuration
@EnableWebSecurity
public class OAuth2ClientConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/", "/error").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2Login(oauth2 -> oauth2
                .loginPage("/login")
                .defaultSuccessUrl("/dashboard")
                .userInfoEndpoint(userInfo -> userInfo
                    .userService(customOAuth2UserService())
                )
            )
            // Also act as Resource Server for our own API
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }

    @Bean
    public OAuth2UserService<OAuth2UserRequest, OAuth2User> customOAuth2UserService() {
        return new CustomOAuth2UserService();
    }
}

// Custom user service — bridge OAuth2 user to application user
@Service
public class CustomOAuth2UserService
        implements OAuth2UserService<OAuth2UserRequest, OAuth2User> {

    @Override
    public OAuth2User loadUser(OAuth2UserRequest userRequest) {
        DefaultOAuth2UserService delegate = new DefaultOAuth2UserService();
        OAuth2User oAuth2User = delegate.loadUser(userRequest);

        String registrationId = userRequest.getClientRegistration().getRegistrationId();
        String email = oAuth2User.getAttribute("email");

        // Find or create local user account
        AppUser appUser = userRepository.findByEmail(email)
            .orElseGet(() -> createUser(email, oAuth2User, registrationId));

        return new CustomOAuth2User(oAuth2User, appUser.getId(), appUser.getRoles());
    }
}
```

**Follow-up Questions:**
1. What is the difference between OAuth2 and OpenID Connect (OIDC)?
2. Can the Authorization Server and Resource Server be the same service? Is that common?
3. How does OAuth2 handle token revocation (RFC 7009)?

**Common Mistakes:**
- Treating OAuth2 as an authentication protocol — it is an *authorization* framework. OIDC adds authentication on top.
- Not validating the `state` parameter in the Authorization Code flow, enabling CSRF attacks on the OAuth2 flow itself.

**Interview Traps:**
- "OAuth2 authenticates users" — this is wrong. OAuth2 only authorizes. OIDC (built on OAuth2) is used for authentication.
- The Resource Server does not need to contact the Authorization Server for every request if using JWT — it verifies the token locally.

**Quick Revision (1-liner):**
OAuth2's four roles — Resource Owner, Client, Authorization Server, Resource Server — enable scoped, revocable, password-free delegation.

---

### Topic 5: OAuth2 Grant Types

**Difficulty:** Hard | **Frequency:** High | **Companies:** Okta, Google, Stripe, Amazon, Goldman Sachs

**Q: Compare OAuth2 grant types. When would you use Authorization Code + PKCE vs Client Credentials? What is PKCE and why was it introduced?**

**Short Answer (2-3 sentences):**
The Authorization Code + PKCE grant is for user-facing applications (web apps, mobile, SPAs) where a human authenticates interactively; PKCE prevents authorization code interception by public clients that cannot safely store a client secret. Client Credentials is for machine-to-machine (M2M) communication — service A calling service B's API with no user involved. The Implicit flow is deprecated in favor of Authorization Code + PKCE for browser clients.

**Deep Explanation:**

**Grant Type Comparison:**

| Grant Type | Use Case | User Involved? | Secure for Public Clients? |
|---|---|---|---|
| Authorization Code + PKCE | Web/mobile/SPA apps | Yes | Yes (PKCE compensates for no secret) |
| Client Credentials | M2M / service accounts | No | No (requires client secret) |
| Implicit (deprecated) | SPA (old approach) | Yes | No — tokens in URL fragment |
| Device Authorization | Smart TVs, CLIs | Yes | Yes |
| Resource Owner Password (deprecated) | Legacy migration | Yes | No — defeats OAuth2 purpose |

**Authorization Code + PKCE Flow (Step by Step):**

```
1. Client generates: code_verifier (random 43-128 char string)
                     code_challenge = BASE64URL(SHA256(code_verifier))

2. Client → Auth Server:
   GET /authorize?
     response_type=code
     &client_id=CLIENT_ID
     &redirect_uri=https://app.example.com/callback
     &scope=openid profile
     &state=RANDOM_STATE
     &code_challenge=BASE64URL_HASH
     &code_challenge_method=S256

3. User authenticates at Auth Server, approves scopes.

4. Auth Server → Client (redirect):
   GET https://app.example.com/callback?code=AUTH_CODE&state=STATE

5. Client validates state (CSRF protection).

6. Client → Auth Server (back channel):
   POST /token
   {
     grant_type: authorization_code,
     code: AUTH_CODE,
     redirect_uri: ...,
     client_id: ...,
     code_verifier: ORIGINAL_VERIFIER  // Auth Server verifies SHA256(verifier) == challenge
   }

7. Auth Server → Client:
   { access_token, token_type, expires_in, refresh_token, id_token }
```

**Why PKCE?**
In mobile apps, the redirect URI can be intercepted by a malicious app on the same device (since mobile OS's allow multiple apps to register the same custom scheme). Without PKCE, the attacker who intercepts the authorization code can exchange it for tokens. PKCE prevents this: the auth code exchange also requires the `code_verifier` that only the legitimate client generated.

**Client Credentials Flow:**
```
Service A → Auth Server: POST /token
{
  grant_type: client_credentials,
  client_id: SERVICE_A_ID,
  client_secret: SECRET,
  scope: api.read
}

Auth Server → Service A: { access_token, expires_in }
Service A → Service B: GET /api/data  (Authorization: Bearer ACCESS_TOKEN)
```

**Real-World Example:**
- **Auth Code + PKCE:** GitHub's mobile app uses PKCE. The app cannot embed a client secret safely (it would be extractable from the binary), so PKCE provides equivalent security.
- **Client Credentials:** Your payment processor microservice authenticates to your fraud detection microservice using Client Credentials — no user is involved, it's service-to-service.

**Code Example:**
```java
// Spring Boot 3.x — OAuth2 Client with Authorization Code + PKCE
// Spring Security auto-applies PKCE for public clients (no client-secret)
// application.yml:
// spring:
//   security:
//     oauth2:
//       client:
//         registration:
//           my-app:
//             provider: my-auth-server
//             client-id: my-spa-client
//             # No client-secret for public client — PKCE applied automatically
//             authorization-grant-type: authorization_code
//             redirect-uri: "{baseUrl}/login/oauth2/code/{registrationId}"
//             scope: openid, profile, email
//         provider:
//           my-auth-server:
//             authorization-uri: https://auth.example.com/oauth2/authorize
//             token-uri: https://auth.example.com/oauth2/token
//             jwk-set-uri: https://auth.example.com/.well-known/jwks.json

// Client Credentials — M2M token fetch
@Configuration
public class WebClientConfig {

    @Bean
    public WebClient webClient(ReactiveClientRegistrationRepository registrations,
                               ReactiveOAuth2AuthorizedClientService clientService) {
        ServerOAuth2AuthorizedClientExchangeFilterFunction oauth2Filter =
            new ServerOAuth2AuthorizedClientExchangeFilterFunction(
                registrations,
                new AuthorizedClientServiceReactiveOAuth2AuthorizedClientManager(
                    registrations, clientService
                )
            );
        oauth2Filter.setDefaultClientRegistrationId("payment-service");
        return WebClient.builder()
            .filter(oauth2Filter)
            .build();
    }
}

// application.yml for M2M:
// spring:
//   security:
//     oauth2:
//       client:
//         registration:
//           payment-service:
//             client-id: ${CLIENT_ID}
//             client-secret: ${CLIENT_SECRET}
//             authorization-grant-type: client_credentials
//             scope: fraud-api.read
//         provider:
//           my-auth-server:
//             token-uri: https://auth.example.com/oauth2/token

@Service
public class FraudCheckService {

    private final WebClient webClient;

    public boolean isFraudulent(String transactionId) {
        return webClient.get()
            .uri("https://fraud-api.internal/check/{id}", transactionId)
            .attributes(clientRegistrationId("payment-service"))
            .retrieve()
            .bodyToMono(FraudResult.class)
            .map(FraudResult::isFraudulent)
            .block();
    }
}
```

**Follow-up Questions:**
1. Why is the Implicit flow deprecated and what specifically makes it less secure than Authorization Code + PKCE?
2. How does the Device Authorization Grant work for devices without a browser?
3. Can a confidential client (with a client_secret) also use PKCE? Should it?

**Common Mistakes:**
- Not validating the `state` parameter in the callback — this prevents CSRF on the OAuth2 flow itself.
- Using Client Credentials with a hard-coded `client_secret` in source code — secrets must be injected via environment variables or a secrets manager.

**Interview Traps:**
- "Does PKCE replace the client secret?" — PKCE does not replace the client secret for confidential clients; it compensates for its *absence* in public clients. Confidential clients should use both.
- The Implicit flow returns the access token in the URL fragment (`#access_token=...`), which is logged in browser history and server access logs — this is why it was deprecated.

**Quick Revision (1-liner):**
Auth Code + PKCE = interactive user flows; Client Credentials = M2M; PKCE prevents code interception for public clients.

---

### Topic 6: OpenID Connect (OIDC)

**Difficulty:** Medium | **Frequency:** High | **Companies:** Okta, Google, Microsoft, Amazon, Stripe

**Q: What is OpenID Connect, and how does it differ from OAuth2? What is an ID token vs an access token?**

**Short Answer (2-3 sentences):**
OpenID Connect (OIDC) is an authentication layer built on top of OAuth2 "” it adds a standardized way to verify user identity and obtain profile information. OAuth2 only handles *authorization* (access delegation); OIDC adds the `id_token` (a JWT containing user identity claims) and the `/userinfo` endpoint. The ID token proves who the user is; the access token grants access to resources.

**Deep Explanation:**

**OIDC Additions to OAuth2:**
- **ID Token:** A JWT returned alongside the access token, containing identity claims (`sub`, `name`, `email`, `picture`). Signed by the Authorization Server.
- **`openid` scope:** Triggers OIDC behavior. Without it, you get plain OAuth2.
- **UserInfo Endpoint:** `GET /userinfo` with the access token returns the user's profile claims.
- **Discovery Document:** `/.well-known/openid-configuration` "” machine-readable endpoint listing all OIDC endpoints, supported scopes, algorithms.

**ID Token vs Access Token:**

| Aspect | ID Token | Access Token |
|---|---|---|
| Purpose | Prove user identity to the Client | Access protected API resources |
| Consumer | The Client (your app) | The Resource Server (API) |
| Format | Always a JWT | JWT or opaque string |
| Claims | `sub`, `name`, `email`, `iat`, `exp`, `aud`, `nonce` | Scopes, resource-specific claims |
| Validation | Client validates locally | Resource Server validates |
| Should be sent to API? | No | Yes |

**OIDC Flows:**
OIDC reuses OAuth2 grant types:
- `response_type=code` â†’ Authorization Code (most secure, use with PKCE)
- `response_type=id_token token` â†’ Implicit (deprecated)
- `response_type=code id_token` â†’ Hybrid

**Standard OIDC Claims:**
- `sub` "” Subject identifier (stable, unique user ID)
- `name`, `given_name`, `family_name` "” Name claims
- `email`, `email_verified` "” Email claims
- `picture` "” Profile picture URL
- `locale`, `zoneinfo` "” Locale/timezone
- `nonce` "” Replay attack prevention (echoed from authorization request)

**Nonce for Replay Prevention:** The client generates a random `nonce`, includes it in the authorization request, and verifies the same `nonce` appears in the returned ID token "” prevents replay attacks.

**Real-World Example:**
"Login with Google" uses OIDC. You approve scopes `openid profile email`, Google returns `id_token` + `access_token`. The app validates the `id_token` locally to establish identity (`sub=google-user-123`, `email=user@gmail.com`) and uses the access token only if calling Google APIs.

**Code Example:**
```java
@Configuration
@EnableWebSecurity
public class OidcSecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/", "/login").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2Login(oauth2 -> oauth2
                .loginPage("/login")
                .userInfoEndpoint(userInfo -> userInfo
                    .oidcUserService(oidcUserService())
                )
            );
        return http.build();
    }

    @Bean
    public OidcUserService oidcUserService() {
        OidcUserService delegate = new OidcUserService();
        return request -> {
            OidcUser oidcUser = delegate.loadUser(request);
            OidcIdToken idToken = oidcUser.getIdToken();
            String subject = idToken.getSubject();
            String email = oidcUser.getEmail();
            String name = oidcUser.getFullName();
            return new CustomOidcUser(oidcUser, lookupOrCreateUser(subject, email, name));
        };
    }
}

@RestController
public class ProfileController {

    @GetMapping("/profile")
    public UserProfile getProfile(@AuthenticationPrincipal OidcUser oidcUser) {
        return UserProfile.builder()
            .subject(oidcUser.getSubject())
            .email(oidcUser.getEmail())
            .name(oidcUser.getFullName())
            .emailVerified(oidcUser.getEmailVerifiedAt() != null)
            .build();
    }

    @GetMapping("/google-calendar")
    public List<CalendarEvent> getCalendar(
            @RegisteredOAuth2AuthorizedClient("google") OAuth2AuthorizedClient client) {
        String accessToken = client.getAccessToken().getTokenValue();
        return calendarService.fetchEvents(accessToken);
    }
}
```

**Follow-up Questions:**
1. What is the `/.well-known/openid-configuration` discovery document used for in practice?
2. How does a Resource Server differentiate between an ID token and an access token?
3. What is the `nonce` claim and how does it protect against replay attacks?

**Common Mistakes:**
- Sending the ID token to the Resource Server API "” the access token is for API calls, the ID token stays with the client.
- Not verifying the `nonce` in the ID token, enabling replay attacks.

**Interview Traps:**
- "What's the difference between OAuth2 and OIDC?" "” OIDC is a standardized identity layer *on top of* OAuth2, adding the ID token, UserInfo endpoint, and discovery.
- The `sub` claim (not `email`) is the stable user identifier "” emails can change.

**Quick Revision (1-liner):**
OIDC = OAuth2 + identity: `id_token` (who you are, for the client) + `access_token` (what you can do, for the API).

---

### Topic 7: Spring Security Architecture

**Difficulty:** Hard | **Frequency:** High | **Companies:** Amazon, Goldman Sachs, JPMorgan, Atlassian, Netflix

**Q: Describe the Spring Security filter chain architecture. How do SecurityContext, AuthenticationManager, and AuthenticationProvider interact?**

**Short Answer (2-3 sentences):**
Spring Security works as a chain of servlet filters (`SecurityFilterChain`) that intercept every HTTP request. `AuthenticationManager` delegates to one or more `AuthenticationProvider` implementations to authenticate credentials; on success, an `Authentication` object is stored in `SecurityContextHolder`. Downstream filters and method-security annotations read the `Authentication` from the `SecurityContext` to make authorization decisions.

**Deep Explanation:**

**Filter Chain Architecture:**
```
HTTP Request
     |
     v
DelegatingFilterProxy  (bridges Servlet container to Spring beans)
     |
     v
FilterChainProxy  (selects matching SecurityFilterChain)
     |
     v
SecurityFilterChain (ordered list of filters):
  SecurityContextPersistenceFilter  (loads/saves SecurityContext)
  BearerTokenAuthenticationFilter  (JWT/OAuth2)
  ExceptionTranslationFilter  (AuthenticationException/AccessDeniedException -> 401/403)
  AuthorizationFilter  (final access decision)
     |
     v
DispatcherServlet -> Controller
```

**Key Components:**
- `SecurityContextHolder` "” holds `SecurityContext` (thread-local by default)
- `SecurityContext` "” contains `Authentication` (principal, credentials, authorities)
- `ProviderManager` (implements `AuthenticationManager`) "” iterates `AuthenticationProvider` list
- `DaoAuthenticationProvider` "” handles `UsernamePasswordAuthenticationToken`, calls `UserDetailsService`

**Real-World Request Flow:**
`GET /api/orders` with `Authorization: Bearer JWT`:
1. `BearerTokenAuthenticationFilter` extracts token, creates `BearerTokenAuthenticationToken`
2. `ProviderManager` finds `JwtAuthenticationProvider`
3. Provider validates JWT, creates `JwtAuthenticationToken` with authorities from `roles` claim
4. `SecurityContextHolder.getContext().setAuthentication(token)`
5. `AuthorizationFilter` checks `hasRole("USER")` â†’ passes
6. Request reaches `OrderController`

**Code Example:**
```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true, securedEnabled = true)
public class SecurityConfig {

    @Bean
    public SecurityFilterChain apiFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/api/**")
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/public/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint((request, response, e) -> {
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                    response.getWriter().write(
                        "{\"error\":\"Unauthorized\",\"message\":\"%s\"}"
                            .formatted(e.getMessage()));
                })
                .accessDeniedHandler((request, response, e) -> {
                    response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                    response.getWriter().write("{\"error\":\"Forbidden\"}");
                })
            );
        return http.build();
    }

    @Bean
    public AuthenticationManager authenticationManager(UserDetailsService uds) {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
        provider.setUserDetailsService(uds);
        provider.setPasswordEncoder(passwordEncoder());
        return new ProviderManager(provider);
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}

// Reading SecurityContext in service layer
@Service
public class AuditService {

    public String getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return (auth == null || !auth.isAuthenticated()) ? "anonymous" : auth.getName();
    }
}
```

**Follow-up Questions:**
1. How does Spring Security handle authentication in asynchronous threads (`@Async`, `CompletableFuture`)?
2. What is the difference between `@Secured` and `@PreAuthorize`?
3. How would you add a custom `AuthenticationProvider` for API key authentication?

**Common Mistakes:**
- Accessing `SecurityContextHolder` in a child thread without configuring `InheritableThreadLocal` strategy "” child thread has no SecurityContext.
- Adding a filter in wrong order "” if custom filter runs after `AuthorizationFilter`, authentication is not yet established.

**Interview Traps:**
- `@EnableMethodSecurity` replaces the deprecated `@EnableGlobalMethodSecurity` in Spring Security 6.
- The default `ThreadLocalSecurityContextHolderStrategy` is per-thread; virtual threads (Java 21) require explicit propagation.

**Quick Revision (1-liner):**
FilterChainProxy â†’ SecurityFilterChain filters â†’ AuthenticationManager â†’ AuthenticationProvider â†’ SecurityContextHolder stores Authentication.

---

### Topic 8: Spring Security JWT Integration

**Difficulty:** Hard | **Frequency:** High | **Companies:** Goldman Sachs, Amazon, Netflix, Stripe, Atlassian

**Q: Walk through implementing a complete JWT authentication filter chain in Spring Boot 3. How does @PreAuthorize work with custom SpEL expressions?**

**Short Answer (2-3 sentences):**
A `JwtAuthenticationFilter` extending `OncePerRequestFilter` extracts the Bearer token, validates it, and populates `SecurityContextHolder`. In Spring Security 6, it integrates via `.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)`. `@PreAuthorize` uses Spring Expression Language (SpEL) evaluated against the `Authentication` object, supporting custom bean method calls for rich authorization logic.

**Deep Explanation:**

**@PreAuthorize SpEL Context:**
- `authentication` "” current `Authentication` object
- `principal` "” the principal (UserDetails or JWT)
- `#paramName` "” method parameter by name (requires `-parameters` compiler flag)
- `@beanName.method(#param)` "” calls a Spring bean method
- Built-ins: `hasRole()`, `hasAnyAuthority()`, `isAuthenticated()`, `isAnonymous()`

**@PostAuthorize:** Runs after the method, can access `returnObject` "” use to filter results or verify the returned object belongs to the caller.

**Real-World Example:**
A multi-tenant SaaS uses `@PreAuthorize("@tenantService.isMember(#tenantId, authentication.name)")` "” the check delegates to a `@Service` bean that queries the DB, ensuring users access only their own tenant.

**Code Example:**
```java
// JWT Authentication Filter
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        if (SecurityContextHolder.getContext().getAuthentication() != null) {
            filterChain.doFilter(request, response);
            return;
        }

        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
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
        }
        filterChain.doFilter(request, response);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return request.getServletPath().startsWith("/api/auth/");
    }
}

// JWT Service (io.jsonwebtoken:jjwt-api)
@Service
public class JwtService {

    @Value("${jwt.secret}")
    private String secretKey;

    @Value("${jwt.expiration:3600}")
    private long expirationSeconds;

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(Decoders.BASE64.decode(secretKey));
    }

    public String generateToken(UserDetails user) {
        return Jwts.builder()
            .subject(user.getUsername())
            .claim("roles", user.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority).toList())
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + expirationSeconds * 1000))
            .signWith(getSigningKey())
            .compact();
    }

    public String extractUsername(String token) {
        return parseClaims(token).getSubject();
    }

    public boolean isTokenValid(String token, UserDetails user) {
        return extractUsername(token).equals(user.getUsername())
            && !parseClaims(token).getExpiration().before(new Date());
    }

    private Claims parseClaims(String token) {
        return Jwts.parser().verifyWith(getSigningKey()).build()
            .parseSignedClaims(token).getPayload();
    }
}

// Method security with @PreAuthorize
@RestController
@RequestMapping("/api/documents")
public class DocumentController {

    @GetMapping
    @PreAuthorize("hasRole('USER')")
    public List<Document> listDocuments() { return documentService.findAll(); }

    // #userId parameter must match authenticated user OR be ADMIN
    @GetMapping("/user/{userId}")
    @PreAuthorize("hasRole('ADMIN') or #userId == authentication.name")
    public List<Document> getUserDocs(@PathVariable String userId) {
        return documentService.findByUser(userId);
    }

    // Delegate complex authZ to a Spring bean
    @DeleteMapping("/{documentId}")
    @PreAuthorize("@docSecurity.canDelete(#documentId, authentication)")
    public ResponseEntity<Void> deleteDocument(@PathVariable Long documentId) {
        documentService.delete(documentId);
        return ResponseEntity.noContent().build();
    }

    // @PostAuthorize "” verify returned object belongs to caller
    @GetMapping("/{id}")
    @PostAuthorize("returnObject.ownerId == authentication.name or hasRole('ADMIN')")
    public Document getDocument(@PathVariable Long id) {
        return documentService.findById(id);
    }
}

// Bean used in SpEL
@Service("docSecurity")
public class DocumentSecurityService {

    public boolean canDelete(Long documentId, Authentication auth) {
        Document doc = documentRepository.findById(documentId).orElseThrow();
        boolean isOwner = doc.getOwnerId().equals(auth.getName());
        boolean isAdmin = auth.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
        return isOwner || isAdmin;
    }
}
```

**Follow-up Questions:**
1. How do you handle token revocation (logout) with stateless JWTs?
2. What is the difference between `@PreAuthorize` and `@PostAuthorize`?
3. How do you propagate SecurityContext to `@Async` methods?

**Common Mistakes:**
- Not calling `filterChain.doFilter()` in the catch block "” request hangs.
- Storing JWT in `localStorage` instead of `HttpOnly` cookies "” exposes to XSS.

**Interview Traps:**
- `@PreAuthorize` requires `@EnableMethodSecurity` "” without it, annotations are silently ignored.
- SpEL `==` is value equality, not reference equality.

**Quick Revision (1-liner):**
JwtAuthenticationFilter extracts + validates token â†’ sets SecurityContext; @PreAuthorize evaluates SpEL including `@bean.method()` calls.

---

### Topic 9: Spring Security OAuth2 Resource Server

**Difficulty:** Hard | **Frequency:** Medium | **Companies:** Okta, Amazon, Goldman Sachs, Stripe

**Q: How do you configure Spring Boot as an OAuth2 Resource Server? How do you extract custom JWT claims and map them to authorities?**

**Short Answer (2-3 sentences):**
Spring Boot auto-configures JWT validation when `spring.security.oauth2.resourceserver.jwt.jwk-set-uri` is set "” it fetches the JWKS, caches public keys, and validates every Bearer token. Custom claims are mapped to `GrantedAuthority` objects via a `JwtAuthenticationConverter`. For opaque tokens, token introspection via `opaquetoken.introspection-uri` is used instead.

**Deep Explanation:**

**JWT vs Opaque Token Resource Server:**

| Aspect | JWT (Self-Contained) | Opaque Token |
|---|---|---|
| Validation | Local "” decode + verify signature | Remote "” call introspection endpoint |
| Revocation | Needs blacklist | Immediate |
| Latency | Low | Higher (network call) |
| Use case | Microservices, high throughput | When immediate revocation required |

**jwk-set-uri vs issuer-uri:**
- `jwk-set-uri` "” directly specifies JWKS URL
- `issuer-uri` "” triggers OIDC discovery (fetches `/.well-known/openid-configuration`), auto-discovers JWKS URL and performs issuer validation. Prefer this for OIDC-compliant servers.

**Real-World Example:**
An e-commerce platform's API Gateway validates JWTs with a `permissions` claim: `["orders:read","orders:write"]`. The Resource Server maps these to `GrantedAuthority`, enabling `@PreAuthorize("hasAuthority('orders:write')")`.

**Code Example:**
```java
// application.yml
// spring:
//   security:
//     oauth2:
//       resourceserver:
//         jwt:
//           issuer-uri: https://auth.example.com
//           # jwk-set-uri auto-discovered from issuer-uri

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class ResourceServerConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .decoder(jwtDecoder())
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            );
        return http.build();
    }

    @Bean
    public JwtDecoder jwtDecoder() {
        NimbusJwtDecoder decoder = NimbusJwtDecoder
            .withJwkSetUri("https://auth.example.com/.well-known/jwks.json")
            .jwsAlgorithm(SignatureAlgorithm.RS256)
            .build();

        OAuth2TokenValidator<Jwt> withIssuer =
            JwtValidators.createDefaultWithIssuer("https://auth.example.com");
        OAuth2TokenValidator<Jwt> withAudience =
            new JwtClaimValidator<List<String>>(JwtClaimNames.AUD,
                aud -> aud != null && aud.contains("https://api.example.com"));

        decoder.setJwtValidator(
            new DelegatingOAuth2TokenValidator<>(withIssuer, withAudience));
        return decoder;
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            List<GrantedAuthority> authorities = new ArrayList<>();

            // Map roles claim
            List<String> roles = jwt.getClaimAsStringList("roles");
            if (roles != null) {
                roles.stream().map(r -> new SimpleGrantedAuthority("ROLE_" + r))
                    .forEach(authorities::add);
            }
            // Map fine-grained permissions claim
            List<String> permissions = jwt.getClaimAsStringList("permissions");
            if (permissions != null) {
                permissions.stream().map(SimpleGrantedAuthority::new)
                    .forEach(authorities::add);
            }
            return authorities;
        });
        converter.setPrincipalClaimName(JwtClaimNames.SUB);
        return converter;
    }
}

// Using JWT claims directly in controller
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @GetMapping
    @PreAuthorize("hasAuthority('orders:read') or hasRole('ADMIN')")
    public List<Order> listOrders(@AuthenticationPrincipal Jwt jwt) {
        String tenantId = jwt.getClaimAsString("tenant_id");
        return orderService.findByTenantAndUser(tenantId, jwt.getSubject());
    }

    @PostMapping
    @PreAuthorize("hasAuthority('orders:write')")
    public Order createOrder(@AuthenticationPrincipal Jwt jwt,
                             @RequestBody @Valid CreateOrderRequest req) {
        return orderService.create(jwt.getClaimAsString("tenant_id"), jwt.getSubject(), req);
    }
}
```

**Follow-up Questions:**
1. How does Spring Security cache and refresh JWKS keys when the Auth Server rotates its signing key?
2. What happens to JWT validation when the Authorization Server is temporarily unavailable?
3. How do you implement a custom `BearerTokenResolver` for tokens arriving in a cookie?

**Common Mistakes:**
- Not configuring audience validation "” tokens issued for one service can be replayed against another.
- Hard-coding the JWKS URI instead of using `issuer-uri` for auto-discovery.

**Interview Traps:**
- `@EnableResourceServer` is a legacy Spring Security OAuth2 annotation "” do not use it with Spring Boot 3 / Spring Security 6. Use `http.oauth2ResourceServer()`.
- `issuer-uri` performs an HTTP GET at application startup "” ensure the Auth Server is reachable during boot, or configure lazy initialization.

**Quick Revision (1-liner):**
`issuer-uri` auto-discovers JWKS + validates issuer; `JwtAuthenticationConverter` maps custom claims to GrantedAuthorities.

---

### Topic 10: Password Storage

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Amazon, Goldman Sachs, Stripe, any company with users

**Q: How should passwords be stored securely? Why are MD5 and SHA1 wrong for password hashing, and how does bcrypt differ?**

**Short Answer (2-3 sentences):**
Passwords must never be stored in plaintext or with fast hash algorithms (MD5, SHA1, SHA256) "” these are trivially brute-forced with modern GPUs. Secure password hashing uses deliberately slow, salted, adaptive algorithms: bcrypt, Argon2id, or scrypt. Spring Security's `PasswordEncoder` abstracts this, with `BCryptPasswordEncoder` and `Argon2PasswordEncoder` as recommended implementations.

**Deep Explanation:**

**Why MD5/SHA1 Are Wrong:**
- MD5 can hash billions of passwords per second on a single GPU.
- No per-user salt â†’ identical passwords produce identical hashes â†’ rainbow tables work.
- SHA256 has the same flaws "” it is designed for speed (TLS, file integrity), not password storage.

**bcrypt:**
- Deliberately slow: O(2^cost), cost typically 10-13 (~100-250ms per hash)
- Auto-generates and embeds salt: `$2a$12$SALT22CHARS.HASH31CHARS` (always 60 chars)
- Cost factor adjustable as hardware improves
- Limitation: silently truncates inputs beyond 72 bytes

**Argon2id (preferred for new systems):**
- Winner of Password Hashing Competition (2015)
- Argon2id variant: hybrid of Argon2d (GPU-resistant) + Argon2i (side-channel resistant)
- Parameters: memory (KB), iterations, parallelism "” highly tunable

**scrypt:** Memory-hard, makes GPU/ASIC attacks expensive. Good alternative to Argon2.

**Real-World Example:**
LinkedIn's 2012 breach exposed 117 million unsalted SHA1 hashes. Attackers cracked the majority within days. Bcrypt with cost 12 would make the same attack take millions of years.

**Code Example:**
```java
// BCryptPasswordEncoder (most common)
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);  // 12 = ~250ms per hash
}

// Argon2 (recommended for new systems)
@Bean
public PasswordEncoder argon2PasswordEncoder() {
    return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
}

// DelegatingPasswordEncoder "” supports migration between algorithms
@Bean
public PasswordEncoder delegatingPasswordEncoder() {
    Map<String, PasswordEncoder> encoders = new HashMap<>();
    encoders.put("bcrypt", new BCryptPasswordEncoder(12));
    encoders.put("argon2", Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8());
    encoders.put("scrypt", SCryptPasswordEncoder.defaultsForSpringSecurity_v5_8());
    // Format stored: {argon2}$argon2id$...
    return new DelegatingPasswordEncoder("argon2", encoders);
}

// User registration
@Service
public class UserService {

    private final PasswordEncoder passwordEncoder;

    public User registerUser(String email, String rawPassword) {
        // Validate strength before encoding
        if (rawPassword.length() < 12) {
            throw new WeakPasswordException("Password must be at least 12 characters");
        }
        String encoded = passwordEncoder.encode(rawPassword);
        // Example: $2a$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy
        return userRepository.save(User.builder()
            .email(email)
            .password(encoded)  // never store raw
            .build());
    }

    public boolean verifyPassword(String rawPassword, String encodedPassword) {
        return passwordEncoder.matches(rawPassword, encodedPassword);
    }
}

// Automatic password upgrade on login (DelegatingPasswordEncoder)
@Service
public class LoginService implements UserDetailsPasswordService {

    @Override
    public UserDetails updatePassword(UserDetails user, String newEncodedPassword) {
        // Called automatically when stored encoding is deprecated
        userRepository.updatePassword(user.getUsername(), newEncodedPassword);
        return ((AppUser) user).withPassword(newEncodedPassword);
    }
}

// Admin reset "” never log raw password
@RestController
public class AdminController {

    @PostMapping("/users/{id}/reset-password")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> resetPassword(@PathVariable Long id,
                                              @RequestBody ResetPasswordRequest req) {
        String encoded = passwordEncoder.encode(req.newPassword());
        userRepository.updatePassword(id, encoded);
        log.info("Password reset for userId={}", id);  // NO raw password in log
        return ResponseEntity.noContent().build();
    }
}
```

**Follow-up Questions:**
1. How do you migrate a legacy database of MD5 hashes to bcrypt without forcing all users to reset their passwords?
2. What is pepper (vs salt), and when would you use it?
3. How does `DelegatingPasswordEncoder` support multiple encoding schemes simultaneously?

**Common Mistakes:**
- Using `new BCryptPasswordEncoder()` with default strength 10 "” may be too fast on modern hardware.
- Logging the raw password anywhere in the request processing pipeline.

**Interview Traps:**
- "Can you reverse a bcrypt hash?" "” No. You verify by hashing the candidate and comparing. bcrypt is one-way.
- bcrypt silently truncates inputs beyond 72 bytes "” for passphrases, consider Argon2 which has no length limit.

**Quick Revision (1-liner):**
Use bcrypt (costâ‰¥12) or Argon2id "” salt prevents rainbow tables, slow cost prevents brute force; never MD5/SHA1.

---


### Topic 11: HTTPS and TLS

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Google, Amazon, Goldman Sachs, Stripe, Cloudflare

**Q: Explain the TLS handshake. What is HSTS, certificate pinning, and mutual TLS (mTLS)?**

**Short Answer (2-3 sentences):**
TLS (Transport Layer Security) encrypts data in transit; the handshake negotiates cipher suites, authenticates the server via its certificate, and establishes session keys. HSTS (HTTP Strict Transport Security) forces browsers to always use HTTPS, preventing downgrade attacks. mTLS extends TLS by requiring the *client* to also present a certificate, enabling mutual authentication "” used extensively in microservice-to-microservice communication.

**Deep Explanation:**

**TLS 1.3 Handshake (simplified):**
```
Client                                    Server
  |---ClientHello (supported ciphers, random)-->|
  |<--ServerHello (chosen cipher, random)-------|
  |<--Certificate (server's X.509 cert)---------|
  |<--CertificateVerify (signature)-------------|
  |<--Finished (MAC of handshake)---------------|
  |---Finished (MAC of handshake)-------------->|
  |<======= Encrypted Application Data ========>|
```

TLS 1.3 completes in 1 RTT (vs 2 RTT for TLS 1.2). 0-RTT resumption allows zero round trips for resumed sessions (with replay attack caveats).

**Certificate Chain:**
```
Root CA (trusted by OS/browser)
  â””â”€â”€ Intermediate CA (signed by Root)
        â””â”€â”€ Server Certificate (signed by Intermediate, contains server's public key)
```
The client verifies the chain up to a trusted Root CA in its trust store.

**HSTS (HTTP Strict Transport Security):**
Response header: `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- Browser remembers to always use HTTPS for the domain for `max-age` seconds
- Prevents SSL stripping attacks (attacker downgrades HTTPS to HTTP)
- `preload`: submit domain to browser preload lists "” HTTPS enforced even on first visit

**Certificate Pinning:**
Hard-code expected certificate fingerprints (or public key hash) in the client app. The client rejects TLS connections even with a valid CA-signed cert if the fingerprint doesn't match. Used in mobile apps to prevent MITM via rogue CA. Drawback: certificate rotation breaks the app.

**Mutual TLS (mTLS):**
Both server and client authenticate with certificates. Used in:
- Zero-trust microservice meshes (Istio, Linkerd)
- API access for financial institutions
- IoT device authentication

```
Client Certificate â†’ Server validates against trusted CA
Server Certificate â†’ Client validates against trusted CA
```

**Real-World Example:**
Cloudflare's internal microservices use mTLS via their NIKA (Network-Interconnect Karmasphere Agent) mesh. Every service has a certificate. Services that don't present a valid cert are rejected at the network layer, regardless of application-level auth.

**Code Example:**
```java
// Spring Boot 3.x "” HTTPS + HSTS configuration
// application.yml:
// server:
//   ssl:
//     key-store: classpath:keystore.p12
//     key-store-password: ${KEYSTORE_PASSWORD}
//     key-store-type: PKCS12
//     key-alias: api-server
//   port: 8443

@Configuration
public class SecurityHeadersConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .requiresChannel(channel -> channel
                .anyRequest().requiresSecure()  // redirect HTTP -> HTTPS
            )
            .headers(headers -> headers
                .httpStrictTransportSecurity(hsts -> hsts
                    .maxAgeInSeconds(31536000)   // 1 year
                    .includeSubDomains(true)
                    .preload(true)
                )
                .contentSecurityPolicy(csp -> csp
                    .policyDirectives("default-src 'self'; frame-ancestors 'none'")
                )
                .frameOptions(HeadersConfigurer.FrameOptionsConfig::deny)
                .xssProtection(Customizer.withDefaults())
                .contentTypeOptions(Customizer.withDefaults())
            );
        return http.build();
    }
}

// mTLS configuration "” server requires client certificate
// application.yml:
// server:
//   ssl:
//     client-auth: need          # require client cert
//     trust-store: classpath:truststore.p12
//     trust-store-password: ${TRUSTSTORE_PASSWORD}
//     trust-store-type: PKCS12

// Extracting client cert info in a filter
@Component
public class ClientCertificateFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {
        X509Certificate[] certs =
            (X509Certificate[]) request.getAttribute("javax.servlet.request.X509Certificate");
        if (certs != null && certs.length > 0) {
            String subject = certs[0].getSubjectX500Principal().getName();
            log.info("mTLS client certificate subject: {}", subject);
            // Set custom header or SecurityContext based on cert CN
            request.setAttribute("CLIENT_ID", extractCN(subject));
        }
        filterChain.doFilter(request, response);
    }

    private String extractCN(String distinguishedName) {
        // Extract CN= value from DN
        return Arrays.stream(distinguishedName.split(","))
            .filter(part -> part.trim().startsWith("CN="))
            .map(part -> part.trim().substring(3))
            .findFirst().orElse("unknown");
    }
}
```

**Follow-up Questions:**
1. What is the difference between TLS 1.2 and TLS 1.3 from a security and performance perspective?
2. How does OCSP stapling improve certificate revocation checking performance?
3. What are the risks of 0-RTT resumption in TLS 1.3?

**Common Mistakes:**
- Not setting `includeSubDomains` in HSTS "” subdomains remain vulnerable to downgrade attacks.
- Pinning the leaf certificate (rather than intermediate CA key) "” requires app update on every cert renewal.

**Interview Traps:**
- "HTTPS encrypts the URL" "” partially true. The domain is visible (SNI in TLS handshake), but the path, query parameters, and body are encrypted.
- TLS is at the transport layer "” it protects data in transit, not at rest. End-to-end encryption is different.

**Quick Revision (1-liner):**
TLS = encrypted transport; HSTS forces HTTPS; mTLS = mutual certificate auth for zero-trust service meshes.

---

### Topic 12: CORS

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Amazon, Netflix, Stripe, Atlassian

**Q: What is CORS and how does the same-origin policy work? Explain preflight requests and common Spring CORS configuration mistakes.**

**Short Answer (2-3 sentences):**
The Same-Origin Policy (SOP) prevents a web page from making requests to a different origin (protocol + domain + port) than the one that served it, protecting against cross-site data theft. CORS (Cross-Origin Resource Sharing) is the browser mechanism that allows servers to *relax* the SOP for specific origins by sending `Access-Control-Allow-*` response headers. Preflight requests are `OPTIONS` requests the browser sends automatically before certain cross-origin requests to check if the server permits them.

**Deep Explanation:**

**Same-Origin Policy:**
Origin = scheme + host + port. `https://app.example.com:443` and `https://api.example.com:443` are different origins. The SOP prevents JavaScript on `app.example.com` from reading responses from `api.example.com` without explicit permission.

**Simple vs Preflighted Requests:**

Simple requests (no preflight): GET/POST/HEAD with only safe headers (`Accept`, `Content-Type: text/plain|form|multipart`).

Preflighted requests (browser sends OPTIONS first): PUT/DELETE/PATCH, custom headers (`Authorization`, `X-Custom-Header`), `Content-Type: application/json`.

**Preflight Flow:**
```
Browser:
OPTIONS /api/orders HTTP/1.1
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Authorization, Content-Type

Server:
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Max-Age: 3600   (cache preflight result for 1 hour)

Then the actual POST request proceeds.
```

**CORS Response Headers:**
- `Access-Control-Allow-Origin`: specific origin or `*` (wildcard "” cannot be used with credentials)
- `Access-Control-Allow-Methods`: allowed HTTP methods
- `Access-Control-Allow-Headers`: allowed request headers
- `Access-Control-Allow-Credentials: true`: allow cookies/auth headers (requires specific origin, not `*`)
- `Access-Control-Expose-Headers`: response headers JS can read
- `Access-Control-Max-Age`: preflight cache duration

**Real-World Example:**
A React SPA at `https://app.stripe.com` calls `https://api.stripe.com/v1/charges`. Stripe's API server returns `Access-Control-Allow-Origin: https://app.stripe.com` (never `*` since credentials are involved). The browser's preflight is cached for 1 hour (`Access-Control-Max-Age: 3600`) to avoid preflight on every request.

**Code Example:**
```java
// Spring Boot 3.x "” Global CORS configuration
@Configuration
@EnableWebSecurity
public class CorsConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            // ... other config
            ;
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();

        // Specify exact origins "” never use "*" in production with credentials
        config.setAllowedOrigins(List.of(
            "https://app.example.com",
            "https://admin.example.com"
        ));
        // Or use patterns for subdomain wildcards
        // config.setAllowedOriginPatterns(List.of("https://*.example.com"));

        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of(
            "Authorization", "Content-Type", "X-Requested-With", "Accept"
        ));
        config.setExposedHeaders(List.of("X-Total-Count", "X-Request-Id"));
        config.setAllowCredentials(true);        // required for cookies/auth headers
        config.setMaxAge(3600L);                 // cache preflight for 1 hour

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }
}

// Controller-level CORS (overrides global for specific endpoints)
@RestController
@CrossOrigin(
    origins = {"https://partner-app.com"},
    methods = {RequestMethod.GET},
    allowedHeaders = {"Authorization"},
    maxAge = 3600
)
@RequestMapping("/api/public")
public class PublicApiController {
    // ...
}

// Permissive config for local development only
@Configuration
@Profile("dev")
public class DevCorsConfig {

    @Bean
    public CorsConfigurationSource devCorsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("http://localhost:*"));
        config.setAllowedMethods(List.of("*"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
```

**Follow-up Questions:**
1. If CORS is a browser enforcement mechanism, why do server-to-server API calls not need CORS headers?
2. What happens if `Access-Control-Allow-Origin: *` is combined with `Access-Control-Allow-Credentials: true`?
3. How do you handle CORS in a Spring Cloud Gateway (reactive stack)?

**Common Mistakes:**
- Configuring CORS in a `@WebMvcConfigurer` but also using `Spring Security` "” Spring Security's `CorsFilter` runs before MVC's CORS, so you must configure CORS on `HttpSecurity`, not just MVC.
- Using `Access-Control-Allow-Origin: *` with credentials "” browsers reject this combination.

**Interview Traps:**
- "CORS prevents attacks" "” CORS is *not* a security mechanism for the server. It only restricts browser behavior. A curl command or Postman call ignores CORS headers entirely.
- Forgetting to handle the `OPTIONS` preflight "” if Spring Security blocks OPTIONS requests, CORS breaks even if the actual request would be allowed.

**Quick Revision (1-liner):**
CORS relaxes Same-Origin Policy via server headers; browsers send OPTIONS preflight for complex requests; never use `*` with credentials.

---

### Topic 13: CSRF

**Difficulty:** Medium | **Frequency:** Medium | **Companies:** Google, Amazon, Goldman Sachs, Netflix

**Q: What is a CSRF attack? How does the synchronizer token pattern work, and when is it safe to disable CSRF protection in REST APIs?**

**Short Answer (2-3 sentences):**
CSRF (Cross-Site Request Forgery) tricks an authenticated user's browser into sending an unwanted request to a server that trusts the user's session cookie. The synchronizer token pattern mitigates this by requiring a secret, per-session CSRF token in requests "” a malicious site cannot read the token due to the Same-Origin Policy, so it cannot forge a valid request. Stateless REST APIs using JWT Bearer tokens (not cookies) are generally safe to disable CSRF because there is no automatic credential inclusion "” the attacker cannot force the browser to send a JWT.

**Deep Explanation:**

**CSRF Attack Scenario:**
1. User logs into `bank.example.com`, gets a session cookie.
2. User visits malicious `evil.com` while still logged in.
3. `evil.com` contains: `<img src="https://bank.example.com/transfer?to=attacker&amount=1000">`
4. Browser automatically includes the session cookie "” the bank processes the transfer as the legitimate user.

**Why It Works:** Browsers automatically attach cookies to requests matching the cookie's domain/path, regardless of which page initiated the request.

**Synchronizer Token Pattern:**
1. Server generates random per-session CSRF token, stores in session.
2. Server embeds token in HTML forms as a hidden field: `<input type="hidden" name="_csrf" value="TOKEN">`
3. On form submission, server validates submitted token matches session token.
4. Attacker on `evil.com` cannot read the token (SOP blocks cross-origin reads) â†’ cannot forge a valid request.

**Double Submit Cookie Pattern (stateless):**
- Server sets CSRF token as a readable (non-HttpOnly) cookie
- JavaScript reads the cookie and includes it as a request header (`X-CSRF-Token`)
- Server verifies header value matches cookie value
- Works because attackers cannot read the cookie value cross-origin

**SameSite Cookies:**
Modern mitigation: `Set-Cookie: sessionId=...; SameSite=Strict` or `SameSite=Lax`
- `Strict`: Cookie not sent on ANY cross-site request
- `Lax`: Cookie not sent on cross-site POST/PUT/DELETE (safe default, allows cross-site GET)
- `None`: Cookie always sent (requires `Secure`)

**When to Disable CSRF in REST APIs:**
Safe to disable when:
1. Authentication is via Bearer token in `Authorization` header (not cookies)
2. API is consumed only by non-browser clients (mobile apps, server-to-server)

Unsafe to disable when:
- API uses cookies for auth (even HttpOnly session cookies)
- API has a browser-based frontend that uses cookie-based auth

**Real-World Example:**
A Spring Boot REST API consumed only by an Angular SPA authenticating via JWT Bearer token can safely disable CSRF. The JWT is stored in memory (or localStorage) and added via JavaScript "” a malicious `evil.com` page cannot force the user's browser to attach a JWT stored in memory, unlike cookies.

**Code Example:**
```java
// CSRF enabled (default) "” for traditional web apps with form login
@Configuration
public class WebAppSecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                // Sets XSRF-TOKEN cookie (readable by JS), expects X-XSRF-TOKEN header
            )
            .authorizeHttpRequests(auth -> auth
                .anyRequest().authenticated()
            );
        return http.build();
    }
}

// CSRF disabled "” safe for stateless REST API with JWT Bearer auth
@Configuration
public class RestApiSecurityConfig {

    @Bean
    public SecurityFilterChain restFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/api/**")
            .csrf(AbstractHttpConfigurer::disable)  // safe: no cookies used for auth
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .anyRequest().authenticated()
            );
        return http.build();
    }
}

// Hybrid: CSRF for web views, disabled for API
@Configuration
public class HybridSecurityConfig {

    @Bean
    @Order(1)
    public SecurityFilterChain apiChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/api/**")
            .csrf(AbstractHttpConfigurer::disable)  // API: JWT auth, no cookies
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }

    @Bean
    @Order(2)
    public SecurityFilterChain webChain(HttpSecurity http) throws Exception {
        http  // web: session + CSRF
            .csrf(csrf -> csrf.csrfTokenRepository(
                CookieCsrfTokenRepository.withHttpOnlyFalse()))
            .formLogin(Customizer.withDefaults());
        return http.build();
    }
}
```

**Follow-up Questions:**
1. Does `SameSite=Lax` on session cookies fully replace the need for CSRF tokens?
2. What is the difference between `CookieCsrfTokenRepository` and `HttpSessionCsrfTokenRepository`?
3. Why are CSRF tokens not needed for GET requests?

**Common Mistakes:**
- Disabling CSRF globally when the app has both a REST API and a web frontend using cookie-based auth.
- Using `SameSite=Strict` for login cookies "” breaks OAuth2 redirect flows where the browser is redirected from the IdP back to your site.

**Interview Traps:**
- "JWT prevents CSRF" "” only if the JWT is stored in memory and sent via `Authorization` header. If the JWT is stored in a cookie, CSRF is still a risk.
- CSRF protection only matters for state-changing requests (POST/PUT/DELETE). GET requests should be idempotent and not require CSRF tokens.

**Quick Revision (1-liner):**
CSRF exploits automatic cookie sending; CSRF tokens or SameSite cookies prevent it; stateless JWT Bearer APIs can safely disable CSRF.

---

### Topic 14: OWASP Top 10 for APIs

**Difficulty:** Hard | **Frequency:** High | **Companies:** Google, Amazon, Goldman Sachs, Stripe, Okta

**Q: Describe the most critical OWASP API Security risks and how to mitigate them in a Spring Boot application.**

**Short Answer (2-3 sentences):**
OWASP API Security Top 10 highlights risks specific to APIs: broken object-level authorization (BOLA), broken authentication, excessive data exposure, injection, and SSRF among others. APIs differ from web apps in that they expose structured data directly, often lack the UI-layer filtering of traditional apps, and are consumed by automated clients. Mitigation requires defense in depth: input validation, output filtering, strict authorization checks, rate limiting, and threat modeling.

**Deep Explanation:**

**Top API Security Risks:**

**API1: Broken Object Level Authorization (BOLA/IDOR)**
- Attacker changes object ID in request to access another user's resource
- Example: `GET /api/orders/12345` "” change 12345 to 12346 to see another user's order
- Fix: Always verify the authenticated user owns/can access the requested object

**API2: Broken Authentication**
- Weak passwords, no MFA, tokens without expiry, tokens in logs
- Fix: Strong password policies, short-lived JWTs, token rotation, never log tokens

**API3: Broken Object Property Level Authorization (Mass Assignment)**
- `POST /users` with body `{"name":"Alice","role":"ADMIN"}` "” if role is not filtered, user becomes admin
- Fix: Use DTOs, never bind request body directly to JPA entities

**API4: Unrestricted Resource Consumption (Rate Limiting)**
- No rate limiting â†’ DoS, credential stuffing, scraping
- Fix: Rate limiting per IP/user, request size limits, pagination limits

**API5: Broken Function Level Authorization**
- Non-admin user accesses admin endpoints
- Fix: Explicit role checks on every endpoint, deny-by-default

**API6: Unrestricted Access to Sensitive Business Flows**
- Automated abuse of business logic (bulk checkout, vote manipulation)
- Fix: Behavioral analysis, CAPTCHA, device fingerprinting

**API7: Server-Side Request Forgery (SSRF)**
- API fetches user-supplied URL â†’ attacker points to internal services (`http://169.254.169.254/` AWS metadata)
- Fix: Allowlist permitted URL schemes/hosts, block private IP ranges

**API8: Security Misconfiguration**
- Debug endpoints exposed, default credentials, verbose error messages, CORS `*`
- Fix: Disable actuator endpoints in prod, custom error handlers, security headers

**API9: Improper Inventory Management**
- Undocumented/deprecated API versions still running
- Fix: API versioning strategy, deprecation policy, API gateway inventory

**API10: Unsafe Consumption of APIs**
- Trusting third-party API responses without validation â†’ injection via upstream API
- Fix: Validate and sanitize data from third-party APIs

**Real-World Example:**
Facebook's 2018 breach involved a BOLA-like flaw: an attacker exploited the "View As" feature to steal access tokens for other users. The API didn't properly verify that the token generation was scoped to the correct user context.

**Code Example:**
```java
// API1: BOLA "” always verify ownership
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    // VULNERABLE "” no ownership check
    @GetMapping("/bad/{orderId}")
    @PreAuthorize("isAuthenticated()")
    public Order getOrderUnsafe(@PathVariable Long orderId) {
        return orderRepository.findById(orderId).orElseThrow();
    }

    // SECURE "” verify ownership
    @GetMapping("/{orderId}")
    @PreAuthorize("isAuthenticated()")
    public Order getOrder(@PathVariable Long orderId,
                          @AuthenticationPrincipal Jwt jwt) {
        String userId = jwt.getSubject();
        return orderRepository.findByIdAndUserId(orderId, userId)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "Order not found"));
    }
}

// API3: Mass Assignment "” never bind request to entity directly
// VULNERABLE:
@PostMapping("/bad")
public User createBad(@RequestBody User user) {  // user.role can be set by attacker
    return userRepository.save(user);
}

// SECURE: use DTO
public record CreateUserRequest(
    @NotBlank String name,
    @Email String email,
    @NotBlank String password
    // no 'role' field "” role is set by server logic only
) {}

@PostMapping
public User create(@RequestBody @Valid CreateUserRequest req) {
    User user = new User();
    user.setName(req.name());
    user.setEmail(req.email());
    user.setPassword(passwordEncoder.encode(req.password()));
    user.setRole(Role.USER);  // always default role on creation
    return userRepository.save(user);
}

// API7: SSRF prevention
@Service
public class UrlFetchService {

    private static final Set<String> ALLOWED_HOSTS = Set.of(
        "api.partner.com", "cdn.example.com"
    );

    public String fetchUrl(String userSuppliedUrl) {
        URI uri;
        try {
            uri = new URI(userSuppliedUrl);
        } catch (URISyntaxException e) {
            throw new IllegalArgumentException("Invalid URL");
        }

        // Allowlist scheme
        if (!List.of("https").contains(uri.getScheme())) {
            throw new SecurityException("Only HTTPS URLs allowed");
        }

        // Allowlist host
        if (!ALLOWED_HOSTS.contains(uri.getHost())) {
            throw new SecurityException("Host not in allowlist: " + uri.getHost());
        }

        // Block private IP ranges
        InetAddress addr = InetAddress.getByName(uri.getHost());
        if (addr.isLoopbackAddress() || addr.isSiteLocalAddress()
                || addr.isLinkLocalAddress()) {
            throw new SecurityException("Private IP addresses not allowed");
        }

        return restTemplate.getForObject(userSuppliedUrl, String.class);
    }
}

// API8: Suppress verbose error messages in production
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleException(Exception e,
                                                          HttpServletRequest request) {
        // Log full details internally
        log.error("Unhandled exception for request {}: {}", request.getRequestURI(), e);
        // Return generic message to client "” no stack traces, no internal paths
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(new ErrorResponse("An internal error occurred",
                UUID.randomUUID().toString()));  // correlation ID for log lookup
    }
}
```

**Follow-up Questions:**
1. How is BOLA (Broken Object Level Authorization) different from Broken Function Level Authorization?
2. What is the difference between SQL injection and NoSQL injection, and how does parameterized query prevent both?
3. How would you implement rate limiting at the Spring Security level vs. at the API gateway level?

**Common Mistakes:**
- Returning the full exception message (including stack traces) in API error responses "” reveals internal structure.
- Trusting user-controlled IDs for data access without checking ownership in the query.

**Interview Traps:**
- "Input validation prevents injection" "” partially. Parameterized queries/prepared statements are the definitive fix for SQL injection. Input validation is defense-in-depth.
- SSRF via DNS rebinding: the allowlist IP check must happen *after* DNS resolution "” an attacker can register `evil.com` pointing to `169.254.169.254`.

**Quick Revision (1-liner):**
OWASP API Top 10: BOLA, broken auth, mass assignment, SSRF, misconfiguration "” fix with ownership checks, DTOs, allowlists, deny-by-default.

---

### Topic 15: Secrets Management

**Difficulty:** Medium | **Frequency:** High | **Companies:** Google, Amazon, Goldman Sachs, Stripe, Netflix

**Q: How should application secrets (DB passwords, API keys, JWT signing keys) be managed? What are the risks of hardcoding secrets?**

**Short Answer (2-3 sentences):**
Hardcoding secrets in source code is dangerous because they are committed to version control, included in container images, and visible to anyone with repository access "” a common cause of data breaches. Secrets should be injected at runtime via environment variables, a secrets manager (HashiCorp Vault, AWS Secrets Manager), or a Kubernetes Secret. Spring Cloud Vault integrates directly with HashiCorp Vault to load secrets into Spring's `Environment` at startup.

**Deep Explanation:**

**Why Hardcoding Is Dangerous:**
- Secrets in Git history survive even after deletion (git rebase/filter-branch required)
- Container images baked with secrets expose them to anyone who pulls the image
- Log output may accidentally include env vars or config values
- Rotation requires code changes and redeployment

**Secret Management Layers:**

1. **Environment Variables** (simplest, acceptable for dev/staging):
   - `export DB_PASSWORD=secret` or Docker `-e DB_PASSWORD=secret`
   - Risk: visible in process listings (`ps aux`), inherited by child processes, logged by some frameworks

2. **Kubernetes Secrets:**
   - Base64-encoded (not encrypted by default "” enable etcd encryption at rest)
   - Mounted as files or env vars into pod
   - RBAC restricts which pods/service accounts can read which secrets

3. **HashiCorp Vault:**
   - Dynamic secrets (DB creds rotated automatically)
   - Lease-based access (secrets expire and must be renewed)
   - Audit log of every secret access
   - AppRole / Kubernetes auth methods for application authentication

4. **AWS Secrets Manager / Parameter Store:**
   - Automatic rotation via Lambda
   - IAM-based access control
   - KMS encryption at rest

5. **Spring Cloud Vault:**
   - Integrates Vault into Spring's `Environment`
   - Secrets loaded at bootstrap, available as `@Value("${db.password}")`
   - Supports secret rotation via Spring Cloud Config refresh

**Secret Rotation Strategy:**
- Short-lived dynamic credentials (Vault DB secrets engine generates a unique DB user per app instance, valid for 1 hour)
- Blue-green deployment for key rotation
- Graceful degradation: app continues using old credential until new one is verified

**Real-World Example:**
Netflix's Lemur manages TLS certificates; HashiCorp Vault manages database credentials. Their Vault setup uses Kubernetes auth: each pod's service account JWT is exchanged for a Vault token scoped to only the secrets that pod needs. Credentials are rotated automatically, and every access is audited.

**Code Example:**
```java
// 1. WRONG "” never hardcode secrets
@Configuration
public class DatabaseConfigBad {
    // NEVER DO THIS
    private static final String DB_PASSWORD = "mySecretPassword123"; // hardcoded!

    @Bean
    public DataSource dataSource() {
        return DataSourceBuilder.create()
            .url("jdbc:postgresql://db.example.com/mydb")
            .username("app_user")
            .password(DB_PASSWORD)  // WRONG
            .build();
    }
}

// 2. Environment variables (acceptable baseline)
// application.yml:
// spring:
//   datasource:
//     url: ${DB_URL}
//     username: ${DB_USERNAME}
//     password: ${DB_PASSWORD}    # injected from env
//   security:
//     oauth2:
//       client:
//         registration:
//           my-app:
//             client-secret: ${OAUTH2_CLIENT_SECRET}

// 3. Spring Cloud Vault integration
// pom.xml: spring-cloud-starter-vault-config
// bootstrap.yml:
// spring:
//   cloud:
//     vault:
//       uri: https://vault.example.com:8200
//       authentication: KUBERNETES
//       kubernetes:
//         role: my-app-role
//         service-account-token-file: /var/run/secrets/kubernetes.io/serviceaccount/token
//       kv:
//         enabled: true
//         backend: secret
//         default-context: my-app    # reads secret/data/my-app
//       database:
//         enabled: true
//         role: my-app-db-role       # dynamic DB credentials

@Configuration
public class VaultConfig {

    @Value("${db.username}")          // loaded from Vault secret/data/my-app
    private String dbUsername;

    @Value("${db.password}")          // Vault DB secrets engine "” rotated automatically
    private String dbPassword;

    @Value("${jwt.signing.key}")      // loaded from Vault
    private String jwtSigningKey;

    @Bean
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(System.getenv("DB_URL"));
        config.setUsername(dbUsername);
        config.setPassword(dbPassword);
        // Configure pool to handle credential rotation
        config.setConnectionTimeout(30000);
        config.setMaximumPoolSize(10);
        return new HikariDataSource(config);
    }
}

// 4. AWS Secrets Manager via Spring Cloud AWS
// pom.xml: spring-cloud-aws-secrets-manager-config
// application.yml:
// spring:
//   config:
//     import: "aws-secretsmanager:/myapp/prod/database,/myapp/prod/jwt"
// This loads JSON secrets from AWS Secrets Manager into Spring Environment

// 5. Secret rotation with @RefreshScope
@Component
@RefreshScope   // bean is re-created when /actuator/refresh is called
public class JwtConfig {

    @Value("${jwt.signing.key}")
    private String signingKey;

    public String getSigningKey() {
        return signingKey;
    }
}

// 6. Detect secrets in code with pre-commit hooks
// .pre-commit-config.yaml:
// repos:
// - repo: https://github.com/Yelp/detect-secrets
//   rev: v1.4.0
//   hooks:
//   - id: detect-secrets
//     args: ['--baseline', '.secrets.baseline']

// 7. Never log sensitive values
@Service
public class PaymentService {

    public void processPayment(String cardNumber, String cvv, BigDecimal amount) {
        // WRONG: log.info("Processing payment card={} cvv={}", cardNumber, cvv);
        // RIGHT: log only last 4 digits, never CVV
        log.info("Processing payment card=****{} amount={}", 
            cardNumber.substring(cardNumber.length() - 4), amount);
        // ... payment logic
    }
}
```

**Follow-up Questions:**
1. How do you handle secret rotation without downtime "” how does Vault's lease renewal work?
2. What is the difference between AWS Secrets Manager and AWS Parameter Store (SSM)?
3. How do you prevent secrets from appearing in JVM heap dumps or thread dumps?

**Common Mistakes:**
- Committing `application.properties` with real credentials to git (even private repos "” contributors see them).
- Not enabling encryption at rest for Kubernetes etcd "” `kubectl get secret` returns base64-decoded values to authorized users.

**Interview Traps:**
- "Environment variables are safe" "” they are better than hardcoding, but visible in process listings, child process environment, and some logging frameworks. A proper secrets manager is the gold standard.
- Base64 encoding a secret is not encryption "” anyone can decode it.

**Quick Revision (1-liner):**
Never hardcode secrets; use environment variables as baseline, Vault/AWS Secrets Manager for production; rotate credentials automatically.

---

## Cheat Sheet

### OAuth2 Grant Types Comparison

| Grant Type | Use Case | User Interaction | Client Type | Token Response |
|---|---|---|---|---|
| **Authorization Code + PKCE** | Web/mobile/SPA user login | Yes | Public or Confidential | access_token + refresh_token + id_token (OIDC) |
| **Client Credentials** | Service-to-service (M2M) | No | Confidential only | access_token only |
| **Device Authorization** | Smart TV, CLI, IoT | Yes (on another device) | Public | access_token + refresh_token |
| **Implicit** (deprecated) | SPA (old) | Yes | Public | access_token in URL fragment |
| **Resource Owner Password** (deprecated) | Legacy migration only | Yes | Confidential | access_token + refresh_token |

**PKCE Parameters:**
- `code_verifier`: random 43-128 char string (A-Z, a-z, 0-9, `-._~`)
- `code_challenge`: `BASE64URL(SHA256(code_verifier))`
- `code_challenge_method`: `S256` (always use S256, not plain)

---

### JWT Claims Reference

| Claim | Full Name | Type | Description |
|---|---|---|---|
| `iss` | Issuer | URI | Who issued the token (Auth Server URL) |
| `sub` | Subject | String | Who the token is about (user ID) |
| `aud` | Audience | String/Array | Who the token is intended for (Resource Server) |
| `exp` | Expiration Time | NumericDate | When the token expires (Unix timestamp) |
| `iat` | Issued At | NumericDate | When the token was issued |
| `nbf` | Not Before | NumericDate | Token not valid before this time |
| `jti` | JWT ID | String | Unique ID for this token (revocation) |
| `nonce` | Nonce | String | OIDC replay prevention value |
| `azp` | Authorized Party | String | Client ID of the authorized party |
| `scope` | Scope | String | Space-separated OAuth2 scopes |

---

### Spring Security 6 Quick Reference

| Task | API |
|---|---|
| Enable method security | `@EnableMethodSecurity` on `@Configuration` |
| Role-based URL authorization | `.authorizeHttpRequests(auth -> auth.requestMatchers(...).hasRole("ADMIN"))` |
| Stateless session | `.sessionManagement(s -> s.sessionCreationPolicy(STATELESS))` |
| Disable CSRF (REST API) | `.csrf(AbstractHttpConfigurer::disable)` |
| JWT Resource Server | `.oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()))` |
| Custom JWT claims â†’ authorities | `JwtAuthenticationConverter` + `setJwtGrantedAuthoritiesConverter()` |
| CORS global config | `.cors(cors -> cors.configurationSource(source))` |
| Custom 401 handler | `.exceptionHandling(ex -> ex.authenticationEntryPoint(...))` |
| Custom 403 handler | `.exceptionHandling(ex -> ex.accessDeniedHandler(...))` |
| Add custom filter | `.addFilterBefore(filter, UsernamePasswordAuthenticationFilter.class)` |

---

### Password Hashing Comparison

| Algorithm | Type | Salt | Cost Factor | Recommended? |
|---|---|---|---|---|
| MD5 | Fast hash | No | None | **No "” broken** |
| SHA1 | Fast hash | No | None | **No "” broken** |
| SHA256 | Fast hash | No | None | **No "” too fast** |
| bcrypt | Slow hash | Auto | 2^cost (10-13) | Yes |
| Argon2id | Memory-hard | Auto | Memory+time+parallelism | **Yes "” preferred** |
| scrypt | Memory-hard | Auto | N, r, p | Yes |

---

### Security HTTP Response Headers

| Header | Example Value | Purpose |
|---|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Force HTTPS |
| `Content-Security-Policy` | `default-src 'self'` | Prevent XSS, data injection |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer info |
| `Permissions-Policy` | `geolocation=(), microphone=()` | Disable browser features |
| `Cache-Control` | `no-store` (for sensitive APIs) | Prevent caching of sensitive data |

---

*End of Chapter 13: Security "” JWT, OAuth2, Spring Security*


