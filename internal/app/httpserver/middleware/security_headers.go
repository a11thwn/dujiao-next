package middleware

import (
	"net/http"
	"strings"
)

const (
	contentTypeOptionsHeader       = "X-Content-Type-Options"
	referrerPolicyHeader           = "Referrer-Policy"
	xssProtectionHeader            = "X-XSS-Protection"
	crossDomainPoliciesHeader      = "X-Permitted-Cross-Domain-Policies"
	strictTransportSecurityHeader  = "Strict-Transport-Security"
	strictTransportSecurityRelease = "max-age=31536000"
)

// SecurityHeadersHandler applies a proxy-independent response-security
// baseline outside the Gin engine. The net/http boundary is intentional: Gin
// resolves automatic trailing-slash redirects before its middleware chain, so
// a Gin-only middleware would leave those responses unprotected.
//
// The baseline intentionally avoids CSP, frame isolation and cross-origin
// isolation headers until the site's configurable scripts, OAuth widgets,
// Telegram Mini App, Turnstile and payment popup flows have dedicated policies.
//
// HSTS is keyed to release mode instead of Request.TLS because production TLS
// may be terminated by tls-shunt-proxy, Nginx, Caddy, a load balancer or a CDN
// before the request reaches the loopback HTTP listener.
func SecurityHeadersHandler(serverMode string, next http.Handler) http.Handler {
	enableHSTS := strings.EqualFold(strings.TrimSpace(serverMode), "release")

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		headers := w.Header()
		headers.Set(contentTypeOptionsHeader, "nosniff")
		headers.Set(referrerPolicyHeader, "strict-origin-when-cross-origin")
		headers.Set(xssProtectionHeader, "0")
		headers.Set(crossDomainPoliciesHeader, "none")
		if enableHSTS {
			headers.Set(strictTransportSecurityHeader, strictTransportSecurityRelease)
		}
		if next == nil {
			http.NotFound(w, r)
			return
		}
		next.ServeHTTP(w, r)
	})
}
