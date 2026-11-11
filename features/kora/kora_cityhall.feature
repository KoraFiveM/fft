@kora @kora_cityhall
Feature: kora_cityhall kiosk
  The City Hall clerk sells identity documents for cash and hands out starter
  jobs through the "qb-cityhall:kiosk" AppShell app. App actions are driven at
  the NUI-callback level through kora_lib's hook; the purchase and apply
  confirmations are browser-side prompts and are not exercised.

  Not covered: starter items (one-shot per character, never triggered here);
  a full inventory at purchase (no safe way to fill the tester's weight); and
  adding a job with AddCityJob (there is no removal API, so only its refusals
  are asserted). Re-applying for a job already held at a higher grade resets
  it to grade 1 (kora_multijob addJob overwrites); that is reported, not tested.

  # Clerk is Config.Cityhalls[1].coords = -264.28, -966.29, 30.22 heading 210;
  # the server accepts requests within Config.PurchaseDistance = 5.0.
  Background:
    Given resource "kora_cityhall" is running

  @ui @world
  Scenario: Clerk opens the kiosk
    Given I stand at -263.63 -967.42 31.22 facing 30.0
    When I aim at -264.28 -966.29 31.0
    And I target "City Hall"
    Then the app "qb-cityhall:kiosk" should be open
    And the app action "purchase:fft_no_such_license" should be unavailable
    When I close the app
    Then no app should be open

  @ui @world
  Scenario Outline: Kiosk sells a document for cash
    Given any city hall "<license>" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "<license>" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I aim at -264.28 -966.29 31.0
    And I target "City Hall"
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:<license>"
    Then I should have 1 more "<license>" than before
    And my "cash" balance should have decreased by <price>

    Examples:
      | license        | price |
      | id_card        | 50    |
      | driver_license | 100   |
      | weaponlicense  | 200   |

  @ui @world @rejection
  Scenario: Kiosk refuses a purchase without enough cash
    Given any city hall "id_card" I buy is removed afterwards
    And I have 49 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I aim at -264.28 -966.29 31.0
    And I target "City Hall"
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:id_card"
    Then I should see a notification containing "don't have enough money"
    And my "cash" balance should be unchanged
    And I should have 0 more "id_card" than before

  # Legion Square, about 460 m from the clerk.
  @ui @world @rejection
  Scenario: Server refuses a purchase made away from the City Hall
    Given any city hall "id_card" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at 195.17 -933.77 30.69 facing 0.0
    When I open the city hall kiosk away from the building
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:id_card"
    Then I should see a notification containing "too far from the City Hall"
    And my "cash" balance should be unchanged
    And I should have 0 more "id_card" than before

  @ui @world
  Scenario: Kiosk hands out a starter job
    Given any city hall job "taxi" I am given is withdrawn afterwards
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I aim at -264.28 -966.29 31.0
    And I target "City Hall"
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "apply:taxi"
    Then I should see a notification containing "successfully applied"
    And the city hall should have added "taxi" to my jobs at grade 1

  @ui @world @rejection
  Scenario: Server refuses a job application made away from the City Hall
    Given any city hall job "taxi" I am given is withdrawn afterwards
    And I stand at 195.17 -933.77 30.69 facing 0.0
    When I open the city hall kiosk away from the building
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "apply:taxi"
    Then I should see a notification containing "too far from the City Hall"
    And the city hall should not have added "taxi" to my jobs

  @ui @world @rejection
  Scenario: Kiosk does not offer a whitelisted job
    # Config.AvailableJobs lists trucker, taxi, tow, news, garbage, bus and
    # hotdog only. The fixture removes the job again should the rule be broken.
    Given any city hall job "police" I am given is withdrawn afterwards
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I aim at -264.28 -966.29 31.0
    And I target "City Hall"
    Then the app "qb-cityhall:kiosk" should be open
    And the app action "apply:police" should be unavailable
    And the city hall should not have added "police" to my jobs

  @server @rejection
  Scenario: Job list refuses a duplicate or unnamed job
    Then offering the job "taxi" at the city hall again should be refused
    And offering a job without a name at the city hall should be refused

  # ---------------------------------------------------------------------------
  # Round 3. The kiosk is opened through kora_cityhall's own client events
  # (client/client.lua: openCityhallMenu, openIdentityMenu, openJobMenu), which
  # pick the nearest hall; the server still checks the distance itself.
  # Server event scenarios send the events kora_cityhall's client and stock qb
  # resources send, and assert the server's own validation.

  @ui @world
  Scenario Outline: Each compatibility event opens the kiosk
    Given I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "<event>" client event
    Then the app "qb-cityhall:kiosk" should be open
    And the city hall kiosk view "identity" should be labelled "ID Card"
    And the city hall kiosk view "jobs" should be labelled "Job Center"
    When I close the app
    Then no app should be open

    Examples:
      | event            |
      | openCityhallMenu |
      | openIdentityMenu |
      | openJobMenu      |

  @ui @world
  Scenario: The kiosk lists every configured document and job
    Given I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openCityhallMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    And the city hall kiosk should list 3 documents and 7 jobs
    And the app action "purchase:drivinglicense" should be unavailable
    And the app action "apply:unemployed" should be unavailable

  @ui @world
  Scenario: Exact cash buys an ID card and leaves nothing
    Given any city hall "id_card" I buy is removed afterwards
    And I have 50 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openIdentityMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:id_card"
    Then I should have 1 more "id_card" than before
    And my "cash" balance should have decreased by 50
    And my "cash" balance should be 0

  @ui @world @rejection
  Scenario: Documents are paid in cash only, never from the bank
    Given any city hall "weaponlicense" I buy is removed afterwards
    And I have 0 in my "cash" account
    And I have 1000 in my "bank" account
    And I remember my "bank" balance
    And I remember how many "weaponlicense" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openIdentityMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:weaponlicense"
    Then I should see a notification containing "you need 200 cash"
    And my "bank" balance should be unchanged
    And I should have 0 more "weaponlicense" than before

  @ui @world @rejection
  Scenario: One dollar short of a driver licence is refused
    Given any city hall "driver_license" I buy is removed afterwards
    And I have 99 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "driver_license" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openIdentityMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:driver_license"
    Then I should see a notification containing "you need 100 cash"
    And my "cash" balance should be unchanged
    And I should have 0 more "driver_license" than before

  @ui @world
  Scenario: The same document can be bought twice
    Given any city hall "id_card" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openIdentityMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:id_card"
    Then I should have 1 more "id_card" than before
    When I trigger the app action "purchase:id_card"
    Then I should have 2 more "id_card" than before
    And my "cash" balance should have decreased by 100

  # About 7 m from the clerk along the same line as the standing spot, outside
  # Config.PurchaseDistance = 5.0. Unverified ground position.
  @ui @world @rejection
  Scenario: A purchase just outside the purchase distance is refused
    Given any city hall "id_card" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at -260.78 -972.38 31.22 facing 30.0
    When I open the city hall kiosk through the "openIdentityMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "purchase:id_card"
    Then I should see a notification containing "too far from the City Hall"
    And my "cash" balance should be unchanged
    And I should have 0 more "id_card" than before

  @ui @world
  Scenario Outline: Each starter job can be applied for at the kiosk
    Given any city hall job "<job>" I am given is withdrawn afterwards
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openJobMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "apply:<job>"
    Then I should see a notification containing "successfully applied"
    And the city hall should have added "<job>" to my jobs at grade 1

    Examples:
      | job     |
      | trucker |
      | taxi    |
      | tow     |
      | news    |
      | garbage |
      | bus     |
      | hotdog  |

  # kora_multijob addJob only adds to the roster; the active job stays.
  @ui @world
  Scenario: Applying for a job does not change the active job
    Given my job is "unemployed" at grade 1
    And any city hall job "bus" I am given is withdrawn afterwards
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openJobMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "apply:bus"
    Then the city hall should have added "bus" to my jobs at grade 1
    And my job should be "unemployed"

  @ui @world @rejection
  Scenario: A full job roster refuses a new starter job
    Given any city hall job "garbage" I am given is withdrawn afterwards
    And my job roster is full without "garbage"
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I open the city hall kiosk through the "openJobMenu" client event
    Then the app "qb-cityhall:kiosk" should be open
    When I trigger the app action "apply:garbage"
    Then I should not see a notification containing "successfully applied"
    And the city hall should not have added "garbage" to my jobs

  @world
  Scenario: The stock licence request buys a document at the clerk
    Given any city hall "driver_license" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "driver_license" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I send the stock city hall licence request for "driver_license" at hall 1
    Then I should have 1 more "driver_license" than before
    And my "cash" balance should have decreased by 100

  @world @rejection
  Scenario: The stock licence request is refused away from the City Hall
    Given any city hall "id_card" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at 195.17 -933.77 30.69 facing 0.0
    When I send the stock city hall licence request for "id_card" at hall 1
    Then I should see a notification containing "too far from the City Hall"
    And my "cash" balance should be unchanged
    And I should have 0 more "id_card" than before

  # Asserts in server/server.lua purchaseID; texts from locales/en.lua.
  @world @rejection
  Scenario: A purchase for a licence the hall does not sell is refused
    Given I have 500 in my "cash" account
    And I remember my "cash" balance
    And I stand at -263.63 -967.42 31.22 facing 30.0
    And I expect a console error from "kora_cityhall" containing "License configuration is missing for the given license"
    When I send the city hall purchase for "fft_no_such_license" at hall 1
    And I wait 1000 milliseconds
    Then my "cash" balance should be unchanged
    And I should have no "fft_no_such_license"

  @world @rejection
  Scenario: A purchase at a hall that does not exist is refused
    Given any city hall "id_card" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    And I expect a console error from "kora_cityhall" containing "Key set for Config.Cityhalls doesnt exist"
    When I send the city hall purchase for "id_card" at hall 99
    And I wait 1000 milliseconds
    Then my "cash" balance should be unchanged
    And I should have 0 more "id_card" than before

  @world @rejection
  Scenario: A stock licence request without a hall is refused
    Given any city hall "id_card" I buy is removed afterwards
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "id_card" I have
    And I stand at -263.63 -967.42 31.22 facing 30.0
    And I expect a console error from "kora_cityhall" containing "Cityhall key is nil"
    When I send the stock city hall licence request for "id_card" without a hall
    And I wait 1000 milliseconds
    Then my "cash" balance should be unchanged
    And I should have 0 more "id_card" than before

  @world
  Scenario: The stock job application resolves the hall from my position
    Given any city hall job "hotdog" I am given is withdrawn afterwards
    And I stand at -263.63 -967.42 31.22 facing 30.0
    When I send the stock city hall job application for "hotdog"
    Then I should see a notification containing "successfully applied"
    And the city hall should have added "hotdog" to my jobs at grade 1

  # Stock shape away from every hall: findNearbyCityhall finds none and the
  # server returns without a message.
  @world @rejection
  Scenario: The stock job application is ignored away from every City Hall
    Given any city hall job "hotdog" I am given is withdrawn afterwards
    And I stand at 195.17 -933.77 30.69 facing 0.0
    When I send the stock city hall job application for "hotdog"
    Then I should not see a notification containing "successfully applied"
    And the city hall should not have added "hotdog" to my jobs

  @world @rejection
  Scenario Outline: The server refuses a whitelisted job however it is requested
    Given any city hall job "police" I am given is withdrawn afterwards
    And I stand at -263.63 -967.42 31.22 facing 30.0
    And I expect a console error from "kora_cityhall" containing "does not exist in Config.Jobs"
    When <request>
    Then I should not see a notification containing "successfully applied"
    And the city hall should not have added "police" to my jobs

    Examples:
      | request                                                   |
      | I send a city hall job application for "police" at hall 1 |
      | I send the stock city hall job application for "police"   |

  @world @rejection
  Scenario: A job application for a hall that does not exist is refused
    Given any city hall job "trucker" I am given is withdrawn afterwards
    And I stand at -263.63 -967.42 31.22 facing 30.0
    And I expect a console error from "kora_cityhall" containing "Key set for Config.Cityhalls doesnt exist"
    When I send a city hall job application for "trucker" at hall 99
    Then I should not see a notification containing "successfully applied"
    And the city hall should not have added "trucker" to my jobs

  @server @rejection
  Scenario Outline: Job list refuses every configured job again
    Then offering the job "<job>" at the city hall again should be refused

    Examples:
      | job     |
      | trucker |
      | tow     |
      | news    |
      | garbage |
      | bus     |
      | hotdog  |

  @server @rejection
  Scenario Outline: Job list refuses a job name that is not text
    Then offering a job named by a <kind> at the city hall should be refused

    Examples:
      | kind    |
      | number  |
      | table   |
      | boolean |
      | none    |
