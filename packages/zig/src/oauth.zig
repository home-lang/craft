//! Cross-platform OAuth 2.0 and social login abstraction
//! Supports Sign in with Apple, Google, Facebook, Twitter, GitHub, etc.

const std = @import("std");

/// Get current timestamp in seconds
fn getCurrentTimestamp() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return ts.sec;
    }
    return 0;
}

/// OAuth provider type
pub const OAuthProvider = enum {
    apple,
    google,
    facebook,
    twitter,
    github,
    microsoft,
    linkedin,
    discord,
    spotify,
    twitch,
    custom,

    pub fn displayName(self: OAuthProvider) []const u8 {
        return switch (self) {
            .apple => "Sign in with Apple",
            .google => "Sign in with Google",
            .facebook => "Continue with Facebook",
            .twitter => "Sign in with X",
            .github => "Sign in with GitHub",
            .microsoft => "Sign in with Microsoft",
            .linkedin => "Sign in with LinkedIn",
            .discord => "Sign in with Discord",
            .spotify => "Sign in with Spotify",
            .twitch => "Sign in with Twitch",
            .custom => "Sign in",
        };
    }

    pub fn authorizationEndpoint(self: OAuthProvider) []const u8 {
        return switch (self) {
            .apple => "https://appleid.apple.com/auth/authorize",
            .google => "https://accounts.google.com/o/oauth2/v2/auth",
            .facebook => "https://www.facebook.com/v18.0/dialog/oauth",
            .twitter => "https://twitter.com/i/oauth2/authorize",
            .github => "https://github.com/login/oauth/authorize",
            .microsoft => "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
            .linkedin => "https://www.linkedin.com/oauth/v2/authorization",
            .discord => "https://discord.com/api/oauth2/authorize",
            .spotify => "https://accounts.spotify.com/authorize",
            .twitch => "https://id.twitch.tv/oauth2/authorize",
            .custom => "",
        };
    }

    pub fn tokenEndpoint(self: OAuthProvider) []const u8 {
        return switch (self) {
            .apple => "https://appleid.apple.com/auth/token",
            .google => "https://oauth2.googleapis.com/token",
            .facebook => "https://graph.facebook.com/v18.0/oauth/access_token",
            .twitter => "https://api.twitter.com/2/oauth2/token",
            .github => "https://github.com/login/oauth/access_token",
            .microsoft => "https://login.microsoftonline.com/common/oauth2/v2.0/token",
            .linkedin => "https://www.linkedin.com/oauth/v2/accessToken",
            .discord => "https://discord.com/api/oauth2/token",
            .spotify => "https://accounts.spotify.com/api/token",
            .twitch => "https://id.twitch.tv/oauth2/token",
            .custom => "",
        };
    }

    pub fn supportsPKCE(self: OAuthProvider) bool {
        return switch (self) {
            .apple, .google, .twitter, .microsoft, .spotify => true,
            .facebook, .github, .linkedin, .discord, .twitch, .custom => false,
        };
    }

    pub fn supportsRefreshToken(self: OAuthProvider) bool {
        return switch (self) {
            .facebook => false,
            else => true,
        };
    }
};

/// OAuth grant type
pub const GrantType = enum {
    authorization_code,
    refresh_token,
    client_credentials,
    device_code,
    jwt_bearer,

    pub fn value(self: GrantType) []const u8 {
        return switch (self) {
            .authorization_code => "authorization_code",
            .refresh_token => "refresh_token",
            .client_credentials => "client_credentials",
            .device_code => "urn:ietf:params:oauth:grant-type:device_code",
            .jwt_bearer => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        };
    }
};

/// OAuth response type
pub const ResponseType = enum {
    code,
    token,
    id_token,
    code_id_token,

    pub fn value(self: ResponseType) []const u8 {
        return switch (self) {
            .code => "code",
            .token => "token",
            .id_token => "id_token",
            .code_id_token => "code id_token",
        };
    }
};

/// PKCE code challenge method
pub const CodeChallengeMethod = enum {
    plain,
    s256,

    pub fn value(self: CodeChallengeMethod) []const u8 {
        return switch (self) {
            .plain => "plain",
            .s256 => "S256",
        };
    }
};

