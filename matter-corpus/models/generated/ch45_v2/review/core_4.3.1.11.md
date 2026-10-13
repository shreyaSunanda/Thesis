# Review: `core_4.3.1.11` — TXT key for pairing hint (PH)

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 44.85
- module: `models/generated/ch45_v2/core_4.3.1.11/vertex-gemini/core_4_3_1_11.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 46, col 5 to line 49, col 88 of module core_4_3_1_11>
/\ piIncluded = FALSE
/\ state = "FactoryReset"
/\ phBits = {1}
/\ extendedDiscoveryEnabled = FALSE
/\ txtRecords = {}
/\ cm = 0
/\ pendingInput = "CommissionerReadTXT"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ piIncluded = FALSE
/\ state = "FactoryReset"
/\ phBits = {1}
/\ extendedDiscoveryEnabled = FALSE
/\ txtRecords = {}
/\ cm = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 46, col 5 to line 49, col 88 of module core_4_3_1_11>
/\ piIncluded = FALSE
/\ state = "FactoryReset"
/\ phBits = {1}
/\ extendedDiscoveryEnabled = FALSE
/\ txtRecords = {}
/\ cm = 0
/\ pendingInput = "CommissionerReadTXT"
```

</details>

## Spec text for this section

4.3.1.11. TXT key for pairing hint (PH)
The optional key PH MAY provide a pairing hint.
If present, it SHALL be encoded as a variable-length decimal number in ASCII text, omitting any
leading zeroes.
The pairing hint represents a base-10 numeric value for a bitmap of methods supported by the
Commissionee in its current state for putting it in Commissioning Mode.
For example, the PH=5 key/value pair represents a hint value with bits 0 and 2 are set.
This value MAY change during the lifecycle of the device.
For example, a device may have a value with bit 0 (Power Cycle) set and bit 2 (Administrator app)
unset when in a factory reset state, and then have a value with bit 0 unset and bit 2 set after it has
been Commissioned.
The bitmap of methods is defined in Table 5, “Pairing and Reset Hint Values”.
If the Commissionee has enabled Extended Discovery, then it SHALL include the key/value pair for
PH in the DNS-SD TXT record when not in Commissioning Mode (CM=0).
This key/value pair MAY be returned when in Commissioning Mode (CM=1).
If the Commissioner does not recognize this value, for example, if the value indicates bit indices
defined in a newer version of this specification than the version which the Commissioner implements, then the Commissioner MAY utilize the bits that it does understand and MAY utilize addi­
tional data sets available for assisting the user. For example, when a Vendor ID and Product ID are
available to the Commissioner, the Section 11.23, “Distributed Compliance Ledger” may also provide a URL for the Device User Guide which can contain additional information to help in Commis­
sioning this Commissionee.
Some of the pairing hints SHALL or MAY require additional information to be encoded for proper
expression of their meaning. This is accomplished with the PI TXT key, described in a following section. Dependency on usage of the PI key is expressed by the Instruction Dependency column in the
table below. For some entries, the use of the PI key is mandatory (indicated as M), while for some
other entries, the use of the PI key is optional (indicated as O). For the remaining entries the use of
the PI key does not apply (indicated as no).
The fields in the bitmap are defined for values of the PH key in the Pairing and Reset Hint Values table below. This bitmap describes methods for putting the device into a specific target state. It is ref­
erenced here to describe methods for putting the device into Commissioning Mode, and it is referenced elsewhere to describe methods for putting the device into other states, such as the Factory
Reset state in the DCL DeviceModel Schema’s FactoryResetStepsHint field.
Table 5. Pairing and Reset Hint Values
Bit
ind
ex
Name
Ins
tru
ctio
n
De
pen
den
cy
Description
Power Cycle
no
The Device will automatically enter the target state upon power
cycle (unplug/re-plug, remove/re-insert batteries). When used with
the target state of Commissioning Mode for a device that is in a factory reset state, this bit SHALL be set to 1 for devices using Standard
Commissioning Flow, and set to 0 otherwise.
Device Manufacturer URL/App
no
To put the device into the desired state, the user can be sent to the
URL specified in the CommissioningCustomFlowUrl of the DeviceModel
schema entry indexed by the Vendor ID and Product ID (e.g., as
found in the announcement) in the Distributed Compliance Ledger.
This URL could lead to a page with instructions, or to an app with
instructions. When used with the target state of Commissioning
Mode for a device that is in a factory reset state, this bit SHALL be
set to 1 for devices requiring Custom Commissioning Flow before
they can be available for Commissioning by any Commissioner.
Administrator
no
The Device has been commissioned. Any Administrator that commissioned the device provides a user interface that may be used to put
the device into Commissioning Mode.
Settings menu on
the Node
no
The settings menu on the Device provides instructions to put it into
the desired state.
Custom Instruction
M
The PI key/value pair SHALL describe a custom way to put the
Device into the target state. This Custom Instruction option is NOT
recommended for use by a Device that does not have knowledge of
the user’s language preference.
Device Manual
no
The Device Manual provides special instructions to put the Device
into the target state (see Section 11.23.6.16, “UserManualUrl”). This is
a catch-all option to capture user interactions that are not codified
by other options in this table.
Press Reset Button no
The Device will enter the target state when reset button is pressed.
Press Reset Button
with application of
power
no
The Device will enter the target state when reset button is pressed
when applying power to it.
Bit
ind
ex
Name
Ins
tru
ctio
n
De
pen
den
cy
Description
Press Reset Button
for N seconds
M
The Device will enter the target state when reset button is pressed
for N seconds. The exact value of N SHALL be made available via PI
key.
Press Reset Button
until light blinks
O
The Device will enter the target state when reset button is pressed
until associated light blinks. Information on color of light MAY be
made available via PI key (see Note 1).
Press Reset Button
for N seconds with
application of
power
M
The Device will enter the target state when reset button is pressed
for N seconds when applying power to it. The exact value of N
SHALL be made available via PI key.
Press Reset Button
until light blinks
with application of
power
O
The Device will enter the target state when reset button is pressed
until associated light blinks when applying power to the Device.
Information on color of light MAY be made available via PI key (see
Note 1).
Press Reset Button
N times
M
The Device will enter the target state when reset button is pressed N
times with maximum 1 second between each press. The exact value
of N SHALL be made available via PI key.
Press Setup Button no
The Device will enter the target state when setup button is pressed.
Press Setup Button
with application of
power
no
The Device will enter the target state when setup button is pressed
when applying power to it.
Press Setup Button
for N seconds
M
The Device will enter the target state when setup button is pressed
for N seconds. The exact value of N SHALL be made available via PI
key.
Press Setup Button
until light blinks
O
The Device will enter the target state when setup button is pressed
until associated light blinks. Information on color of light MAY be
made available via PI key (see Note 1).
Press Setup Button
for N seconds with
application of
power
M
The Device will enter the target state when setup button is pressed
for N seconds when applying power to it. The exact value of N
SHALL be made available via PI key.
Bit
ind
ex
Name
Ins
tru
ctio
n
De
pen
den
cy
Description
Press Setup Button
until light blinks
with application of
power
O
The Device will enter the target state when setup button is pressed
until associated light blinks when applying power to the Device.
Information on color of light MAY be made available via PI key (see
Note 1).
Press Setup Button
N times
M
The Device will enter the target state when setup button is pressed N
times with maximum 1 second between each press. The exact value
of N SHALL be made available via PI key.
Power Cycle N
times
M
The Device will automatically enter the target state after exactly N
power OFF/ON sequences (unplug/re-plug, remove/re-insert batteries) starting from the powered ON state. A non-zero X value provides
the minimum number of seconds to keep the device in the ON state
before the next iteration. A non-zero Y value specifies the total
elapsed time during which exactly N power cycles must be detected
in order to enter the desired state. A non-zero Z value means that the
device will blink Z times to indicate that the sequence was detected,
before entering the desired state. If a variable (X, Y, or Z) is set to 0,
then the corresponding aspect of the instruction is not specified. The
format of the PI key’s value SHALL be N,X,Y,Z where N,X,Y and Z are
variable length decimal values (no leading zeros) and there are no
spaces or other characters present in the value.
For example, 5,1,10,3 indicates that within 10 seconds the device
must be powered OFF then ON 5 times, remaining in the ON state
each time for at least 1 second, and the device will blink 3 times to
indicate success before entering the target state. Alternatively,
8,0,20,0 indicates that within 20 seconds the device must be powered OFF then ON 8 times in order to enter the target state.
Bit
ind
ex
Name
Ins
tru
ctio
n
De
pen
den
cy
Description
Press Button for N
seconds with indication
M
The Device will enter the target state when the button is pressed for
N seconds. A non-zero Z value means that the device will blink Z
times to indicate that the action was detected, before entering the
desired state. A present and non-blank A value can be used to specify the button(s) where buttons are indicated using HDMI CEC Key
Codes (see HDMI) in hexadecimal notation separated by operators
'&' and '|' to indicate 'and' (both buttons) and 'or' (any of the buttons)
respectively. The format of the PI key’s value SHALL be N,Z or N,Z,A,
where N and Z are variable length decimal values (no leading zeros),
A is blank or a combination of CEC Key Codes separated by '&' or '|',
and there are no spaces or other characters present in the value.
For example, 10,3 indicates that any button can be held for 10 seconds, and the device will blink 3 times before entering the target
state. Additional examples: 5,,0x46 indicates that the pause button
(CEC Key Code 0x46) must be held for 5 seconds, 5,,0x01&0x02 indicates that the up and down buttons (CEC Key Codes 0x01 and 0x02)
must be held 5 secs, and 5,,0x01|0x02 indicates that either the up or
down buttons must be held 5 secs.
Bit
ind
ex
Name
Ins
tru
ctio
n
De
pen
den
cy
Description
Power Cycle Until
Indication
M
The Device will automatically enter the target state after a variable
number of power OFF/ON sequences (unplug/re-plug, remove/re-
insert batteries) starting from the powered ON state. A non-zero X
value provides the number of seconds to keep the device in the ON
state before moving to the OFF state. A non-zero Y value provides
the number of seconds to keep the device in the OFF state before
moving to the ON state. A non-zero Z value means that the device
will blink Z times to indicate that the sequence was detected, before
entering the desired state. An M value can be used to indicate the
color name of the light blink, where the color name may be one of:
white, red, green, blue, orange, yellow, purple, cool white, warm
white, sequence (for rainbow sequence). An N value can be used to
indicate the initial state (OFF or ON), where the default when missing or left blank is ON. If the variable X, Y, Z, M or N is blank or set to
0, then the corresponding aspect of the instruction is not specified.
The format of the PI key’s value SHALL be X,Y,Z,M,N where X, Y and
Z are variable length decimal values (no leading zeros) and there are
no spaces or other characters present in the value, while M is a single color name, and N, when present, is one of either ON or OFF.
For example, 1,2,3,yellow,ON indicates that the device must be powered OFF then ON repeatedly, starting in the ON state, remaining in
the ON state each time for 1 second, remaining in the OFF state each
time for 2 seconds, and the device will blink in yellow 3 times to
indicate success before entering the target state. Alternatively,
0,0,0,sequence indicates that the device must be powered OFF then
ON repeatedly until it blinks in a sequence of colors to indicate it has
entered the target state.
Note 1: When the PH key indicates a light to blink (one or more of bits 9, 11, 16 or 18 is set), information on color of light MAY be made available via PI key. When using such color indication in PI key,
only basic primary and secondary colors that could unambiguously be decoded by a commissioner
and understood by an end-user, but without worry of localization, SHOULD be used, e.g. white, red,
green, blue, orange, yellow, purple, unless otherwise specified.
Note 2: Any undefined values are reserved for future use.
Note 3: A Commissionee can indicate multiple methods of being put into Commissioning Mode by
setting multiple bits in the bitmap at the same time. However, only one such method can be speciMatter Specification R1.6
fied which has a mandatory dependency on the PI key (PI Dependency=M) at a time.
For example:
• A PH value of 33 (bits 0 and 5 are set) indicates that the user can cause the Commissionee to
enter Commissioning Mode by either power cycling it or by following special instructions provided in the Device Manual.
• A PH value of 9 (bits 0 and 3 are set) indicates that the user can cause the Commissionee to enter
Commissioning Mode by either power cycling it or going to the settings menu and following
instructions there.
• A PH value of 1 (bit 0 is set) indicates that the user can cause the Commissionee to enter Commissioning Mode only by power cycling it.
• A PH value of 16 (bit 4 is set) indicates that the user can cause the Commissionee to enter Commissioning Mode following a custom procedure described by the value of the PI key.
• A PH value of 256 (bits 8 is set) indicates that the user can cause the Commissionee to enter Commissioning Mode by pressing the reset button for a duration of time in seconds specified via by
the value of the PI key.
When the PH key is provided, at least one bit in the above bitmap SHALL be set. That is, a PH value of
0 is undefined and illegal.
When the PH key is provided, the Commissioner SHOULD take its value into account when providing guidance to the user regarding steps required to put the Commissionee into Commissioning
Mode.
