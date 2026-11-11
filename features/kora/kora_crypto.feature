@kora @kora_crypto
Feature: kora_crypto stick exchange
  Players crack crypto sticks at the exchange for Qbit. The crack itself is a
  skill minigame that tests never force, so these scenarios cover the market
  state, the wallet command, the guard for players without a stick, and the
  server's own guards on the events the minigame ends with: the exchange
  distance and the single-use crack ticket that only the stick check mints.
  No scenario holds a stick while targeting the exchange, so no ticket exists.

  Background:
    Given resource "kora_crypto" is running

  @server
  Scenario: Market publishes a bounded price
    Then the crypto market should publish a price within its configured bounds

  @ui
  Scenario: Wallet command reports the Qbit balance
    When I run the command "checkCrypto"
    Then I should see a notification containing "Total Value"

  # Exchange is Crypto.Exchange = 1276.21, -1709.88, 54.57 (Lester's house).
  @world
  Scenario: Exchange offers the crack option
    Given I stand at 1275.2 -1710.6 54.77 facing 300.0
    When I aim at 1276.21 -1709.88 54.57
    Then the target option "Crack Crypto Stick" should be visible

  @world @rejection
  Scenario: Exchange refuses a player without a crypto stick
    Given I should have no "cryptostick"
    And I remember my "crypto" balance
    And I stand at 1275.2 -1710.6 54.77 facing 300.0
    When I aim at 1276.21 -1709.88 54.57
    And I target "Crack Crypto Stick"
    Then I should see a notification containing "don't have a cryptostick"
    And my "crypto" balance should be unchanged

  @server
  Scenario: Market history is a chain of bounded price moves
    Then the crypto market history should be a chain of bounded price moves

  @server
  Scenario: Published market matches the stored crypto row
    Given resource "kora_sql" is running
    Then the crypto market should match its database row

  @ui
  Scenario: Wallet command values the Qbit balance at the market price
    Given I have 3 in my "crypto" account
    And my Qbit wallet should read 3 on the client
    When I run the command "checkCrypto"
    Then I should see the Qbit wallet value for 3 coins

  @ui
  Scenario: Wallet command reports an empty wallet
    Given I have 0 in my "crypto" account
    And my Qbit wallet should read 0 on the client
    When I run the command "checkCrypto"
    Then I should see a notification containing "You Have 0 QBit(s) Total Value: $ 0"

  @world @rejection
  Scenario: Exchange keeps the Qbit balance of a player without a stick
    Given I should have no "cryptostick"
    And I have 2 in my "crypto" account
    And I remember my "crypto" balance
    And I stand at 1275.2 -1710.6 54.77 facing 300.0
    When I aim at 1276.21 -1709.88 54.57
    And I target "Crack Crypto Stick"
    Then I should see a notification containing "don't have a cryptostick"
    And no progress bar should be running
    And my "crypto" balance should be unchanged

  # Away from Crypto.Exchange the events fail their distance assert, which the
  # server prints as a script error (locales/en.lua asserts.too_far). The
  # stand point is the kora_banking counter in Legion Square.
  @world @rejection
  Scenario Outline: Exchange ignores a crack report from far away
    Given I hold 1 "cryptostick"
    And I remember how many "cryptostick" I have
    And I remember my "crypto" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I expect a console error from "kora_crypto" containing "is too far from the exchange"
    When I report a <outcome> crypto crack to the server
    Then my "crypto" balance should be unchanged
    And I should have 0 fewer "cryptostick" than before

    Examples:
      | outcome    |
      | successful |
      | failed     |

  # At the exchange the events need a ticket minted by
  # qb-crypto:server:hasCryptoStick; without one they are logged and ignored.
  @world @rejection
  Scenario Outline: Exchange ignores a crack report without a crack ticket
    Given I hold 1 "cryptostick"
    And I remember how many "cryptostick" I have
    And I remember my "crypto" balance
    And I stand at 1275.2 -1710.6 54.77 facing 300.0
    When I report a <outcome> crypto crack to the server
    Then my "crypto" balance should be unchanged
    And I should have 0 fewer "cryptostick" than before

    Examples:
      | outcome    |
      | successful |
      | failed     |

  @world @rejection
  Scenario: Repeated crack reports without a ticket pay nothing
    Given I hold 2 "cryptostick"
    And I remember how many "cryptostick" I have
    And I remember my "crypto" balance
    And I stand at 1275.2 -1710.6 54.77 facing 300.0
    When I report a successful crypto crack to the server
    And I report a successful crypto crack to the server
    And I report a failed crypto crack to the server
    Then my "crypto" balance should be unchanged
    And I should have 0 fewer "cryptostick" than before