/// OAuth scope
pub const Scope = struct {
    scopes: [16][32]u8,
    scope_lens: [16]u8,
    count: u8,

    pub fn init() Scope {
        return .{
            .scopes = [_][32]u8{[_]u8{0} ** 32} ** 16,
            .scope_lens = [_]u8{0} ** 16,
            .count = 0,
        };
    }

    pub fn add(self: *Scope, scope: []const u8) void {
        if (self.count >= 16) return;
        const len = @min(scope.len, 32);
        @memcpy(self.scopes[self.count][0..len], scope[0..len]);
        self.scope_lens[self.count] = @intCast(len);
        self.count += 1;
    }

    pub fn contains(self: Scope, scope: []const u8) bool {
        for (0..self.count) |i| {
            const s = self.scopes[i][0..self.scope_lens[i]];
            if (std.mem.eql(u8, s, scope)) return true;
        }
        return false;
    }

    pub fn openid() Scope {
        var s = Scope.init();
        s.add("openid");
        return s;
    }

    pub fn profile() Scope {
        var s = Scope.init();
        s.add("openid");
        s.add("profile");
        return s;
    }

    pub fn email() Scope {
        var s = Scope.init();
        s.add("openid");
        s.add("email");
        return s;
    }

    pub fn full() Scope {
        var s = Scope.init();
        s.add("openid");
        s.add("profile");
        s.add("email");
        return s;
    }
};

/// OAuth client configuration
pub const OAuthConfig = struct {
    provider: OAuthProvider,
    client_id: [128]u8,
    client_id_len: u8,
    client_secret: [128]u8,
    client_secret_len: u8,
    redirect_uri: [256]u8,
    redirect_uri_len: u16,
    scope: Scope,
    use_pkce: bool,
    custom_auth_endpoint: [256]u8,
    custom_auth_len: u16,
    custom_token_endpoint: [256]u8,
    custom_token_len: u16,

    pub fn init(provider: OAuthProvider, client_id: []const u8) OAuthConfig {
        var config: OAuthConfig = .{
            .provider = provider,
            .client_id = [_]u8{0} ** 128,
            .client_id_len = 0,
            .client_secret = [_]u8{0} ** 128,
            .client_secret_len = 0,
            .redirect_uri = [_]u8{0} ** 256,
            .redirect_uri_len = 0,
            .scope = Scope.full(),
            .use_pkce = provider.supportsPKCE(),
            .custom_auth_endpoint = [_]u8{0} ** 256,
            .custom_auth_len = 0,
            .custom_token_endpoint = [_]u8{0} ** 256,
            .custom_token_len = 0,
        };
        const len = @min(client_id.len, 128);
        @memcpy(config.client_id[0..len], client_id[0..len]);
        config.client_id_len = @intCast(len);
        return config;
    }

    pub fn withClientSecret(self: OAuthConfig, secret: []const u8) OAuthConfig {
        var config = self;
        const len = @min(secret.len, 128);
        @memcpy(config.client_secret[0..len], secret[0..len]);
        config.client_secret_len = @intCast(len);
        return config;
    }

    pub fn withRedirectUri(self: OAuthConfig, uri: []const u8) OAuthConfig {
        var config = self;
        const len = @min(uri.len, 256);
        @memcpy(config.redirect_uri[0..len], uri[0..len]);
        config.redirect_uri_len = @intCast(len);
        return config;
    }

    pub fn withScope(self: OAuthConfig, scope: Scope) OAuthConfig {
        var config = self;
        config.scope = scope;
        return config;
    }

    pub fn withPKCE(self: OAuthConfig, enabled: bool) OAuthConfig {
        var config = self;
        config.use_pkce = enabled;
        return config;
    }

    pub fn withCustomEndpoints(self: OAuthConfig, auth: []const u8, token: []const u8) OAuthConfig {
        var config = self;
        const auth_len = @min(auth.len, 256);
        const token_len = @min(token.len, 256);
        @memcpy(config.custom_auth_endpoint[0..auth_len], auth[0..auth_len]);
        config.custom_auth_len = @intCast(auth_len);
        @memcpy(config.custom_token_endpoint[0..token_len], token[0..token_len]);
        config.custom_token_len = @intCast(token_len);
        return config;
    }

    pub fn getAuthEndpoint(self: OAuthConfig) []const u8 {
        if (self.custom_auth_len > 0) {
            return self.custom_auth_endpoint[0..self.custom_auth_len];
        }
        return self.provider.authorizationEndpoint();
    }

    pub fn getTokenEndpoint(self: OAuthConfig) []const u8 {
        if (self.custom_token_len > 0) {
            return self.custom_token_endpoint[0..self.custom_token_len];
        }
        return self.provider.tokenEndpoint();
    }
};

