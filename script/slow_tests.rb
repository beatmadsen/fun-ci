# frozen_string_literal: true

# A passing test each recording's slow suite selects and its fast suite
# leaves out, by the stack's own convention, so script/suites_apart.rb sees
# the slow suite run a test (SuitesApart::SLOW_RAN says what that looks like).
SLOW_TESTS = {
  "maven" => { "src/test/java/shop/CartIT.java" => <<~JAVA },
    package shop;

    import static org.junit.jupiter.api.Assertions.assertEquals;
    import org.junit.jupiter.api.Test;

    class CartIT {
        @Test void runsWhenSlowTestsAreAskedFor() { assertEquals(2, 1 + 1); }
    }
  JAVA
  "dotnet-test" => { "CartSlowTests.cs" => <<~CS },
    using Xunit;

    [Trait("Category", "Slow")]
    public class CartSlowTests
    {
        [Fact]
        public void RunsWhenSlowTestsAreAskedFor() => Assert.Equal(2, 1 + 1);
    }
  CS
  "exunit" => { "test/cart_slow_test.exs" => <<~EXS },
    defmodule CartSlowTest do
      use ExUnit.Case
      @moduletag :slow

      test "runs when slow tests are asked for" do
        assert 1 + 1 == 2
      end
    end
  EXS
  "dart-test" => { "test/cart_slow_test.dart" => <<~DART },
    @Tags(['slow'])
    library;

    import 'package:test/test.dart';

    void main() {
      test('runs when slow tests are asked for', () {
        expect(1 + 1, equals(2));
      });
    }
  DART
  "swift-test" => { "Tests/CartTests/CartSlowTests.swift" => <<~SWIFT },
    import XCTest

    final class CartSlowTests: XCTestCase {
        func testRunsWhenSlowTestsAreAskedFor() {
            XCTAssertEqual(1 + 1, 2)
        }
    }
  SWIFT
  "pytest" => { "tests/test_slow.py" => <<~PY },
    import pytest


    @pytest.mark.slow
    def test_runs_when_slow_tests_are_asked_for():
        assert 1 + 1 == 2
  PY
  "rspec" => { "spec/slow_spec.rb" => <<~RB }
    RSpec.describe "a slow test", :slow do
      it("runs when slow tests are asked for") { expect(1 + 1).to eq(2) }
    end
  RB
}.freeze
