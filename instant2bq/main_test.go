package instant2bq

import (
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func setupEnv(t *testing.T, vars map[string]string) {
	originals := make(map[string]string)
	for key := range vars {
		originals[key] = os.Getenv(key)
	}
	for key, value := range vars {
		if value == "" {
			os.Unsetenv(key)
		} else {
			os.Setenv(key, value)
		}
	}
	t.Cleanup(func() {
		for key, value := range originals {
			if value == "" {
				os.Unsetenv(key)
			} else {
				os.Setenv(key, value)
			}
		}
	})
}

func withPullMsgsSyncFunc(t *testing.T, fn func(io.Writer, string, string) error) {
	original := pullMsgsSyncFunc
	pullMsgsSyncFunc = fn
	t.Cleanup(func() {
		pullMsgsSyncFunc = original
	})
}

func TestHandler_MissingProjectID(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID":      "",
		"SUBSCRIPTION_ID": "test-sub",
	})

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	handler(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestHandler_MissingSubscriptionID(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID":      "test-project",
		"SUBSCRIPTION_ID": "",
	})

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	handler(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestHandler_Success(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID":      "test-project",
		"SUBSCRIPTION_ID": "test-sub",
	})

	called := false
	var gotProject string
	var gotSub string
	withPullMsgsSyncFunc(t, func(w io.Writer, projectID, subscriptionID string) error {
		called = true
		gotProject = projectID
		gotSub = subscriptionID
		return nil
	})

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	handler(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	if !called {
		t.Fatalf("expected pullMsgsSync to be called")
	}
	if gotProject != "test-project" {
		t.Fatalf("expected projectID 'test-project', got '%s'", gotProject)
	}
	if gotSub != "test-sub" {
		t.Fatalf("expected subscriptionID 'test-sub', got '%s'", gotSub)
	}
}

func TestHandler_PullError(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID":      "test-project",
		"SUBSCRIPTION_ID": "test-sub",
	})

	withPullMsgsSyncFunc(t, func(w io.Writer, projectID, subscriptionID string) error {
		return errors.New("pull error")
	})

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	handler(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", w.Code)
	}
}
