package total2bq

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"
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

func TestTotal2bq_MissingProjectID(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID": "",
	})

	req := httptest.NewRequest("POST", "/", nil)
	w := httptest.NewRecorder()

	total2bq(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected status 500, got %d", w.Code)
	}

	body := w.Body.String()
	if body == "" {
		t.Error("expected error message in body")
	}
}

func TestTotal2bq_InvalidJSON(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID": "test-project-id",
	})

	req := httptest.NewRequest("POST", "/", bytes.NewReader([]byte("invalid json")))
	w := httptest.NewRecorder()

	total2bq(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestTotal2bq_MissingAttributes(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID": "test-project-id",
	})

	msg := PushRequest{
		Message: PubSubMessage{
			Attributes: map[string]string{},
		},
	}

	body, _ := json.Marshal(msg)
	req := httptest.NewRequest("POST", "/", bytes.NewReader(body))
	w := httptest.NewRecorder()

	total2bq(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400, got %d", w.Code)
	}
}

func TestTotal2bq_InvalidTimestamp(t *testing.T) {
	setupEnv(t, map[string]string{
		"PROJECT_ID": "test-project-id",
	})

	testCases := []struct {
		name      string
		timestamp string
	}{
		{"invalid format", "invalid-timestamp"},
		{"wrong format", "2026/01/18 10:30:00"},
		{"missing time", "2026-01-18"},
		{"empty string", ""},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			msg := PushRequest{
				Message: PubSubMessage{
					Attributes: map[string]string{
						"point_id":      "test-point-001",
						"power":         "12345.6",
						"timestamp_str": tc.timestamp,
					},
				},
			}

			body, _ := json.Marshal(msg)
			req := httptest.NewRequest("POST", "/", bytes.NewReader(body))
			w := httptest.NewRecorder()

			total2bq(w, req)

			if w.Code != http.StatusBadRequest {
				t.Errorf("expected status 400 for timestamp '%s', got %d", tc.timestamp, w.Code)
			}
		})
	}
}

func TestTimestampParsing(t *testing.T) {
	testCases := []struct {
		name         string
		input        string
		expectError  bool
		expectedHour int
	}{
		{
			name:         "valid timestamp morning",
			input:        "2026-01-18 10:30:00",
			expectError:  false,
			expectedHour: 10,
		},
		{
			name:         "valid timestamp evening",
			input:        "2026-01-18 23:59:59",
			expectError:  false,
			expectedHour: 23,
		},
		{
			name:         "valid timestamp midnight",
			input:        "2026-01-18 00:00:00",
			expectError:  false,
			expectedHour: 0,
		},
		{
			name:        "invalid format slash",
			input:       "2026/01/18 10:30:00",
			expectError: true,
		},
		{
			name:        "invalid format no time",
			input:       "2026-01-18",
			expectError: true,
		},
		{
			name:        "empty string",
			input:       "",
			expectError: true,
		},
		{
			name:        "random string",
			input:       "not a timestamp",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			ts, err := time.ParseInLocation("2006-01-02 15:04:05", tc.input, JST)

			if tc.expectError {
				if err == nil {
					t.Errorf("expected error for input '%s' but got none", tc.input)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error for input '%s': %v", tc.input, err)
				}
				if ts.Hour() != tc.expectedHour {
					t.Errorf("expected hour %d, got %d", tc.expectedHour, ts.Hour())
				}
				// Verify timezone is JST
				if ts.Location().String() != "Asia/Tokyo" {
					t.Errorf("expected timezone Asia/Tokyo, got %s", ts.Location().String())
				}
			}
		})
	}
}

func TestTotalDataStructure(t *testing.T) {
	pointID := "test-point-001"
	ts := time.Date(2026, 1, 18, 10, 30, 0, 0, JST)
	power := "12345.6"

	data := TotalData{
		PointID:    pointID,
		Timestamp:  ts,
		TotalPower: power,
	}

	if data.PointID != pointID {
		t.Errorf("expected PointID %s, got %s", pointID, data.PointID)
	}
	if !data.Timestamp.Equal(ts) {
		t.Errorf("expected Timestamp %v, got %v", ts, data.Timestamp)
	}
	if data.TotalPower != power {
		t.Errorf("expected TotalPower %s, got %s", power, data.TotalPower)
	}
}

func TestPubSubMessageStructure(t *testing.T) {
	msg := PubSubMessage{
		Attributes: map[string]string{
			"point_id":      "test-001",
			"power":         "12345.6",
			"timestamp_str": "2026-01-18 10:30:00",
		},
		ID:          "msg-123",
		PublishTime: "2026-01-18T10:30:00Z",
	}

	if msg.Attributes["point_id"] != "test-001" {
		t.Error("Attributes not set correctly")
	}
	if msg.ID != "msg-123" {
		t.Error("ID not set correctly")
	}
}

func TestJSTTimezone(t *testing.T) {
	// Verify JST constant
	if JST_DIFF != 9*60*60 {
		t.Errorf("expected JST_DIFF to be %d, got %d", 9*60*60, JST_DIFF)
	}

	// Verify JST zone offset
	_, offset := time.Now().In(JST).Zone()
	if offset != JST_DIFF {
		t.Errorf("expected JST offset %d, got %d", JST_DIFF, offset)
	}
}