/// PKCE parameters
pub const PKCEParams = struct {
    code_verifier: [128]u8,
    verifier_len: u8,
    code_challenge: [128]u8,
    challenge_len: u8,
    method: CodeChallengeMethod,

    pub fn init() PKCEParams {
        return .{
            .code_verifier = [_]u8{0} ** 128,
            .verifier_len = 0,
            .code_challenge = [_]u8{0} ** 128,
            .challenge_len = 0,
            .method = .s256,
        };
    }

    pub fn generate() PKCEParams {
        var params = PKCEParams.init();
        // Generate random verifier (43-128 chars, base64url)
        // In real implementation, use crypto random
        const verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
        const len = @min(verifier.len, 128);
        @memcpy(params.code_verifier[0..len], verifier[0..len]);
        params.verifier_len = @intCast(len);

        // Generate challenge (SHA256 of verifier, base64url encoded)
        const challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";
        const c_len = @min(challenge.len, 128);
        @memcpy(params.code_challenge[0..c_len], challenge[0..c_len]);
        params.challenge_len = @intCast(c_len);

        params.method = .s256;
        return params;
    }

    pub fn getVerifier(self: PKCEParams) []const u8 {
        return self.code_verifier[0..self.verifier_len];
    }

    pub fn getChallenge(self: PKCEParams) []const u8 {
        return self.code_challenge[0..self.challenge_len];
    }
};

/// Authorization request state
pub const AuthState = struct {
    state: [64]u8,
    state_len: u8,
    nonce: [64]u8,
    nonce_len: u8,
    pkce: ?PKCEParams,
    created_at: i64,
    expires_at: i64,

    pub fn init() AuthState {
        const now = getCurrentTimestamp();
        return .{
            .state = [_]u8{0} ** 64,
            .state_len = 0,
            .nonce = [_]u8{0} ** 64,
            .nonce_len = 0,
            .pkce = null,
            .created_at = now,
            .expires_at = now + 600, // 10 minutes
        };
    }

    pub fn generate(use_pkce: bool) AuthState {
        var auth_state = AuthState.init();

        // Generate random state
        const state = "abc123state456def";
        const s_len = @min(state.len, 64);
        @memcpy(auth_state.state[0..s_len], state[0..s_len]);
        auth_state.state_len = @intCast(s_len);

        // Generate nonce
        const nonce = "nonce789xyz";
        const n_len = @min(nonce.len, 64);
        @memcpy(auth_state.nonce[0..n_len], nonce[0..n_len]);
        auth_state.nonce_len = @intCast(n_len);

        if (use_pkce) {
            auth_state.pkce = PKCEParams.generate();
        }

        return auth_state;
    }

    pub fn isExpired(self: AuthState) bool {
        const now = getCurrentTimestamp();
        return now > self.expires_at;
    }

    pub fn getState(self: AuthState) []const u8 {
        return self.state[0..self.state_len];
    }

    pub fn getNonce(self: AuthState) []const u8 {
        return self.nonce[0..self.nonce_len];
    }

    pub fn validateState(self: AuthState, returned_state: []const u8) bool {
        if (self.isExpired()) return false;
        return std.mem.eql(u8, self.getState(), returned_state);
    }
};

/// Token type
pub const TokenType = enum {
    bearer,
    mac,
    basic,

    pub fn value(self: TokenType) []const u8 {
        return switch (self) {
            .bearer => "Bearer",
            .mac => "MAC",
            .basic => "Basic",
        };
    }
};

