@kora @kora_bossmenu
Feature: kora_bossmenu management
  Bosses manage applicants, employees and application questions through the
  "kora_bossmenu:management" AppShell app; anyone can apply for a job through an
  input form. The menu and form are opened with the client exports the target
  zones call (openBossMenu, openApplication) and driven at the NUI-callback
  level through kora_lib's hook. The test character is the only employee or
  applicant any step names.

  Not covered: hiring, promoting or firing anyone, and paying a bonus (they
  change another character or move society money); crediting or debiting a
  business account (visible to other players and written to an audit log that
  has no delete API, so only refusals are asserted); the boss stash (it opens
  the kora_inventory UI); and the "Open Boss Menu" target inside the police
  station. Gang menus and extra menu items are covered only as far as opening,
  listing and refusing go. A duplicate application ("You already applied for
  this job.") is not covered: it needs a third submit within the limit. The
  README commands /openbossmenu and /jobapply are not registered by the code.

  Side effects that cannot be undone: opening the menu or a form creates the
  job's default row in kora_bossmenu_jobs if it is missing, and denying the
  tester's own application appends one line to the job's audit log.
  submitApplication is limited to 2 calls per 60 s, which this feature uses up:
  wait a minute before running it again.

  Background:
    Given resource "kora_bossmenu" is running

  @server
  Scenario: Business balance mirrors the society bank account
    Given resource "kora_banking" is running
    Then the boss menu business balance of "police" should match its bank account

  @server @rejection
  Scenario: Money exports refuse an unknown business
    Then the boss menu should know no business called "fft_no_such_job"
    And paying 10 into the boss menu business "fft_no_such_job" should be refused with "unknown job"
    And taking 10 out of the boss menu business "fft_no_such_job" should be refused with "unknown job"

  @server @rejection
  Scenario: Money exports refuse a zero amount
    Then paying 0 into the boss menu business "police" should be refused with "amount must be positive"
    And taking 0 out of the boss menu business "police" should be refused with "amount must be positive"

  # police grade 5 (Chief) is the only isboss grade in kora_core/shared/jobs.lua.
  @ui
  Scenario: Boss opens the management menu
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And the app action "boss:fft_no_such_action" should be unavailable
    When I close the app
    Then no app should be open

  @ui @rejection
  Scenario: Menu stays closed for an employee below boss grade
    Given my job is "police" at grade 1
    When I open the boss menu for my job
    Then the boss menu should have refused to open

  @ui
  Scenario: Boss adds and removes an application question
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I remember the boss menu count of "questions"
    And I add the boss menu question "FFT probe question"
    Then the app should answer with a "success" notice containing "Management changes saved"
    And the boss menu count of "questions" should have changed by 1
    When I remove the boss menu question I added
    Then the app should answer with a "success" notice containing "Management changes saved"
    And the boss menu count of "questions" should have changed by 0

  @ui @rejection
  Scenario: Menu refuses a question with an unknown answer type
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the app action "boss:add-question" with:
      """
      { "value": { "question": "FFT probe question", "type": "essay" } }
      """
    Then the app should answer with a "destructive" notice containing "Invalid question"

  @ui @rejection
  Scenario: Menu refuses a bonus without an amount
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the boss menu action "boss:bonus" on myself with:
      """
      { "amount": 0 }
      """
    Then the app should answer with a "destructive" notice containing "Invalid bonus amount"

  # The employee check runs before any money is taken from the society.
  @ui @rejection
  Scenario: Menu refuses a bonus for someone who is not an employee
    Given resource "kora_banking" is running
    And my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the app action "boss:bonus" with:
      """
      { "itemId": "FFT00000", "value": { "amount": 1 } }
      """
    Then the app should answer with a "destructive" notice containing "not an employee"

  @ui @rejection
  Scenario Outline: Menu refuses a rank the boss may not assign
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the boss menu action "boss:rank" on myself with:
      """
      { "grade": "<grade>" }
      """
    Then the app should answer with a "destructive" notice containing "<reason>"
    And my job should be "police"

    Examples:
      | grade | reason                                       |
      | 5     | You cannot assign your rank or a higher rank |
      | 99    | Invalid employee rank                        |

  @ui @rejection
  Scenario: Boss cannot fire an employee of the same rank
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the boss menu action "boss:fire" on myself
    Then the app should answer with a "destructive" notice containing "equal or higher-ranked"
    And my job should be "police"

  # "Deny" exists only on applicant rows (client/main.lua appDefinition). With
  # no applicants kora_lib refuses the undeclared action before the server is
  # asked; with other applicants pending the server answers "Application not
  # found." (server/main.lua denyApplicant). Either refusal passes.
  @ui @rejection
  Scenario: Menu refuses to decide an application that does not exist
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    Then the boss menu should refuse to deny an application from "FFT00000"

  @ui @rejection
  Scenario: Application form refuses an unknown organization
    When I start a job application for "fft_no_such_job"
    Then I should see a notification containing "Unknown organization"

  @ui @rejection
  Scenario: Application with blank answers is refused
    When I start a job application for "police"
    Then an input dialog should open
    When I answer every job application question with blanks
    Then I should see a notification containing "Every question must be answered"

  # Nothing stops a boss applying to their own job, so the tester stays police
  # chief throughout: clear any leftover application, apply, then deny it.
  @ui
  Scenario: Submitted application reaches the boss and can be denied
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And no job application of mine is pending in the boss menu
    When I close the app
    Then no app should be open
    When I start a job application for "police"
    And I answer every job application question with "FFT functional test"
    Then I should see a notification containing "application was submitted"
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the boss menu action "boss:deny" on myself
    Then the app should answer with a "success" notice containing "Management changes saved"
    And the boss menu should refuse to deny my application again

  # Apply zone is Config.Menus.job[1].apply[1] = 438.84, -981.15, 30.69 (a
  # 1 x 1 x 2.6 m box reaching the lobby floor at about 29.7, 2.5 m reach) in the
  # police station lobby. The aim is at the floor inside it. Nothing is submitted.
  @ui @world
  Scenario: Apply point in the police station opens the application form
    Given I stand at 438.84 -982.4 30.69 facing 0.0
    When I aim at 438.84 -981.15 29.8
    And I target "Apply for Job"
    Then an input dialog should open
    When I cancel the input dialog
    Then I should not see a notification containing "application was submitted"

  # ---------------------------------------------------------------------------
  # Business-money exports (server/main.lua credit, debit, balance and the
  # qb-management wrappers). Only refusals and balance reads: nothing is paid.
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: Every job's business balance mirrors its society account
    Given resource "kora_banking" is running
    Then the boss menu business balance of "<job>" should match its bank account

    Examples:
      | job       |
      | ambulance |
      | mechanic  |
      | roadside  |
      | bodyshop  |
      | tow       |

  @server
  Scenario Outline: Gang balances mirror their society account
    Given resource "kora_banking" is running
    Then the boss menu gang balance of "<gang>" should match its bank account

    Examples:
      | gang   |
      | ballas |
      | vagos  |

  # roleDefinition() excludes the civilian job and the "none" gang, and the job
  # exports do not know gangs.
  @server @rejection
  Scenario Outline: Business exports know no balance for an organisation they do not manage
    Then the boss menu should know no business called "<name>"

    Examples:
      | name       |
      | unemployed |
      | ballas     |

  @server @rejection
  Scenario Outline: Gang balance export reports nothing for an unknown gang
    Then the boss menu should report no gang balance for "<gang>"

    Examples:
      | gang             |
      | none             |
      | fft_no_such_gang |

  @server @rejection
  Scenario Outline: Money exports refuse amounts that are not a positive whole number
    Then paying the amount "<amount>" into the boss menu business "mechanic" should be refused with "amount must be positive"
    And taking the amount "<amount>" out of the boss menu business "mechanic" should be refused with "amount must be positive"

    Examples:
      | amount |
      | -25    |
      | 0.9    |
      | ten    |

  @server @rejection
  Scenario: Money exports refuse the civilian job
    Then paying 10 into the boss menu business "unemployed" should be refused with "unknown job"
    And taking 10 out of the boss menu business "unemployed" should be refused with "unknown job"

  @server @rejection
  Scenario Outline: Legacy qb-management money exports refuse what the boss menu refuses
    Then the legacy boss menu export "<export>" should refuse <amount> for "<name>"

    Examples:
      | export          | amount | name            |
      | AddMoney        | 0      | police          |
      | RemoveMoney     | -5     | police          |
      | AddMoney        | 10     | fft_no_such_job |
      | RemoveMoney     | 10     | unemployed      |
      | AddGangMoney    | 0      | ballas          |
      | RemoveGangMoney | 0      | vagos           |
      | AddGangMoney    | 10     | none            |
      | RemoveGangMoney | 10     | fft_no_such_job |

  # ---------------------------------------------------------------------------
  # Who may open which menu. Boss grades are kora_core/shared/jobs.lua and
  # gangs.lua. Opening a menu creates the organisation's default
  # kora_bossmenu_jobs row if it is missing (see the feature notes).
  # ---------------------------------------------------------------------------

  @ui
  Scenario Outline: Each job's boss opens its own management menu
    Given my job is "<job>" at grade <grade>
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And the boss menu should be managing "<label>"
    And the boss menu roster should be titled "Employee roster"
    And the boss menu should count at least 1 employee
    When I close the app
    Then no app should be open

    Examples:
      | job       | grade | label               |
      | police    | 5     | Law Enforcement     |
      | ambulance | 5     | EMS                 |
      | mechanic  | 3     | Mechanic            |
      | roadside  | 3     | Roadside Assistance |
      | bodyshop  | 3     | Bodyshop            |
      | tow       | 3     | Recovery            |

  @ui
  Scenario Outline: A gang boss opens the gang menu
    Given my gang is "<gang>" at grade 3
    When I open the gang boss menu
    Then the app "kora_bossmenu:management" should be open
    And the boss menu should be managing "<label>"
    And the boss menu roster should be titled "Gang roster"
    When I close the app
    Then no app should be open

    Examples:
      | gang   | label  |
      | ballas | Ballas |
      | vagos  | Vagos  |

  # getJobData() falls back to the gang when the job grade is not a boss grade.
  @ui
  Scenario: A gang boss below boss grade at work opens the gang menu from the job entry point
    Given my job is "police" at grade 1
    And my gang is "ballas" at grade 3
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And the boss menu should be managing "Ballas"
    And the boss menu roster should be titled "Gang roster"

  # requireBoss() answers "You are not a boss for this organization." and
  # openBossMenu() shows that reason.
  @ui @rejection
  Scenario: A gang member below boss grade is refused the gang menu with the reason
    Given my gang is "ballas" at grade 2
    When I open the gang boss menu
    Then the boss menu should have refused to open with "You are not a boss for this organization."

  @ui @rejection
  Scenario Outline: A job boss grade one below the top is refused the menu
    Given my job is "<job>" at grade <grade>
    And my gang is "none" at grade 1
    When I open the boss menu for my job
    Then the boss menu should stay closed

    Examples:
      | job       | grade |
      | police    | 4     |
      | mechanic  | 2     |
      | tow       | 2     |

  @ui
  Scenario: The qb-bossmenu compatibility event opens the menu for a boss
    Given my job is "mechanic" at grade 3
    When the legacy menu event "qb-bossmenu:client:OpenMenu" fires on my client
    Then the app "kora_bossmenu:management" should be open
    And the boss menu should be managing "Mechanic"

  @ui @rejection
  Scenario: The qb-bossmenu compatibility event does nothing for an employee
    Given my job is "mechanic" at grade 1
    And my gang is "none" at grade 1
    When the legacy menu event "qb-bossmenu:client:OpenMenu" fires on my client
    Then the boss menu should stay closed
    And I should not see a notification containing "boss menu"

  @ui
  Scenario: The qb-gangmenu compatibility event opens the gang menu for a gang boss
    Given my gang is "vagos" at grade 3
    When the legacy menu event "qb-gangmenu:client:OpenMenu" fires on my client
    Then the app "kora_bossmenu:management" should be open
    And the boss menu roster should be titled "Gang roster"

  @ui @rejection
  Scenario: The qb-gangmenu compatibility event does nothing for a gang member
    Given my gang is "vagos" at grade 1
    When the legacy menu event "qb-gangmenu:client:OpenMenu" fires on my client
    Then the boss menu should stay closed

  # ---------------------------------------------------------------------------
  # Application questions (boss:add-question / edit-question / remove-question)
  # ---------------------------------------------------------------------------

  @ui
  Scenario Outline: Each answer type can be added and removed
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I remember the boss menu count of "questions"
    And I add the boss menu question "FFT <type> probe question" of type "<type>"
    Then the app should answer with a "success" notice containing "Management changes saved"
    And the boss menu count of "questions" should have changed by 1
    When I remove the boss menu question I added
    Then the app should answer with a "success" notice containing "Management changes saved"
    And the boss menu count of "questions" should have changed by 0

    Examples:
      | type   |
      | long   |
      | number |
      | yesno  |

  # The application form renders each answer type as its own field
  # (client/main.lua applicationFields). Nothing is submitted.
  @ui
  Scenario Outline: A new question appears on the application form as the right field
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I add the boss menu question "FFT <type> form question" of type "<type>"
    Then the app should answer with a "success" notice containing "Management changes saved"
    When I close the app
    And I start a job application for "police"
    Then the job application form should be titled "Apply: Law Enforcement"
    And the last job application question should be the one I added
    When I cancel the input dialog
    And I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I remove the boss menu question I added
    Then the app should answer with a "success" notice containing "Management changes saved"

    Examples:
      | type   |
      | short  |
      | long   |
      | number |
      | yesno  |

  @ui
  Scenario: A question longer than 250 characters is cut to 250
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I add a boss menu question longer than 250 characters
    Then the app should answer with a "success" notice containing "Management changes saved"
    When I close the app
    And I start a job application for "police"
    Then the last job application question should be cut to 250 characters
    When I cancel the input dialog
    And I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I remove the boss menu question I added
    Then the app should answer with a "success" notice containing "Management changes saved"

  @ui
  Scenario: A boss edits a question's text and answer type
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I add the boss menu question "FFT question before edit" of type "short"
    And I remember the boss menu count of "questions"
    And I edit the boss menu question I added to "FFT question after edit" of type "yesno"
    Then the app should answer with a "success" notice containing "Management changes saved"
    And the boss menu count of "questions" should have changed by 0
    When I close the app
    And I start a job application for "police"
    Then the last job application question should be the one I added
    When I cancel the input dialog
    And I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I remove the boss menu question I added
    Then the app should answer with a "success" notice containing "Management changes saved"

  @ui
  Scenario: A removed question is no longer asked
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I add the boss menu question "FFT question to remove" of type "short"
    And I remove the boss menu question I added
    Then the app should answer with a "success" notice containing "Management changes saved"
    When I close the app
    And I start a job application for "police"
    Then the job application form should not include the question I added
    When I cancel the input dialog
    Then no job application form should open

  @ui @rejection
  Scenario: Menu refuses to change a question to an unknown answer type
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I add the boss menu question "FFT question with a fixed type" of type "short"
    And I try to change the boss menu question I added to type "essay"
    Then the app should answer with a "destructive" notice containing "Invalid question"

  @ui @rejection
  Scenario Outline: Menu refuses a malformed new question
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the app action "boss:add-question" with:
      """
      { "value": <value> }
      """
    Then the app should answer with a "destructive" notice containing "Invalid question"

    Examples:
      | value                                         |
      | { "question": "FFT probe question" }          |
      | { "question": 42, "type": "short" }           |
      | { "type": "long" }                            |

  # A blank question would add an empty, unanswerable field to every
  # application; the server should refuse it like any other invalid question.
  @ui @rejection
  Scenario: Menu refuses a blank question
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I try to add a blank boss menu question
    Then the app should answer with a "destructive" notice containing "Invalid question"

  @ui @rejection
  Scenario Outline: Menu refuses to touch a question it does not hold
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    Then the boss menu should fail to "<verb>" question number 99

    Examples:
      | verb   |
      | edit   |
      | remove |

  # ---------------------------------------------------------------------------
  # Employee actions: refusals only (no-one is hired, promoted, fired or paid)
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario Outline: Menu refuses more ranks the boss may not assign
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the boss menu action "boss:rank" on myself with:
      """
      { "grade": "<grade>" }
      """
    Then the app should answer with a "destructive" notice containing "<reason>"
    And my job should be "police"

    Examples:
      | grade | reason                                                |
      | 0     | Invalid employee rank                                 |
      | -1    | Invalid employee rank                                 |
      | chief | Invalid employee rank                                 |
      | 4     | You cannot manage an equal or higher-ranked employee |

  @ui @rejection
  Scenario Outline: Menu refuses an employee action without an employee
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the app action "<action>" with:
      """
      { "value": <value> }
      """
    Then the app should answer with a "destructive" notice containing "<reason>"
    And my job should be "police"

    Examples:
      | action     | value             | reason                |
      | boss:rank  | { "grade": "1" }  | Invalid employee rank |
      | boss:fire  | {}                | Invalid employee      |
      | boss:bonus | { "amount": 1 }   | Invalid bonus amount  |

  # setRank() and fireEmployee() do not check that the target is an employee
  # (only giveBonus does); kora_multijob then refuses the unknown character.
  @ui @rejection
  Scenario Outline: Menu refuses to rank or fire a character that does not exist
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the app action "<action>" with:
      """
      { "itemId": "FFT00000", "value": <value> }
      """
    Then the app should answer with a "destructive" notice containing "employee was not found"

    Examples:
      | action    | value            |
      | boss:rank | { "grade": "1" } |
      | boss:fire | {}               |

  @ui @rejection
  Scenario Outline: Menu refuses a bonus that is not a positive whole amount
    Given my job is "police" at grade 5
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the boss menu action "boss:bonus" on myself with:
      """
      { "amount": <amount> }
      """
    Then the app should answer with a "destructive" notice containing "Invalid bonus amount"

    Examples:
      | amount |
      | -100   |
      | 0.5    |

  @ui @rejection
  Scenario: A boss of a smaller job cannot fire themselves either
    Given my job is "mechanic" at grade 3
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    When I trigger the boss menu action "boss:fire" on myself
    Then the app should answer with a "destructive" notice containing "equal or higher-ranked"
    And my job should be "mechanic"

  # ---------------------------------------------------------------------------
  # Extra menu items added by other resources (client/main.lua extraItems).
  # The item fires a local client event owned by the step file.
  # ---------------------------------------------------------------------------

  @ui
  Scenario: An extra boss menu item is offered and runs its event
    Given my job is "police" at grade 5
    And the boss menu carries an extra item "fft_probe" labelled "FFT probe item"
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And the boss menu should offer the extra item "fft_probe" labelled "FFT probe item"
    When I trigger the app action "boss:extra:fft_probe"
    Then the boss menu extra item "fft_probe" should have run once
    And no app should be open

  @ui @rejection
  Scenario Outline: Server-side and command extra items are not offered
    Given my job is "police" at grade 5
    And the boss menu carries a <kind> extra item "<id>"
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And the app action "boss:extra:<id>" should be unavailable

    Examples:
      | kind        | id         |
      | server-side | fft_server |
      | command     | fft_cmd    |

  @ui @rejection
  Scenario: A removed extra item is no longer offered
    Given my job is "police" at grade 5
    And the boss menu carries an extra item "fft_gone" labelled "FFT removed item"
    And the boss menu extra item "fft_gone" is removed
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And the app action "boss:extra:fft_gone" should be unavailable

  @ui
  Scenario: A gang menu item is offered in the gang menu only
    Given my job is "police" at grade 5
    And my gang is "ballas" at grade 3
    And the gang menu carries an extra item "fft_gang" labelled "FFT gang item"
    When I open the boss menu for my job
    Then the app "kora_bossmenu:management" should be open
    And the app action "boss:extra:fft_gang" should be unavailable
    When I close the app
    And I open the gang boss menu
    Then the app "kora_bossmenu:management" should be open
    And the boss menu should offer the extra item "fft_gang" labelled "FFT gang item"

  # ---------------------------------------------------------------------------
  # Application form (openApplication). Nothing is submitted: the submit limit
  # is used up by the scenarios above.
  # ---------------------------------------------------------------------------

  @ui
  Scenario: The gang application form opens with the gang's name
    When I start a gang application for "ballas"
    Then the job application form should be titled "Apply: Ballas"
    When I cancel the input dialog
    Then I should not see a notification containing "application was submitted"

  @ui @rejection
  Scenario Outline: No application form opens for an organisation that does not recruit
    When I start a <kind> application for "<name>"
    Then no job application form should open
    And I should see a notification containing "Unknown organization"

    Examples:
      | kind | name       |
      | job  | unemployed |
      | gang | none       |
