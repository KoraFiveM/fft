@kora @kora_crafting
Feature: kora_crafting stations and creator
  Players open a crafting station with kora_target, pick a recipe in the
  crafting app and wait for a progress bar; the server takes the materials and
  gives the result. Admins build recipes and stations in /craftCreator.

  The resource ships no stations and has no exports, so kora_crafting's FFT
  hook builds one throwaway station ("fft_station", recipe "fft_recipe", target
  "FFT test craft") 1.6 m in front of the tester through the creator's own
  admin callbacks, and deletes it afterwards. Everything after that (target,
  app, progress bar) is the real player path; app actions are driven at the
  NUI-callback level, not by clicking rendered buttons.

  Requirements: the tester has the "command" ace, and stands on foot on open,
  level ground. The aim point is unverified until run live. While a station
  scenario runs, other players nearby can see and use the test station, hence the
  global tag. Each creator call writes a kora_crafting_logs audit row; those rows
  have no delete API and expire after 30 days.

  Creator read-backs reopen /craftCreator and read view and block titles from
  kora_lib's hook (deeper card content is cut by its depth limit); block counts
  such as "Required items (2)" are the authoritative part. The "too far away"
  scenario teleports the tester 12 m straight back from the station, so the
  ground behind the tester must be open.

  Not covered: skill XP rewards (kora_skills XP cannot be removed), walking away
  during the progress bar (the bar blocks movement), cancelling a craft
  (kora_lib's hook has no progress-cancel action), the too-fast-finish guard
  (needs a modified client), placing a location with the creator's world
  raycast, prop stations and gang locks (the hook fixture has no object or gang
  field), the 20-material limit, and the non-admin refusal (the tester's ace
  cannot be changed from a test).

  Background:
    Given resource "kora_crafting" is running

  @ui
  Scenario: An admin creates and deletes a recipe in the creator
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    And the crafting server should have the recipe "fft_creator_recipe"
    When I start the crafting creator action "recipe:delete"
    Then a confirmation should open
    When I confirm
    Then the crafting creator should answer with a "success" notice containing "Recipe deleted."
    And the crafting server should not have the recipe "fft_creator_recipe"
    And I close the app

  @ui @rejection
  Scenario: Cancelling the name dialog creates no recipe
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    Then an input dialog should open
    When I cancel the input dialog
    Then the crafting creator should answer without a notice
    And the crafting server should not have the recipe "fft_creator_recipe"
    And I close the app

  @ui @rejection
  Scenario: Declining the confirmation keeps the recipe
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "recipe:delete"
    Then a confirmation should open
    When I decline
    Then the crafting creator should answer without a notice
    And the crafting server should have the recipe "fft_creator_recipe"
    And I close the app

  @ui @world @global
  Scenario: Crafting uses up the materials and gives the result
    Given I hold 2 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And my client should know the crafting test station
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    And I should have no "plastic"
    And the app "kora_crafting:menu" should be open
    And the app action "craft:fft_recipe" should be unavailable
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A kept material is required but not used up
    Given I hold 1 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station makes 2 "glass" with 1 "plastic" that is kept
    And I remember how many "glass" I have
    And I remember how many "plastic" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 2x Glass."
    And I should have 2 more "glass" than before
    And I should have 0 fewer "plastic" than before
    And the app "kora_crafting:menu" should be open
    When I close the app
    Then no crafting should be in progress

  @ui @world @global @rejection
  Scenario: A recipe cannot be crafted without its materials
    Given a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    Then I should have no "plastic"
    When I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the app action "craft:fft_recipe" should be unavailable
    And I should have 0 more "glass" than before
    When I close the app
    Then no crafting should be in progress

  @ui @world @global @rejection
  Scenario: Materials that disappear during the craft cancel it
    Given I hold 2 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    When I remove 2 "plastic"
    Then the progress bar should finish
    And I should see a notification containing "You need 2x Plastic."
    And I should have 0 more "glass" than before
    And the app "kora_crafting:menu" should be open
    When I close the app
    Then no crafting should be in progress

  @world @global @rejection
  Scenario: A job-locked station is hidden from other jobs
    Given my job is "unemployed" at grade 1
    And a crafting test station for the "police" job turns 2 "plastic" into 1 "glass"
    And my client should know the crafting test station
    When I aim at the crafting test station
    Then no target option should be visible

  @ui @world @global @rejection
  Scenario: The server refuses a craft after the job is lost
    Given my job is "police" at grade 1
    And I hold 2 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station for the "police" job turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When my job is "unemployed" at grade 1
    And I craft the recipe "fft_recipe"
    Then I should see a notification containing "You cannot use this station."
    And no progress bar should be running
    And I should have 2 "plastic"
    And I should have 0 more "glass" than before
    And no crafting should be in progress

  @ui @world @global @rejection
  Scenario: A recipe above my skill level cannot be crafted
    Given I hold 2 "plastic"
    And a crafting test station turns 2 "plastic" into 1 "glass" behind a skill level I lack
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the app action "craft:fft_recipe" should be unavailable
    And I should have 2 "plastic"
    And I should have 0 more "glass" than before
    When I close the app
    Then no crafting should be in progress

  # ---------------------------------------------------------------------------
  # Creator: recipes (client/creator.lua recipeAction, server/creator.lua,
  # server/rules.lua). Read-backs reopen the creator so the app is rebuilt from
  # a fresh kora_crafting:creator:get, then read view and block titles.
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario: A whitespace-only recipe name creates nothing
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "name": "   " }
      """
    Then the crafting creator should answer without a notice
    And the crafting server should have 0 test recipes
    And I close the app

  @ui
  Scenario: A second recipe with the same name gets a numbered id
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    And the crafting server should have the recipe "fft_creator_recipe"
    And the crafting server should have the recipe "fft_creator_recipe_2"
    And the crafting server should have 2 test recipes
    And I close the app

  # trim(label, 48) keeps the name; makeId lowercases, turns every run of
  # non-alphanumerics into "_" and cuts the id to 36 characters.
  @ui
  Scenario: A long recipe name is shortened into its id
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT  Long--Name: abcdefghijklmnopqrstuvwxyz0123456789" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    And the crafting server should have the recipe "fft_long_name_abcdefghijklmnopqrstuv"
    When I reopen the crafting creator
    Then the crafting app view "recipe" should be titled "FFT  Long--Name: abcdefghijklmnopqrstuvwxyz01234"
    And I close the app

  # copyLabel: "X" -> "X-2", "X-2" -> "X-3"; makeId turns them into x_2, x_3.
  @ui
  Scenario: Duplicating a recipe twice numbers the copies
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "recipe:duplicate"
    Then the crafting creator should answer with a "success" notice containing "Recipe duplicated. You are now editing the copy."
    And the crafting server should have the recipe "fft_creator_recipe_2"
    When I start the crafting creator action "recipe:duplicate"
    Then the crafting creator should answer with a "success" notice containing "Recipe duplicated. You are now editing the copy."
    And the crafting server should have the recipe "fft_creator_recipe_3"
    When I reopen the crafting creator
    Then the crafting app view "recipe" should be titled "FFT creator recipe-3"
    And I close the app

  @ui
  Scenario: A new recipe makes nothing until its result is picked
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I reopen the crafting creator
    Then the crafting app view "recipe" should say "Makes nothing yet."
    And the crafting app should show the block "Required items (0)"
    When I search the crafting creator items for "plastic"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:pick:plastic"
    Then the crafting creator should answer with a "success" notice containing "It now makes Plastic."
    When I reopen the crafting creator
    Then the crafting app view "recipe" should say "Makes 1x Plastic."
    And I close the app

  # Results only exist after a server search (kora_crafting:creator:items:search),
  # and kora_lib refuses actions that no visible card declares.
  @ui @rejection
  Scenario: Items can only be picked from a search that found them
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    And the app action "recipe:pick:plastic" should be unavailable
    And the app action "recipe:add:plastic" should be unavailable
    When I search the crafting creator items for "fft_no_such_item_zz"
    Then the crafting creator should answer without a notice
    And the app action "recipe:pick:plastic" should be unavailable
    When I search the crafting creator items for "plastic"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:pick:plastic"
    Then the crafting creator should answer with a "success" notice containing "It now makes Plastic."
    And the app action "recipe:pick:plastic" should be unavailable
    And I close the app

  @ui
  Scenario: Materials are added, edited and removed through the amount dialog
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I search the crafting creator items for "plastic"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:add:plastic"
    Then the crafting amount dialog should default to 1 and "use"
    When I answer the crafting amount dialog with "3" and "use"
    Then the crafting creator should answer with a "success" notice containing "3x Plastic added."
    And the app action "recipe:add:plastic" should be unavailable
    When I start the crafting creator action "recipe:edit:plastic"
    Then the crafting amount dialog should default to 3 and "use"
    When I answer the crafting amount dialog with "5" and "keep"
    Then the crafting creator should answer with a "success" notice containing "Plastic now needs 5x."
    When I reopen the crafting creator
    Then the crafting app should show the block "Required items (1)"
    When I start the crafting creator action "recipe:edit:plastic"
    Then the crafting amount dialog should default to 5 and "keep"
    When I cancel the input dialog
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:remove:plastic"
    Then the crafting creator should answer with a "success" notice containing "Plastic removed."
    When I reopen the crafting creator
    Then the crafting app should show the block "Required items (0)"
    And I close the app

  @ui
  Scenario: A recipe can need several different materials
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I search the crafting creator items for "plastic"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:add:plastic"
    And I answer the crafting amount dialog with "2" and "use"
    Then the crafting creator should answer with a "success" notice containing "2x Plastic added."
    When I search the crafting creator items for "iron"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:add:iron"
    And I answer the crafting amount dialog with "1" and "keep"
    Then the crafting creator should answer with a "success" notice containing "1x Iron added."
    When I reopen the crafting creator
    Then the crafting app should show the block "Required items (2)"
    And I close the app

  # server/rules.lua cleanGive: whole amounts 1-1000 (Limits.recipeAmount);
  # client/creator.lua askAmount floors the number first.
  @ui
  Scenario Outline: Material amount <amount> is <outcome>
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I search the crafting creator items for "plastic"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:add:plastic"
    And I answer the crafting amount dialog with "<amount>" and "use"
    Then the crafting creator should answer with a "<tone>" notice containing "<message>"
    When I reopen the crafting creator
    Then the crafting app should show the block "Required items (<count>)"
    And I close the app

    Examples:
      | amount | outcome  | tone        | message                                                | count |
      | 1      | accepted | success     | 1x Plastic added.                                      | 1     |
      | 1000   | accepted | success     | 1000x Plastic added.                                   | 1     |
      | 2.7    | floored  | success     | 2x Plastic added.                                      | 1     |
      | 0      | refused  | destructive | The amount for plastic must be between 1 and 1000.     | 0     |
      | 1001   | refused  | destructive | The amount for plastic must be between 1 and 1000.     | 0     |
      | -5     | refused  | destructive | The amount for plastic must be between 1 and 1000.     | 0     |

  # server/rules.lua cleanRecipeDetails, plus the client-side animation
  # dictionary check in client/creator.lua recipeAction.
  @ui @rejection
  Scenario Outline: Recipe details with <field> "<value>" are refused
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I search the crafting creator items for "glass"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:pick:glass"
    Then the crafting creator should answer with a "success" notice containing "It now makes Glass."
    When I save the crafting recipe details with "<field>" set to "<value>"
    Then the crafting creator should answer with a "destructive" notice containing "<message>"
    When I reopen the crafting creator
    Then the crafting app view "recipe" should be titled "FFT creator recipe"
    And the crafting app view "recipe" should say "Makes 1x Glass."
    And I close the app

    Examples:
      | field        | value            | message                                             |
      | label        |                  | Enter a name for the recipe.                        |
      | amount       | 0                | The amount made must be between 1 and 1000.         |
      | amount       | 1001             | The amount made must be between 1 and 1000.         |
      | amount       |                  | The amount made must be between 1 and 1000.         |
      | progressTime | 499              | Progress time must be between 500 and 300000 ms.    |
      | progressTime | 300001           | Progress time must be between 500 and 300000 ms.    |
      | progressTime |                  | Progress time must be between 500 and 300000 ms.    |
      | animClip     |                  | An animation needs both a dictionary and a clip.    |
      | animDict     |                  | An animation needs both a dictionary and a clip.    |
      | animClip     | bad clip!        | Enter a valid animation clip.                       |
      | animFlag     | 65536            | Animation flag must be between 0 and 65535.         |
      | animFlag     | -1               | Animation flag must be between 0 and 65535.         |
      | animDict     | fft_no_such_dict | Unknown animation dictionary.                       |
      | skill        | bad skill!       | Invalid skill.                                      |
      | skill        | fft_no_such      | That skill does not exist.                          |
      | xp           | 100001           | XP must be between 0 and 100000.                    |
      | xp           | -1               | XP must be between 0 and 100000.                    |
      | level        | 1001             | The level must be between 0 and 1000.               |
      | level        | -1               | The level must be between 0 and 1000.               |

  @ui
  Scenario Outline: Recipe details with <field> "<value>" are saved
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I search the crafting creator items for "glass"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:pick:glass"
    Then the crafting creator should answer with a "success" notice containing "It now makes Glass."
    When I save the crafting recipe details with "<field>" set to "<value>"
    Then the crafting creator should answer with a "success" notice containing "Saved."
    When I reopen the crafting creator
    Then the crafting app view "recipe" should say "<makes>"
    And I close the app

    Examples:
      | field        | value         | makes               |
      | amount       | 1000          | Makes 1000x Glass.  |
      | amount       | 7.9           | Makes 7x Glass.     |
      | progressTime | 500           | Makes 1x Glass.     |
      | progressTime | 300000        | Makes 1x Glass.     |
      | animFlag     | 0             | Makes 1x Glass.     |
      | animFlag     | 65535         | Makes 1x Glass.     |
      | skill        | crafting      | Makes 1x Glass.     |
      | level        | 1000          | Makes 1x Glass.     |
      | tag          | fft tag       | Makes 1x Glass.     |
      | label        | FFT renamed   | Makes 1x Glass.     |

  @ui
  Scenario: A recipe can drop its animation
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I save the crafting recipe details with:
      """
      { "label": "FFT creator recipe", "animDict": "", "animClip": "", "animFlag": "" }
      """
    Then the crafting creator should answer with a "success" notice containing "Saved."
    And the crafting server should have the recipe "fft_creator_recipe"
    And I close the app

  # Renaming keeps the id (server/creator.lua recipes:details saves under id).
  @ui
  Scenario: Renaming a recipe keeps its id
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I save the crafting recipe details with:
      """
      { "label": "  FFT renamed recipe  ", "tag": "fft" }
      """
    Then the crafting creator should answer with a "success" notice containing "Saved."
    And the crafting server should have the recipe "fft_creator_recipe"
    And the crafting server should not have the recipe "fft_renamed_recipe"
    When I reopen the crafting creator
    Then the crafting app view "recipe" should be titled "FFT renamed recipe"
    And I close the app

  # ---------------------------------------------------------------------------
  # Creator: stations (client/creator.lua stationAction).
  # ---------------------------------------------------------------------------

  @ui
  Scenario: An admin creates a station and gives it a recipe
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "station:new"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    And the crafting server should have the station "fft_creator_station"
    And my client should know the crafting station "fft_creator_station" with the target label "Craft"
    When I start the crafting creator action "station:add:fft_creator_recipe"
    Then the crafting creator should answer with a "success" notice containing "Recipe added."
    And the app action "station:add:fft_creator_recipe" should be unavailable
    When I reopen the crafting creator
    Then the crafting app view "station" should be titled "FFT creator station"
    And the crafting app should show the block "Recipes on this station (1)"
    And the crafting app should show the block "Locations (0)"
    When I start the crafting creator action "station:remove:fft_creator_recipe"
    Then the crafting creator should answer with a "success" notice containing "Recipe removed."
    When I reopen the crafting creator
    Then the crafting app should show the block "Recipes on this station (0)"
    And I close the app

  @ui @rejection
  Scenario: Cancelling the station name dialog creates no station
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "station:new"
    Then an input dialog should open
    When I cancel the input dialog
    Then the crafting creator should answer without a notice
    And the crafting server should not have the station "fft_creator_station"
    And I close the app

  # recipeMatches: every word must appear in the label, tag or result item.
  @ui
  Scenario: The station recipe search filters the recipes you can add
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "station:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    When I search the crafting creator recipes for "fft zz_no_match"
    Then the crafting creator should answer without a notice
    And the app action "station:add:fft_creator_recipe" should be unavailable
    When I search the crafting creator recipes for "creator FFT"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "station:add:fft_creator_recipe"
    Then the crafting creator should answer with a "success" notice containing "Recipe added."
    And I close the app

  @ui
  Scenario: Station settings are saved and fall back to defaults
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "station:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    When I start the crafting creator action "station:details" with:
      """
      { "label": "FFT forge", "targetLabel": "FFT use the forge", "targetIcon": "fa-solid fa-fire" }
      """
    Then the crafting creator should answer with a "success" notice containing "Saved."
    And my client should know the crafting station "fft_creator_station" with the target label "FFT use the forge"
    When I start the crafting creator action "station:details" with:
      """
      { "label": "FFT forge", "targetLabel": "   ", "targetIcon": "" }
      """
    Then the crafting creator should answer with a "success" notice containing "Saved."
    And my client should know the crafting station "fft_creator_station" with the target label "Craft"
    When I reopen the crafting creator
    Then the crafting app view "station" should be titled "FFT forge"
    And I close the app

  @ui @rejection
  Scenario: A station needs a name
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "station:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    When I start the crafting creator action "station:details" with:
      """
      { "label": "  ", "targetLabel": "FFT nameless", "targetIcon": "" }
      """
    Then the crafting creator should answer with a "destructive" notice containing "Enter a name for the station."
    And my client should know the crafting station "fft_creator_station" with the target label "Craft"
    When I reopen the crafting creator
    Then the crafting app view "station" should be titled "FFT creator station"
    And I close the app

  @ui @rejection
  Scenario: Placing a prop station refuses an unknown model
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "station:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    When I start the crafting creator action "station:place" with:
      """
      { "gang": "", "job": "", "object": "fft_no_such_prop_model" }
      """
    Then the crafting creator should answer with a "destructive" notice containing "Unknown object model."
    And the app "kora_crafting:creator" should be open
    When I reopen the crafting creator
    Then the crafting app should show the block "Locations (0)"
    And I close the app

  @ui
  Scenario: A duplicated station keeps its recipes but no locations
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "station:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    When I start the crafting creator action "station:add:fft_creator_recipe"
    Then the crafting creator should answer with a "success" notice containing "Recipe added."
    When I start the crafting creator action "station:duplicate"
    Then the crafting creator should answer with a "success" notice containing "Station duplicated without locations."
    And the crafting server should have the station "fft_creator_station_2"
    When I reopen the crafting creator
    Then the crafting app view "station" should be titled "FFT creator station-2"
    And the crafting app should show the block "Recipes on this station (1)"
    And the crafting app should show the block "Locations (0)"
    And I close the app

  @ui
  Scenario: Deleting a station needs confirmation
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "station:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    When I start the crafting creator action "station:delete"
    Then a confirmation should open
    When I decline
    Then the crafting creator should answer without a notice
    And the crafting server should have the station "fft_creator_station"
    When I start the crafting creator action "station:delete"
    Then a confirmation should open
    When I confirm
    Then the crafting creator should answer with a "success" notice containing "Station deleted."
    And the crafting server should not have the station "fft_creator_station"
    When I reopen the crafting creator
    Then the crafting app should not have the view "station"
    And I close the app

  # Deleting a recipe takes it off every station (server/data.lua DeleteRecipe).
  @ui
  Scenario: Deleting a recipe takes it off its station
    Given crafting test data is removed afterwards
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator recipe" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "station:new"
    And I submit the input dialog with:
      """
      { "name": "FFT creator station" }
      """
    Then the crafting creator should answer with a "success" notice containing "Station created."
    When I start the crafting creator action "station:add:fft_creator_recipe"
    Then the crafting creator should answer with a "success" notice containing "Recipe added."
    When I start the crafting creator action "recipe:select:fft_creator_recipe"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "recipe:delete"
    And I confirm
    Then the crafting creator should answer with a "success" notice containing "Recipe deleted."
    When I reopen the crafting creator
    Then the crafting app should not have the view "recipe"
    And the crafting app should show the block "Recipes on this station (0)"
    And I close the app

  # ---------------------------------------------------------------------------
  # Stations in the world (client/craft.lua, server/craft.lua). The hook builds
  # fft_station / fft_recipe; the creator then changes them like an admin would.
  # ---------------------------------------------------------------------------

  @ui @world @global
  Scenario: A recipe's own progress text and time are used
    Given I hold 2 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:select:fft_recipe"
    Then the crafting creator should answer without a notice
    When I save the crafting recipe details with:
      """
      { "progressLabel": "FFT welding", "progressTime": "2000" }
      """
    Then the crafting creator should answer with a "success" notice containing "Saved."
    When I close the app
    And I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "FFT welding" should start
    And the crafting progress bar should last 2000 milliseconds
    And the progress bar should finish
    And I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    And I should have no "plastic"
    When I close the app
    Then no crafting should be in progress

  # After a craft the station loop asks kora_crafting:menu again; its 1000 ms
  # cooldown (shared/constants.lua Cooldowns.menu) must not close the station
  # after the shortest allowed recipe (500 ms).
  @ui @world @global
  Scenario: The station reopens after the shortest allowed craft
    Given I hold 2 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:select:fft_recipe"
    Then the crafting creator should answer without a notice
    When I save the crafting recipe details with "progressTime" set to "500"
    Then the crafting creator should answer with a "success" notice containing "Saved."
    When I close the app
    And I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    And the app "kora_crafting:menu" should be open
    And I should not see a notification containing "Slow down."
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A renamed station shows its new target and menu title
    Given I hold 2 "plastic"
    And a crafting test station turns 2 "plastic" into 1 "glass"
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "station:select:fft_station"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "station:details" with:
      """
      { "label": "FFT forge", "targetLabel": "FFT renamed craft", "targetIcon": "" }
      """
    Then the crafting creator should answer with a "success" notice containing "Saved."
    And my client should know the crafting station "fft_station" with the target label "FFT renamed craft"
    When I close the app
    And I aim at the crafting test station
    And I target "FFT renamed craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app view "recipes" should be titled "FFT forge"
    And the crafting app view "recipes" should say "Pick something to craft."
    And the crafting app should show the block "Ready to craft (1)"
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A recipe with two materials uses up both
    Given I hold 2 "plastic"
    And I hold 3 "iron"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 2 "plastic" and 3 "iron" into 1 "glass"
    And I remember how many "glass" I have
    And I remember how many "iron" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app should show the block "Ready to craft (1)"
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    And I should have 3 fewer "iron" than before
    And I should have no "plastic"
    When I close the app
    Then no crafting should be in progress

  @ui @world @global @rejection
  Scenario: Having only some of the materials is not enough
    Given I hold 2 "plastic"
    And a crafting test station turns 2 "plastic" and 3 "iron" into 1 "glass"
    And I remember how many "glass" I have
    Then I should have no "iron"
    When I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app should show the block "Missing something (1)"
    And the crafting app should not show the block "Ready to craft (1)"
    And the crafting app view "recipes" should say "You cannot craft anything here yet."
    And the app action "craft:fft_recipe" should be unavailable
    And I should have 2 "plastic"
    And I should have 0 more "glass" than before
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A recipe that needs nothing can always be crafted
    Given any "glass" I craft is removed afterwards
    And a crafting test station makes 1 "glass" from nothing
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app should show the block "Ready to craft (1)"
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A kept tool and a used-up material in one recipe
    Given I hold 1 "plastic"
    And I hold 2 "iron"
    And any "glass" I craft is removed afterwards
    And a crafting test station makes 1 "glass" with 1 "plastic" kept and 2 "iron" used up
    And I remember how many "glass" I have
    And I remember how many "plastic" I have
    And I remember how many "iron" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    And I should have 0 fewer "plastic" than before
    And I should have 2 fewer "iron" than before
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A station can be used twice in a row
    Given I hold 4 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should have 1 more "glass" than before
    And the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should have 2 more "glass" than before
    And I should have no "plastic"
    And the app "kora_crafting:menu" should be open
    And the app action "craft:fft_recipe" should be unavailable
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A recipe can make several items at once
    Given I hold 1 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 1 "plastic" into 10 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 10x Glass."
    And I should have 10 more "glass" than before
    And I should have no "plastic"
    When I close the app
    Then no crafting should be in progress

  # server/craft.lua begin re-checks the materials (craftable) before starting.
  @ui @world @global @rejection
  Scenario: Materials that disappear while the menu is open stop the craft from starting
    Given I hold 2 "plastic"
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I remove 2 "plastic"
    And I craft the recipe "fft_recipe"
    Then I should see a notification containing "You need 2x Plastic."
    And no progress bar should be running
    And I should have 0 more "glass" than before
    And no crafting should be in progress

  @ui @world @global @rejection
  Scenario: A station deleted while its menu is open cannot be used
    Given I hold 2 "plastic"
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When the crafting test data is deleted
    And I craft the recipe "fft_recipe"
    Then I should see a notification containing "This station is not available."
    And no progress bar should be running
    And I should have 2 "plastic"
    And I should have 0 more "glass" than before
    And no crafting should be in progress

  @world @global @rejection
  Scenario: A deleted station disappears from the world
    Given a crafting test station turns 2 "plastic" into 1 "glass"
    And my client should know the crafting test station
    When the crafting test data is deleted
    Then my client should no longer know the crafting test station
    When I aim at the crafting test station
    Then no target option should be visible

  @ui @world @global @rejection
  Scenario: A station without recipes says so
    Given a crafting test station turns 2 "plastic" into 1 "glass"
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "station:select:fft_station"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "station:remove:fft_recipe"
    Then the crafting creator should answer with a "success" notice containing "Recipe removed."
    When I close the app
    And I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app should show the block "This station has no recipes yet."
    And the crafting app view "recipes" should say "You cannot craft anything here yet."
    And the app action "craft:fft_recipe" should be unavailable
    When I close the app
    Then no crafting should be in progress

  # server/craft.lua menu only lists recipeComplete() recipes.
  @ui @world @global @rejection
  Scenario: An unfinished recipe on a station is hidden from players
    Given I hold 2 "plastic"
    And a crafting test station turns 2 "plastic" into 1 "glass"
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:new"
    And I submit the input dialog with:
      """
      { "name": "FFT unfinished" }
      """
    Then the crafting creator should answer with a "success" notice containing "Recipe created."
    When I start the crafting creator action "station:select:fft_station"
    Then the crafting creator should answer without a notice
    When I start the crafting creator action "station:add:fft_unfinished"
    Then the crafting creator should answer with a "success" notice containing "Recipe added."
    When I reopen the crafting creator
    Then the crafting app should show the block "Recipes on this station (2)"
    When I close the app
    And I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app should show the block "Ready to craft (1)"
    And the crafting app should not show the block "Missing something (1)"
    And the app action "craft:fft_unfinished" should be unavailable
    When I close the app
    Then no crafting should be in progress

  # kora_skills levels start at 1, so level 1 is always met (isLevel).
  @ui @world @global
  Scenario: A recipe needing skill level 1 can be crafted
    Given I hold 2 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:select:fft_recipe"
    Then the crafting creator should answer without a notice
    When I save the crafting recipe details with:
      """
      { "skill": "crafting", "level": "1" }
      """
    Then the crafting creator should answer with a "success" notice containing "Saved."
    When I close the app
    And I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app should show the block "Ready to craft (1)"
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    When I close the app
    Then no crafting should be in progress

  @ui @world @global
  Scenario: A job-locked station works for that job
    Given my job is "police" at grade 1
    And I hold 2 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station for the "police" job turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You made 1x Glass."
    And I should have 1 more "glass" than before
    When I close the app
    Then no crafting should be in progress

  # Job locks compare the job name only, not duty (server/_functions.lua
  # locationAllowed, client/_functions.lua canUse).
  @ui @world @global
  Scenario: A job-locked station also works off duty
    Given I am off duty as "police" at grade 1
    And I hold 2 "plastic"
    And a crafting test station for the "police" job turns 2 "plastic" into 1 "glass"
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    And the crafting app should show the block "Ready to craft (1)"
    When I close the app
    Then no crafting should be in progress

  # server/craft.lua finish gives the materials back when AddItem fails.
  # 500 iron + 1000 glass at weight 100 each exceed kora_core maxWeight 120000.
  @ui @world @global @rejection
  Scenario: A craft whose result does not fit gives the materials back
    Given I hold 500 "iron"
    And I hold 1 "plastic"
    And any "glass" I craft is removed afterwards
    And a crafting test station turns 1 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    When I run the command "craftCreator"
    Then the app "kora_crafting:creator" should be open
    When I start the crafting creator action "recipe:select:fft_recipe"
    Then the crafting creator should answer without a notice
    When I save the crafting recipe details with "amount" set to "1000"
    Then the crafting creator should answer with a "success" notice containing "Saved."
    When I close the app
    And I aim at the crafting test station
    And I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I craft the recipe "fft_recipe"
    Then a progress bar labelled "Crafting..." should start
    And the progress bar should finish
    And I should see a notification containing "You do not have room for that."
    And I should have 1 "plastic"
    And I should have 0 more "glass" than before
    When I close the app
    Then no crafting should be in progress

  # server/craft.lua resolveStation: isNear within Config.Distance (5.0).
  @ui @world @global @rejection
  Scenario: Walking away from the station before crafting is refused
    Given I hold 2 "plastic"
    And a crafting test station turns 2 "plastic" into 1 "glass"
    And I remember how many "glass" I have
    And I aim at the crafting test station
    When I target "FFT test craft"
    Then the app "kora_crafting:menu" should be open
    When I move 12 metres away from the crafting test station
    And I craft the recipe "fft_recipe"
    Then I should see a notification containing "You are too far away."
    And no progress bar should be running
    And I should have 2 "plastic"
    And I should have 0 more "glass" than before
    And no crafting should be in progress
