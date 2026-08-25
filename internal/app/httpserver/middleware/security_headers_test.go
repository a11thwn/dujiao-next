package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/dujiao-next/internal/config"
	"github.com/gin-gonic/gin"
)

func TestSecurityHeadersMiddlewareBaselineAndHSTSMode(t *testing.T) {
	gin.SetMode(gin.TestMode)

	for _, tc := range []struct {
		name     string
		mode     string
		wantHSTS string
	}{
		{name: "release", mode: gin.ReleaseMode, wantHSTS: strictTransportSecurityRelease},
		{name: "trimmed case insensitive release", mode: " Release ", wantHSTS: strictTransportSecurityRelease},
		{name: "debug", mode: gin.DebugMode, wantHSTS: ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r := gin.New()
			r.GET("/ok", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"ok": true}) })
			handler := SecurityHeadersHandler(tc.mode, r)

			w := httptest.NewRecorder()
			handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/ok", nil))

			assertSecurityHeader(t, w, contentTypeOptionsHeader, "nosniff")
			assertSecurityHeader(t, w, referrerPolicyHeader, "strict-origin-when-cross-origin")
			assertSecurityHeader(t, w, xssProtectionHeader, "0")
			assertSecurityHeader(t, w, crossDomainPoliciesHeader, "none")
			assertSecurityHeader(t, w, strictTransportSecurityHeader, tc.wantHSTS)
		})
	}
}

func TestSecurityHeadersMiddlewareCoversShortCircuitsAndAllowsStricterOverrides(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(CORSMiddleware(config.CORSConfig{
		AllowedOrigins:   []string{"https://shop.example.test"},
		AllowedMethods:   []string{http.MethodGet, http.MethodOptions},
		AllowedHeaders:   []string{"Content-Type"},
		AllowCredentials: true,
		MaxAge:           600,
	}))
	r.GET("/abort", func(c *gin.Context) { c.AbortWithStatus(http.StatusNotFound) })
	r.GET("/strict-referrer", func(c *gin.Context) {
		c.Header(referrerPolicyHeader, "no-referrer")
		c.Status(http.StatusNoContent)
	})
	handler := SecurityHeadersHandler(gin.ReleaseMode, r)

	preflight := httptest.NewRecorder()
	preflightRequest := httptest.NewRequest(http.MethodOptions, "/abort", nil)
	preflightRequest.Header.Set("Origin", "https://shop.example.test")
	handler.ServeHTTP(preflight, preflightRequest)
	if preflight.Code != http.StatusNoContent {
		t.Fatalf("preflight status=%d want=%d", preflight.Code, http.StatusNoContent)
	}
	assertSecurityHeader(t, preflight, contentTypeOptionsHeader, "nosniff")
	assertSecurityHeader(t, preflight, strictTransportSecurityHeader, strictTransportSecurityRelease)
	assertSecurityHeader(t, preflight, "Access-Control-Allow-Origin", "https://shop.example.test")
	assertSecurityHeader(t, preflight, "Vary", "Origin")

	aborted := httptest.NewRecorder()
	handler.ServeHTTP(aborted, httptest.NewRequest(http.MethodGet, "/abort", nil))
	if aborted.Code != http.StatusNotFound {
		t.Fatalf("aborted status=%d want=%d", aborted.Code, http.StatusNotFound)
	}
	assertSecurityHeader(t, aborted, contentTypeOptionsHeader, "nosniff")

	missing := httptest.NewRecorder()
	handler.ServeHTTP(missing, httptest.NewRequest(http.MethodGet, "/missing", nil))
	if missing.Code != http.StatusNotFound {
		t.Fatalf("missing status=%d want=%d", missing.Code, http.StatusNotFound)
	}
	assertSecurityHeader(t, missing, contentTypeOptionsHeader, "nosniff")

	override := httptest.NewRecorder()
	handler.ServeHTTP(override, httptest.NewRequest(http.MethodGet, "/strict-referrer", nil))
	assertSecurityHeader(t, override, referrerPolicyHeader, "no-referrer")
}

func TestSecurityHeadersHandlerCoversGinAutomaticRedirect(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.GET("/health", func(c *gin.Context) { c.Status(http.StatusOK) })
	handler := SecurityHeadersHandler(gin.ReleaseMode, r)

	w := httptest.NewRecorder()
	handler.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/health/", nil))
	if w.Code != http.StatusMovedPermanently && w.Code != http.StatusTemporaryRedirect {
		t.Fatalf("redirect status=%d want=%d or %d", w.Code, http.StatusMovedPermanently, http.StatusTemporaryRedirect)
	}
	assertSecurityHeader(t, w, contentTypeOptionsHeader, "nosniff")
	assertSecurityHeader(t, w, referrerPolicyHeader, "strict-origin-when-cross-origin")
	assertSecurityHeader(t, w, xssProtectionHeader, "0")
	assertSecurityHeader(t, w, crossDomainPoliciesHeader, "none")
	assertSecurityHeader(t, w, strictTransportSecurityHeader, strictTransportSecurityRelease)
}

func assertSecurityHeader(t *testing.T, recorder *httptest.ResponseRecorder, name string, want string) {
	t.Helper()
	if got := recorder.Header().Get(name); got != want {
		t.Fatalf("header %s=%q want=%q", name, got, want)
	}
}
