package main

import "testing"

func TestGreeting(t *testing.T) {
	if Greeting() != "evaluation" {
		t.Fatalf("unexpected greeting")
	}
}
