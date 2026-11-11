@kora @kora_emotemenu
Feature: kora_emotemenu emotes, walk styles and expressions
  Emotes are played with the real chat commands and checked against the
  replicated state the server reads (kora_emotemenu:active/last/walk/expression).
  Every emote is cancelled in cleanup and the tester's walk style and expression
  are restored. The menu is a kora_lib menu, answered at the NUI-callback level
  through kora_lib's hook; nothing clicks the rendered wheel. The menu scenarios
  assume the default Config.menuStyle 'radial' (an admin can change it live).
  Not covered:
  - Shared emotes (handshake, hug): they invite the nearest real player, and the
    tester must be the only subject.
  - The kora_police cuff bag (koraCuffed) and the dead block: they need another
    resource's cuff or death state. The cuffed block is covered through the
    third-party keys the resource also reads (handcuffed, isCuffed), set
    locally and unreplicated the way such a cuff script would, then cleared.
  - /emoteMaker itself (a free camera tool) and a successful save or delete:
    saving rewrites shared/created.json and broadcasts to every client. Only
    refusals are driven: the editor's own required-field checks through its
    NUI callbacks, and the server's payload validation. The server answers a
    tester without the "command" ACE with a permission refusal before it
    validates, so those scenarios accept either refusal and prove on the
    server that created.json did not change.
  - The context and app menu styles: Config.menuStyle is an admin setting.
  - A successful registerEmote: there is no unregister, so the entry would stay
    until the resource restarts. Only its name validation is checked.
  - Pressing the cancel key (X): key presses are not simulated; /cancel is used.
  - That the animation, prop or facial pose looks right on the ped.

  Background:
    Given resource "kora_emotemenu" is running

  Scenario Outline: Command plays an emote and the server sees it
    When I play the emote "<emote>"
    Then the emote "<emote>" should be playing
    And the server should see me playing the emote "<emote>"

    Examples:
      | emote     |
      | wave      |
      | dance     |
      | surrender |
      | clipboard |

  @world
  Scenario: Scenario emote plays where I stand
    When I play the emote "lean"
    Then the emote "lean" should be playing
    And the text prompt should show "Cancel emote"

  Scenario: Cancel command stops the emote
    Given I play the emote "wave"
    And the emote "wave" should be playing
    And the text prompt should show "Cancel emote"
    When I cancel my emote
    Then no emote should be playing
    And I should see a notification containing "Emote cancelled."
    And no text prompt should be shown
    And the server should see me playing no emote
    And my last emote should be "wave"

  Scenario: A new emote replaces the current one
    Given I play the emote "wave"
    And the emote "wave" should be playing
    When I play the emote "salute"
    Then the emote "salute" should be playing
    And the server should see me playing the emote "salute"

  @rejection
  Scenario: Unknown emote is refused
    When I play the emote "fft_no_such_emote"
    Then I should see a notification containing "That emote is not registered."
    And no emote should be playing

  @rejection
  Scenario: Export reports why an emote was refused
    Then playing the emote "fft_no_such_emote" through the export should be refused with "That emote is not registered."
    And no emote should be playing

  @world @rejection
  Scenario: Scenario emotes are refused inside a vehicle
    Given I am driving a temporary "blista"
    When I play the emote "sit"
    Then I should see a notification containing "That emote cannot be played inside a vehicle."
    And no emote should be playing
    And I should be in a vehicle

  Scenario: Walk style is set and replicated
    When I set my walk style to "brave"
    Then I should see a notification containing "Walk style: Brave"
    And my walk style should be "brave"
    And the server should see my walk style as "brave"

  @rejection
  Scenario: Unknown walk style is refused
    Then my walk style should stay as it was after I try the walk style "fft_no_such_walk"
    And I should see a notification containing "That walk style is not configured."

  Scenario: Expression is set and replicated
    When I set my expression to "happy"
    Then I should see a notification containing "Expression: Happy"
    And my expression should be "happy"
    And the server should see my expression as "happy"
    When I set my expression to "default"
    Then my expression should be "default"

  @rejection
  Scenario: Unknown expression is refused
    Then my expression should stay as it was after I try the expression "fft_no_such_face"
    And I should see a notification containing "That expression is not configured."

  @ui
  Scenario: Menu lists the emote categories and options
    When I open the emote menu
    Then a menu should open
    And the menu should list "General"
    And the menu should list "Dances"
    And the menu should list "Props"
    And the menu should list "Scenarios"
    And the menu should list "Walk style"
    And the menu should list "Expression"
    And the menu should list "Cancel emote"
    When I close the menu
    Then no menu should be open
    And no emote should be playing

  @ui
  Scenario: Choosing an emote in the menu plays it
    When I open the emote menu
    Then a menu should open
    When I choose "Wave" in the menu
    Then the emote "wave" should be playing
    And the server should see me playing the emote "wave"

  @ui
  Scenario: Choosing a walk style in the menu applies it
    When I open the emote menu
    Then a menu should open
    When I choose "Confident" in the menu
    Then my walk style should be "confident"
    And I should see a notification containing "Walk style: Confident"

  @rejection
  Scenario: Registering an emote with an invalid name is refused
    Then registering an emote named "bad name!" should be refused
    And playing the emote "bad name!" through the export should be refused with "That emote is not registered."

  # ---------------------------------------------------------------------------
  # Emotes: more of the catalogue, name handling and the exports
  # ---------------------------------------------------------------------------

  Scenario Outline: The rest of the solo catalogue plays by command
    When I play the emote "<emote>"
    Then the emote "<emote>" should be playing
    And the server should see me playing the emote "<emote>"
    And the text prompt should show "Cancel emote"

    Examples:
      | emote  |
      | salute |
      | coffee |
      | guitar |
      | dance2 |

  Scenario: Emote names are not case sensitive
    When I play the emote "WAVE"
    Then the emote "wave" should be playing
    And the server should see me playing the emote "wave"

  Scenario: The export plays an emote and reports success
    Then playing the emote "salute" through the export should succeed
    And the emote "salute" should be playing
    And the server should see me playing the emote "salute"

  Scenario: Playing the same emote again keeps it playing
    Given I play the emote "wave"
    And the emote "wave" should be playing
    When I play the emote "wave"
    Then the emote "wave" should be playing
    And I should not see a notification containing "Emote cancelled."

  Scenario: The cancel export reports whether an emote was stopped
    Given I play the emote "wave"
    And the emote "wave" should be playing
    Then cancelling my emote through the export should report that it stopped one
    And no emote should be playing
    And the server should see me playing no emote
    And cancelling my emote through the export should report that nothing was playing

  @rejection
  Scenario: Cancelling with nothing playing says nothing
    Given no emote should be playing
    When I cancel my emote
    Then I should not see a notification containing "Emote cancelled."
    And no emote should be playing

  @rejection
  Scenario: A refused emote leaves the running emote and the last emote alone
    Given I play the emote "wave"
    And the emote "wave" should be playing
    When I play the emote "fft_no_such_emote"
    Then I should see a notification containing "That emote is not registered."
    And the emote "wave" should be playing
    And the server should remember my last emote as "wave"

  Scenario: The last emote is remembered after a cancel and a refusal
    Given I play the emote "dance"
    And the emote "dance" should be playing
    When I cancel my emote
    And I play the emote "fft_no_such_emote"
    Then no emote should be playing
    And my last emote should be "dance"
    And the server should remember my last emote as "dance"

  Scenario: A hidden partner emote plays by name and shows no cancel hint
    Given I play the emote "wave"
    And the text prompt should show "Cancel emote"
    When I play the emote "handshake_partner"
    Then the emote "handshake_partner" should be playing
    And no text prompt should be shown

  @world @rejection
  Scenario: A shared emote needs another player within reach
    Given nobody else is within reach for a shared emote
    Then playing the emote "handshake" through the export should be refused with "Move within 3.0m of another player."
    And no emote should be playing
    When I play the emote "hug"
    Then I should see a notification containing "Move within 3.0m of another player."
    And no emote should be playing

  # ---------------------------------------------------------------------------
  # Vehicles
  # ---------------------------------------------------------------------------

  @world
  Scenario: An animation emote plays in a vehicle without leaving the seat
    Given I am driving a temporary "blista"
    When I play the emote "wave"
    Then the emote "wave" should be playing
    And I should be in a vehicle
    When I cancel my emote
    Then no emote should be playing
    And I should see a notification containing "Emote cancelled."
    And I should be in a vehicle

  @world @rejection
  Scenario Outline: Standing emotes are refused inside a vehicle
    Given I am driving a temporary "blista"
    Then playing the emote "<emote>" through the export should be refused with "That emote cannot be played inside a vehicle."
    And no emote should be playing
    And I should be in a vehicle

    Examples:
      | emote             |
      | sit               |
      | lean              |
      | handshake         |
      | hug               |
      | handshake_partner |

  @world @rejection
  Scenario: A refused vehicle emote does not stop the one already playing
    Given I am driving a temporary "blista"
    And I play the emote "wave"
    And the emote "wave" should be playing
    When I play the emote "lean"
    Then I should see a notification containing "That emote cannot be played inside a vehicle."
    And the emote "wave" should be playing

  @world @rejection
  Scenario: Walk styles cannot be changed inside a vehicle
    Given I am driving a temporary "blista"
    Then my walk style should stay as it was after I try the walk style "brave"
    And I should see a notification containing "Walk styles cannot be changed inside a vehicle."
    And setting the walk style "sad" through the export should be refused with "Walk styles cannot be changed inside a vehicle."

  @world
  Scenario: An expression can be set inside a vehicle
    Given I am driving a temporary "blista"
    When I set my expression to "smug"
    Then my expression should be "smug"
    And the server should see my expression as "smug"
    And I should be in a vehicle

  # ---------------------------------------------------------------------------
  # Cuffed (third-party cuff keys read by canUse in client/main.lua)
  # ---------------------------------------------------------------------------

  @rejection
  Scenario Outline: A cuffed player cannot start an emote
    Given a third-party cuff script marks me as cuffed with the state key "<key>"
    When I play the emote "wave"
    Then I should see a notification containing "You cannot use emotes right now."
    And no emote should be playing
    And playing the emote "salute" through the export should be refused with "You cannot use emotes right now."
    And the server should see me playing no emote

    Examples:
      | key        |
      | handcuffed |
      | isCuffed   |

  @rejection
  Scenario: Being cuffed stops the running emote without a notice
    Given I play the emote "wave"
    And the emote "wave" should be playing
    When a third-party cuff script marks me as cuffed with the state key "handcuffed"
    Then no emote should be playing
    And the server should see me playing no emote
    And no text prompt should be shown
    And I should not see a notification containing "Emote cancelled."
    And my last emote should be "wave"

  @ui @rejection
  Scenario: A cuffed player cannot open the emote menu
    Given a third-party cuff script marks me as cuffed with the state key "handcuffed"
    When I run the command "emotes"
    Then I should see a notification containing "You cannot use emotes right now."
    And no menu should be open

  Scenario: Emotes work again once the cuffs are off
    Given a third-party cuff script marks me as cuffed with the state key "handcuffed"
    And playing the emote "wave" through the export should be refused with "You cannot use emotes right now."
    When the third-party cuff state is cleared
    And I play the emote "wave"
    Then the emote "wave" should be playing
    And the server should see me playing the emote "wave"

  # ---------------------------------------------------------------------------
  # Walk styles (Config.walks)
  # ---------------------------------------------------------------------------

  Scenario Outline: Every configured walk style can be set
    When I set my walk style to "<walk>"
    Then I should see a notification containing "Walk style: <label>"
    And my walk style should be "<walk>"
    And the server should see my walk style as "<walk>"

    Examples:
      | walk      | label     |
      | casual    | Casual    |
      | confident | Confident |
      | drunk     | Drunk     |
      | hurry     | Hurry     |
      | sad       | Sad       |
      | default   | Default   |

  Scenario: The walk command without a name returns to the default
    Given I set my walk style to "hurry"
    And my walk style should be "hurry"
    When I run the command "walk"
    Then my walk style should be "default"
    And I should see a notification containing "Walk style: Default"
    And the server should see my walk style as "default"

  Scenario: Walk style names are not case sensitive
    When I set my walk style to "BRAVE"
    Then my walk style should be "brave"
    And the server should see my walk style as "brave"

  Scenario: The reset export returns the walk style to the default
    Given I set my walk style to "drunk"
    And my walk style should be "drunk"
    When I reset my walk style through the export
    Then my walk style should be "default"
    And the server should see my walk style as "default"

  Scenario: One walk style replaces another
    Given I set my walk style to "sad"
    And my walk style should be "sad"
    When I set my walk style to "confident"
    Then my walk style should be "confident"
    And the server should see my walk style as "confident"

  @rejection
  Scenario: The walk export reports why a style was refused
    Given I set my walk style to "casual"
    And my walk style should be "casual"
    Then setting the walk style "fft_no_such_walk" through the export should be refused with "That walk style is not configured."
    And my walk style should be "casual"

  Scenario: Changing the walk style does not stop an emote
    Given I play the emote "wave"
    And the emote "wave" should be playing
    When I set my walk style to "sad"
    Then my walk style should be "sad"
    And the emote "wave" should be playing

  # ---------------------------------------------------------------------------
  # Expressions (Config.expressions)
  # ---------------------------------------------------------------------------

  Scenario Outline: Every configured expression can be set
    When I set my expression to "<expression>"
    Then I should see a notification containing "Expression: <label>"
    And my expression should be "<expression>"
    And the server should see my expression as "<expression>"

    Examples:
      | expression | label    |
      | angry      | Angry    |
      | smug       | Smug     |
      | stressed   | Stressed |

  Scenario: The default expression clears the replicated state
    Given I set my expression to "angry"
    And the server should see my expression as "angry"
    When I run the command "expression"
    Then I should see a notification containing "Expression: Default"
    And my expression should be "default"
    And the server should see no expression on me

  Scenario: Expression names are not case sensitive
    When I set my expression to "HAPPY"
    Then my expression should be "happy"
    And the server should see my expression as "happy"

  Scenario: The reset export clears the expression
    Given I set my expression to "stressed"
    And my expression should be "stressed"
    When I reset my expression through the export
    Then my expression should be "default"
    And the server should see no expression on me

  @rejection
  Scenario: The expression export reports why an expression was refused
    Given I set my expression to "smug"
    And my expression should be "smug"
    Then setting the expression "fft_no_such_face" through the export should be refused with "That expression is not configured."
    And my expression should be "smug"

  Scenario: An expression survives an emote and its cancel
    Given I set my expression to "happy"
    And my expression should be "happy"
    When I play the emote "wave"
    And the emote "wave" should be playing
    And I cancel my emote
    Then no emote should be playing
    And my expression should be "happy"
    And the server should see my expression as "happy"

  # ---------------------------------------------------------------------------
  # Menu (kora_lib radial menu, answered at the callback level)
  # ---------------------------------------------------------------------------

  @ui
  Scenario: The emote command without a name opens the menu
    When I open the emote menu with the bare emote command
    Then a menu should open
    And the menu should list "General"
    When I close the menu
    Then no menu should be open

  @ui
  Scenario: The toggle export opens the menu
    When I open the emote menu through the export
    Then a menu should open
    And the menu should list "Cancel emote"
    When I close the menu
    Then no menu should be open

  @ui
  Scenario: Menu lists shared emotes but never the hidden partner entries
    When I open the emote menu
    Then a menu should open
    And the menu should list "Shared"
    And the menu should list "emote:handshake"
    And the menu should list "emote:hug"
    And the menu should not list "emote:handshake_partner"
    And the menu should not list "emote:hug_partner"
    And the menu should not list "Handshake (partner)"

  @ui
  Scenario: Menu lists every built-in emote, walk style and expression
    When I open the emote menu
    Then a menu should open
    And the menu should list "emote:wave"
    And the menu should list "emote:salute"
    And the menu should list "emote:surrender"
    And the menu should list "emote:sit"
    And the menu should list "emote:lean"
    And the menu should list "emote:clipboard"
    And the menu should list "emote:coffee"
    And the menu should list "emote:guitar"
    And the menu should list "emote:dance"
    And the menu should list "emote:dance2"
    And the menu should list "walk:default"
    And the menu should list "walk:brave"
    And the menu should list "walk:casual"
    And the menu should list "walk:confident"
    And the menu should list "walk:drunk"
    And the menu should list "walk:hurry"
    And the menu should list "walk:sad"
    And the menu should list "expression:default"
    And the menu should list "expression:angry"
    And the menu should list "expression:happy"
    And the menu should list "expression:smug"
    And the menu should list "expression:stressed"

  @ui @rejection
  Scenario: Cancel emote is disabled in the menu while nothing plays
    Given no emote should be playing
    When I open the emote menu
    Then a menu should open
    And the emote menu entry "cancel" should be disabled
    And the emote menu entry "cancel" should be described as "No emote is playing"
    And choosing the disabled emote menu entry "cancel" should be refused

  @ui
  Scenario: Cancel emote in the menu stops the running emote
    Given I play the emote "dance"
    And the emote "dance" should be playing
    When I open the emote menu
    Then a menu should open
    And the emote menu entry "cancel" should be enabled
    And the emote menu entry "cancel" should be described as "Stop the current emote"
    When I choose "cancel" in the menu
    Then no emote should be playing
    And I should see a notification containing "Emote cancelled."
    And the server should see me playing no emote

  @ui
  Scenario: The menu marks the active walk style
    Given I set my walk style to "brave"
    And my walk style should be "brave"
    When I open the emote menu
    Then a menu should open
    And the emote menu entry "walk:brave" should be described as "Currently active"
    And the emote menu entry "walk:default" should not be marked active
    And the emote menu entry "walk:casual" should not be marked active

  @ui
  Scenario: The menu marks the active expression
    Given I set my expression to "angry"
    And my expression should be "angry"
    When I open the emote menu
    Then a menu should open
    And the emote menu entry "expression:angry" should be described as "Currently active"
    And the emote menu entry "expression:default" should not be marked active
    And the emote menu entry "expression:happy" should not be marked active

  @ui
  Scenario: The menu marks the defaults after a reset
    Given I set my walk style to "sad"
    And my walk style should be "sad"
    And I set my expression to "smug"
    And my expression should be "smug"
    When I reset my walk style through the export
    And I reset my expression through the export
    And I open the emote menu
    Then a menu should open
    And the emote menu entry "walk:default" should be described as "Currently active"
    And the emote menu entry "expression:default" should be described as "Currently active"
    And the emote menu entry "walk:sad" should not be marked active
    And the emote menu entry "expression:smug" should not be marked active

  @ui
  Scenario: Choosing an expression in the menu applies it
    When I open the emote menu
    Then a menu should open
    When I choose "expression:happy" in the menu
    Then my expression should be "happy"
    And I should see a notification containing "Expression: Happy"
    And the server should see my expression as "happy"

  @ui
  Scenario: Choosing the default walk style in the menu resets it
    Given I set my walk style to "drunk"
    And my walk style should be "drunk"
    When I open the emote menu
    Then a menu should open
    When I choose "walk:default" in the menu
    Then my walk style should be "default"
    And I should see a notification containing "Walk style: Default"

  @ui
  Scenario: Choosing a prop emote in the menu plays it
    When I open the emote menu
    Then a menu should open
    When I choose "emote:coffee" in the menu
    Then the emote "coffee" should be playing
    And the server should see me playing the emote "coffee"

  @ui
  Scenario: Closing the menu leaves a running emote alone
    Given I play the emote "wave"
    And the emote "wave" should be playing
    When I open the emote menu
    Then a menu should open
    When I close the menu
    Then no menu should be open
    And the emote "wave" should be playing

  @ui @world @rejection
  Scenario: A scenario emote chosen from the menu is refused inside a vehicle
    Given I am driving a temporary "blista"
    When I open the emote menu
    Then a menu should open
    When I choose "emote:sit" in the menu
    Then I should see a notification containing "That emote cannot be played inside a vehicle."
    And no emote should be playing
    And I should be in a vehicle

  @ui @world @rejection
  Scenario: A walk style chosen from the menu is refused inside a vehicle
    Given I am driving a temporary "blista"
    When I open the emote menu
    Then a menu should open
    When I choose "walk:hurry" in the menu
    Then I should see a notification containing "Walk styles cannot be changed inside a vehicle."

  # ---------------------------------------------------------------------------
  # registerEmote validation (refusals only: a registration cannot be undone)
  # ---------------------------------------------------------------------------

  @rejection
  Scenario Outline: Registering an emote with an invalid definition is refused
    Then registering an emote with the invalid definition "<case>" should be refused
    And playing the emote "fft_refused_emote" through the export should be refused with "That emote is not registered."

    Examples:
      | case                      |
      | not_a_table               |
      | no_label                  |
      | label_not_text            |
      | unknown_type              |
      | no_type                   |
      | visible_without_category  |
      | visible_unknown_category  |
      | anim_without_dict         |
      | anim_without_clip         |
      | scenario_without_scenario |

  @rejection
  Scenario Outline: Registering an emote under an invalid name is refused
    Then registering an emote named "<name>" should be refused

    Examples:
      | name       |
      | two words  |
      | emote.name |
      | emote:name |

  # ---------------------------------------------------------------------------
  # Emote maker: the editor's own checks (NUI callbacks) and server validation
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario Outline: The emote maker will not save an incomplete emote
    Given the emote maker editor has only these fields filled: "<filled>"
    And I remember the saved emote file
    Then saving in the emote maker should be refused
    And I should see a notification containing "<message>"
    And the saved emote file should be unchanged

    Examples:
      | filled          | message                             |
      | none            | Enter a name first.                 |
      | name            | Enter a label first.                |
      | name,label      | Enter an animation dictionary first. |
      | name,label,dict | Enter an animation clip first.      |
      | label,dict,clip | Enter a name first.                 |

  @ui @rejection
  Scenario: The emote maker will not preview without an animation
    Given the emote maker editor has only these fields filled: "name,label"
    When I ask the emote maker to preview
    Then I should see a notification containing "Enter an animation dictionary and clip first."
    And no emote should be playing

  # Each case fills the editor through creator:change and presses save through
  # creator:action, the same callbacks the creator page uses, so only values
  # the editor can hold reach the server (client/emote_creator.lua readUiState).
  @ui @rejection
  Scenario Outline: The server refuses an invalid emote maker save
    Given I remember the saved emote file
    When I fill the emote maker with the invalid case "<case>" and save
    Then the emote maker should answer "<message>" unless I lack permission to create emotes
    And the saved emote file should be unchanged

    Examples:
      | case                 | message                                                                |
      | name_with_space      | Names may only use letters, digits, _ and -.                           |
      | name_with_dot        | Names may only use letters, digits, _ and -.                           |
      | name_too_long        | Names may only use letters, digits, _ and -.                           |
      | category_scenarios   | Choose a valid category.                                               |
      | category_shared      | Choose a valid category.                                               |
      | category_unknown     | Choose a valid category.                                               |
      | dict_with_space      | Enter a valid animation dictionary and clip.                           |
      | dict_too_long        | Enter a valid animation dictionary and clip.                           |
      | clip_with_space      | Enter a valid animation dictionary and clip.                           |
      | flag_negative        | The flag must be a whole number.                                       |
      | flag_too_big         | The flag must be a whole number.                                       |
      | prop_bad_model       | Prop 1 is invalid.                                                     |
      | prop_offset_too_far  | Prop 1 is invalid.                                                     |
      | second_prop_bad_bone | Prop 2 is invalid.                                                     |
      | name_taken           | already exists.                                                        |
      | editing_unknown      | That saved emote could not be found. Refresh the editor and try again. |

  @ui @rejection
  Scenario Outline: The server refuses to delete an emote that was never saved
    Given I remember the saved emote file
    When I ask the emote maker to delete the saved emote "<name>"
    Then the emote maker should answer "<message>" unless I lack permission to delete emotes
    And the saved emote file should be unchanged

    Examples:
      | name               | message                            |
      | bad name!          | Choose a valid saved emote.        |
      | fft_no_such_saved  | That saved emote no longer exists. |
      | wave               | That saved emote no longer exists. |