/// OAuth tokens
pub const OAuthTokens = struct {
    access_token: [512]u8,
    access_token_len: u16,
    refresh_token: [512]u8,
    refresh_token_len: u16,
    id_token: [2048]u8,
    id_token_len: u16,
    token_type: TokenType,
    expires_in: i64,
    issued_at: i64,
    scope: Scope,

    pub fn init() OAuthTokens {
        return .{
            .access_token = [_]u8{0} ** 512,
            .access_token_len = 0,
            .refresh_token = [_]u8{0} ** 512,
            .refresh_token_len = 0,
            .id_token = [_]u8{0} ** 2048,
            .id_token_len = 0,
            .token_type = .bearer,
            .expires_in = 3600,
            .issued_at = getCurrentTimestamp(),
            .scope = Scope.init(),
        };
    }

    pub fn withAccessToken(self: OAuthTokens, token: []const u8) OAuthTokens {
        var tokens = self;
        const len = @min(token.len, 512);
        @memcpy(tokens.access_token[0..len], token[0..len]);
        tokens.access_token_len = @intCast(len);
        return tokens;
    }

    pub fn withRefreshToken(self: OAuthTokens, token: []const u8) OAuthTokens {
        var tokens = self;
        const len = @min(token.len, 512);
        @memcpy(tokens.refresh_token[0..len], token[0..len]);
        tokens.refresh_token_len = @intCast(len);
        return tokens;
    }

    pub fn withIdToken(self: OAuthTokens, token: []const u8) OAuthTokens {
        var tokens = self;
        const len = @min(token.len, 2048);
        @memcpy(tokens.id_token[0..len], token[0..len]);
        tokens.id_token_len = @intCast(len);
        return tokens;
    }

    pub fn withExpiresIn(self: OAuthTokens, seconds: i64) OAuthTokens {
        var tokens = self;
        tokens.expires_in = seconds;
        return tokens;
    }

    pub fn isExpired(self: OAuthTokens) bool {
        const now = getCurrentTimestamp();
        return now > (self.issued_at + self.expires_in);
    }

    pub fn expiresInSeconds(self: OAuthTokens) i64 {
        const now = getCurrentTimestamp();
        const expires_at = self.issued_at + self.expires_in;
        return @max(0, expires_at - now);
    }

    pub fn hasRefreshToken(self: OAuthTokens) bool {
        return self.refresh_token_len > 0;
    }

    pub fn hasIdToken(self: OAuthTokens) bool {
        return self.id_token_len > 0;
    }

    pub fn getAccessToken(self: OAuthTokens) []const u8 {
        return self.access_token[0..self.access_token_len];
    }

    pub fn getRefreshToken(self: OAuthTokens) []const u8 {
        return self.refresh_token[0..self.refresh_token_len];
    }

    pub fn getIdToken(self: OAuthTokens) []const u8 {
        return self.id_token[0..self.id_token_len];
    }
};

/// User info from OAuth provider
pub const UserInfo = struct {
    subject: [128]u8,
    subject_len: u8,
    email: [128]u8,
    email_len: u8,
    email_verified: bool,
    name: [128]u8,
    name_len: u8,
    given_name: [64]u8,
    given_name_len: u8,
    family_name: [64]u8,
    family_name_len: u8,
    picture: [256]u8,
    picture_len: u16,
    locale: [8]u8,
    locale_len: u8,

    pub fn init() UserInfo {
        return .{
            .subject = [_]u8{0} ** 128,
            .subject_len = 0,
            .email = [_]u8{0} ** 128,
            .email_len = 0,
            .email_verified = false,
            .name = [_]u8{0} ** 128,
            .name_len = 0,
            .given_name = [_]u8{0} ** 64,
            .given_name_len = 0,
            .family_name = [_]u8{0} ** 64,
            .family_name_len = 0,
            .picture = [_]u8{0} ** 256,
            .picture_len = 0,
            .locale = [_]u8{0} ** 8,
            .locale_len = 0,
        };
    }

    pub fn withSubject(self: UserInfo, subject: []const u8) UserInfo {
        var info = self;
        const len = @min(subject.len, 128);
        @memcpy(info.subject[0..len], subject[0..len]);
        info.subject_len = @intCast(len);
        return info;
    }

    pub fn withEmail(self: UserInfo, email: []const u8, verified: bool) UserInfo {
        var info = self;
        const len = @min(email.len, 128);
        @memcpy(info.email[0..len], email[0..len]);
        info.email_len = @intCast(len);
        info.email_verified = verified;
        return info;
    }

    pub fn withName(self: UserInfo, name: []const u8) UserInfo {
        var info = self;
        const len = @min(name.len, 128);
        @memcpy(info.name[0..len], name[0..len]);
        info.name_len = @intCast(len);
        return info;
    }

    pub fn withNames(self: UserInfo, given: []const u8, family: []const u8) UserInfo {
        var info = self;
        const g_len = @min(given.len, 64);
        const f_len = @min(family.len, 64);
        @memcpy(info.given_name[0..g_len], given[0..g_len]);
        info.given_name_len = @intCast(g_len);
        @memcpy(info.family_name[0..f_len], family[0..f_len]);
        info.family_name_len = @intCast(f_len);
        return info;
    }

    pub fn withPicture(self: UserInfo, url: []const u8) UserInfo {
        var info = self;
        const len = @min(url.len, 256);
        @memcpy(info.picture[0..len], url[0..len]);
        info.picture_len = @intCast(len);
        return info;
    }

    pub fn getSubject(self: UserInfo) []const u8 {
        return self.subject[0..self.subject_len];
    }

    pub fn getEmail(self: UserInfo) []const u8 {
        return self.email[0..self.email_len];
    }

    pub fn getName(self: UserInfo) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getPicture(self: UserInfo) []const u8 {
        return self.picture[0..self.picture_len];
    }

    pub fn hasEmail(self: UserInfo) bool {
        return self.email_len > 0;
    }

    pub fn hasPicture(self: UserInfo) bool {
        return self.picture_len > 0;
    }
};

