@kora @kora_multijob
Feature: kora_multijob saved job roster
  The /multijob roster keeps every job a character holds, switches the active
  job and toggles duty. App actions are driven at the NUI-callback level through
  kora_lib's hook; they do not click rendered controls.

  Background:
    Given resource "kora_multijob" is running

  @server
  Scenario: Roster records a newly assigned job
    Given my job is "mechanic" at grade 2
    Then my job roster should include "mechanic"
    And my job roster should show "mechanic" at grade 2
    And my job roster should mark "mechanic" as the active job

  @server
  Scenario: Saved job is listed without becoming active
    Given my job is "mechanic" at grade 1
    And my job roster also holds "taxi" at grade 1
    Then my job roster should include "taxi"
    And my job roster should mark "mechanic" as the active job
    And my job should be "mechanic"

  @server @rejection
  Scenario Outline: Roster refuses an invalid job
    Then adding "<job>" at grade <grade> to my job roster should be refused with "<reason>"
    And my job roster should not include "<job>"

    Examples:
      | job             | grade | reason        |
      | fft_no_such_job | 1     | unknown job   |
      | mechanic        | 99    | unknown grade |

  @ui
  Scenario: Command opens the roster app
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I close the app
    Then no app should be open

  @ui
  Scenario: Roster app switches the active job
    Given my job is "taxi" at grade 1
    And my job is "mechanic" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I trigger the app action "multijob:select" on "taxi"
    Then the app should answer with a "success" notice containing "Job roster updated"
    And my job should be "taxi"
    And my job roster should include "mechanic"

  @ui
  Scenario: Roster app toggles duty for the active job
    Given I am off duty as "mechanic" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I trigger the app action "multijob:duty"
    Then I should be on duty
    When I trigger the app action "multijob:duty"
    Then I should be off duty

  @ui @rejection
  Scenario: Roster app refuses to remove the active job
    # A second saved job makes the app declare "Leave job"; the server must
    # still refuse it for the active one.
    Given my job is "taxi" at grade 1
    And my job is "mechanic" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I trigger the app action "multijob:quit" on "mechanic"
    Then the app should answer with a "destructive" notice containing "choose another active job"
    And my job roster should include "mechanic"
    And my job should be "mechanic"

  @ui @rejection
  Scenario: Roster app offers no duty toggle for a duty-locked job
    Given I am off duty as "police" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    Then the app action "multijob:duty" should be unavailable
    And I should be off duty

  # ---------------------------------------------------------------------------
  # Saved roster contents (server.lua jobRecord / view). Labels, grades and pay
  # are kora_core/shared/jobs.lua; icons and duty locks are config.lua.
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: Roster entries carry the job's label, grade and pay
    Given my job is "<job>" at grade <grade>
    Then my job roster should describe "<job>" as "<label>" grade "<gradeLabel>" paying <pay>
    And my job roster should give "<job>" the icon "<icon>"

    Examples:
      | job       | grade | label               | gradeLabel | pay | icon              |
      | mechanic  | 2     | Mechanic            | Mechanic   | 60  | Wrench            |
      | ambulance | 3     | EMS                 | Paramedic  | 100 | HeartPulse        |
      | tow       | 3     | Recovery            | Owner      | 100 | Truck             |
      | bodyshop  | 1     | Bodyshop            | Detailer   | 40  | BriefcaseBusiness |
      | roadside  | 2     | Roadside Assistance | Technician | 60  | BriefcaseBusiness |

  @server
  Scenario: The civilian fallback is always on the roster
    Given my job is "mechanic" at grade 1
    Then my job roster should include "unemployed"
    And my job roster should describe "unemployed" as "Civilian" grade "Freelancer" paying 10

  @server
  Scenario: Police is duty-locked on the roster and other jobs are not
    Given my job is "police" at grade 1
    And my job roster also holds "mechanic" at grade 1
    Then my job roster should mark "police" as duty-locked
    And my job roster should not mark "mechanic" as duty-locked
    And my job roster should give "police" the icon "Shield"

  @server
  Scenario: Roster lists saved jobs from the best paid down
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 3
    And my job roster also holds "bodyshop" at grade 2
    Then my job roster should list jobs from the best paid down

  @server
  Scenario: Roster mirrors the active job's duty state
    Given I am on duty as "mechanic" at grade 1
    Then my job roster should say I am on duty
    Given I am off duty as "mechanic" at grade 1
    Then my job roster should say I am off duty

  @server
  Scenario: Changing the active job's grade updates the roster
    Given my job is "mechanic" at grade 1
    And my job is "mechanic" at grade 3
    Then my job roster should show "mechanic" at grade 3

  @server
  Scenario: A roster looked up by citizenid lists saved jobs but no active job
    Given my job is "mechanic" at grade 1
    Then my job roster looked up by citizenid should include "mechanic" with no active job

  @server
  Scenario: Saved jobs survive dropping the roster cache
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 2
    When my job roster cache is dropped
    Then my job roster should show "tow" at grade 2
    And my job roster should mark "mechanic" as the active job

  # ---------------------------------------------------------------------------
  # addJob export
  # ---------------------------------------------------------------------------

  # jobRecord() treats grade 0 as grade 1 for old zero-based qb jobs.
  @server
  Scenario: A grade 0 job is saved at grade 1
    Given my job is "mechanic" at grade 1
    When adding "tow" at grade 0 to my job roster should be accepted
    Then my job roster should show "tow" at grade 1

  @server
  Scenario: Adding a saved job again updates its grade
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 1
    When adding "tow" at grade 3 to my job roster should be accepted
    Then my job roster should show "tow" at grade 3
    And my job should be "mechanic"

  @server @rejection
  Scenario Outline: Roster refuses more invalid jobs
    Then adding "<job>" at grade <grade> to my job roster should be refused with "<reason>"
    And my job roster should not include "<job>"

    Examples:
      | job      | grade | reason        |
      | tow      | 4     | unknown grade |
      | bodyshop | -1    | unknown grade |
      | none     | 1     | unknown job   |

  # Config.maxJobs = 4 counts saved jobs other than the civilian fallback; an
  # update to a job already saved is still allowed when the roster is full.
  @server @rejection
  Scenario: A full roster refuses another job but still accepts a grade change
    Given my job is "mechanic" at grade 1
    And my job roster is filled to its limit of 4 saved jobs
    Then adding one more job to my job roster should be refused with "job roster is full"
    And adding "mechanic" at grade 2 to my job roster should be accepted
    And my job roster should show "mechanic" at grade 2

  # ---------------------------------------------------------------------------
  # Employee exports used by kora_bossmenu (getEmployees, setEmployeeJob,
  # removeEmployeeJob). Only the tester and made-up FFT citizenids are named.
  # ---------------------------------------------------------------------------

  @server
  Scenario: The employee list for a job includes me at my saved grade
    Given my job is "mechanic" at grade 2
    Then the employee list for "mechanic" should include me at grade 2
    And the employee list for "mechanic" should be sorted by name

  @server
  Scenario: A saved job that is not active is still on the employee list
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 2
    Then the employee list for "tow" should include me at grade 2

  @server @rejection
  Scenario Outline: The employee list refuses an unknown job
    Then the employee list for "<job>" should be refused

    Examples:
      | job             |
      | fft_no_such_job |
      | none            |

  @server
  Scenario: Setting a saved job's grade through the employee export keeps the active job
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 1
    When I set my saved job "tow" to grade 2 through the employee export
    Then my job roster should show "tow" at grade 2
    And my job should be "mechanic"
    And my job grade should be 1

  @server
  Scenario: Setting the active job's grade through the employee export changes my grade
    Given my job is "mechanic" at grade 1
    When I set my saved job "mechanic" to grade 2 through the employee export
    Then my job grade should be 2
    And my job roster should show "mechanic" at grade 2

  @server
  Scenario: The employee export can save a job I did not hold
    Given my job is "mechanic" at grade 1
    When I set my saved job "tow" to grade 1 through the employee export
    Then my job roster should show "tow" at grade 1
    And my job should be "mechanic"

  @server @rejection
  Scenario Outline: The employee export refuses an invalid job or grade
    Given my job is "mechanic" at grade 1
    Then setting my saved job "<job>" to grade <grade> should be refused with "<reason>"
    And my job grade should be 1

    Examples:
      | job             | grade | reason        |
      | fft_no_such_job | 1     | unknown job   |
      | mechanic        | 9     | unknown grade |

  @server @rejection
  Scenario Outline: The employee export refuses a character that does not exist
    Then setting the job of citizen "<citizen>" to "mechanic" at grade 1 should be refused with "<reason>"

    Examples:
      | citizen  | reason                                            |
      |          | invalid citizenid or job storage is still starting |
      | FFT00000 | employee was not found                            |

  @server
  Scenario: Removing a saved job through the employee export
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 1
    When I remove my job "tow" through the employee export
    Then my job roster should not include "tow"
    And my job should be "mechanic"
    And the employee list for "tow" should not include me

  # removeEmployeeJob() moves an online employee off a removed active job.
  @server
  Scenario: Removing the active job through the employee export makes me a civilian
    Given my job is "mechanic" at grade 1
    When I remove my job "mechanic" through the employee export
    Then my job should be "unemployed"
    And my job roster should not include "mechanic"

  @server @rejection
  Scenario Outline: The employee export refuses to remove a job I cannot lose
    Given my job is "mechanic" at grade 1
    Then removing my job "<job>" through the employee export should be refused with "<reason>"
    And my job should be "mechanic"

    Examples:
      | job             | reason                                       |
      | unemployed      | invalid employee job                         |
      | fft_no_such_job | unknown job or job storage is still starting |
      | bodyshop        | employee does not have that job              |

  @server @rejection
  Scenario: The employee export refuses to remove a job from a character that does not exist
    Then removing the job "mechanic" of citizen "FFT00000" should be refused with "employee was not found"

  # ---------------------------------------------------------------------------
  # Roster app (client.lua appDefinition / onAction)
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Switching jobs in the app announces the new active job
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 2
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I trigger the app action "multijob:select" on "tow"
    Then the app should answer with a "success" notice containing "Job roster updated"
    And I should see a notification containing "Active job set to Recovery."
    And my job should be "tow"
    And my job grade should be 2
    And my job roster should mark "tow" as the active job

  @ui
  Scenario: Choosing the civilian fallback in the app makes me unemployed
    Given my job is "mechanic" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I trigger the app action "multijob:select" on "unemployed"
    Then the app should answer with a "success" notice containing "Job roster updated"
    And my job should be "unemployed"
    And my job roster should include "mechanic"

  @ui
  Scenario: Leaving a saved job in the app removes it from the roster
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I remember the job roster app count
    And I trigger the app action "multijob:quit" on "tow"
    Then the app should answer with a "success" notice containing "Job roster updated"
    And the job roster app count should have changed by -1
    And I should see a notification containing "Job removed from your roster."
    And my job roster should not include "tow"
    And my job should be "mechanic"

  @ui @rejection
  Scenario: The app refuses to remove the civilian fallback
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I trigger the app action "multijob:quit" on "unemployed"
    Then the app should answer with a "destructive" notice containing "that job cannot be removed"
    And my job roster should include "unemployed"

  @ui @rejection
  Scenario Outline: The app refuses a job that is not on the roster
    Given my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    When I trigger the app action "<action>" on "fft_no_such_job"
    Then the app should answer with a "destructive" notice containing "that job is not in your roster"
    And my job should be "mechanic"

    Examples:
      | action          |
      | multijob:select |
      | multijob:quit   |

  @ui @rejection
  Scenario: The app offers no duty toggle to an on-duty officer either
    # Only the active job's row carries "multijob:duty"; a duty-locked active job has none.
    Given I am on duty as "police" at grade 1
    When I run the command "multijob"
    Then the app "kora_multijob:roster" should be open
    Then the app action "multijob:duty" should be unavailable
    And I should be on duty

  # ---------------------------------------------------------------------------
  # /givejob and /removejob (server.lua, kora_core 'admin' permission). The
  # tester is the target ("<my server id>" is filled in by the step).
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario Outline: Roster admin commands explain their usage
    Given I may manage job rosters
    When I run the command "<command>"
    Then I should see a notification containing "<usage>"

    Examples:
      | command   | usage                               |
      | givejob   | Usage: /givejob [id] [job] [grade]  |
      | removejob | Usage: /removejob [id] [job]        |

  @ui
  Scenario: /givejob saves a job on my roster
    Given I may manage job rosters
    And my job is "mechanic" at grade 1
    And my saved "tow" job is restored afterwards
    When I run the roster command "givejob" on myself with "tow 2"
    Then I should see a notification containing "Job saved."
    And I should see a notification containing "A job was added to your roster."
    And my job roster should show "tow" at grade 2
    And my job should be "mechanic"

  @ui @rejection
  Scenario Outline: /givejob refuses an invalid job
    Given I may manage job rosters
    And my saved "<job>" job is restored afterwards
    When I run the roster command "givejob" on myself with "<job> <grade>"
    Then I should see a notification containing "<reason>"
    And my job roster should not include "<job>"

    Examples:
      | job             | grade | reason        |
      | fft_no_such_job | 1     | unknown job   |
      | bodyshop        | 9     | unknown grade |

  @ui
  Scenario: /removejob removes a saved job
    Given I may manage job rosters
    And my job is "mechanic" at grade 1
    And my job roster also holds "tow" at grade 1
    When I run the roster command "removejob" on myself with "tow"
    Then I should see a notification containing "Job removed."
    And my job roster should not include "tow"

  @ui @rejection
  Scenario Outline: /removejob refuses a job that cannot be removed
    Given I may manage job rosters
    And my job is "mechanic" at grade 1
    When I run the roster command "removejob" on myself with "<job>"
    Then I should see a notification containing "<reason>"
    And my job should be "mechanic"
    And my job roster should include "mechanic"

    Examples:
      | job        | reason                                   |
      | mechanic   | Player must change active job first.     |
      | unemployed | Player does not have that removable job. |
      | bodyshop   | Player does not have that removable job. |
