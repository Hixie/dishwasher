use strict;

# This program reads the logs from dishwasher.js and pretty-prints
# data from cycles It's incomplete because when I got to this point, I
# instead started working on the Dishwasher Model script (see model/).

my $lastCycleState = 'None';
my $lastOperatingMode = '';
my $lastActiveCycleNumber = '';
my $lastStepNumber = 0;
my $lastDoorCount = 0;
my $currentCycleState = 'None';
my $currentOperatingMode = 'Off';
my $currentActiveCycleNumber = '';
my $currentActiveCycle = '';
my $currentStepNumber = 0;
my $currentStep = 0;
my $currentDoorCount = 0;
my $currentUserConfiguration = '';
my $displayState = 0;
my $unknownCycles = {};
while (<>) {
    # PARSER
    if (m/cycleState: (.+)/) {
        $currentCycleState = $1;
        if ($currentCycleState ne 'Cycle Inactive') {
            next;
        }
    }
    if (m/operatingMode: (.+)/) {
        $currentOperatingMode = $1;
    }
    if (m/doorCount.+?([0-9]+)/) {
        $currentDoorCount = $1;
    }
    if (m/userConfiguration: (.+)/) {
        $currentUserConfiguration = $1;
    }
    if (m/activeCycle=([0-9]+)/) {
        $currentActiveCycleNumber = $1;
        if ($currentActiveCycleNumber != $lastActiveCycleNumber) {
            $lastStepNumber = -1;
        }
        die unless m/activeCycleStep=([0-9]+|nil)/;
    }
    if (m/activeCycleStep=([0-9]+|nil)/) {
        $currentStepNumber = $1;
        if ($currentStepNumber eq 'nil') {
            $currentStepNumber = 0;
        }
    }

    $currentStep = "$currentStepNumber";
   
    # turn numbers into text
    if ($currentActiveCycleNumber == 0) {
        $currentActiveCycle = '?? Steam, Heated Dry, Boost, Autosense Program';
        # step PreWash: 0, 1; MainWash: 8, 9, 10; Rinsing: 13, 14
    } elsif ($currentActiveCycleNumber == 2) {
        $currentActiveCycle = '?? Autosense Program';
    } elsif ($currentActiveCycleNumber == 3) {
        $currentActiveCycle = 'Heavy Program';
    } elsif ($currentActiveCycleNumber == 6) {
        $currentActiveCycle = 'Normal Program';
        # step 1 - silent, 1 minute
        # step 2 - sounds like filling with water, 1 minute
        # step 8 - silent
        # step 9 - spinning sounds, many minutes
        # step 10 - spinning sounds, many minutes, temperature rose
        # step 11 - first a bit of filling then spinning sounds, many minutes, temperature peaked at start
        # step 15 - 1 minute
        # step 16 - turbidity reducing, minutes
    } elsif ($currentActiveCycleNumber == 11) {
        $currentActiveCycle = 'Light Program';
    } elsif ($currentActiveCycleNumber == 15) {
        $currentActiveCycle = 'Prewash Phase A';
        # step 1 - sounds like filling with water
    } elsif ($currentActiveCycleNumber == 16) {
        $currentActiveCycle = '?? Steam Phase A';
        # step 0 - ?
        # step 1 - lots of water inside the machine when i opened it...
        # step 3 -
        # step 4 - lots of water inside the machine when i opened it...
    } elsif ($currentActiveCycleNumber == 20) {
        $currentActiveCycle = 'Draining A';
        # step 0 - silent, 1 second
        # step 1 - sounds like draining, 18 seconds
        # step 2 - silent, 20 seconds
        # step 3 - sounds like draining then motor sound?, 1 minute
    } elsif ($currentActiveCycleNumber == 21) {
        $currentActiveCycle = 'Prewash Phase B (Non-Heavy)';
        # temperature steady in this cycle, turbidity peaked
        # step 0 - sounds like spinning, 4 minutes
    } elsif ($currentActiveCycleNumber == 22) {
        $currentActiveCycle = '?? Prewash in Steam, Heated Dry, Boost, Autosense';
        # PreWash, Steam, Heated Dry, Boost, Autosense
        # step 0 - ?
        # step 1 - ?
    } elsif ($currentActiveCycleNumber == 23) {
        $currentActiveCycle = 'Normal Sanitize Rinse Phase';
        # temperatures rise during this cycle
        # step 0 - initially sounded like adding water, then silent, 1 minute
        # step 1 - ditto, 
    } elsif ($currentActiveCycleNumber == 25) {
        $currentActiveCycle = 'Heavy Program Prewash Phase D (Non-Steam)';
    } elsif ($currentActiveCycleNumber == 26) {
        $currentActiveCycle = 'Sanitize Rinse Phase';
        # step 0 - about 30 seconds
        # step 1 - sounds like spinning, turbidity reducing, many minutes
    } elsif ($currentActiveCycleNumber == 27) {
        $currentActiveCycle = 'Autosense Program Rinse Phase';
    } elsif ($currentActiveCycleNumber == 35) {
        $currentActiveCycle = 'Heavy Program Prewash Phase A';
    } elsif ($currentActiveCycleNumber == 37) {
        $currentActiveCycle = 'Heavy Program Prewash Phase C';
    } elsif ($currentActiveCycleNumber == 39) {
        $currentActiveCycle = 'Heavy Program Prewash Phase B';
    } elsif ($currentActiveCycleNumber == 52) {
        $currentActiveCycle = 'Heated dry';
    } elsif ($currentActiveCycleNumber == 56) {
        $currentActiveCycle = 'Non-Sanitizing Final Phase';
    } elsif ($currentActiveCycleNumber == 59) {
        $currentActiveCycle = 'Sanitizing';
        # step 0 - just over 1 minute, quiet sounds (filling?)
        # step 1 - spinning sounds, many many minutes, temperature rose a lot
        # step 2 - more of the same, starting around 68.3 deg C
    } elsif ($currentActiveCycleNumber == 63) {
        $currentActiveCycle = 'Standby with Sanitize Light';
        # step 4 - idle
    } elsif ($currentActiveCycleNumber == 66) {
        $currentActiveCycle = 'Inactive';
    } elsif ($currentActiveCycleNumber == 71) {
        $currentActiveCycle = 'Steam Phase B';
    } elsif ($currentActiveCycleNumber == 74) {
        $currentActiveCycle = 'Ending';
        # step 0 - 3 seconds
        # step 1 - draining, 20 seconds
        # step 2 - silent, 20 seconds
        # step 3 - draining, then motor sounds, 1 minute, then end of program
    } elsif ($currentActiveCycleNumber == 75) {
        $currentActiveCycle = 'Draining B';
        # step 0, 20 seconds
        # step 1, silent, 20 seconds
        # step 2, draining, then motor sounds, 1 minute
    } else {
        $currentActiveCycle = "Unknown cycle $currentActiveCycleNumber";
        if ($currentActiveCycleNumber != $lastActiveCycleNumber) {
            $unknownCycles->{$currentActiveCycle} += 1;
        }
    }

    # DISPLAY
    if ($currentDoorCount ne $lastDoorCount) {
        print("\n\n======= DOOR OPENED ($currentDoorCount) ========");
        $lastDoorCount = $currentDoorCount;
        $displayState = 0;
    }
    if ($currentOperatingMode ne $lastOperatingMode) {
        print("\n\n* $currentOperatingMode *");
        $lastOperatingMode = $currentOperatingMode;
        $displayState = 0;
        if ($currentOperatingMode eq 'Cycle Active') {
            print(" ($currentUserConfiguration)");
        }
    }
    if (($currentCycleState ne $lastCycleState) or
        (($displayState < 1) and
         (($currentActiveCycleNumber != $lastActiveCycleNumber) or
          ($currentStepNumber != $lastStepNumber)))) {
        print("\n$currentCycleState");
        $lastCycleState = $currentCycleState;
        $displayState = 1;
    }
    if (($currentActiveCycleNumber != $lastActiveCycleNumber) or
        (($displayState < 2) and
         ($currentStepNumber ne $lastStepNumber))) {
        if ($displayState < 2) {
            print("\n  ");
        } else {
            print("\n  ");
        }
        print("$currentActiveCycle");
        $lastActiveCycleNumber = $currentActiveCycleNumber;
        $displayState = 2;
    }
    if ($currentStepNumber != $lastStepNumber) {
        if ($displayState == 2) {
            print ": ";
        } elsif ($displayState == 3) {
            print ", ";
        } else {
            print " ??? ";
        }
        print("$currentStep");
        $lastStepNumber = $currentStepNumber;
        $displayState = 3;
    }
}
print("\n\n");