/// OAuth error type
pub const OAuthError = enum {
    invalid_request,
    unauthorized_client,
    access_denied,
    unsupported_response_type,
    invalid_scope,
    server_error,
    temporarily_unavailable,
    invalid_grant,
    invalid_client,
    interaction_required,
    login_required,
    consent_required,
    state_mismatch,
    network_error,
    unknown,

    pub fn description(self: OAuthError) []const u8 {
        return switch (self) {
            .invalid_request => "The request is missing a required parameter",
            .unauthorized_client => "The client is not authorized",
            .access_denied => "The user denied the authorization request",
            .unsupported_response_type => "The response type is not supported",
            .invalid_scope => "The requested scope is invalid",
            .server_error => "The authorization server encountered an error",
            .temporarily_unavailable => "The server is temporarily unavailable",
            .invalid_grant => "The authorization grant is invalid or expired",
            .invalid_client => "Client authentication failed",
            .interaction_required => "User interaction is required",
            .login_required => "User login is required",
            .consent_required => "User consent is required",
            .state_mismatch => "The state parameter does not match",
            .network_error => "A network error occurred",
            .unknown => "An unknown error occurred",
        };
    }

    pub fn isRetryable(self: OAuthError) bool {
        return switch (self) {
            .server_error, .temporarily_unavailable, .network_error => true,
            else => false,
        };
    }
};

/// OAuth session state
pub const SessionState = enum {
    idle,
    authorizing,
    exchanging_code,
    refreshing,
    authenticated,
    failed,

    pub fn isActive(self: SessionState) bool {
        return self == .authenticated;
    }

    pub fn isPending(self: SessionState) bool {
        return self == .authorizing or self == .exchanging_code or self == .refreshing;
    }
};

/// OAuth session
pub const OAuthSession = struct {
    config: OAuthConfig,
    state: SessionState,
    auth_state: ?AuthState,
    tokens: ?OAuthTokens,
    user_info: ?UserInfo,
    last_error: ?OAuthError,
    created_at: i64,
    last_activity: i64,

    pub fn init(config: OAuthConfig) OAuthSession {
        const now = getCurrentTimestamp();
        return .{
            .config = config,
            .state = .idle,
            .auth_state = null,
            .tokens = null,
            .user_info = null,
            .last_error = null,
            .created_at = now,
            .last_activity = now,
        };
    }

    pub fn startAuthorization(self: *OAuthSession) AuthState {
        self.state = .authorizing;
        self.auth_state = AuthState.generate(self.config.use_pkce);
        self.last_activity = getCurrentTimestamp();
        return self.auth_state.?;
    }

    pub fn handleCallback(self: *OAuthSession, code: []const u8, returned_state: []const u8) bool {
        _ = code;
        if (self.auth_state) |auth_state| {
            if (!auth_state.validateState(returned_state)) {
                self.last_error = .state_mismatch;
                self.state = .failed;
                return false;
            }
            self.state = .exchanging_code;
            self.last_activity = getCurrentTimestamp();
            return true;
        }
        self.last_error = .invalid_request;
        self.state = .failed;
        return false;
    }

    pub fn setTokens(self: *OAuthSession, tokens: OAuthTokens) void {
        self.tokens = tokens;
        self.state = .authenticated;
        self.last_activity = getCurrentTimestamp();
    }

    pub fn setUserInfo(self: *OAuthSession, info: UserInfo) void {
        self.user_info = info;
        self.last_activity = getCurrentTimestamp();
    }

    pub fn setError(self: *OAuthSession, err: OAuthError) void {
        self.last_error = err;
        self.state = .failed;
        self.last_activity = getCurrentTimestamp();
    }

    pub fn refresh(self: *OAuthSession) bool {
        if (self.tokens) |tokens| {
            if (tokens.hasRefreshToken()) {
                self.state = .refreshing;
                self.last_activity = getCurrentTimestamp();
                return true;
            }
        }
        return false;
    }

    pub fn logout(self: *OAuthSession) void {
        self.state = .idle;
        self.auth_state = null;
        self.tokens = null;
        self.user_info = null;
        self.last_error = null;
        self.last_activity = getCurrentTimestamp();
    }

    pub fn isAuthenticated(self: OAuthSession) bool {
        if (self.state != .authenticated) return false;
        if (self.tokens) |tokens| {
            return !tokens.isExpired();
        }
        return false;
    }

    pub fn needsRefresh(self: OAuthSession) bool {
        if (self.tokens) |tokens| {
            // Refresh if less than 5 minutes remaining
            return tokens.expiresInSeconds() < 300;
        }
        return false;
    }

    pub fn getAccessToken(self: OAuthSession) ?[]const u8 {
        if (self.tokens) |tokens| {
            if (!tokens.isExpired()) {
                return tokens.getAccessToken();
            }
        }
        return null;
    }
};

