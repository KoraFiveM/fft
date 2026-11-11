@kora @kora_mdt
Feature: kora_mdt terminal access and role gating
  On-duty police and EMS open the records terminal with /mdt; the server
  refuses everyone else. The terminal is a kora_lib app ("kora_mdt:terminal")
  driven at the NUI-callback level, not through rendered controls. Each role
  is shown only its own pages and actions.

  Read-only: the MDT has no delete API, so nothing here files a report, case,
  warrant, BOLO, charge, criminal or medical record. Searches use terms that
  match nobody. While a scenario runs the tester counts as an on-duty officer
  or medic for other resources; the job is restored in cleanup.

  Create actions are exercised only up to their validation refusals, which
  return before anything is written; lookups use ids and citizen IDs that
  match nobody ("FFT00000ZZ9", report/case/warrant/BOLO 999999999).

  Not covered: every successful create, close, link, serve, revoke, resolve
  and charge edit (they leave rows behind); the judge role (kora_core seeds no "judge" job);
  ballistic analysis and the weapon-licence range (minigames, a temporary
  weapon and a licence that would stay on the tester); automatic firearm
  registration (needs a real Ammu-Nation purchase); the server refusing a
  callback the terminal does not offer to the role (only reachable by sending
  the callback directly).

  Background:
    Given resource "kora_mdt" is running

  @ui
  Scenario: An on-duty officer opens the police terminal
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal should be titled "Mobile Data Terminal"
    And the MDT terminal should offer the page "dashboard"
    And the MDT terminal should offer the page "reports"
    And the MDT terminal should offer the page "warrants"
    And the MDT terminal should not offer the page "medical"
    When I close the app
    Then no app should be open

  @ui
  Scenario: An on-duty medic opens the medical terminal
    Given I am on duty as "ambulance" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal should be titled "Medical Records Terminal"
    And the MDT terminal should offer the page "search"
    And the MDT terminal should offer the page "medical"
    And the MDT terminal should not offer the page "dashboard"
    And the MDT terminal should not offer the page "reports"

  # Config.mdt.roles.requireOnDuty = true.
  @ui @rejection
  Scenario Outline: The terminal stays closed without an on-duty role
    Given I am off duty as "<job>" at grade 1
    When I run the command "mdt"
    Then I should see a notification containing "You must be on duty as police, EMS, or a judge to use the MDT."
    And no app should be open

    Examples:
      | job        |
      | police     |
      | ambulance  |
      | unemployed |

  @ui @rejection
  Scenario: A medic is not offered police actions
    Given I am on duty as "ambulance" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the app action "vehicle:search" should be unavailable
    And the app action "charges:list" should be unavailable
    And the app action "report:refresh" should be unavailable
    And the app action "criminal:create" should be unavailable

  @ui @rejection
  Scenario: An officer is not offered medical or charge management actions
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal should not offer the page "charges"
    And the app action "medical:create" should be unavailable
    And the app action "charge:create" should be unavailable
    And the app action "charge:refresh" should be unavailable

  # Grade 5 of "police" is Chief (isboss) in kora_core/shared/jobs.lua.
  @ui
  Scenario: A police boss is offered charge management
    Given I am on duty as "police" at grade 5
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal should offer the page "charges"
    When I trigger the app action "charge:refresh"
    Then the MDT terminal should have moved to the page "charges"
    And the MDT page "charges" should be headed "Charge management"

  @ui
  Scenario: An officer searches citizens
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "person:search" with:
      """
      { "value": { "query": "fftzzqxnobody" } }
      """
    Then the MDT terminal should have moved to the page "search"
    And the MDT page "search" should be headed "Citizen search"

  @ui
  Scenario: A medic searches patients
    Given I am on duty as "ambulance" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "person:search" with:
      """
      { "value": { "query": "fftzzqxnobody" } }
      """
    Then the MDT terminal should have moved to the page "search"
    And the MDT page "search" should be headed "Citizen search"

  @ui @rejection
  Scenario: A search needs at least two characters
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "person:search" with:
      """
      { "value": { "query": "z" } }
      """
    Then the app should answer with a "destructive" notice containing "enter at least two characters"
    When I trigger the app action "vehicle:search" with:
      """
      { "value": { "query": "z" } }
      """
    Then the app should answer with a "destructive" notice containing "enter at least two characters"

  @ui
  Scenario: An officer searches vehicles and opens the penal code
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "vehicle:search" with:
      """
      { "value": { "query": "fftzzqxnobody" } }
      """
    Then the MDT terminal should have moved to the page "search"
    And the MDT page "search" should be headed "Vehicle search"
    When I trigger the app action "charges:list"
    Then the MDT terminal should have moved to the page "results"
    And the MDT page "results" should be headed "Penal code"

  @ui
  Scenario: An officer refreshes the report list
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "report:refresh"
    Then the app should answer with a "success" notice containing "Reports refreshed."
    And the MDT terminal should have moved to the page "reports"

  # Config.mdt.firearms.lookupMode = 'npc': sale records are only released at
  # the Ammu-Nation records clerk, not from the terminal.
  @ui @rejection
  Scenario: The firearm registry is not released from the terminal
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "firearm:search" with:
      """
      { "value": { "serial": "FFT-NO-SUCH-SERIAL" } }
      """
    Then the app should answer with a "destructive" notice containing "speak to the store records clerk"

  # Visibility only: selecting it starts the range session (temporary weapon
  # and a minigame).
  @world
  Scenario: The Ammu-Nation range counter offers the weapon licence test
    Given I stand at 21.6 -1105.3 29.8 facing 310.0
    When I aim at 22.5 -1104.5 29.8
    Then the target option "start weapon licence range" should be visible

  # --- What each role is shown when the terminal opens ----------------------

  @ui
  Scenario Outline: The police terminal opens every page with its heading
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal page "<page>" should be labelled "<label>"
    And the MDT terminal page "<page>" should open headed "<heading>"

    Examples:
      | page      | label     | heading              |
      | dashboard | Dashboard | Operations dashboard |
      | search    | Search    | Records search       |
      | reports   | Reports   | Incident reports     |
      | cases     | Cases     | Investigations       |
      | warrants  | Warrants  | Warrants             |
      | bolos     | BOLOs     | Be On Lookout        |
      | tools     | Tools     | Police tools         |
      | results   | Record    | Record viewer        |

  # Each list is loaded before the terminal opens; a list that failed to load
  # is replaced by a "Could not load ..." block (client/terminal.lua listFailed).
  @ui
  Scenario: The police terminal opens with its dashboard and lists loaded
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal should be described as "Law enforcement operations and records"
    And the MDT terminal page "dashboard" should open described as "Current records requiring attention."
    And the MDT terminal page "dashboard" should show the list "Recent reports"
    And the MDT terminal page "reports" should show the list "Recent reports"
    And the MDT terminal page "cases" should show the list "Investigation files"
    And the MDT terminal page "warrants" should show the list "Warrant register"
    And the MDT terminal page "bolos" should show the list "Current and recent BOLOs"

  @ui
  Scenario: The medical terminal labels its search for patients
    Given I am on duty as "ambulance" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal should be described as "Patient and treatment records"
    And the MDT terminal page "search" should be labelled "Patients"
    And the MDT terminal page "medical" should open headed "Medical records"
    And the MDT terminal page "results" should open headed "Record viewer"
    And the MDT terminal should not offer the page "cases"
    And the MDT terminal should not offer the page "warrants"
    And the MDT terminal should not offer the page "bolos"
    And the MDT terminal should not offer the page "tools"
    And the MDT terminal should not offer the page "charges"

  @ui @rejection
  Scenario: A medic is not offered police record actions
    Given I am on duty as "ambulance" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the app action "warrant:create" should be unavailable
    And the app action "bolo:create" should be unavailable
    And the app action "case:create" should be unavailable
    And the app action "case:refresh" should be unavailable
    And the app action "firearm:search" should be unavailable
    And the app action "analysis:start" should be unavailable

  @ui
  Scenario: A police boss's terminal opens the charge catalogue
    Given I am on duty as "police" at grade 5
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the MDT terminal page "charges" should be labelled "Charges"
    And the MDT terminal page "charges" should open headed "Charge management"
    And the MDT terminal should offer the page "dashboard"
    And the MDT terminal should offer the page "tools"

  # --- Refreshing lists -----------------------------------------------------

  @ui
  Scenario Outline: An officer refreshes a list
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "<action>"
    Then the app should answer with a "success" notice containing "<notice>"
    And the MDT terminal should have moved to the page "<page>"

    Examples:
      | action          | notice              | page     |
      | case:refresh    | Cases refreshed.    | cases    |
      | warrant:refresh | Warrants refreshed. | warrants |
      | bolo:refresh    | BOLOs refreshed.    | bolos    |

  # --- Searches -------------------------------------------------------------

  @ui @rejection
  Scenario Outline: An empty or one-character search term is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "<action>" with:
      """
      { "value": { "query": "<query>" } }
      """
    Then the app should answer with a "destructive" notice containing "enter at least two characters"
    And the last MDT action should have changed no page

    Examples:
      | action         | query |
      | person:search  |       |
      | person:search  | z     |
      | vehicle:search | z     |

  @ui @rejection
  Scenario: A search with no term is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "person:search"
    Then the app should answer with a "destructive" notice containing "enter at least two characters"
    And the last MDT action should have changed no page

  @ui
  Scenario: A search result page repeats the term that was searched
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "person:search" with:
      """
      { "value": { "query": "  fftzzqxnobody  " } }
      """
    Then the MDT terminal should have moved to the page "search"
    And the MDT page "search" should be headed "Citizen search"
    And the MDT page "search" should be described with "fftzzqxnobody"

  # --- Opening records that do not exist ------------------------------------

  @ui @rejection
  Scenario: Selecting an unknown citizen is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "person:search" with:
      """
      { "value": { "query": "fftzzqxnobody" } }
      """
    And I trigger the app action "person:select" on "FFT00000ZZ9"
    Then the app should answer with a "destructive" notice containing "person not found"
    And the last MDT action should have changed no page

  @ui @rejection
  Scenario: A medic selecting an unknown patient is refused
    Given I am on duty as "ambulance" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "person:search" with:
      """
      { "value": { "query": "fftzzqxnobody" } }
      """
    And I trigger the app action "person:select" on "FFT00000ZZ9"
    Then the app should answer with a "destructive" notice containing "person not found"

  @ui @rejection
  Scenario Outline: Selecting an unknown or malformed vehicle plate is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "vehicle:search" with:
      """
      { "value": { "query": "fftzzqxnobody" } }
      """
    And I trigger the app action "vehicle:select" on "<plate>"
    Then the app should answer with a "destructive" notice containing "<notice>"
    And the last MDT action should have changed no page

    Examples:
      | plate               | notice             |
      | FFTZZQX1            | Vehicle not found. |
      | FFTZZQXTOOLONGPLATE | invalid plate      |

  @ui @rejection
  Scenario Outline: Selecting an unknown or malformed record id is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "<action>" on "<id>"
    Then the app should answer with a "destructive" notice containing "<notice>"
    And the last MDT action should have changed no page

    Examples:
      | action         | id        | notice             |
      | report:select  | fft       | invalid report     |
      | report:select  | 999999999 | Report not found.  |
      | case:select    | fft       | invalid case       |
      | case:select    | 999999999 | case not found     |
      | warrant:select | 999999999 | Warrant not found. |
      | bolo:select    | 999999999 | BOLO not found.    |

  @ui @rejection
  Scenario: A firearm search needs a serial
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "firearm:search" with:
      """
      { "value": { "serial": "" } }
      """
    Then the app should answer with a "destructive" notice containing "serial is required"

  # --- Validation refusals (nothing is written) -----------------------------
  # Config.mdt.requiredFields and kora_mdt/shared/required.lua name the field.

  @ui @rejection
  Scenario Outline: An incident report missing a required field is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "report:create" with:
      """
      { "value": { "title": "<title>", "citizenid": "<subject>", "narrative": "<narrative>" } }
      """
    Then the app should answer with a "destructive" notice containing "<notice>"
    And the last MDT action should have changed no page

    Examples:
      | title     | subject     | narrative     | notice                                              |
      |           |             | FFT narrative | Title is required.                                  |
      | FFT title |             |               | Incident narrative is required.                     |
      | FFT title | FFT00000ZZ9 | FFT narrative | Citizen ID not found. Check the subject citizen ID. |

  @ui @rejection
  Scenario Outline: A case missing a required field or naming a bad report is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "case:create" with:
      """
      { "value": { "title": "<title>", "priority": "normal", "summary": "<summary>", "report_id": "<report>" } }
      """
    Then the app should answer with a "destructive" notice containing "<notice>"
    And the last MDT action should have changed no page

    Examples:
      | title     | summary     | report    | notice                       |
      |           | FFT summary | 1         | Case title is required.      |
      | FFT title |             | 1         | Investigation summary is required. |
      | FFT title | FFT summary | fft       | invalid initial report       |
      | FFT title | FFT summary | 999999999 | initial report not found     |

  @ui @rejection
  Scenario Outline: A warrant missing a field or naming an unknown citizen is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "warrant:create" with:
      """
      { "value": { "citizenid": "<citizenid>", "reason": "<reason>", "days": 1 } }
      """
    Then the app should answer with a "destructive" notice containing "<notice>"
    And the last MDT action should have changed no page

    Examples:
      | citizenid   | reason     | notice                                      |
      |             | FFT reason | Citizen ID is required.                     |
      | FFT00000ZZ9 |            | Probable cause / reason is required.        |
      | FFT00000ZZ9 | FFT reason | Citizen ID not found. Check the citizen ID. |

  @ui @rejection
  Scenario Outline: A BOLO missing a field is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "bolo:create" with:
      """
      { "value": { "subject_type": "<kind>", "identifier": "<identifier>", "title": "<title>", "description": "<description>", "days": 1 } }
      """
    Then the app should answer with a "destructive" notice containing "<notice>"
    And the last MDT action should have changed no page

    Examples:
      | kind    | identifier  | title     | description     | notice                                           |
      | alien   | FFT00000ZZ9 | FFT title | FFT description | Choose a valid subject type (person or vehicle). |
      | person  |             | FFT title | FFT description | Enter a citizen ID or name for the subject.      |
      | vehicle |             | FFT title | FFT description | Enter the vehicle plate.                         |
      | person  | FFT00000ZZ9 |           | FFT description | Alert title is required.                         |
      | vehicle | FFTZZQX1    | FFT title |                 | Description and instructions is required.        |

  @ui @rejection
  Scenario Outline: A criminal record missing a field or naming nobody is refused
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "criminal:create" with:
      """
      { "value": { "citizenid": "<citizenid>", "charge": "<charge>", "notes": "FFT notes" } }
      """
    Then the app should answer with a "destructive" notice containing "<notice>"

    Examples:
      | citizenid   | charge             | notice                  |
      |             | Speeding           | Citizen ID is required. |
      | FFT00000ZZ9 |                    | Charge is required.     |
      | FFT00000ZZ9 | FFT no such charge | unknown charge          |
      | FFT00000ZZ9 | Speeding           | citizen not found       |
      | FFT00000ZZ9 | spd-01             | citizen not found       |

  @ui @rejection
  Scenario Outline: A medical record missing a field or naming nobody is refused
    Given I am on duty as "ambulance" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "medical:create" with:
      """
      { "value": { "citizenid": "<citizenid>", "notes": "<notes>" } }
      """
    Then the app should answer with a "destructive" notice containing "<notice>"

    Examples:
      | citizenid   | notes     | notice                         |
      |             | FFT notes | Citizen ID is required.        |
      | FFT00000ZZ9 |           | Treatment / notes is required. |
      | FFT00000ZZ9 | FFT notes | citizen not found              |

  @ui @rejection
  Scenario Outline: Attaching a report to a case needs a real case and report
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "case:attach-report" with:
      """
      { "value": { "case_id": "<case>", "report_id": "<report>" } }
      """
    Then the app should answer with a "destructive" notice containing "<notice>"
    And the last MDT action should have changed no page

    Examples:
      | case      | report    | notice                 |
      | fft       | 1         | invalid case or report |
      | 1         | 0         | invalid case or report |
      | 999999999 | 999999999 | case not found         |

  # --- Charge management (police boss) ----------------------------------------

  @ui @rejection
  Scenario Outline: A malformed charge is refused
    Given I am on duty as "police" at grade 5
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "charge:create" with:
      """
      { "value": { "code": "<code>", "label": "<label>", "fine": <fine> } }
      """
    Then the app should answer with a "destructive" notice containing "enter a valid code, label, and non-negative fine"
    And the last MDT action should have changed no page

    Examples:
      | code       | label     | fine       |
      |            | FFT label | 1          |
      | FFT BAD    | FFT label | 1          |
      | FFT-NOPE   |           | 1          |
      | FFT-NOPE   | FFT label | -1         |
      | FFT-NOPE   | FFT label | 2000000001 |
      | FFT-NOPE   | FFT label | "lots"     |

  @ui @rejection
  Scenario: Selecting an unknown charge is refused
    Given I am on duty as "police" at grade 5
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "charge:select" on "FFT-NOPE"
    Then the app should answer with a "destructive" notice containing "Charge not found."

  # Config.mdt.charges seeds SPD-01 "Speeding". Selecting it only reads it; the
  # edits below are refused before anything is written.
  @ui @rejection
  Scenario: A charge edit with a blank name or negative fine is refused
    Given I am on duty as "police" at grade 5
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    When I trigger the app action "charge:select" on "SPD-01"
    Then the MDT terminal should have moved to the page "results"
    And the MDT page "results" should be headed "Speeding"
    When I trigger the app action "charge:edit" with:
      """
      { "value": { "label": "", "fine": 250 } }
      """
    Then the app should answer with a "destructive" notice containing "enter a valid charge name and non-negative fine"
    When I trigger the app action "charge:edit" with:
      """
      { "value": { "label": "Speeding", "fine": -1 } }
      """
    Then the app should answer with a "destructive" notice containing "enter a valid charge name and non-negative fine"

  @ui @rejection
  Scenario: An officer below boss grade cannot open a charge
    Given I am on duty as "police" at grade 1
    When I run the command "mdt"
    Then the app "kora_mdt:terminal" should be open
    And the app action "charge:select" should be unavailable
    And the app action "charge:edit" should be unavailable
