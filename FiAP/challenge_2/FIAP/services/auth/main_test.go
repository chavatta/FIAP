package main

import "testing"

func TestGreeting(t *testing.T) {
	if Greeting() != "auth" {
		t.Fatalf("unexpected greeting")
	}
}