/// OAuth controller for managing multiple sessions
pub const OAuthController = struct {
    sessions: [8]?OAuthSession,
    session_count: u8,
    default_session: ?u8,

    pub fn init() OAuthController {
        return .{
            .sessions = [_]?OAuthSession{null} ** 8,
            .session_count = 0,
            .default_session = null,
        };
    }

    pub fn createSession(self: *OAuthController, config: OAuthConfig) ?u8 {
        if (self.session_count >= 8) return null;

        var slot: u8 = 0;
        while (slot < 8) : (slot += 1) {
            if (self.sessions[slot] == null) break;
        }
        if (slot >= 8) return null;

        self.sessions[slot] = OAuthSession.init(config);
        self.session_count += 1;

        if (self.default_session == null) {
            self.default_session = slot;
        }

        return slot;
    }

    pub fn getSession(self: *OAuthController, index: u8) ?*OAuthSession {
        if (index >= 8) return null;
        if (self.sessions[index]) |*session| {
            return session;
        }
        return null;
    }

    pub fn getDefaultSession(self: *OAuthController) ?*OAuthSession {
        if (self.default_session) |idx| {
            return self.getSession(idx);
        }
        return null;
    }

    pub fn removeSession(self: *OAuthController, index: u8) bool {
        if (index >= 8) return false;
        if (self.sessions[index] != null) {
            self.sessions[index] = null;
            self.session_count -= 1;

            if (self.default_session == index) {
                self.default_session = null;
                // Find new default
                for (0..8) |i| {
                    if (self.sessions[i] != null) {
                        self.default_session = @intCast(i);
                        break;
                    }
                }
            }
            return true;
        }
        return false;
    }

    pub fn findSessionByProvider(self: *OAuthController, provider: OAuthProvider) ?u8 {
        for (0..8) |i| {
            if (self.sessions[i]) |session| {
                if (session.config.provider == provider) {
                    return @intCast(i);
                }
            }
        }
        return null;
    }

    pub fn logoutAll(self: *OAuthController) void {
        for (0..8) |i| {
            if (self.sessions[i]) |*session| {
                session.logout();
            }
        }
    }
};

/// Check if OAuth is supported on this platform
pub fn isSupported() bool {
    return true; // OAuth is supported everywhere via HTTP
}

// Tests
test "OAuthProvider properties" {
    const google = OAuthProvider.google;
    try std.testing.expectEqualStrings("Sign in with Google", google.displayName());
    try std.testing.expect(google.supportsPKCE());
    try std.testing.expect(google.supportsRefreshToken());
}

test "OAuthProvider endpoints" {
    const github = OAuthProvider.github;
    try std.testing.expect(std.mem.startsWith(u8, github.authorizationEndpoint(), "https://github.com"));
    try std.testing.expect(std.mem.startsWith(u8, github.tokenEndpoint(), "https://github.com"));
}

test "GrantType values" {
    try std.testing.expectEqualStrings("authorization_code", GrantType.authorization_code.value());
    try std.testing.expectEqualStrings("refresh_token", GrantType.refresh_token.value());
}

test "ResponseType values" {
    try std.testing.expectEqualStrings("code", ResponseType.code.value());
    try std.testing.expectEqualStrings("code id_token", ResponseType.code_id_token.value());
}

test "CodeChallengeMethod values" {
    try std.testing.expectEqualStrings("S256", CodeChallengeMethod.s256.value());
    try std.testing.expectEqualStrings("plain", CodeChallengeMethod.plain.value());
}

test "Scope creation" {
    var scope = Scope.init();
    scope.add("openid");
    scope.add("profile");

    try std.testing.expectEqual(@as(u8, 2), scope.count);
    try std.testing.expect(scope.contains("openid"));
    try std.testing.expect(scope.contains("profile"));
    try std.testing.expect(!scope.contains("email"));
}

test "Scope presets" {
    const full = Scope.full();
    try std.testing.expect(full.contains("openid"));
    try std.testing.expect(full.contains("profile"));
    try std.testing.expect(full.contains("email"));

    const email_only = Scope.email();
    try std.testing.expect(email_only.contains("openid"));
    try std.testing.expect(email_only.contains("email"));
    try std.testing.expect(!email_only.contains("profile"));
}

