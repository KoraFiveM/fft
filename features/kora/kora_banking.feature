@kora @kora_banking
Feature: kora_banking counter, ATM and society accounts
  Players bank at a branch counter or an ATM through the "kora_banking:bank"
  AppShell app; the server re-checks position, session, balances and limits on
  every request. App actions are driven at the NUI-callback level through
  kora_lib's hook; they do not click rendered controls, and kora_lib does not
  apply the form's min, max or pattern at that level, so the refusals asserted
  here are the server's own.

  Every successful deposit or withdrawal writes a bank_statements row for the
  test character. Those rows have no delete API, and personal withdrawals count
  toward the 5000 daily ATM allowance, so the success paths move small amounts.

  Most scenarios below the app ones talk to the server over banking's own
  request channel (kora_banking:server:request), sending exactly what the
  banking client sends, so the server's session, distance, card, PIN and
  amount checks decide every answer. Shared accounts the suite opens are named
  "fft ..." and closed again in cleanup by the same transfer and close actions
  a player uses; other shared accounts the test character owns are never
  touched.

  Not covered: transfers to another character (the tester is the only
  subject); successful credits and debits on a society or gang account (money
  other players see); granting access to another real character; "givecash"
  (needs a second player); and bank tiers, which are disabled in config.

  Background:
    Given resource "kora_banking" is running

  @server
  Scenario: Every job has a society account
    Then the bank should hold a society account for "police"
    And the bank should hold no account named "fft_no_such_account"

  @server @rejection
  Scenario Outline: Society account refuses an invalid credit
    Given I remember the bank balance of the account "police"
    Then crediting the bank account "<account>" with <amount> should be refused
    And the bank balance of the account "police" should be unchanged

    Examples:
      | account             | amount |
      | police              | 0      |
      | police              | -50    |
      | fft_no_such_account | 100    |

  @server @rejection
  Scenario: Society account cannot be overdrawn
    Given I remember the bank balance of the account "police"
    Then debiting the bank account "police" beyond its balance should be refused
    And the bank balance of the account "police" should be unchanged

  # Counter is Config.locations[1] = 149.05, -1041.3, 29.37 (Fleeca, Legion
  # Square). With tiers disabled its target label is "Open bank".
  @ui @world
  Scenario: Branch counter opens the bank app
    Given I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I close the app
    Then no app should be open

  @ui @world
  Scenario: Counter deposits cash into the personal account
    Given I have 500 in my "cash" account
    And I have 1000 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:deposit" with:
      """
      { "value": { "account": "checking", "amount": 200 } }
      """
    Then the app should answer with a "success" notice containing "Deposited $200"
    And my "cash" balance should have decreased by 200
    And my "bank" balance should have increased by 200

  @ui @world
  Scenario: Counter withdraws cash from the personal account
    Given I have 0 in my "cash" account
    And I have 1000 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:withdraw" with:
      """
      { "value": { "account": "checking", "amount": 100 } }
      """
    Then the app should answer with a "success" notice containing "Withdrew $100"
    And my "bank" balance should have decreased by 100
    And my "cash" balance should have increased by 100

  @ui @world @rejection
  Scenario Outline: Counter refuses an invalid cash request
    Given I have 100 in my "cash" account
    And I have 100 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "<action>" with:
      """
      { "value": { "account": "<account>", "amount": <amount> } }
      """
    Then I should see a notification containing "<reason>"
    And my "cash" balance should be unchanged
    And my "bank" balance should be unchanged

    Examples:
      | action           | account             | amount | reason                                  |
      | banking:deposit  | checking            | 101    | You do not have that much cash          |
      | banking:withdraw | checking            | 101    | That account does not have enough money |
      | banking:deposit  | checking            | 0      | Enter a valid amount                    |
      | banking:withdraw | checking            | -20    | Enter a valid amount                    |
      | banking:deposit  | fft_no_such_account | 50     | You cannot use that account             |

  @ui @world @rejection
  Scenario: Counter refuses a transfer between the same account
    Given I have 500 in my "bank" account
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:transfer:internal" with:
      """
      { "value": { "from": "checking", "to": "checking", "amount": 50 } }
      """
    Then I should see a notification containing "Choose two different accounts"
    And my "bank" balance should be unchanged

  @ui @world @rejection
  Scenario: Counter refuses a transfer to an unknown account number
    Given I have 500 in my "bank" account
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:transfer:player" with:
      """
      { "value": { "from": "checking", "recipient": "fft_no_such_account", "amount": 50 } }
      """
    Then I should see a notification containing "No account was found with that number"
    And my "bank" balance should be unchanged

  @ui @world @rejection
  Scenario Outline: Counter refuses an invalid shared account
    Given I have 500 in my "bank" account
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:create-shared" with:
      """
      { "value": { "name": "<name>", "amount": <amount> } }
      """
    Then I should see a notification containing "<reason>"
    And my "bank" balance should be unchanged
    And the bank should hold no account named "<name>"

    Examples:
      | name           | amount | reason                                   |
      | fft suite acct | 0      | You can not open a shared account with   |
      | ff             | 50     | Account names need at least 3 characters |

  @ui @world
  Scenario: Counter issues a bank card
    Given I should have no "bank_card"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:order-card" with:
      """
      { "value": { "pin": "4821" } }
      """
    Then the app should answer with a "success" notice containing "Bank card issued"
    And I should have at least 1 "bank_card"

  @ui @world @rejection
  Scenario: Counter refuses a card with a short PIN
    Given I should have no "bank_card"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:order-card" with:
      """
      { "value": { "pin": "12" } }
      """
    Then I should see a notification containing "Choose a 4-digit PIN"
    And I should have no "bank_card"

  # ATM is Config.atmCoords[1] = 147.4, -1035.8, 29.3 (outside the Legion
  # Square Fleeca); reach is atmDistance 1.8 plus atmTolerance 1.0.
  @ui @world @rejection
  Scenario: ATM refuses a player without a bank card
    Given I should have no "bank_card"
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    When I aim at 147.4 -1035.8 29.8
    And I target "Use ATM"
    Then I should see a notification containing "need a bank card"
    And no progress bar should be running
    And no app should be open

  @ui @world @rejection
  Scenario: ATM stays locked after a wrong PIN
    # A granted card carries no PIN, so no PIN can unlock it. One attempt only:
    # five wrong attempts lock the session for 30 seconds.
    Given I hold 1 "bank_card"
    And I have 500 in my "bank" account
    And I remember my "bank" balance
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    When I aim at 147.4 -1035.8 29.8
    And I target "Use ATM"
    Then a progress bar labelled "Accessing ATM" should start
    And the app "kora_banking:bank" should be open
    And the app action "banking:withdraw" should be unavailable
    When I trigger the app action "banking:unlock" with:
      """
      { "value": { "pin": "0000" } }
      """
    Then the app should answer with a "destructive" notice containing "Incorrect PIN"
    And the ATM should have stayed locked
    And the app action "banking:withdraw" should be unavailable
    And my "bank" balance should be unchanged

  @ui @world
  Scenario: ATM unlocks with the issued card's PIN and enforces the daily limit
    Given I have 0 in my "cash" account
    And I have 6000 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:order-card" with:
      """
      { "value": { "pin": "4821" } }
      """
    Then I should have at least 1 "bank_card"
    When I close the app
    Then no app should be open
    Given I remember my "bank" balance
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    When I aim at 147.4 -1035.8 29.8
    And I target "Use ATM"
    Then a progress bar labelled "Accessing ATM" should start
    And the app "kora_banking:bank" should be open
    When I trigger the app action "banking:unlock" with:
      """
      { "value": { "pin": "4821" } }
      """
    Then the ATM should have unlocked its cash view
    # 5001 is above Config.dailyLimit = 5000 whatever was withdrawn today.
    When I trigger the app action "banking:withdraw" with:
      """
      { "value": { "account": "checking", "amount": 5001 } }
      """
    Then I should see a notification containing "Above the limit"
    And my "bank" balance should be unchanged
    # The ATM app declares the cash view only.
    And the app action "banking:transfer:internal" should be unavailable
    And the app action "banking:order-card" should be unavailable

  # ---------------------------------------------------------------------------
  # Exports and account rows (server.lua, server/finance.lua)
  # ---------------------------------------------------------------------------

  @server
  Scenario: Every gang has a gang account
    # Created at startup for each kora_core gang except "none".
    Then the bank should hold a gang account for "ballas"
    And the bank should hold a gang account for "vagos"

  @server @rejection
  Scenario: Society account refuses a fractional credit and invalid debits
    Given I remember the bank balance of the account "police"
    Then crediting the bank account "police" with half a dollar should be refused
    And debiting the bank account "police" with 0 should be refused
    And debiting the bank account "police" with -50 should be refused
    And debiting the bank account "fft_no_such_account" with 10 should be refused
    And the bank balance of the account "police" should be unchanged

  @server @rejection
  Scenario: Durable banking exports refuse an unlisted resource
    Then the durable banking exports should refuse this resource

  # ---------------------------------------------------------------------------
  # The request channel itself
  # ---------------------------------------------------------------------------

  @rejection
  Scenario: Bank refuses an unknown request
    When I send the banking request "fft_unknown_operation"
    Then the bank should refuse with "Invalid banking request."

  @rejection
  Scenario: Bank refuses an action that is not a table
    When I send a banking action that is not a table
    Then the bank should refuse with "Invalid request."

  @rejection
  Scenario: Bank refuses an action without a session
    Given I have 100 in my "cash" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    When I close my banking session
    And I send the banking action:
      """
      { "kind": "deposit", "account": "checking", "amount": 10 }
      """
    Then the bank should refuse with "Your banking session expired."
    And my "cash" balance should be unchanged
    And my "bank" balance should be unchanged

  # ---------------------------------------------------------------------------
  # Counter sessions
  # ---------------------------------------------------------------------------

  @world
  Scenario: Counter session snapshot reflects the character
    Given I have 250 in my "cash" account
    And I have 1234 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    Then the bank snapshot should be for a counter session
    And the bank snapshot account "checking" should be a "checking" account labelled "Personal bank"
    And the bank snapshot should not let me manage the account "checking"
    And the bank snapshot should show 1234 in the account "checking"
    And the bank snapshot should show 250 cash
    And the bank snapshot should show my citizen ID as the account number
    And the bank snapshot should list 0 bank cards
    And the bank snapshot should report the configured limits

  @world @rejection
  Scenario Outline: Counter session refuses a player away from the branch
    Given I stand at <x> <y> <z> facing 158.0
    Then opening a bank counter session for location <index> should be refused with "Move closer to a bank counter."

    Examples:
      | x      | y        | z     | index |
      | 149.38 | -1040.46 | 29.37 | 99    |
      | 149.38 | -1040.46 | 29.37 | 0     |
      | 147.77 | -1034.87 | 29.34 | 1     |

  @world
  Scenario: Counter session resolves the branch from the player's position
    # branchAt(): the client-sent index only has to name a real location; the
    # branch is the configured location nearest the player (Config.locations[8]
    # is Blaine County Savings, far from here).
    Given I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 8
    Then the bank snapshot should be for a counter session

  @world @rejection
  Scenario: Counter session ends when the player walks away
    Given I have 100 in my "cash" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    And I send the banking action:
      """
      { "kind": "deposit", "account": "checking", "amount": 10 }
      """
    Then the bank should refuse with "Your banking session expired."
    And my "cash" balance should be unchanged
    And my "bank" balance should be unchanged

  @world @rejection
  Scenario: Counter refuses a PIN entry
    Given I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I enter the ATM PIN "4821"
    Then the bank should refuse with "Open an ATM first."

  # ---------------------------------------------------------------------------
  # Counter cash: amounts are floored and must be 1..1000000000 (roundAmount)
  # ---------------------------------------------------------------------------

  @world
  Scenario Outline: Counter deposit floors the amount it is given
    Given I have 100 in my "cash" account
    And I have 100 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "deposit", "account": "checking", "amount": <amount> }
      """
    Then the bank should answer "<message>"
    And my "cash" balance should have decreased by <moved>
    And my "bank" balance should have increased by <moved>
    And the bank snapshot should show <bank> in the account "checking"

    Examples:
      | amount | message        | moved | bank |
      | 1.9    | Deposited $1.  | 1     | 101  |
      | "5"    | Deposited $5.  | 5     | 105  |
      | 100    | Deposited $100. | 100 | 200 |

  @world @rejection
  Scenario Outline: Counter refuses an amount that is not a whole positive number
    Given I have 100 in my "cash" account
    And I have 100 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "<kind>", "account": "checking", "amount": <amount> }
      """
    Then the bank should refuse with "Enter a valid amount."
    And my "cash" balance should be unchanged
    And my "bank" balance should be unchanged

    Examples:
      | kind     | amount     |
      | deposit  | 0.5        |
      | deposit  | "abc"      |
      | deposit  | 1000000001 |
      | withdraw | null       |
      | withdraw | -1         |

  @world
  Scenario: Counter deposit writes a statement with its reference
    Given I have 100 in my "cash" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "deposit", "account": "checking", "amount": 2, "reason": "$reference" }
      """
    Then the bank should answer "Deposited $2."
    And the bank snapshot should record a "deposit" of 2 on "checking" with my reference

  @world
  Scenario: Counter withdrawal counts toward the daily ATM allowance
    # Config: bank-counter withdrawals are not blocked by the ATM limit but
    # count toward it (dailyWithdrawalRemaining in server.lua).
    Given I have 0 in my "cash" account
    And I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    Then the bank snapshot should allow at least 1 more ATM withdrawal today
    When I remember my ATM allowance
    And I send the banking action:
      """
      { "kind": "withdraw", "account": "checking", "amount": 1, "reason": "$reference" }
      """
    Then the bank should answer "Withdrew $1."
    And my ATM allowance should have dropped by 1
    And the bank snapshot should record a "withdraw" of 1 on "checking" with my reference

  @world
  Scenario: Counter deposit does not use up the daily ATM allowance
    Given I have 100 in my "cash" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I remember my ATM allowance
    And I send the banking action:
      """
      { "kind": "deposit", "account": "checking", "amount": 1 }
      """
    Then the bank should answer "Deposited $1."
    And my ATM allowance should be unchanged

  # ---------------------------------------------------------------------------
  # Counter transfers (transfer() in server.lua)
  # ---------------------------------------------------------------------------

  @world @rejection
  Scenario Outline: Counter refuses an invalid transfer
    # Not a society boss, so "police" is not a usable source account.
    Given my job is "unemployed" at grade 1
    And I have 100 in my "bank" account
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "transfer", <fields> }
      """
    Then the bank should refuse with "<reason>"
    And my "bank" balance should be unchanged

    Examples:
      | fields                                                              | reason                                          |
      | "from": "fft_no_such_account", "to": "checking", "amount": 5         | You cannot use the source account.              |
      | "from": "checking", "to": "fft_no_such_account", "amount": 5         | You cannot use the destination account.         |
      | "from": "checking", "amount": 5                                      | Enter an account number.                        |
      | "from": "checking", "recipient": "   ", "amount": 5                  | Enter an account number.                        |
      | "from": "checking", "recipient": "$citizenid", "amount": 5           | Use an internal transfer for your own accounts. |
      | "from": "checking", "recipient": "fft_no_such_account", "amount": 0  | Enter a valid amount.                           |
      | "from": "police", "to": "checking", "amount": 5                      | You cannot use the source account.              |

  @world @rejection
  Scenario: Counter refuses to send more than the personal account holds to a society
    # "police" resolves as an account name (resolveRecipient), so only the
    # debit stands between this request and a society credit.
    Given I have 100 in my "bank" account
    And I remember my "bank" balance
    And I remember the bank balance of the account "police"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "transfer", "from": "checking", "recipient": "police", "amount": 101 }
      """
    Then the bank should refuse with "The source account does not have enough money."
    And my "bank" balance should be unchanged
    And the bank balance of the account "police" should be unchanged

  # ---------------------------------------------------------------------------
  # Society and gang accounts: visible to bosses only (mayUse in server.lua)
  # ---------------------------------------------------------------------------

  @world
  Scenario: Society boss sees and manages the society account
    # Grade 5 is the police Chief, isboss in kora_core's jobs.
    Given my job is "police" at grade 5
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    Then the bank snapshot account "police" should be a "job" account labelled "Society bank"
    And the bank snapshot should let me manage the account "police"

  @world @rejection
  Scenario: Society member below boss neither sees nor uses the society account
    Given my job is "police" at grade 1
    And I have 100 in my "cash" account
    And I remember my "cash" balance
    And I remember the bank balance of the account "police"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    Then the bank snapshot should not list the account "police"
    When I send the banking action:
      """
      { "kind": "deposit", "account": "police", "amount": 10 }
      """
    Then the bank should refuse with "You cannot use that account."
    And my "cash" balance should be unchanged
    And the bank balance of the account "police" should be unchanged

  @world @rejection
  Scenario: Society boss cannot overdraw the society account
    Given my job is "police" at grade 5
    And I have 0 in my "cash" account
    And I remember my "cash" balance
    And I remember the bank balance of the account "police"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "withdraw", "account": "police", "amount": 1000000000 }
      """
    Then the bank should refuse with "That account does not have enough money."
    And my "cash" balance should be unchanged
    And the bank balance of the account "police" should be unchanged

  @world @rejection
  Scenario: Society boss cannot deposit more cash than they carry
    Given my job is "police" at grade 5
    And I have 10 in my "cash" account
    And I remember my "cash" balance
    And I remember the bank balance of the account "police"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "deposit", "account": "police", "amount": 11 }
      """
    Then the bank should refuse with "You do not have that much cash."
    And my "cash" balance should be unchanged
    And the bank balance of the account "police" should be unchanged

  @world
  Scenario: Gang boss sees the gang account
    # Grade 3 is the Ballas Boss, isboss in kora_core's gangs.
    Given my gang is "ballas" at grade 3
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    Then the bank snapshot account "ballas" should be a "gang" account labelled "Gang bank"
    And the bank snapshot should let me manage the account "ballas"

  @world
  Scenario: Gang member below boss does not see the gang account
    Given my gang is "ballas" at grade 1
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    Then the bank snapshot should not list the account "ballas"

  # ---------------------------------------------------------------------------
  # Shared accounts (manage() in server.lua). Names start with "fft" so the
  # cleanup sweep can close them; amounts stay small because the opening
  # balance is a checking withdrawal that counts toward the ATM allowance.
  # ---------------------------------------------------------------------------

  @world
  Scenario: Shared account round trip: open, rename, fund, empty and close
    Given I have 20 in my "cash" account
    And I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    And I remember my "bank" balance
    And I remember my "cash" balance
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 5 }
      """
    Then the bank should answer "Shared account created."
    And my "bank" balance should have decreased by 5
    And the bank should hold a shared account "fft shared one" owned by me with 5
    And the bank snapshot account "fft shared one" should be a "shared" account labelled "Shared bank"
    And the bank snapshot should let me manage the account "fft shared one"
    And the bank snapshot should show 5 in the account "fft shared one"
    When I send the banking action:
      """
      { "kind": "rename", "account": "fft shared one", "name": "fft shared two" }
      """
    Then the bank should answer "Shared account renamed."
    And the bank should hold no account named "fft shared one"
    And the bank should hold a shared account "fft shared two" owned by me with 5
    When I send the banking action:
      """
      { "kind": "deposit", "account": "fft shared two", "amount": 3 }
      """
    Then the bank should answer "Deposited $3."
    And my "cash" balance should have decreased by 3
    And the bank should hold a shared account "fft shared two" owned by me with 8
    When I send the banking action:
      """
      { "kind": "transfer", "from": "fft shared two", "to": "checking", "amount": 8 }
      """
    Then the bank should answer "Transferred $8."
    And my "bank" balance should have increased by 3
    And the bank should hold a shared account "fft shared two" owned by me with 0
    When I send the banking action:
      """
      { "kind": "delete", "account": "fft shared two" }
      """
    Then the bank should answer "Shared account closed."
    And the bank should hold no account named "fft shared two"
    And the bank snapshot should not list the account "fft shared two"

  @world
  Scenario: Shared account receives a transfer sent to its name
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    And I remember my "bank" balance
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    When I send the banking action:
      """
      { "kind": "transfer", "from": "checking", "recipient": "fft shared one", "amount": 2 }
      """
    Then the bank should answer "Sent $2."
    And my "bank" balance should have decreased by 3
    And the bank should hold a shared account "fft shared one" owned by me with 3

  @world @rejection
  Scenario: Shared account cannot pay out more than it holds
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 2 }
      """
    Then the bank should answer "Shared account created."
    Given I remember my "bank" balance
    When I send the banking action:
      """
      { "kind": "transfer", "from": "fft shared one", "to": "checking", "amount": 3 }
      """
    Then the bank should refuse with "The source account does not have enough money."
    And my "bank" balance should be unchanged
    And the bank should hold a shared account "fft shared one" owned by me with 2

  @world @rejection
  Scenario: Shared account with money cannot be closed
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    When I send the banking action:
      """
      { "kind": "delete", "account": "fft shared one" }
      """
    Then the bank should refuse with "Move the remaining balance before closing this account."
    And the bank should hold a shared account "fft shared one" owned by me with 1

  @world @rejection
  Scenario Outline: Shared account opening refuses an invalid request
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    And I remember my "bank" balance
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": <name>, "amount": <amount> }
      """
    Then the bank should refuse with "<reason>"
    And my "bank" balance should be unchanged

    Examples:
      | name             | amount | reason                                              |
      | "fft shared one" | 101    | Your personal account does not have enough money.   |
      | "fft shared one" | -5     | Enter an opening balance.                           |
      | "fft shared one" | "abc"  | Enter an opening balance.                           |
      | "  ab  "         | 5      | Account names need at least 3 characters.           |
      | null             | 5      | Account names need at least 3 characters.           |
      | "-fft shared"    | 5      | Use letters, numbers, spaces, dashes or underscores. |
      | "fft!shared"     | 5      | Use letters, numbers, spaces, dashes or underscores. |
      | "police"         | 5      | That account name is already in use.                |

  @world @rejection
  Scenario: Shared account names are unique
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    Given I remember my "bank" balance
    When I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should refuse with "That account name is already in use."
    And my "bank" balance should be unchanged
    And the bank should hold a shared account "fft shared one" owned by me with 1

  @world @rejection
  Scenario: A character owns at most two shared accounts
    # Config.maxAccounts = 2.
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    When I send the banking action:
      """
      { "kind": "create", "name": "fft shared two", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    Given I remember my "bank" balance
    When I send the banking action:
      """
      { "kind": "create", "name": "fft shared three", "amount": 1 }
      """
    Then the bank should refuse with "You can own up to 2 shared accounts."
    And my "bank" balance should be unchanged
    And the bank should hold no account named "fft shared three"

  @world @rejection
  Scenario: Shared account rename refuses an invalid change
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    When I send the banking action:
      """
      { "kind": "rename", "account": "fft shared one", "name": "x" }
      """
    Then the bank should refuse with "Enter a valid account name."
    When I send the banking action:
      """
      { "kind": "rename", "account": "fft shared one", "name": "police" }
      """
    Then the bank should refuse with "That account name is already in use."
    When I send the banking action:
      """
      { "kind": "fftUnknownKind", "account": "fft shared one" }
      """
    Then the bank should refuse with "Unknown account action."
    And the bank should hold a shared account "fft shared one" owned by me with 1

  @world @rejection
  Scenario Outline: Only the owner may change a shared account
    Given my job is "police" at grade 5
    And I remember the bank balance of the account "police"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "<kind>", "account": "<account>", "name": "fft renamed", "citizenid": "$citizenid" }
      """
    Then the bank should refuse with "Only the account owner can make that change."
    And the bank should hold a society account for "police"
    And the bank balance of the account "police" should be unchanged

    Examples:
      | kind           | account             |
      | rename         | police              |
      | delete         | police              |
      | addMember      | police              |
      | removeMember   | police              |
      | delete         | fft_no_such_account |
      | fftUnknownKind | fft_no_such_account |

  @world @rejection @slow
  Scenario: Shared account access refuses an invalid member
    # The 10 second wait empties Config.memberRateLimit (5 per 10 s) first.
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    When I wait 10000 milliseconds
    And I send the banking action:
      """
      { "kind": "addMember", "account": "fft shared one", "citizenid": "   " }
      """
    Then the bank should refuse with "Enter a citizen ID."
    When I send the banking action:
      """
      { "kind": "addMember", "account": "fft shared one", "citizenid": "FFTNOCITIZEN" }
      """
    Then the bank should refuse with "No character has that citizen ID."
    When I send the banking action:
      """
      { "kind": "removeMember", "account": "fft shared one", "citizenid": "FFTNOCITIZEN" }
      """
    Then the bank should refuse with "That person does not have access."

  @world @slow
  Scenario: Shared account access can be granted and removed again
    # The tester's own citizen ID is the one existing character a scenario may
    # use; the members list is the users column of the account row.
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    And the bank should not list me as a member of "fft shared one"
    When I wait 10000 milliseconds
    And I send the banking action:
      """
      { "kind": "addMember", "account": "fft shared one", "citizenid": "$citizenid" }
      """
    Then the bank should answer "Account access granted."
    And the bank should list me as a member of "fft shared one"
    When I send the banking action:
      """
      { "kind": "addMember", "account": "fft shared one", "citizenid": "$citizenid" }
      """
    Then the bank should refuse with "That person already has access."
    When I send the banking action:
      """
      { "kind": "removeMember", "account": "fft shared one", "citizenid": "$citizenid" }
      """
    Then the bank should answer "Account access removed."
    And the bank should not list me as a member of "fft shared one"

  @world @rejection @slow
  Scenario: Shared account access changes are rate limited
    Given I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    And I own no shared bank accounts
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "create", "name": "fft shared one", "amount": 1 }
      """
    Then the bank should answer "Shared account created."
    When I wait 10000 milliseconds
    Then sending the banking action 5 times should be refused each time with "That person does not have access.":
      """
      { "kind": "removeMember", "account": "fft shared one", "citizenid": "FFTNOCITIZEN" }
      """
    When I send the banking action:
      """
      { "kind": "removeMember", "account": "fft shared one", "citizenid": "FFTNOCITIZEN" }
      """
    Then the bank should refuse with "Wait before changing account access again."

  # ---------------------------------------------------------------------------
  # ATM sessions (openBanking, atmCardCallback, pinCallback in server.lua)
  # ---------------------------------------------------------------------------

  @world @rejection
  Scenario: ATM card check needs a card and a nearby machine
    Given I should have no "bank_card"
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    Then the bank card check without a position should be refused with "You need a bank card to use an ATM."
    And the bank card check at 147.4 -1035.8 29.3 should be refused with "You need a bank card to use an ATM."
    Given I hold 1 "bank_card"
    Then the bank card check without a position should pass
    And the bank card check at 147.4 -1035.8 29.3 should pass
    # Config.locations[1], about 6.5 m from the ATM stand.
    And the bank card check at 149.05 -1041.3 29.37 should be refused with "Move closer to an ATM."

  @world @rejection
  Scenario Outline: ATM session refuses a player away from the machine
    Given I hold 1 "bank_card"
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    Then opening an ATM session at <x> <y> <z> should be refused with "Move closer to an ATM."

    Examples:
      | x       | y        | z     |
      | 149.05  | -1041.3  | 29.37 |
      | 20000.0 | -1035.8  | 29.3  |

  @world @rejection
  Scenario: ATM session without a card is refused before the distance
    Given I should have no "bank_card"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    Then opening an ATM session at 147.4 -1035.8 29.3 should be refused with "You need a bank card to use an ATM."

  @world @rejection
  Scenario: Locked ATM shows nothing and refuses every action
    Given I hold 1 "bank_card"
    And I have 100 in my "bank" account
    And I remember my "bank" balance
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    When I open an ATM session at 147.4 -1035.8 29.3
    Then the ATM session should be locked
    When I send the banking action:
      """
      { "kind": "withdraw", "account": "checking", "amount": 1 }
      """
    Then the bank should refuse with "Your banking session expired."
    And my "bank" balance should be unchanged

  @world @rejection
  Scenario Outline: ATM refuses a malformed PIN
    # A granted card carries no PIN, so these are all wrong; one attempt each
    # stays far below the five-attempt lock.
    Given I hold 1 "bank_card"
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    When I open an ATM session at 147.4 -1035.8 29.3
    And I enter the ATM PIN "<pin>"
    Then the bank should refuse with "Incorrect PIN."

    Examples:
      | pin   |
      | 12    |
      | 48210 |
      | abcd  |

  @world @rejection
  Scenario: ATM PIN needs an open ATM session
    Given I hold 1 "bank_card"
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    When I close my banking session
    And I enter the ATM PIN "4821"
    Then the bank should refuse with "Open an ATM first."

  @world @rejection @slow
  Scenario: Five wrong PINs lock the ATM session
    Given I should have no "bank_card"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "orderCard", "pin": "4821" }
      """
    Then the bank should answer "Bank card issued."
    And the bank snapshot should list 1 bank cards
    Given I stand at 147.77 -1034.87 29.34 facing 158.0
    When I open an ATM session at 147.4 -1035.8 29.3
    # Wrong PINs from earlier scenarios count against the player (the tester is
    # never dropped between scenarios); a correct PIN clears that count.
    And I enter the ATM PIN "4821"
    Then the ATM session should be unlocked
    When I enter the ATM PIN "0000"
    Then the bank should refuse with "Incorrect PIN."
    When I enter the ATM PIN "0001"
    And I enter the ATM PIN "0002"
    And I enter the ATM PIN "0003"
    Then the bank should refuse with "Incorrect PIN."
    When I enter the ATM PIN "0004"
    Then the bank should refuse with "Too many attempts. Wait 30 seconds and try again."
    When I enter the ATM PIN "4821"
    Then the bank should refuse with "Too many attempts. Wait a moment and try again."
    # The lock belongs to the player for 30 s (kora_banking server.lua pinCallback);
    # let it pass so the next ATM scenario starts unlocked.
    And I wait 11000 milliseconds
    And I wait 11000 milliseconds
    And I wait 11000 milliseconds

  @world @rejection @slow
  Scenario: ATM lockout survives reopening the ATM
    # The PIN prompt promises "a temporary account lockout" (client.lua), so
    # closing and reopening the machine must not clear the 30 second lock.
    Given I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "orderCard", "pin": "4821" }
      """
    Then the bank should answer "Bank card issued."
    Given I stand at 147.77 -1034.87 29.34 facing 158.0
    When I open an ATM session at 147.4 -1035.8 29.3
    # A correct PIN clears wrong attempts left by earlier scenarios.
    And I enter the ATM PIN "4821"
    Then the ATM session should be unlocked
    When I enter the ATM PIN "0000"
    And I enter the ATM PIN "0001"
    And I enter the ATM PIN "0002"
    And I enter the ATM PIN "0003"
    And I enter the ATM PIN "0004"
    Then the bank should refuse with "Too many attempts. Wait 30 seconds and try again."
    When I close my banking session
    And I open an ATM session at 147.4 -1035.8 29.3
    And I enter the ATM PIN "4821"
    Then the bank should refuse with "Too many attempts. Wait a moment and try again."
    # The lock belongs to the player for 30 s (kora_banking server.lua pinCallback);
    # let it pass so the next ATM scenario starts unlocked.
    And I wait 11000 milliseconds
    And I wait 11000 milliseconds
    And I wait 11000 milliseconds

  @world
  Scenario: Unlocked ATM serves cash from the personal account only
    Given my job is "police" at grade 5
    And I have 10 in my "cash" account
    And I have 100 in my "bank" account
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "orderCard", "pin": "4821" }
      """
    Then the bank should answer "Bank card issued."
    And the bank snapshot should list the account "police"
    Given I stand at 147.77 -1034.87 29.34 facing 158.0
    When I open an ATM session at 147.4 -1035.8 29.3
    And I enter the ATM PIN "4821"
    Then the ATM session should be unlocked
    And the bank snapshot should list only my personal account
    And the bank snapshot should show 100 in the account "checking"
    And the bank snapshot should allow at least 1 more ATM withdrawal today
    Given I remember my "cash" balance
    And I remember my "bank" balance
    When I send the banking action:
      """
      { "kind": "withdraw", "account": "checking", "amount": 1 }
      """
    Then the bank should answer "Withdrew $1."
    And my "cash" balance should have increased by 1
    And my "bank" balance should have decreased by 1
    When I send the banking action:
      """
      { "kind": "deposit", "account": "checking", "amount": 2 }
      """
    Then the bank should answer "Deposited $2."
    And my "cash" balance should have decreased by 1
    And my "bank" balance should have increased by 1

  @world @rejection
  Scenario Outline: Unlocked ATM refuses counter-only requests
    Given my job is "police" at grade 5
    And I have 100 in my "bank" account
    And I remember the bank balance of the account "police"
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I open a bank counter session for location 1
    And I send the banking action:
      """
      { "kind": "orderCard", "pin": "4821" }
      """
    Then the bank should answer "Bank card issued."
    Given I stand at 147.77 -1034.87 29.34 facing 158.0
    When I open an ATM session at 147.4 -1035.8 29.3
    And I enter the ATM PIN "4821"
    Then the ATM session should be unlocked
    Given I remember my "bank" balance
    When I send the banking action:
      """
      <payload>
      """
    Then the bank should refuse with "<reason>"
    And my "bank" balance should be unchanged
    And the bank balance of the account "police" should be unchanged

    Examples:
      | payload                                                                 | reason                                   |
      | { "kind": "transfer", "from": "checking", "to": "police", "amount": 1 }  | Transfers are available inside a bank.   |
      | { "kind": "orderCard", "pin": "1234" }                                   | That action is not available at an ATM.  |
      | { "kind": "create", "name": "fft shared one", "amount": 1 }              | That action is not available at an ATM.  |
      | { "kind": "withdraw", "account": "police", "amount": 1 }                 | ATMs only support your personal account. |
      | { "kind": "deposit", "account": "police", "amount": 1 }                  | ATMs only support your personal account. |

  # ---------------------------------------------------------------------------
  # The AppShell app (client.lua)
  # ---------------------------------------------------------------------------

  @ui @world
  Scenario: Counter app opens on the accounts view and selects accounts
    Given I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    And the bank app should be showing the "accounts" view
    And selecting the account "fft_no_such_account" in the bank app should be refused
    When I trigger the app action "banking:select-account" on "checking"
    Then the bank app should have refreshed as "Kora Bank" with default view "accounts"

  @ui @world
  Scenario: Locked ATM app opens on the PIN view
    Given I hold 1 "bank_card"
    And I stand at 147.77 -1034.87 29.34 facing 158.0
    When I aim at 147.4 -1035.8 29.8
    And I target "Use ATM"
    Then the app "kora_banking:bank" should be open
    And the bank app should be showing the "unlock" view
    And the app action "banking:deposit" should be unavailable
    And the app action "banking:transfer:internal" should be unavailable

  @ui @world @rejection
  Scenario: Counter app transfer to an unknown account leaves the balance alone
    Given I have 500 in my "bank" account
    And I remember my "bank" balance
    And I stand at 149.38 -1040.46 29.37 facing 158.0
    When I aim at 149.05 -1041.3 29.6
    And I target "Open bank"
    Then the app "kora_banking:bank" should be open
    When I trigger the app action "banking:transfer:internal" with:
      """
      { "value": { "from": "checking", "to": "fft_no_such_account", "amount": 50 } }
      """
    Then I should see a notification containing "You cannot use the destination account"
    And my "bank" balance should be unchanged
