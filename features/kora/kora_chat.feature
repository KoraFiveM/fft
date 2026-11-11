@kora @kora_chat
Feature: kora_chat message dispatch and composer
  Server scenarios call the real exports and deliver only to the tester; the
  dispatch log is the local server event chatMessage. Composer scenarios run
  kora_chat's own NUI callbacks at the callback level; they do not type into
  the rendered input and do not observe the rendered feed.

  Not covered, because the message would reach other players: /ooc, /me with
  text and a plain local message. Also not covered: the rate limit (it would
  need a real local message), and the effect of /clearchat and feed rendering
  (kora_chat's own NUI page cannot be observed without a hook). Also not
  covered: registerMessageHook (no unregister; a hook stays until FFT stops)
  and registerMode (it always creates a command, which cannot be unregistered
  from FiveM). Client receipt scenarios listen to the net events kora_chat's
  server sends to the tester's client; they do not observe the rendered feed.

  Background:
    Given resource "kora_chat" is running

  @server
  Scenario: A trusted message is delivered to one player
    Given I watch the chat dispatch log
    When chat delivers a "say" message "fft chat probe one" from "FFT Sender" to me
    Then the chat dispatch log should hold "fft chat probe one" from "FFT Sender"

  @server @rejection
  Scenario Outline: An invalid message is refused
    Given I watch the chat dispatch log
    Then chat should refuse to deliver a "<type>" message "<message>" to me with "invalid message"
    And the chat dispatch log should not hold "<message>"

    Examples:
      | type             | message            |
      | fft_no_such_type | fft chat probe two |
      | say              |                    |

  @server @rejection
  Scenario: A message of only control characters is refused
    Then chat should refuse to deliver a message of only control characters to me with "invalid message"

  @server
  Scenario: A trusted message is shortened to the length limit
    Given I watch the chat dispatch log
    When chat delivers a trusted message of 500 characters starting with "fft-long-" to me
    Then the chat dispatch log should hold a message of 400 characters starting with "fft-long-"

  @server @rejection
  Scenario: A message that looks like a command is cancelled
    Then chat should refuse to deliver a "say" message "/fft_chat_probe hello" to me with "cancelled"

  @server
  Scenario: The chat commands are registered
    Then the chat command "me" should be registered on the server
    And the chat command "ooc" should be registered on the server
    And the chat command "say" should be registered on the server

  @rejection
  Scenario: An action command without a message is refused
    Given I watch the chat dispatch log
    When I run the command "me"
    Then I should see a notification containing "Missing message for /me"
    And I should have dispatched no chat message

  @ui @rejection
  Scenario: The composer rejects a message over the length limit
    Given I watch the chat dispatch log
    When I submit a chat composer message of 450 characters
    Then I should see a notification containing "Your message is too long"
    And I should have dispatched no chat message

  @ui @rejection
  Scenario: A cancelled or blank composer submission sends nothing
    Given I watch the chat dispatch log
    When I cancel the chat composer
    And I submit a blank chat composer message
    And I wait 750 milliseconds
    Then I should have dispatched no chat message

  @ui
  Scenario: Argument suggestions answer with a bounded empty list
    Then chat argument suggestions for "me" argument 1 should be empty
    And chat argument suggestions for "me" argument 99 should be empty
    And the chat command "clearchat" should be registered on my client

  @server @rejection
  Scenario: Another resource cannot take over a built-in message type
    Given I watch the chat dispatch log
    Then registering the chat message type "say" from the test runner should fail
    And unregistering the chat message type "say" from the test runner should be refused
    When chat delivers a "say" message "fft chat probe three" from "FFT Sender" to me
    Then the chat dispatch log should hold "fft chat probe three" from "FFT Sender"

  @server @global
  Scenario: A custom message type can be registered, used and removed
    Given I watch the chat dispatch log
    And the test runner registers the commandless chat message type "fft_probe"
    When chat delivers a "fft_probe" message "fft chat probe four" from "FFT Sender" to me
    Then the chat dispatch log should hold "fft chat probe four" from "FFT Sender"
    When the test runner unregisters the chat message type "fft_probe"
    Then chat should refuse to deliver a "fft_probe" message "fft chat probe five" to me with "invalid message"

  # ---------------------------------------------------------------------------
  # Round 3. Every delivery below targets the tester only.

  @server
  Scenario Outline: A message with no author is named after its type
    Given I watch the chat dispatch log
    When chat delivers a "<type>" message "<message>" to me without an author
    Then the chat dispatch log should hold "<message>" from "<author>"

    Examples:
      | type | message               | author |
      | say  | fft chat author say   | Local  |
      | me   | fft chat author me    | Action |
      | ooc  | fft chat author ooc   | OOC    |
      | SAY  | fft chat author upper | Local  |

  @server
  Scenario Outline: A message sent as me carries my name for its identity
    Given I watch the chat dispatch log
    When chat delivers a "<type>" message "<message>" to me as myself
    Then the chat dispatch log should hold "<message>" from my <identity> name

    Examples:
      | type | message                 | identity  |
      | say  | fft chat identity say   | character |
      | me   | fft chat identity me    | character |
      | ooc  | fft chat identity ooc   | account   |

  @server
  Scenario: A message to a list of players is delivered
    Given I watch the chat dispatch log
    When chat delivers a "say" message "fft chat probe list" to a list holding only me
    Then the chat dispatch log should hold "fft chat probe list" from "FFT Sender"

  @server
  Scenario: Surrounding whitespace is trimmed
    Given I watch the chat dispatch log
    When chat delivers the padded probe message to me
    Then chat should have accepted the probe message
    And the chat dispatch log should hold "fft chat padded" from "FFT Sender"

  @server
  Scenario: Control characters inside a message are removed
    Given I watch the chat dispatch log
    When chat delivers the control probe message to me
    Then chat should have accepted the probe message
    And the chat dispatch log should hold "fftchatcontrol" from "FFT Sender"

  @server @rejection
  Scenario: A command hidden behind leading spaces is still cancelled
    Given I watch the chat dispatch log
    When chat delivers the slash_after_spaces probe message to me
    Then chat should have refused the probe message with "cancelled"

  @server
  Scenario: A message of exactly the length limit is kept whole
    Given I watch the chat dispatch log
    When chat delivers a trusted message of 400 characters starting with "fft-exact-" to me
    Then the chat dispatch log should hold a message of 400 characters starting with "fft-exact-"

  @server
  Scenario: A message one character over the limit loses one character
    Given I watch the chat dispatch log
    When chat delivers a trusted message of 401 characters starting with "fft-over-" to me
    Then the chat dispatch log should hold a message of 400 characters starting with "fft-over-"

  @server
  Scenario: The length limit counts characters, not bytes
    Given I watch the chat dispatch log
    When chat delivers a trusted message of 401 "é" characters to me
    Then the chat dispatch log should hold a message of 400 "é" characters

  @server @rejection
  Scenario Outline: A send with bad arguments is rejected before dispatch
    Given I watch the chat dispatch log
    Then chat should reject a send with a bad <argument>
    And the chat dispatch log should not hold "fft chat bad target"
    And the chat dispatch log should not hold "fft chat bad type"
    And the chat dispatch log should not hold "fft chat bad options"

    Examples:
      | argument        |
      | target_text     |
      | target_fraction |
      | target_list     |
      | type_number     |
      | options_text    |

  @server @rejection
  Scenario Outline: A message type with a bad definition is refused
    Then registering a chat message type with a bad <field> should fail

    Examples:
      | field         |
      | name          |
      | definition    |
      | label         |
      | command       |
      | command_taken |
      | scope         |
      | range_zero    |
      | range_huge    |
      | identity      |
      | permission    |
      | icon          |
      | color_name    |
      | color_short   |
      | duration_zero |
      | duration_huge |

  @server @rejection
  Scenario Outline: Another resource cannot remove a built-in message type
    Given I watch the chat dispatch log
    Then unregistering the chat message type "<type>" from the test runner should be refused
    When chat delivers a "<type>" message "fft chat still <type>" from "FFT Sender" to me
    Then the chat dispatch log should hold "fft chat still <type>" from "FFT Sender"

    Examples:
      | type |
      | say  |
      | me   |
      | ooc  |
      | OOC  |

  @server @rejection
  Scenario: Removing a message type that does not exist reports nothing removed
    Then unregistering the chat message type "fft_never_registered" should report nothing to remove
    And unregistering a chat message type that is not text should fail

  @server @global
  Scenario: A message type name is case-insensitive
    Given I watch the chat dispatch log
    And the test runner registers the commandless chat message type "FFT_Case" in mixed case
    When chat delivers a "fft_case" message "fft chat case lower" from "FFT Sender" to me
    And chat delivers a "FFT_CASE" message "fft chat case upper" from "FFT Sender" to me
    Then the chat dispatch log should hold "fft chat case lower" from "FFT Sender"
    And the chat dispatch log should hold "fft chat case upper" from "FFT Sender"
    When the test runner unregisters the chat message type "FFT_CASE"
    Then chat should refuse to deliver a "fft_case" message "fft chat case gone" to me with "invalid message"

  @server @global
  Scenario: The owner can register its message type again and remove it once
    Given I watch the chat dispatch log
    And the test runner registers the commandless chat message type "fft_again"
    And the test runner registers the commandless chat message type "fft_again" again
    When chat delivers a "fft_again" message "fft chat again" from "FFT Sender" to me
    Then the chat dispatch log should hold "fft chat again" from "FFT Sender"
    When the test runner unregisters the chat message type "fft_again"
    Then unregistering the chat message type "fft_again" should report nothing to remove

  @global
  Scenario: My client is told when a message type is added and removed
    Given my client watches the chat event "kora_chat:typeAdded"
    And my client watches the chat event "kora_chat:typeRemoved"
    And the test runner registers the commandless chat message type "fft_notice"
    Then my client should receive "kora_chat:typeAdded" mentioning "fft_notice"
    When the test runner unregisters the chat message type "fft_notice"
    Then my client should receive "kora_chat:typeRemoved" mentioning "fft_notice"

  Scenario: My client receives a trusted message
    Given my client watches the chat event "chat:addMessage"
    When chat delivers a "say" message "fft chat client probe" from "FFT Sender" to me
    Then my client should receive "chat:addMessage" mentioning "fft chat client probe"

  @rejection
  Scenario: My client receives nothing for a refused message
    Given my client watches the chat event "chat:addMessage"
    Then chat should refuse to deliver a "say" message "/fft_chat_probe client" to me with "cancelled"
    And my client should not have received "chat:addMessage" mentioning "fft_chat_probe client"

  Scenario Outline: The stock addMessage export reaches my client
    Given my client watches the chat event "chat:addMessage"
    When the chat compatibility export on "<identity>" sends me the message "<message>"
    Then my client should receive "chat:addMessage" mentioning "<message>"

    Examples:
      | identity  | message                |
      | kora_chat | fft chat compat direct |
      | chat      | fft chat compat stock  |

  @server @rejection
  Scenario: The stock addMessage export refuses a missing message
    Then the chat compatibility export should refuse a missing message

  Scenario: Chat answers its initial state with types and command suggestions
    Given my client watches the chat event "kora_chat:types"
    And my client watches the chat event "chat:addSuggestion"
    When my client asks chat for its initial state
    Then my client should receive the chat type list with "say"
    And my client should receive the chat type list with "me"
    And my client should receive the chat type list with "ooc"
    And my client should receive "chat:addSuggestion" mentioning "/me"
    And my client should receive "chat:addSuggestion" mentioning "/ooc"

  @rejection
  Scenario Outline: A chat command without a message is refused with chat's own text
    Given I watch the chat dispatch log
    When I run the command "<command>"
    Then I should see a notification containing "Missing message for /<name>"
    And I should have dispatched no chat message

    Examples:
      | command | name |
      | ooc     | ooc  |

  @ui @rejection
  Scenario Outline: The composer runs an empty chat command, which is refused
    Given I watch the chat dispatch log
    When I submit the chat command "<name>" without a message in the composer
    Then I should see a notification containing "Missing message for /<name>"
    And I should have dispatched no chat message

    Examples:
      | name |
      | me   |
      | ooc  |

  @ui
  Scenario: The composer accepts a message of exactly the length limit
    Given I watch the chat dispatch log
    When I submit a chat composer message of 400 characters
    Then I should not see a notification containing "too long"
    And I should have dispatched no chat message

  @ui @rejection
  Scenario: The composer rejects a message one character over the limit
    Given I watch the chat dispatch log
    When I submit a chat composer message of 401 characters
    Then I should see a notification containing "Your message is too long (max 400 characters)"
    And I should have dispatched no chat message

  @ui @rejection
  Scenario: The composer ignores empty, slash-only and non-text submissions
    Given I watch the chat dispatch log
    When I submit a chat composer message of only control characters
    And I submit a lone slash in the chat composer
    And I submit a chat composer message that is not text
    And I wait 750 milliseconds
    Then I should have dispatched no chat message
    And I should not see a notification containing "too long"

  @ui @rejection
  Scenario Outline: Malformed argument suggestion requests answer an empty list
    Then chat argument suggestions for a request with a bad <part> should be empty

    Examples:
      | part            |
      | index_zero      |
      | index_over      |
      | index_fraction  |
      | index_text      |
      | long_command    |
      | long_query      |
      | many_args       |
      | unknown_command |

  @ui @rejection
  Scenario: The composer geometry callback acknowledges a malformed report
    Then the chat geometry callback should acknowledge a malformed report