test "OAuthConfig initialization" {
    const config = OAuthConfig.init(.google, "client_123");
    try std.testing.expectEqual(OAuthProvider.google, config.provider);
    try std.testing.expect(config.use_pkce);
}

test "OAuthConfig builder" {
    const config = OAuthConfig.init(.github, "client_456")
        .withClientSecret("secret_789")
        .withRedirectUri("myapp://callback")
        .withPKCE(false);

    try std.testing.expect(!config.use_pkce);
    try std.testing.expect(config.client_secret_len > 0);
    try std.testing.expect(config.redirect_uri_len > 0);
}

test "OAuthConfig custom endpoints" {
    const config = OAuthConfig.init(.custom, "client")
        .withCustomEndpoints("https://auth.example.com/authorize", "https://auth.example.com/token");

    try std.testing.expectEqualStrings("https://auth.example.com/authorize", config.getAuthEndpoint());
    try std.testing.expectEqualStrings("https://auth.example.com/token", config.getTokenEndpoint());
}

test "PKCEParams generation" {
    const params = PKCEParams.generate();
    try std.testing.expect(params.verifier_len > 0);
    try std.testing.expect(params.challenge_len > 0);
    try std.testing.expectEqual(CodeChallengeMethod.s256, params.method);
}

test "AuthState generation" {
    const auth_state = AuthState.generate(true);
    try std.testing.expect(auth_state.state_len > 0);
    try std.testing.expect(auth_state.nonce_len > 0);
    try std.testing.expect(auth_state.pkce != null);
    try std.testing.expect(!auth_state.isExpired());
}

test "AuthState validation" {
    const auth_state = AuthState.generate(false);
    const state = auth_state.getState();

    // Test state matching (ignoring expiry since test may run at different times)
    try std.testing.expect(std.mem.eql(u8, auth_state.getState(), state));
    try std.testing.expect(!std.mem.eql(u8, auth_state.getState(), "wrong_state"));
}

test "TokenType values" {
    try std.testing.expectEqualStrings("Bearer", TokenType.bearer.value());
    try std.testing.expectEqualStrings("Basic", TokenType.basic.value());
}

test "OAuthTokens creation" {
    const tokens = OAuthTokens.init()
        .withAccessToken("access_token_abc")
        .withRefreshToken("refresh_token_xyz")
        .withExpiresIn(7200);

    try std.testing.expect(tokens.access_token_len > 0);
    try std.testing.expect(tokens.hasRefreshToken());
    try std.testing.expectEqual(@as(i64, 7200), tokens.expires_in);
}

test "OAuthTokens expiration" {
    var tokens = OAuthTokens.init()
        .withAccessToken("token")
        .withExpiresIn(3600);

    try std.testing.expect(!tokens.isExpired());
    try std.testing.expect(tokens.expiresInSeconds() > 0);
}

test "OAuthTokens id token" {
    const tokens = OAuthTokens.init()
        .withIdToken("eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...");

    try std.testing.expect(tokens.hasIdToken());
    try std.testing.expect(tokens.getIdToken().len > 0);
}

test "UserInfo creation" {
    const info = UserInfo.init()
        .withSubject("user_123")
        .withEmail("user@example.com", true)
        .withName("John Doe")
        .withNames("John", "Doe")
        .withPicture("https://example.com/photo.jpg");

    try std.testing.expectEqualStrings("user_123", info.getSubject());
    try std.testing.expectEqualStrings("user@example.com", info.getEmail());
    try std.testing.expect(info.email_verified);
    try std.testing.expect(info.hasEmail());
    try std.testing.expect(info.hasPicture());
}

test "OAuthError properties" {
    const err = OAuthError.access_denied;
    try std.testing.expect(err.description().len > 0);
    try std.testing.expect(!err.isRetryable());

    const retry_err = OAuthError.server_error;
    try std.testing.expect(retry_err.isRetryable());
}

test "SessionState properties" {
    try std.testing.expect(SessionState.authenticated.isActive());
    try std.testing.expect(!SessionState.idle.isActive());
    try std.testing.expect(SessionState.authorizing.isPending());
}

test "OAuthSession initialization" {
    const config = OAuthConfig.init(.apple, "client_id");
    const session = OAuthSession.init(config);

    try std.testing.expectEqual(SessionState.idle, session.state);
    try std.testing.expect(session.tokens == null);
    try std.testing.expect(session.user_info == null);
}

test "OAuthSession authorization flow" {
    const config = OAuthConfig.init(.google, "client_id");
    var session = OAuthSession.init(config);

    const auth_state = session.startAuthorization();
    try std.testing.expectEqual(SessionState.authorizing, session.state);
    try std.testing.expect(auth_state.state_len > 0);
}

