
this is a works-for-me grade coreboot payload picker

original work was a half-afternoon project.
basicly "lets take a look at libpayload". 

because bayou doesnt build/work at all (seems to need a few years worth of libpayload updates and re-integrating into build), 
seabios has too many drivers for my taste (even when stripped down), 
and cb-grub is a mess i never want to see again.

just tested it builds by copying the dir to a coreboot/payloads/ and running "make" twice.
the resulting .elf has a reasonable size but i didnt test it just now.

the code contains a bazillion of commented out debugprints and other research leftovers.
i have been using the result "in production" for the last months, but never rebuilt it.

it may be interesting to others as anyways. 

license situation unclear since its somewhat futile to track down where the individual parts were copy-pasted from by now.
feedback not involving lawyers welcome.

