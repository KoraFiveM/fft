@kora @kora_core
Feature: kora_core modern export API
  The exports documented in kora_core/docs.md, called for the test character
  only: money, items, metadata, job, gang and duty, player data paths, change
  subscriptions, transactions, shared registries, identity and permissions.

  Money scenarios use the bank and crypto accounts. Cash may be inventory-owned
  physical cash, which is covered by the kora_inventory and vending suites.

  Not covered, on purpose: addPermission and removePermission (persistent ACE
  state), a successful transferMoney (needs a second player), clearInventory
  and setItems, character creation and deletion, a successful
  registerPlayerDataField or createUseable (cannot be undone while fft runs),
  stopPaycheck and stopNeedsDecay, dispatch alerts (kora_dispatch turns each
  into a real call), and a valid transaction `random` list (not deterministic;
  only its refusals are driven). registerShared and unregisterShared run in
  one @global scenario with a scratch fft_ location.

  Background:
    Given resource "kora_core" is running

  @server
  Scenario: Adding and removing money moves the balance and emits receipts
    Given I have 200 in my "bank" account
    And I remember my "bank" balance
    When the core adds 50 to my "bank" account
    Then the core should report 250 in my "bank" account
    And the core money receipt for "bank" should record add of 50
    When the core removes 120 from my "bank" account
    Then the core should report 130 in my "bank" account
    And the core money receipt for "bank" should record remove of 120
    And my "bank" balance should have decreased by 70

  @server
  Scenario: The bank account may be overdrawn but crypto may not
    Given I have 10 in my "bank" account
    And I have 5 in my "crypto" account
    When the core removes 30 from my "bank" account
    Then the core should report -20 in my "bank" account
    And the core should refuse to remove 6 from my "crypto" account with "insufficient funds"
    And the core should report 5 in my "crypto" account

  @server @rejection
  Scenario Outline: Invalid money additions are refused
    Given I have 100 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse to add <amount> to my "<account>" account with "<reason>"
    And my "bank" balance should be unchanged
    And no core money receipt should exist for "<account>"

    Examples:
      | amount | account        | reason                  |
      | 25     | fft_no_account | invalid account         |
      | 0      | bank           | amount must be positive |
      | -25    | bank           | amount must be positive |

  @server @rejection
  Scenario: Removals and assignments below the account floor are refused
    Given I have 100 in my "bank" account
    And I have 0 in my "crypto" account
    And I remember my "bank" balance
    Then the core should refuse to remove 60000 from my "bank" account with "insufficient funds"
    And the core should refuse to set my "bank" account to -60000 with "below account floor"
    And the core should refuse to set my "crypto" account to -1 with "below account floor"
    And the core should refuse to remove 0 from my "bank" account with "amount must be positive"
    And my "bank" balance should be unchanged
    And the core should report 0 in my "crypto" account
    And the core should report no "fft_no_account" account for me

  @server
  Scenario: Items are granted, counted, located and taken
    Given the core should report my carried weight within my limit
    And the core should say I can carry 3 "water_bottle"
    When I hold 3 "water_bottle"
    Then the core should count 3 "water_bottle" on me
    And the core should confirm I have 3 "water_bottle"
    And the core should deny I have 4 "water_bottle"
    And the core should find my "water_bottle" by name and by slot
    And the core should report my carried weight has grown
    When the core takes 2 "water_bottle" from me
    Then the core should count 1 "water_bottle" on me
    And the core should deny I have 2 "water_bottle"

  @server @rejection
  Scenario: Unknown items and missing stock are refused
    Given I hold 1 "water_bottle"
    Then the core should refuse to give me 1 "fft_no_such_item" with "unknown item"
    And the core should say I cannot carry 1 "fft_no_such_item" because "unknown item"
    And the core should say I cannot carry 100000 "water_bottle" because "over weight"
    And the core should refuse to take 2 "water_bottle" from me with "not enough of item"
    And the core should count 1 "water_bottle" on me
    And the core should find no "fft_no_such_item" by name

  @server
  Scenario: Metadata is set, announced and incremented within its clamp
    Given I watch core metadata announcements
    And my metadata "fft_probe" is 10
    Then the core should have announced my metadata "fft_probe" as 10
    When the core increments my metadata "fft_probe" by 5 within 0 and 100
    Then the core increment should have returned 15
    And my metadata "fft_probe" should be 15
    And the core should have announced my metadata "fft_probe" as 15
    When the core increments my metadata "fft_probe" by 500 within 0 and 100
    Then the core increment should have returned 100
    And my metadata "fft_probe" should be 100
    When the core increments my metadata "fft_probe" by -500 within 0 and 100
    Then the core increment should have returned 0
    And my metadata "fft_probe" should be 0

  @server @rejection
  Scenario: A metadata key must be text
    Then the core should refuse a metadata key that is not text
    And the core should hold no metadata "12345" for me

  @server
  Scenario: A job assignment is described and indexed
    Given my job is "mechanic" at grade 2
    Then the core should describe my job as "mechanic" grade 2 named "Mechanic"
    And the core should list me among "mechanic" staff
    And the core should not list me among "police" staff
    And my core player data at "job.name" should be the text "mechanic"
    And my core player data at "job.grade.level" should be 2

  @server
  Scenario: Duty changes move the on-duty index and count
    Given I am off duty as "mechanic" at grade 1
    And I remember the core on-duty count for "mechanic"
    Then the core should not list me among on-duty "mechanic" staff
    When the core puts me on duty
    Then I should be on duty
    And the core should list me among on-duty "mechanic" staff
    And the core on-duty count for "mechanic" should have changed by 1
    When the core takes me off duty
    Then I should be off duty
    And the core should not list me among on-duty "mechanic" staff
    And the core on-duty count for "mechanic" should have changed by 0

  @server
  Scenario: A gang assignment is described
    Given my gang is "ballas" at grade 2
    Then the core should describe my gang as "ballas" grade 2 named "Soldier"
    And my core player data at "gang.name" should be the text "ballas"

  @server @rejection
  Scenario: Unknown jobs and gangs are refused
    Given my job is "mechanic" at grade 1
    And my gang is "ballas" at grade 1
    Then the core should refuse to set my job to "fft_no_such_job" with "unknown job"
    And the core should refuse to set my gang to "fft_no_such_gang" with "unknown gang"
    And my job should be "mechanic"
    And my gang should be "ballas" according to the core

  @server
  Scenario: Player data is readable by path, citizen id and player list
    Given I have 321 in my "bank" account
    Then my core player data at "money.bank" should be 321
    And my core player data at "citizenid" should match my full snapshot
    And my core player data at "fft_no.such.path" should be absent
    And the core should find me by my citizen id
    And the core should find nobody by the citizen id "FFT_NO_SUCH_CITIZEN"
    And the core player list should include me

  Scenario: The client mirror follows server writes
    Given I have 432 in my "bank" account
    And my job is "mechanic" at grade 1
    Then my client core mirror at "money.bank" should become 432
    And my client core mirror at "job.name" should become the text "mechanic"

  @server
  Scenario: A change subscription sees writes until it is cancelled
    Given I subscribe to core changes under "metadata.fft_probe"
    When the core writes 7 to my player data at "metadata.fft_probe"
    Then my core subscription should have seen "metadata.fft_probe" become 7
    And my metadata "fft_probe" should be 7
    When I cancel my core subscription
    And the core writes 8 to my player data at "metadata.fft_probe"
    Then my metadata "fft_probe" should be 8
    And my core subscription should have recorded 1 changes

  @server @rejection
  Scenario: The write funnel refuses an empty path
    Then the core should refuse an empty player data path with "path must be a non-empty array"

  @server
  Scenario: A transaction moves money and items together
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    And I remember how many "water_bottle" I have
    When the core runs this transaction for me:
      """
      {
        "reason": "functional test",
        "money": { "remove": [ { "account": "bank", "amount": 20 } ] },
        "items": { "add": [ { "item": "water_bottle", "amount": 2 } ] }
      }
      """
    Then my "bank" balance should have decreased by 20
    And I should have 2 more "water_bottle" than before

  @server @rejection
  Scenario: A transaction the character cannot afford changes nothing
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    And I remember how many "water_bottle" I have
    Then the core should refuse this transaction with "insufficient funds":
      """
      {
        "reason": "functional test",
        "money": { "remove": [ { "account": "bank", "amount": 500 } ] },
        "items": { "add": [ { "item": "water_bottle", "amount": 2 } ] }
      }
      """
    And my "bank" balance should be unchanged
    And I should have 0 more "water_bottle" than before

  @server @rejection
  Scenario: A transaction that needs a missing item changes nothing
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse this transaction with "not enough of item: lockpick":
      """
      {
        "reason": "functional test",
        "money": { "add": [ { "account": "bank", "amount": 30 } ] },
        "items": { "remove": [ { "item": "lockpick", "amount": 1 } ] }
      }
      """
    And my "bank" balance should be unchanged

  @server @rejection
  Scenario: Malformed transactions are refused
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse a transaction that is not a table
    And the core should refuse this transaction with "invalid money entry":
      """
      { "money": { "remove": [ { "account": "bank", "amount": 0 } ] } }
      """
    And the core should refuse this transaction with "item amount must be a positive whole number":
      """
      { "items": { "add": [ { "item": "water_bottle", "amount": 0 } ] } }
      """
    And my "bank" balance should be unchanged

  @server
  Scenario: Shared registries answer lookups
    Then the core registry "items" should label "water_bottle" as "Water"
    And the core registry "jobs" should label "mechanic" as "Mechanic"
    And the core registry "gangs" should label "ballas" as "Ballas"
    And the core job "mechanic" should define 3 grades
    And the core registry "items" should list "water_bottle" among its records
    And the core registry "items" should not know "fft_no_such_item"
    And the core registry "fft_no_such_registry" should not know "water_bottle"

  @server
  Scenario: Identity and permission lookups are read only
    Given I remember my core permission level
    Then the core should grant me the baseline "user" permission
    And the core should report my identifiers
    And the core should generate a citizen id that is not mine
    And my core permission level should be unchanged

  # ---------------------------------------------------------------------------
  # Money edges
  # ---------------------------------------------------------------------------

  @server
  Scenario: Setting a balance assigns it exactly and publishes it
    Given I have 100 in my "bank" account
    And I remember my "bank" balance
    When the core sets my "bank" account to 777
    Then the core should report 777 in my "bank" account
    And the core money receipt for "bank" should record set of 777
    And my core money state bag for "bank" should be 777
    When the core adds 23 to my "bank" account
    Then my core money state bag for "bank" should be 800

  @server
  Scenario: The bank may be overdrawn exactly to its floor and no further
    Given I have 0 in my "bank" account
    When the core removes 50000 from my "bank" account
    Then the core should report -50000 in my "bank" account
    And the core should refuse to remove 1 from my "bank" account with "insufficient funds"
    And the core should report -50000 in my "bank" account
    When the core sets my "bank" account to -50000
    Then the core should report -50000 in my "bank" account

  @server
  Scenario: Crypto can be spent down to exactly zero
    Given I have 5 in my "crypto" account
    When the core removes 5 from my "crypto" account
    Then the core should report 0 in my "crypto" account
    And the core should refuse to remove 1 from my "crypto" account with "insufficient funds"

  @server
  Scenario: Fractional and numeric text amounts are accepted on ledger accounts
    Given I have 100 in my "bank" account
    When the core adds the amount "12.5" to my "bank" account
    Then the core should report the amount "112.5" in my "bank" account
    When the core adds the amount "7.5" to my "bank" account
    Then the core should report 120 in my "bank" account

  @server @rejection
  Scenario Outline: Amounts that are not finite numbers are refused
    Given I have 100 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse to <action> the amount "<amount>" for my "bank" account with "<reason>"
    And my "bank" balance should be unchanged
    And no core money receipt should exist for "bank"

    Examples:
      | action | amount  | reason                         |
      | add    | abc     | amount must be positive        |
      | add    | 1e999   | amount must be positive        |
      | add    | -0.5    | amount must be positive        |
      | remove | 1e999   | amount must be positive        |
      | remove | abc     | amount must be positive        |
      | set    | abc     | amount must be a finite number |
      | set    | 1e999   | amount must be a finite number |
      | set    | -1e999  | amount must be a finite number |

  @server @rejection
  Scenario Outline: Unknown accounts are refused for every write
    Given I have 100 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse to <action> the amount "25" for my "fft_no_account" account with "invalid account"
    And my "bank" balance should be unchanged
    And no core money receipt should exist for "fft_no_account"

    Examples:
      | action |
      | add    |
      | remove |
      | set    |

  @server @rejection
  Scenario: Transfers to nobody or to an unknown account change nothing
    Given I have 200 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse to transfer 50 from my "bank" account to an absent player
    And the core should refuse to transfer 0 from my "bank" account to myself with "invalid transfer"
    And the core should refuse to transfer -5 from my "bank" account to myself with "invalid transfer"
    And the core should refuse to transfer 50 from my "fft_no_account" account to myself with "invalid transfer"
    And my "bank" balance should be unchanged
    And no core money receipt should exist for "bank"

  @server
  Scenario: The tax preview is consistent with the configured rate
    Then the core tax preview for 1000 should follow the configured rate
    And the core tax preview for 7 should follow the configured rate
    And the core should refuse to collect a tax of 0

  @server @rejection
  Scenario Outline: Offline credits are refused before any write
    Given I have 100 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse an offline "<account>" credit of "<amount>" to <who> with "<reason>"
    And my "bank" balance should be unchanged

    Examples:
      | account        | amount | who   | reason                             |
      | bank           | 10     | blank | invalid citizenid                  |
      | fft_no_account | 10     | me    | invalid account                    |
      | bank           | 0      | me    | amount must be positive and finite |
      | bank           | -5     | me    | amount must be positive and finite |
      | bank           | 1e999  | me    | amount must be positive and finite |
      | bank           | 10     | me    | player is online                   |

  @server @rejection
  Scenario: An offline credit to a citizen that does not exist is refused
    Then the core should refuse an offline "bank" credit of "10" to FFT_NO_SUCH_CITIZEN with "player not found"

  # ---------------------------------------------------------------------------
  # Absent players
  # ---------------------------------------------------------------------------

  @server @rejection
  Scenario Outline: Writes for a server id with no loaded player are refused
    Then the core export "<export>" should refuse an absent player with "<reason>"

    Examples:
      | export            | reason               |
      | addMoney          | no such player       |
      | removeMoney       | no such player       |
      | setMoney          | no such player       |
      | setJob            | no such player       |
      | setGang           | no such player       |
      | setMetaData       | no such player       |
      | incrementMetaData | no such player       |
      | setPath           | no such player       |
      | savePlayer        | no such player       |
      | jailPlayer        | no such player       |
      | setDevMode        | player is not loaded |

  @server
  Scenario: Reads for a server id with no loaded player are empty
    Then the core should know nothing about an absent player

  # ---------------------------------------------------------------------------
  # Items
  # ---------------------------------------------------------------------------

  @server
  Scenario: Repeated grants of a stackable item share one slot
    Given I hold 2 "water_bottle"
    And I hold 3 "water_bottle"
    Then the core should keep my "water_bottle" in one stack of 5
    And the core should count 5 "water_bottle" on me

  @server @rejection
  Scenario Outline: Non-positive item amounts are refused
    Given I hold 1 "water_bottle"
    Then the core should refuse to give me <amount> "water_bottle"
    And the core should refuse to take <amount> "water_bottle" from me with "invalid amount"
    And the core should count 1 "water_bottle" on me

    Examples:
      | amount |
      | 0      |
      | -1     |

  @server
  Scenario: Item lists and count maps are checked as a whole
    Given I hold 2 "water_bottle"
    And I hold 1 "sandwich"
    Then the core should confirm I have each of "water_bottle,sandwich"
    And the core should deny I have each of "water_bottle,fft_no_such_item"
    And the core should confirm I have these amounts:
      """
      { "water_bottle": 2, "sandwich": 1 }
      """
    And the core should deny I have these amounts:
      """
      { "water_bottle": 3, "sandwich": 1 }
      """
    And the core should deny I have these amounts:
      """
      { "water_bottle": 1, "fft_no_such_item": 1 }
      """

  @server
  Scenario: A stack moves to a free slot and back
    Given I hold 2 "water_bottle"
    And the core should find nothing in my first free slot
    When the core moves my "water_bottle" to a free slot
    Then the core should show my "water_bottle" only in the slot it was moved to
    And the core should count 2 "water_bottle" on me
    When the core moves my "water_bottle" back
    Then the core should count 2 "water_bottle" on me

  @server @rejection
  Scenario: Impossible moves are refused and change nothing
    Given I hold 2 "water_bottle"
    And I hold 1 "sandwich"
    Then the core should refuse to move from my first free slot with "empty source slot"
    And the core should refuse to move my "water_bottle" to slot 0 with "invalid move"
    And the core should refuse to move my "water_bottle" to slot 999 with "invalid move"
    And the core should refuse to move my "water_bottle" onto my "sandwich" with "destination occupied"
    And the core should count 2 "water_bottle" on me
    And the core should count 1 "sandwich" on me

  @server @rejection
  Scenario: Using an item the character does not hold is refused
    Then the core should refuse to use "fft_no_such_item" with "item not found"
    And the core should refuse to use "lockpick" with "item not found"

  # ---------------------------------------------------------------------------
  # Metadata and needs
  # ---------------------------------------------------------------------------

  @server
  Scenario: An increment without bounds starts an absent key from zero
    Given the core should hold no metadata "fft_probe_absent" for me
    When the core increments my metadata "fft_probe_absent" by -7 without bounds
    Then the core increment should have returned -7
    And my metadata "fft_probe_absent" should be -7
    And the core should list my metadata "fft_probe_absent" as -7 in the full table

  @server
  Scenario: Text metadata and text deltas count as zero when incremented
    Given my metadata "fft_probe" is the text "not a number"
    When the core increments my metadata "fft_probe" by 4 without bounds
    Then the core increment should have returned 4
    When the core increments my metadata "fft_probe" by the text "lots"
    Then the core increment should have returned 4
    And my metadata "fft_probe" should be 4

  @server
  Scenario: A metadata value already outside the clamp is pulled inside it
    Given my metadata "fft_probe" is 250
    When the core increments my metadata "fft_probe" by 0 within 0 and 100
    Then the core increment should have returned 100
    And my metadata "fft_probe" should be 100

  @server
  Scenario: Resetting needs fills hunger and thirst and clears stress
    Given my metadata "hunger" is 40
    And my metadata "thirst" is 30
    And my metadata "stress" is 20
    When the core resets my needs
    Then my metadata "hunger" should be 100
    And my metadata "thirst" should be 100
    And my metadata "stress" should be 0

  # ---------------------------------------------------------------------------
  # Jobs, gangs and duty
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: Every seeded job grade is described as the registry defines it
    Given my job is "<job>" at grade <grade>
    Then the core should describe my job "<job>" at grade <grade> as the registry defines

    Examples:
      | job        | grade |
      | unemployed | 1     |
      | police     | 1     |
      | police     | 5     |
      | ambulance  | 3     |
      | mechanic   | 1     |
      | mechanic   | 3     |
      | roadside   | 2     |
      | bodyshop   | 3     |
      | tow        | 2     |

  @server
  Scenario Outline: Every seeded gang grade is described as the registry defines it
    Given my gang is "<gang>" at grade <grade>
    Then the core should describe my gang "<gang>" at grade <grade> as the registry defines

    Examples:
      | gang   | grade |
      | none   | 1     |
      | ballas | 1     |
      | ballas | 3     |
      | vagos  | 2     |

  @server
  Scenario Outline: Job grades are read as whole numbers of at least one
    Given I am given the job "mechanic" at the grade "<grade>"
    Then my core player data at "job.grade.level" should be <level>
    And the core should describe a grade that the job "mechanic" defines

    Examples:
      | grade | level |
      | 0     | 1     |
      | -3    | 1     |
      | 2.7   | 2     |
      | text  | 1     |

  @server
  Scenario: A gang grade below one is read as one
    Given I am given the gang "ballas" at the grade "0"
    Then my core player data at "gang.grade.level" should be 1
    And the core should describe a grade that the gang "ballas" defines

  @server
  Scenario: A job grade above the highest defined grade is not reported as a real grade
    Given I am given the job "mechanic" at the grade "9"
    Then the core should describe a grade that the job "mechanic" defines

  @server
  Scenario: Changing job resets duty to the job's default
    Given I am on duty as "mechanic" at grade 1
    When I am given the job "mechanic" at the grade "2"
    Then I should be off duty
    When I am given the job "unemployed" at the grade "1"
    Then I should be on duty

  @server
  Scenario: Job, gang and duty changes are announced
    Given I watch core job announcements
    And my job is "mechanic" at grade 1
    And my gang is "vagos" at grade 1
    Then the core should have announced my job as "mechanic"
    And the core should have announced my gang as "vagos"
    When the core puts me on duty
    Then the core should have announced my duty as on
    When the core takes me off duty
    Then the core should have announced my duty as off

  @server
  Scenario: Leaving a job removes me from its index
    Given my job is "mechanic" at grade 1
    And the core should list me among "mechanic" staff
    When I am given the job "roadside" at the grade "1"
    Then the core should not list me among "mechanic" staff
    And the core should list me among "roadside" staff
    And the core should not list me among on-duty "mechanic" staff

  @server
  Scenario: Putting someone on duty twice counts them once
    Given I am off duty as "mechanic" at grade 1
    And I remember the core on-duty count for "mechanic"
    When the core puts me on duty
    And the core puts me on duty
    Then the core on-duty count for "mechanic" should have changed by 1
    And the published on-duty count for "mechanic" should match the core

  @server
  Scenario: Job type indexes follow membership and duty
    Given I am off duty as "mechanic" at grade 2
    And I remember the core on-duty count for job type "automotive"
    Then the core should list me among "automotive" job type staff
    And the core should not list me among "leo" job type staff
    And the core should not list me among on-duty "automotive" job type staff
    And the core held job type counts should include "automotive"
    When the core puts me on duty
    Then the core should list me among on-duty "automotive" job type staff
    And the core on-duty count for job type "automotive" should have changed by 1
    And the core on-duty job type counts should include "automotive"

  @server
  Scenario: The duty roster describes me only while I am on duty
    Given I am off duty as "mechanic" at grade 2
    Then the core on-duty roster for "mechanic" should not list me
    And the core full roster for "mechanic" should describe me off duty
    When the core puts me on duty
    Then the core on-duty roster for "mechanic" should describe me
    And the core on-duty roster for job type "leo" should not list me
    And the published on-duty count for "mechanic" should match the core

  @server @rejection
  Scenario: Offline job and gang writes refuse unknown roles and online characters
    Then the core should refuse to store the offline job "fft_no_such_job" for me with "unknown job"
    And the core should refuse to store the offline gang "fft_no_such_gang" for me with "unknown gang"
    And the core should refuse to store the offline job "mechanic" for me with "player is online"

  # ---------------------------------------------------------------------------
  # Player data surface
  # ---------------------------------------------------------------------------

  @server
  Scenario: The whole player record, login state and readiness are reported
    Then the core should report my whole player data
    And the core should report me logged in and itself ready

  @server
  Scenario: A bare key subscription sees writes beneath it
    Given I subscribe to core changes under the single key "metadata"
    When the core writes 11 to my player data at "metadata.fft_probe"
    Then my core subscription should have seen "metadata.fft_probe" become 11

  @server
  Scenario: A subscription ignores writes outside its prefix
    Given I subscribe to core changes under "metadata.fft_other"
    When the core writes 12 to my player data at "metadata.fft_probe"
    Then my metadata "fft_probe" should be 12
    And my core subscription should have recorded 0 changes

  @server @rejection
  Scenario: Malformed subscriptions, saves and data fields are refused
    Then the core should refuse a change subscription without a handler
    And the core should refuse to save my player field "fft_no_field" with "invalid player field"
    And the core should refuse to register the player data field "money" with "invalid or reserved PlayerData field"
    And the core should refuse to register the player data field "citizenid" with "invalid or reserved PlayerData field"
    And the core should refuse to register the player data field "Fft-Bad" with "invalid or reserved PlayerData field"
    And the core should refuse to register the player data field "fft_probe_field" with "provider must be callable"
    And the core should refuse to write the player data field "fft_probe_field" with "PlayerData field is not registered"
    And my core player data at "fft_probe_field" should be absent

  Scenario: A client data watch sees server writes
    Given I watch my client core data under "metadata.fft_probe"
    When the core writes 13 to my player data at "metadata.fft_probe"
    Then my client core watch should have seen "metadata.fft_probe" become 13
    And my client core mirror at "metadata.fft_probe" should become 13

  # ---------------------------------------------------------------------------
  # Development mode
  # ---------------------------------------------------------------------------

  Scenario: Development mode turns on and off for the character only
    Given I watch core dev mode announcements
    When the core turns my dev mode on
    Then the core should report my dev mode on
    And my client should report dev mode on
    When the core turns my dev mode on
    And the core turns my dev mode off
    Then the core should report my dev mode off
    And my client should report dev mode off
    And the core should have announced my dev mode changes as "on,off"

  @server @rejection
  Scenario: Development mode needs a boolean
    Then the core should refuse to set my dev mode to the text "yes" with "enabled must be a boolean"
    And the core should refuse to set my dev mode to the text "true" with "enabled must be a boolean"

  # ---------------------------------------------------------------------------
  # Jail
  # ---------------------------------------------------------------------------

  @server @rejection
  Scenario Outline: A jail sentence must be a positive number of minutes
    Then the core should refuse to jail me for "<minutes>" minutes with "minutes must be positive"
    And the core should not hold me in jail

    Examples:
      | minutes |
      | 0       |
      | -1      |
      | soon    |

  @world
  Scenario: A jail sentence holds the character until release
    Given I will be brought back here after the core jail
    When the core jails me for 1 minute
    Then the core should hold me in jail for at most 60 seconds
    And the core should have announced that I was jailed for 1 minute
    And I should see a notification containing "You have been jailed for 1 minutes."
    And I should be within 10 metres of the core jail
    When the core releases me from jail
    Then the core should have announced my release from jail
    And I should see a notification containing "You have been released."
    And the core should not hold me in jail
    And I return to where I stood before the core jail

  # ---------------------------------------------------------------------------
  # Transactions
  # ---------------------------------------------------------------------------

  @server
  Scenario: A transaction can take an item and pay for it
    Given I hold 2 "water_bottle"
    And I have 50 in my "bank" account
    And I remember my "bank" balance
    And I remember how many "water_bottle" I have
    When the core runs this transaction for me:
      """
      {
        "reason": "functional test",
        "items": { "remove": [ { "item": "water_bottle", "amount": 1 } ] },
        "money": { "add": [ { "account": "bank", "amount": 30 } ] }
      }
      """
    Then my "bank" balance should have increased by 30
    And I should have 1 fewer "water_bottle" than before

  @server
  Scenario: An empty transaction succeeds and changes nothing
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    When the core runs this transaction for me:
      """
      { "reason": "functional test" }
      """
    Then my "bank" balance should be unchanged
    And no core money receipt should exist for "bank"

  @server @rejection
  Scenario: A failing second crypto payment rolls back the first
    Given I have 5 in my "crypto" account
    Then the core should refuse this transaction with "insufficient funds":
      """
      {
        "reason": "functional test",
        "money": { "remove": [
          { "account": "crypto", "amount": 3 },
          { "account": "crypto", "amount": 3 }
        ] }
      }
      """
    And the core should report 5 in my "crypto" account

  @server @rejection
  Scenario: Several bank payments are checked against the balance together
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse this transaction with "insufficient funds":
      """
      {
        "reason": "functional test",
        "money": { "remove": [
          { "account": "bank", "amount": 30 },
          { "account": "bank", "amount": 30 }
        ] }
      }
      """
    And my "bank" balance should be unchanged

  @server @rejection
  Scenario: Repeated removals of one item are added up before the check
    Given I hold 1 "water_bottle"
    And I have 50 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse this transaction with "not enough of item: water_bottle":
      """
      {
        "reason": "functional test",
        "money": { "add": [ { "account": "bank", "amount": 10 } ] },
        "items": { "remove": [
          { "item": "water_bottle", "amount": 1 },
          { "item": "water_bottle", "amount": 1 }
        ] }
      }
      """
    And the core should count 1 "water_bottle" on me
    And my "bank" balance should be unchanged

  @server @rejection
  Scenario: Transactions that cannot be carried or credited change nothing
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    And I remember how many "water_bottle" I have
    Then the core should refuse this transaction with "over weight":
      """
      {
        "reason": "functional test",
        "money": { "remove": [ { "account": "bank", "amount": 10 } ] },
        "items": { "add": [ { "item": "water_bottle", "amount": 100000 } ] }
      }
      """
    And the core should refuse this transaction with "unknown item":
      """
      {
        "reason": "functional test",
        "money": { "remove": [ { "account": "bank", "amount": 10 } ] },
        "items": { "add": [ { "item": "fft_no_such_item", "amount": 1 } ] }
      }
      """
    And the core should refuse this transaction with "invalid account":
      """
      {
        "reason": "functional test",
        "money": {
          "remove": [ { "account": "bank", "amount": 10 } ],
          "add": [ { "account": "fft_no_account", "amount": 10 } ]
        }
      }
      """
    And my "bank" balance should be unchanged
    And I should have 0 more "water_bottle" than before

  @server @rejection
  Scenario: Malformed transaction entries are refused
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    Then the core should refuse this transaction with "invalid money entry":
      """
      { "money": { "remove": [ { "account": "bank", "amount": 2.5 } ] } }
      """
    And the core should refuse this transaction with "invalid money entry":
      """
      { "money": { "add": [ { "amount": 10 } ] } }
      """
    And the core should refuse this transaction with "invalid item entry":
      """
      { "items": { "add": [ { "amount": 1 } ] } }
      """
    And the core should refuse this transaction with "item amount must be a positive whole number":
      """
      { "items": { "remove": [ { "item": "water_bottle", "amount": 1.5 } ] } }
      """
    And my "bank" balance should be unchanged

  @server @rejection
  Scenario: Malformed reward lists are refused before anything moves
    Given I have 50 in my "bank" account
    And I remember my "bank" balance
    And I remember how many "water_bottle" I have
    Then the core should refuse this reward transaction with "random must be a table":
      """
      { "money": { "add": [ { "account": "bank", "amount": 10 } ] }, "random": "water_bottle" }
      """
    And the core should refuse this reward transaction with "invalid random item entry":
      """
      { "money": { "add": [ { "account": "bank", "amount": 10 } ] }, "random": [ { "amount": 1 } ] }
      """
    And the core should refuse this reward transaction with "random item amount must be a positive whole number or an integer range":
      """
      { "money": { "add": [ { "account": "bank", "amount": 10 } ] }, "random": [ { "item": "water_bottle", "amount": 0 } ] }
      """
    And the core should refuse this reward transaction with "random item amount must be a positive whole number or an integer range":
      """
      { "money": { "add": [ { "account": "bank", "amount": 10 } ] }, "random": [ { "item": "water_bottle", "amount": { "min": 3, "max": 1 } } ] }
      """
    And the core should refuse this reward transaction with "random item amount must be a positive whole number or an integer range":
      """
      { "money": { "add": [ { "account": "bank", "amount": 10 } ] }, "random": [ { "item": "water_bottle", "amount": 1.5 } ] }
      """
    And my "bank" balance should be unchanged
    And I should have 0 more "water_bottle" than before

  # ---------------------------------------------------------------------------
  # Registries
  # ---------------------------------------------------------------------------

  @server
  Scenario: Every registry reports a consistent snapshot
    Then the core registry snapshot should describe every registry
    And the core location "spawn_legion" should be labelled "Legion Square"
    And the core location "garage_legion" should be labelled "Legion Garage"

  @server @rejection
  Scenario: Malformed shared records and watches are refused
    Then the core should refuse a shared location "fft_probe_location" that is not a table
    And the core should refuse a shared record for the unknown registry "fft_no_such_registry"
    And the core should refuse a location record keyed "fft_probe_other" under the key "fft_probe_location"
    And the core should refuse to watch the registry "fft_no_such_registry" with "no such registry"
    And the core should refuse to watch the registry "locations" with "handler must be callable"
    And the core should refuse to unregister the unknown location "fft_probe_location"

  @server @global
  Scenario: A shared record is added, updated and removed with announcements
    Given I watch the core registry "locations"
    And I remember the core registry count for "locations"
    When the core registers the probe location "fft_probe_location" labelled "FFT probe" at the location "spawn_legion"
    Then the core registry "locations" count should have changed by 1
    And the core location "fft_probe_location" should be labelled "FFT probe"
    And the core registry watch should have seen add of "fft_probe_location"
    When the core registers the probe location "fft_probe_location" labelled "FFT probe updated" at the location "spawn_legion"
    Then the core registry "locations" count should have changed by 1
    And the core location "fft_probe_location" should be labelled "FFT probe updated"
    And the core registry watch should have seen update of "fft_probe_location"
    When the core unregisters the probe location "fft_probe_location"
    Then the core registry "locations" count should have changed by 0
    And the core registry "locations" should not know "fft_probe_location"
    And the core registry watch should have seen remove of "fft_probe_location"

  # ---------------------------------------------------------------------------
  # Identity, permissions, commands, logs and utilities
  # ---------------------------------------------------------------------------

  @server
  Scenario: Identity lookups find the character by its stored identifier
    Then the core should find my citizen id by my primary identifier
    And the core should find no citizen by the license identifier "fft_no_such_license"
    And the core should generate 10 distinct citizen ids shaped like mine

  @server
  Scenario: Permission helpers agree with the permission level
    Given I remember my core permission level
    Then the core opt-in and privileged permissions should follow my level
    And the core should grant me the baseline "user" permission
    And my core permission level should be unchanged

  @server
  Scenario: Admin commands, log statistics and the paycheck loop are registered
    Then the core should list the "jail" command for "admin"
    And the core should list the "unjail" command for "admin"
    And the core log statistics and paycheck loop should be live

  @server
  Scenario: The pure utility exports behave as documented
    Then the core should round 2.5 to 3.0
    And the core should round -2.5 to -2.0
    And the core should round 1.23456 to 2 places as 1.23
    And the core should round a text value to 0
    And the core should trim "  a b  " to "a b"
    And the core should split "a,b,,c" on "," into 4 parts
    And the core should split "abc" on "," into 1 parts
    And the core should split "a.b" on "." into 2 parts
    And the core should make random letter text of length 8
    And the core should make random digit text of length 6
    And the core should make random alphanumeric text of length 12
    And the core should make random letter text of length 0
    And the core should read, write and copy nested paths

  @client
  Scenario: Every vehicle model in the game is in the shared vehicles list
    Then every registered vehicle model should be in the shared vehicles list