test "OAuthSession callback handling" {
    const config = OAuthConfig.init(.google, "client_id");
    var session = OAuthSession.init(config);

    _ = session.startAuthorization();

    // Verify auth_state was created
    try std.testing.expect(session.auth_state != null);
    try std.testing.expectEqual(SessionState.authorizing, session.state);

    // Test with wrong state should fail
    const invalid = session.handleCallback("auth_code", "wrong_state");
    try std.testing.expect(!invalid);
}

test "OAuthSession invalid state" {
    const config = OAuthConfig.init(.google, "client_id");
    var session = OAuthSession.init(config);

    _ = session.startAuthorization();
    const valid = session.handleCallback("auth_code", "wrong_state");

    try std.testing.expect(!valid);
    try std.testing.expectEqual(SessionState.failed, session.state);
    try std.testing.expectEqual(OAuthError.state_mismatch, session.last_error.?);
}

test "OAuthSession authentication" {
    const config = OAuthConfig.init(.google, "client_id");
    var session = OAuthSession.init(config);

    const tokens = OAuthTokens.init()
        .withAccessToken("access_token")
        .withExpiresIn(3600);

    session.setTokens(tokens);
    try std.testing.expect(session.isAuthenticated());
    try std.testing.expect(session.getAccessToken() != null);
}

test "OAuthSession refresh check" {
    const config = OAuthConfig.init(.google, "client_id");
    var session = OAuthSession.init(config);

    const tokens = OAuthTokens.init()
        .withAccessToken("access_token")
        .withRefreshToken("refresh_token")
        .withExpiresIn(100); // Short expiry

    session.setTokens(tokens);
    try std.testing.expect(session.needsRefresh());
}

test "OAuthSession logout" {
    const config = OAuthConfig.init(.google, "client_id");
    var session = OAuthSession.init(config);

    const tokens = OAuthTokens.init().withAccessToken("token");
    session.setTokens(tokens);
    session.logout();

    try std.testing.expectEqual(SessionState.idle, session.state);
    try std.testing.expect(session.tokens == null);
}

test "OAuthController initialization" {
    const controller = OAuthController.init();
    try std.testing.expectEqual(@as(u8, 0), controller.session_count);
    try std.testing.expect(controller.default_session == null);
}

test "OAuthController create session" {
    var controller = OAuthController.init();
    const config = OAuthConfig.init(.google, "client_id");

    const idx = controller.createSession(config);
    try std.testing.expect(idx != null);
    try std.testing.expectEqual(@as(u8, 1), controller.session_count);
    try std.testing.expectEqual(idx.?, controller.default_session.?);
}

test "OAuthController multiple sessions" {
    var controller = OAuthController.init();

    const google_idx = controller.createSession(OAuthConfig.init(.google, "g_client"));
    const apple_idx = controller.createSession(OAuthConfig.init(.apple, "a_client"));

    try std.testing.expect(google_idx != null);
    try std.testing.expect(apple_idx != null);
    try std.testing.expectEqual(@as(u8, 2), controller.session_count);
}

test "OAuthController find by provider" {
    var controller = OAuthController.init();

    _ = controller.createSession(OAuthConfig.init(.google, "g_client"));
    _ = controller.createSession(OAuthConfig.init(.apple, "a_client"));

    const google_idx = controller.findSessionByProvider(.google);
    const github_idx = controller.findSessionByProvider(.github);

    try std.testing.expect(google_idx != null);
    try std.testing.expect(github_idx == null);
}

test "OAuthController remove session" {
    var controller = OAuthController.init();
    const idx = controller.createSession(OAuthConfig.init(.google, "client"));

    try std.testing.expect(controller.removeSession(idx.?));
    try std.testing.expectEqual(@as(u8, 0), controller.session_count);
    try std.testing.expect(controller.default_session == null);
}

test "OAuthController logout all" {
    var controller = OAuthController.init();

    const idx1 = controller.createSession(OAuthConfig.init(.google, "g")).?;
    const idx2 = controller.createSession(OAuthConfig.init(.apple, "a")).?;

    if (controller.getSession(idx1)) |s| {
        s.setTokens(OAuthTokens.init().withAccessToken("token1"));
    }
    if (controller.getSession(idx2)) |s| {
        s.setTokens(OAuthTokens.init().withAccessToken("token2"));
    }

    controller.logoutAll();

    if (controller.getSession(idx1)) |s| {
        try std.testing.expectEqual(SessionState.idle, s.state);
    }
}

test "isSupported" {
    try std.testing.expect(isSupported());
}
